/**
 * 老师标签颜色算法：名字字符串哈希转 HSL（色相 0~359，饱和度 70%，亮度 50%），确保非灰、非黑、非白。
 */
export function getTeacherHslColor(name) {
  if (!name) {
    return {
      bg: 'hsl(200, 70%, 50%)',
      color: '#ffffff',
      border: 'hsl(200, 70%, 42%)',
    };
  }

  let hash = 0;
  for (let i = 0; i < name.length; i++) {
    hash = (hash << 5) - hash + name.charCodeAt(i);
    hash |= 0;
  }

  const hue = Math.abs(hash) % 360;
  return {
    bg: `hsl(${hue}, 70%, 50%)`,
    color: '#ffffff',
    border: `hsl(${hue}, 70%, 42%)`,
    rawHue: hue,
  };
}

/**
 * 08:00 - 22:00，每 30 分钟一个 slot，全天共 28 个 slot (0..27)
 * slot 0: 08:00-08:30 ... slot 27: 21:30-22:00
 */
export function getSlotTimeRange(slotIndex) {
  const startMinutesTotal = 8 * 60 + slotIndex * 30;
  const endMinutesTotal = startMinutesTotal + 30;

  const startH = Math.floor(startMinutesTotal / 60).toString().padStart(2, '0');
  const startM = (startMinutesTotal % 60).toString().padStart(2, '0');

  const endH = Math.floor(endMinutesTotal / 60).toString().padStart(2, '0');
  const endM = (endMinutesTotal % 60).toString().padStart(2, '0');

  return `${startH}:${startM} - ${endH}:${endM}`;
}

/**
 * 生成全天 28 个时段的基础列表
 */
export function getAllSlots() {
  return Array.from({ length: 28 }, (_, index) => ({
    index,
    timeRange: getSlotTimeRange(index),
  }));
}
