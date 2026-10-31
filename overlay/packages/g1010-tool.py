#!/usr/bin/env python3
"""Canon PIXMA G1010 printhead maintenance tool (IVEC XML protocol)."""

import argparse
import datetime
import glob
import os
import subprocess
import sys

NS_IVEC = 'xmlns:ivec="http://www.canon.com/ns/cmd/2008/07/common/"'
NS_VCN = 'xmlns:vcn="http://www.canon.com/ns/cmd/2008/07/canon/"'
JOB_ID = "00000002"

GROUP_MAP = {
    "all": "all",
    "black": "group1",
    "bk": "group1",
    "group1": "group1",
    "color": "group2",
    "colour": "group2",
    "cmy": "group2",
    "group2": "group2",
}


def build_ivec_job(operation: str, mtype: str, inkgroup: str | None = None) -> bytes:
    now = datetime.datetime.now().strftime("%Y%m%d%H%M%S")
    start = (
        f'<?xml version="1.0" encoding="utf-8" ?>'
        f"<cmd {NS_IVEC} {NS_VCN}><ivec:contents>"
        f"<ivec:operation>StartJob</ivec:operation>"
        f'<ivec:param_set servicetype="maintenance">'
        f"<ivec:jobID>{JOB_ID}</ivec:jobID>"
        f"<ivec:bidi>0</ivec:bidi>"
        f"<ivec:jobname/><ivec:username/><ivec:computername/>"
        f"<ivec:job_description><![CDATA[maintenance]]></ivec:job_description>"
        f"<vcn:host_environment>linux</vcn:host_environment>"
        f"</ivec:param_set></ivec:contents></cmd>"
    )
    cfg = (
        f'<?xml version="1.0" encoding="utf-8" ?>'
        f"<cmd {NS_IVEC} {NS_VCN}><ivec:contents>"
        f"<ivec:operation>SetJobConfiguration</ivec:operation>"
        f'<ivec:param_set servicetype="maintenance">'
        f"<ivec:jobID>{JOB_ID}</ivec:jobID>"
        f"<ivec:datetime>{now}</ivec:datetime>"
        f"</ivec:param_set></ivec:contents></cmd>"
    )
    group_xml = f"<ivec:inkgroup>{inkgroup}</ivec:inkgroup>" if inkgroup else ""
    body = (
        f'<?xml version="1.0" encoding="utf-8"?>'
        f"<cmd {NS_IVEC}><ivec:contents>"
        f"<ivec:operation>{operation}</ivec:operation>"
        f'<ivec:param_set servicetype="maintenance">'
        f"{group_xml}"
        f"<ivec:type>{mtype}</ivec:type>"
        f"<ivec:jobID>{JOB_ID}</ivec:jobID>"
        f"</ivec:param_set></ivec:contents></cmd>"
    )
    end = (
        f'<?xml version="1.0" encoding="utf-8" ?>'
        f"<cmd {NS_IVEC}><ivec:contents>"
        f"<ivec:operation>EndJob</ivec:operation>"
        f'<ivec:param_set servicetype="maintenance">'
        f"<ivec:jobID>{JOB_ID}</ivec:jobID>"
        f"</ivec:param_set></ivec:contents></cmd>"
    )
    return (start + cfg + body + end).encode("utf-8")


def find_cups_queue() -> str | None:
    try:
        out = subprocess.check_output(["lpstat", "-v"], text=True, stderr=subprocess.DEVNULL)
    except Exception:
        return None
    for line in out.splitlines():
        if any(k in line.lower() for k in ("g1010", "g1000", "g4000", "canon")):
            # format: device for <queue>: <uri>
            prefix = "device for "
            if line.startswith(prefix) and ":" in line:
                return line[len(prefix) :].split(":", 1)[0].strip()
    try:
        out = subprocess.check_output(["lpstat", "-d"], text=True, stderr=subprocess.DEVNULL)
        if ":" in out:
            return out.split(":", 1)[1].strip()
    except Exception:
        pass
    return None


def send_payload(payload: bytes, device: str | None, queue: str | None, to_stdout: bool, title: str) -> None:
    if to_stdout:
        sys.stdout.buffer.write(payload)
        sys.stdout.buffer.flush()
        return

    if device:
        with open(device, "wb") as f:
            f.write(payload)
        print(f"Sent '{title}' ({len(payload)} bytes) directly to {device}", file=sys.stderr)
        return

    q = queue or find_cups_queue()
    if q:
        subprocess.run(
            ["lp", "-d", q, "-o", "raw", "-t", f"G1010 {title}"],
            input=payload,
            check=True,
        )
        print(f"Submitted raw maintenance job '{title}' to CUPS queue '{q}'", file=sys.stderr)
        return

    devs = sorted(glob.glob("/dev/usb/lp*"))
    if devs and os.access(devs[0], os.W_OK):
        with open(devs[0], "wb") as f:
            f.write(payload)
        print(f"Sent '{title}' ({len(payload)} bytes) directly to {devs[0]}", file=sys.stderr)
        return

    sys.exit(
        "Error: no CUPS queue or writable /dev/usb/lp* found.\n"
        "Specify a CUPS queue with '-P <queue>' or a USB device with '-d /dev/usb/lp0'."
    )


def main() -> None:
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("-P", "--queue", help="CUPS printer queue name (sends via 'lp -o raw')")
    common.add_argument("-d", "--device", help="Direct USB printer device node (e.g. /dev/usb/lp0)")
    common.add_argument("--stdout", action="store_true", help="Write raw IVEC XML packet to stdout and exit")

    p = argparse.ArgumentParser(
        prog="g1010-tool",
        description="Canon PIXMA G1010 printhead maintenance utility (IVEC XML protocol).",
        parents=[common],
    )

    sub = p.add_subparsers(dest="cmd", required=True)

    sub.add_parser("nozzle", parents=[common], help="Print nozzle check pattern (load 1 sheet of A4 plain paper)")

    p_clean = sub.add_parser("clean", parents=[common], help="Regular printhead cleaning")
    p_clean.add_argument(
        "-g", "--group", default="all", choices=list(GROUP_MAP.keys()), help="Ink group (default: all)"
    )

    p_deep = sub.add_parser("deep-clean", parents=[common], help="Deep printhead cleaning")
    p_deep.add_argument(
        "-g",
        "--group",
        default="all",
        choices=["all", "black", "bk", "group1"],
        help="Ink group (G1010 deep cleaning supports all or black; default: all)",
    )

    p_flush = sub.add_parser("flush", parents=[common], help="System ink flush / tube purge (consumes a lot of ink)")
    p_flush.add_argument(
        "-g", "--group", default="all", choices=list(GROUP_MAP.keys()), help="Ink group (default: all)"
    )
    p_flush.add_argument("-y", "--yes", action="store_true", help="Skip confirmation prompt")

    sub.add_parser("roller", parents=[common], help="Paper feed roller cleaning")
    sub.add_parser("platen", parents=[common], help="Bottom plate (platen) cleaning")
    sub.add_parser("regi-check", parents=[common], help="Print head alignment check pattern")
    args = p.parse_args()

    if args.cmd == "nozzle":
        payload = build_ivec_job("TestPrint", "nozzle_check")
        send_payload(payload, args.device, args.queue, args.stdout, "Nozzle Check")
    elif args.cmd == "clean":
        grp = GROUP_MAP[args.group]
        payload = build_ivec_job("Cleaning", "regular", grp)
        send_payload(payload, args.device, args.queue, args.stdout, f"Regular Cleaning ({grp})")
    elif args.cmd == "deep-clean":
        grp = GROUP_MAP[args.group]
        payload = build_ivec_job("Cleaning", "deep", grp)
        send_payload(payload, args.device, args.queue, args.stdout, f"Deep Cleaning ({grp})")
    elif args.cmd == "flush":
        if not args.stdout and not args.yes:
            ans = input("Ink flush (choke cleaning) consumes a large amount of ink. Continue? [y/N] ")
            if ans.strip().lower() not in ("y", "yes"):
                sys.exit("Aborted.")
        grp = GROUP_MAP[args.group]
        payload = build_ivec_job("Cleaning", "choke", grp)
        send_payload(payload, args.device, args.queue, args.stdout, f"Ink Flush ({grp})")
    elif args.cmd == "roller":
        payload = build_ivec_job("RollerCleaning", "roller")
        send_payload(payload, args.device, args.queue, args.stdout, "Roller Cleaning")
    elif args.cmd == "platen":
        payload = build_ivec_job("RollerCleaning", "platen")
        send_payload(payload, args.device, args.queue, args.stdout, "Platen Cleaning")
    elif args.cmd == "regi-check":
        payload = build_ivec_job("TestPrint", "regi_check")
        send_payload(payload, args.device, args.queue, args.stdout, "Alignment Check")


if __name__ == "__main__":
    main()
