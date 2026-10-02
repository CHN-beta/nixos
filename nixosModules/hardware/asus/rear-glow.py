"""Flowing rainbow for the ROG Flow Z13 (GZ302EA) rear window.

The rear window is the ``0b05:18c6`` USB device and is reachable through two
HID interfaces:

* a standard HID LampArray interface (usage page ``0x59``) exposing 11
  independently programmable lamps;
* a vendor "Aura" interface (output report id ``0x5d``) whose power message
  has to be sent once so the rear zone is actually powered while awake.

This script takes host control of the LampArray interface and streams a hue
gradient over the lamps, which produces the same slowly flowing rainbow the
Windows tooling shows.  ``--once`` renders a single static gradient frame.

Nothing else is touched; on exit (SIGTERM/SIGINT) the firmware regains
autonomous control of the device.
"""

import argparse
import fcntl
import glob
import os
import signal
import struct
import sys
import time

VID_PID = "HID_ID=0003:00000B05:000018C6"
LAMPARRAY_PREFIX = b"\x06\x59\x00"  # usage page 0x59, usage LampArray
VENDOR_REPORT_ID = b"\x85\x5d"      # output report id 0x5d, Aura packets

AURA_ID = 0x5D
AURA_OUT_SIZE = 64                  # report size declared for report id 0x5d
# vendor power message: all of keyboard/bar/lid/rear enabled while awake
AURA_POWER_ALL_ON = bytes([AURA_ID, 0xBD, 0x01, 0xFF, 0xFF, 0xFF, 0xFF])

R_MULTI, R_CTRL = 0x04, 0x06
MULTI_SLOTS = 8                     # slots per LampMultiUpdateReport
MULTI_SIZE = 1 + 2 + 2 * MULTI_SLOTS + 4 * MULTI_SLOTS
CTRL_SIZE = 2


def _ioc(direction, typ, nr, size):
    return (direction << 30) | (size << 16) | (ord(typ) << 8) | nr


def get_feature(fd, report_id, size):
    buf = bytearray(size)
    buf[0] = report_id
    fcntl.ioctl(fd, _ioc(3, "H", 0x07, size), buf, True)  # HIDIOCGFEATURE
    return bytes(buf)


def set_feature(fd, data):
    buf = bytearray(data)
    fcntl.ioctl(fd, _ioc(3, "H", 0x06, len(buf)), buf, True)  # HIDIOCSFEATURE


def find_devices():
    """Return (lamparray, vendor) hidraw paths for 0b05:18c6."""
    lamparray = vendor = None
    for sysfs in sorted(glob.glob("/sys/class/hidraw/hidraw*")):
        try:
            with open(sysfs + "/device/uevent") as fh:
                if VID_PID not in fh.read():
                    continue
            with open(sysfs + "/device/report_descriptor", "rb") as fh:
                descriptor = fh.read()
        except OSError:
            continue
        node = "/dev/" + os.path.basename(sysfs)
        if descriptor.startswith(LAMPARRAY_PREFIX):
            lamparray = node
        elif VENDOR_REPORT_ID in descriptor:
            vendor = node
    return lamparray, vendor


def lamp_count(fd):
    return struct.unpack_from("<H", get_feature(fd, 0x01, 23), 1)[0]


def set_autonomous(fd, enabled):
    set_feature(fd, bytes([R_CTRL, 1 if enabled else 0]))


def write_lamps(fd, colors):
    """colors: sequence of (lamp id, r, g, b, intensity)."""
    chunks = [colors[i:i + MULTI_SLOTS] for i in range(0, len(colors), MULTI_SLOTS)]
    for index, chunk in enumerate(chunks):
        buf = bytearray(MULTI_SIZE)
        buf[0] = R_MULTI
        buf[1] = len(chunk)                       # LampCount
        buf[2] = 0x01 if index == len(chunks) - 1 else 0x00  # LampUpdateComplete
        for slot, (lamp_id, *_rest) in enumerate(chunk):
            struct.pack_into("<H", buf, 3 + 2 * slot, lamp_id)
        base = 3 + 2 * MULTI_SLOTS
        for slot, (_id, red, green, blue, intensity) in enumerate(chunk):
            buf[base + 4 * slot:base + 4 * slot + 4] = bytes(
                [red, green, blue, intensity]
            )
        set_feature(fd, bytes(buf))


def hsv_to_rgb(hue, value=1.0, saturation=1.0):
    hue = hue % 360.0
    chroma = value * saturation
    second = chroma * (1 - abs((hue / 60.0) % 2 - 1))
    offset = value - chroma
    segment = int(hue // 60) % 6
    red, green, blue = [
        (chroma, second, 0.0),
        (second, chroma, 0.0),
        (0.0, chroma, second),
        (0.0, second, chroma),
        (second, 0.0, chroma),
        (chroma, 0.0, second),
    ][segment]
    return (
        round((red + offset) * 255),
        round((green + offset) * 255),
        round((blue + offset) * 255),
    )


def paint(fd, count, phase, direction, intensity, hue_span):
    step = hue_span / count
    colors = []
    for lamp in range(count):
        hue = lamp * step * direction + phase
        red, green, blue = hsv_to_rgb(hue)
        colors.append((lamp, red, green, blue, intensity))
    write_lamps(fd, colors)


class RearGlow:
    def __init__(self, args):
        self.args = args
        self.fd = None
        self.count = 0
        self.vendor_fd = None
        self.vendor_due = 0.0
        self.stopping = False

    def open(self):
        lamparray, vendor = find_devices()
        if lamparray is None:
            raise OSError("no HID LampArray interface for 0b05:18c6")
        self.fd = os.open(lamparray, os.O_RDWR)
        self.count = lamp_count(self.fd)
        if self.args.vendor_enable and vendor is not None and self.vendor_fd is None:
            self.vendor_fd = os.open(vendor, os.O_RDWR)
        self.vendor_power()
        set_autonomous(self.fd, False)
        self.vendor_due = time.monotonic() + self.args.vendor_refresh

    def vendor_power(self):
        """(Re)assert the rear-zone power state on the vendor interface."""
        if self.vendor_fd is None:
            return
        buf = bytearray(AURA_OUT_SIZE)
        buf[: len(AURA_POWER_ALL_ON)] = AURA_POWER_ALL_ON
        os.write(self.vendor_fd, buf)

    def release(self, autonomous=True):
        if self.fd is not None and autonomous:
            try:
                set_autonomous(self.fd, True)
            except OSError:
                pass
        for fd in (self.fd, self.vendor_fd):
            if fd is not None:
                try:
                    os.close(fd)
                except OSError:
                    pass
        self.fd = self.vendor_fd = None

    def stop(self, *_args):
        self.stopping = True

    def run(self):
        signal.signal(signal.SIGTERM, self.stop)
        signal.signal(signal.SIGINT, self.stop)
        attempts = 0
        while not self.stopping:
            try:
                self.open()
                attempts = 0
            except OSError as error:
                attempts += 1
                if attempts > self.args.retries:
                    print(f"giving up: {error}", file=sys.stderr)
                    return 1
                print(f"device unavailable ({error}), retrying", file=sys.stderr)
                self.stopping = self.wait(2.0)
                continue
            print(
                f"driving {self.count} lamps: speed={self.args.speed} deg/s "
                f"fps={self.args.fps} direction={self.args.direction}",
                file=sys.stderr,
            )
            try:
                self.animate()
            except OSError as error:
                print(f"lost device: {error}", file=sys.stderr)
                attempts += 1
                if attempts > self.args.retries:
                    self.release(autonomous=False)
                    return 1
                self.release(autonomous=False)
            else:
                self.release()
                return 0
        return 0

    def wait(self, seconds):
        deadline = time.monotonic() + seconds
        while not self.stopping and time.monotonic() < deadline:
            time.sleep(0.1)
        return self.stopping

    def animate(self):
        sign = -1 if self.args.direction == "reverse" else 1
        start = time.monotonic()
        frame = 0
        while not self.stopping:
            now = time.monotonic()
            if self.args.vendor_refresh and now >= self.vendor_due:
                self.vendor_power()
                self.vendor_due = now + self.args.vendor_refresh
            phase = (self.args.speed * (now - start)) % 360.0
            paint(self.fd, self.count, phase, sign, self.args.intensity, self.args.span)
            frame += 1
            delay = start + frame / self.args.fps - time.monotonic()
            if delay > 0:
                time.sleep(delay)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--speed", type=float, default=30.0,
                        help="hue degrees per second (default: %(default)s)")
    parser.add_argument("--fps", type=float, default=30.0,
                        help="update rate, device minimum interval is 2 ms")
    parser.add_argument("--direction", choices=["forward", "reverse"],
                        default="forward")
    parser.add_argument("--intensity", type=int, default=255,
                        help="0-255, clamped to the device's level count")
    parser.add_argument("--span", type=float, default=360.0,
                        help="total hue range spread across the lamps")
    parser.add_argument("--vendor-enable", dest="vendor_enable",
                        action="store_true", default=True,
                        help="send the vendor power message (default)")
    parser.add_argument("--no-vendor-enable", dest="vendor_enable",
                        action="store_false")
    parser.add_argument("--vendor-refresh", type=float, default=0.0,
                        help="re-send the vendor power message every N "
                             "seconds; 0 sends it once at start (default). "
                             "Every re-send makes the EC re-initialise the "
                             "zone, which blinks the strip")
    parser.add_argument("--retries", type=int, default=15)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--once", action="store_true",
                      help="render one static gradient frame and exit")
    mode.add_argument("--off", action="store_true",
                      help="turn the lamps off and exit")
    mode.add_argument("--auto-on", action="store_true",
                      help="hand control back to the firmware and exit")
    mode.add_argument("--probe", action="store_true",
                      help="print the detected interfaces and exit")
    args = parser.parse_args()

    if args.probe:
        lamparray, vendor = find_devices()
        if lamparray is None:
            print("0b05:18c6 LampArray interface not found")
            return 1
        fd = os.open(lamparray, os.O_RDWR)
        try:
            print(f"LampArray: {lamparray}  vendor: {vendor}  "
                  f"lamps: {lamp_count(fd)}")
        finally:
            os.close(fd)
        return 0

    glow = RearGlow(args)
    if args.auto_on:
        glow.open()
        set_autonomous(glow.fd, True)
        glow.release(autonomous=False)
        return 0
    if args.off:
        glow.open()
        write_lamps(glow.fd, [(lamp, 0, 0, 0, 0) for lamp in range(glow.count)])
        glow.release()
        return 0
    if args.once:
        glow.open()
        paint(glow.fd, glow.count, 0.0, 1, args.intensity, args.span)
        glow.release()
        return 0
    return glow.run()


if __name__ == "__main__":
    sys.exit(main())
