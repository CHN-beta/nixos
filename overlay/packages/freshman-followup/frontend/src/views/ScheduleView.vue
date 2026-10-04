<template>
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-5">
    <!-- Header -->
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-4">
      <div>
        <h2 class="text-lg font-bold text-slate-800 flex items-center space-x-2">
          <span>心理咨询师值班排班表</span>
          <span class="text-xs bg-emerald-50 text-emerald-700 border border-emerald-200 px-2 py-0.5 rounded-full font-medium">
            全天 28 时段 · 8 列固定展示
          </span>
        </h2>
        <p class="text-xs text-slate-500 mt-0.5">纵轴为 28 个半小时时段，横轴为 8 个固定咨询师列（老师可固定在专属列连续排班）</p>
      </div>

      <button
        @click="loadSchedules"
        class="self-start sm:self-auto inline-flex items-center space-x-1.5 px-3 py-1.5 rounded-lg border border-slate-200 bg-white text-xs text-slate-600 hover:bg-slate-50 transition-colors shadow-sm"
      >
        <svg class="w-3.5 h-3.5 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path>
        </svg>
        <span>刷新排班</span>
      </button>
    </div>

    <!-- Date Selection Bar -->
    <div class="bg-white p-3.5 rounded-xl border border-slate-200 shadow-sm mb-4">
      <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div class="flex items-center space-x-2 overflow-x-auto pb-1 sm:pb-0">
          <span class="text-xs font-semibold text-slate-600 shrink-0">排班日期：</span>
          <button
            v-for="d in availableDates"
            :key="d.date"
            @click="selectDate(d.date)"
            type="button"
            class="px-3 py-1.5 rounded-lg text-xs font-medium transition-all shrink-0 border"
            :class="selectedDate === d.date
              ? 'bg-emerald-600 text-white border-emerald-600 shadow-sm'
              : 'bg-slate-50 text-slate-700 border-slate-200 hover:bg-slate-100'"
          >
            {{ formatDateLabel(d.date) }}
          </button>
        </div>

        <!-- Legend & Stats -->
        <div class="flex items-center space-x-3 text-xs text-slate-500 pt-2 sm:pt-0 border-t sm:border-t-0 border-slate-100 shrink-0">
          <div class="flex items-center space-x-1.5">
            <span class="w-2.5 h-2.5 rounded-full bg-emerald-500"></span>
            <span>空闲: <strong class="text-slate-700">{{ stats.free }}</strong></span>
          </div>
          <div class="flex items-center space-x-1.5">
            <span class="w-2.5 h-2.5 rounded-full bg-[#D1D5DB]"></span>
            <span>已预约: <strong class="text-slate-700">{{ stats.booked }}</strong></span>
          </div>
          <div class="text-slate-400">
            总计: <strong class="text-slate-700">{{ stats.total }}</strong>
          </div>
        </div>
      </div>
    </div>

    <!-- 2D Grid Board: 28 Rows x 8 Columns -->
    <div class="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">
      <!-- Loading -->
      <div v-if="loading" class="py-20 text-center text-xs text-slate-400">
        <div class="inline-block animate-spin rounded-full h-8 w-8 border-4 border-emerald-500 border-t-transparent mb-2"></div>
        <p>加载排班数据中...</p>
      </div>

      <!-- Matrix Table -->
      <div v-else class="overflow-x-auto">
        <table class="min-w-[960px] w-full border-collapse text-xs">
          <!-- Table Header: Columns -->
          <thead>
            <tr class="bg-slate-100/80 border-b border-slate-200 text-slate-700">
              <th class="p-2.5 w-32 min-w-[128px] text-left font-semibold sticky left-0 bg-slate-100 z-10 border-r border-slate-200 shadow-xs">
                时段 (纵轴)
              </th>
              <th
                v-for="colIndex in 8"
                :key="colIndex - 1"
                class="p-2.5 text-center font-semibold border-r border-slate-200 last:border-r-0 min-w-[105px]"
              >
                <div class="flex flex-col items-center">
                  <span class="font-bold text-slate-800">第 {{ colIndex }} 列</span>
                  <span
                    v-if="getColumnSummary(colIndex - 1)"
                    class="text-[10px] text-emerald-700 bg-emerald-50 border border-emerald-200/80 px-1.5 py-0.2 rounded-full mt-0.5 max-w-[95px] truncate font-normal"
                    :title="getColumnSummary(colIndex - 1)"
                  >
                    {{ getColumnSummary(colIndex - 1) }}
                  </span>
                </div>
              </th>
            </tr>
          </thead>

          <!-- Table Body: 28 Slots Rows -->
          <tbody class="divide-y divide-slate-100">
            <tr
              v-for="slot in slotsData"
              :key="slot.index"
              class="hover:bg-slate-50/40 transition-colors"
            >
              <!-- Left Sticky Time Column -->
              <td class="p-2 w-32 min-w-[128px] sticky left-0 bg-white border-r border-slate-200 z-10 shadow-xs">
                <div
                  @click="openSlotModal(slot, null)"
                  class="cursor-pointer group flex items-center space-x-1.5 hover:text-emerald-700"
                  title="点击管理此时段所有排班"
                >
                  <span class="w-4 h-4 rounded-full bg-slate-100 group-hover:bg-emerald-100 group-hover:text-emerald-700 text-slate-500 flex items-center justify-center text-[10px] font-mono shrink-0">
                    {{ slot.index + 1 }}
                  </span>
                  <span class="font-mono text-slate-700 font-semibold text-[11px] group-hover:underline">
                    {{ slot.timeRange }}
                  </span>
                </div>
              </td>

              <!-- 8 Grid Columns -->
              <td
                v-for="colIndex in 8"
                :key="colIndex - 1"
                class="p-1 border-r border-slate-100 last:border-r-0 text-center align-middle h-11"
              >
                <!-- Cell with Teacher -->
                <div
                  v-if="getTeacherAt(slot.index, colIndex - 1)"
                  @click="openSlotModal(slot, colIndex - 1)"
                  class="w-full h-full min-h-[34px] px-1.5 py-1 rounded-lg text-xs font-medium shadow-2xs flex flex-col justify-center items-center transition-all hover:scale-[1.02] cursor-pointer"
                  :style="getTeacherBadgeStyle(getTeacherAt(slot.index, colIndex - 1))"
                  :title="getTeacherAt(slot.index, colIndex - 1).student_id ? `已预约: ${getTeacherAt(slot.index, colIndex - 1).student_name}` : '空闲可预约'"
                >
                  <span class="font-semibold leading-tight truncate max-w-[95px]">
                    {{ getTeacherAt(slot.index, colIndex - 1).teacher_name }}
                  </span>
                  <span
                    v-if="getTeacherAt(slot.index, colIndex - 1).student_id !== null"
                    class="text-[9px] bg-black/25 text-white px-1 rounded mt-0.5 truncate max-w-[95px]"
                  >
                    已约: {{ getTeacherAt(slot.index, colIndex - 1).student_name }}
                  </span>
                  <span
                    v-else
                    class="text-[9px] bg-white/25 text-white px-1 rounded mt-0.5"
                  >
                    空闲
                  </span>
                </div>

                <!-- Empty Cell: Clickable to add teacher in this exact column -->
                <button
                  v-else
                  @click="openSlotModal(slot, colIndex - 1)"
                  type="button"
                  class="w-full h-full min-h-[34px] rounded-lg border border-dashed border-transparent hover:border-emerald-300 hover:bg-emerald-50/40 text-slate-300 hover:text-emerald-600 transition-all flex items-center justify-center group"
                  :title="`在 ${slot.timeRange} 第 ${colIndex} 列排班`"
                >
                  <svg class="w-3.5 h-3.5 opacity-0 group-hover:opacity-100 transition-opacity" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"></path>
                  </svg>
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- Slot Management Modal -->
    <SlotManageModal
      v-model="showSlotModal"
      :slot-info="activeSlot"
      :teachers="activeSlotTeachers"
      @refresh="loadSchedules"
    />
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { api } from '../api/client';
import { getTeacherHslColor, getAllSlots } from '../utils/color';
import SlotManageModal from '../components/SlotManageModal.vue';

const availableDates = ref([]);
const selectedDate = ref('');
const schedules = ref([]);
const loading = ref(false);

const baseSlots = getAllSlots();

// Modal state
const showSlotModal = ref(false);
const activeSlot = ref(null);

const slotsData = computed(() => {
  return baseSlots.map(slot => {
    const matching = schedules.value.filter(s => s.slot_index === slot.index);
    return {
      index: slot.index,
      timeRange: slot.timeRange,
      teachers: matching,
    };
  });
});

const activeSlotTeachers = computed(() => {
  if (!activeSlot.value) return [];
  return schedules.value.filter(s => s.slot_index === activeSlot.value.index);
});

const stats = computed(() => {
  let booked = 0;
  let free = 0;
  for (const s of schedules.value) {
    if (s.student_id !== null) booked++;
    else free++;
  }
  return {
    total: schedules.value.length,
    booked,
    free,
  };
});

function getTeacherAt(slotIndex, columnIndex) {
  return schedules.value.find(s => s.slot_index === slotIndex && s.column_index === columnIndex);
}

/**
 * 汇总某列上当天主要出现的老师姓名（方便在表头一目了然看列归属）
 */
function getColumnSummary(colIndex) {
  const teachersInCol = schedules.value
    .filter(s => s.column_index === colIndex)
    .map(s => s.teacher_name);

  if (teachersInCol.length === 0) return '';
  const uniqueNames = [...new Set(teachersInCol)];
  if (uniqueNames.length === 1) return uniqueNames[0];
  return uniqueNames.slice(0, 2).join(' / ');
}

async function loadDates() {
  try {
    const dates = await api.getAvailableDates();
    availableDates.value = dates;
    if (dates.length > 0) {
      selectedDate.value = dates[0].date;
      await loadSchedules();
    }
  } catch (err) {
    console.error('Failed to load available dates:', err);
  }
}

async function selectDate(date) {
  selectedDate.value = date;
  await loadSchedules();
}

async function loadSchedules() {
  if (!selectedDate.value) return;
  loading.value = true;
  try {
    schedules.value = await api.getSchedules(selectedDate.value);
  } catch (err) {
    console.error('Failed to load schedules:', err);
  } finally {
    loading.value = false;
  }
}

function formatDateLabel(dateStr) {
  if (!dateStr) return '';
  const d = new Date(dateStr);
  const weekDays = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
  const dayName = weekDays[d.getDay()];
  return `${dateStr} (${dayName})`;
}

/**
 * 老师标签颜色算法：名字字符串哈希转 HSL（色相 0~359，饱和度 70%，亮度 50%），确保非灰、非黑、非白。
 * 已预约老师强制渲染为浅灰（#D1D5DB）。
 */
function getTeacherBadgeStyle(t) {
  if (t.student_id !== null) {
    return {
      backgroundColor: '#D1D5DB',
      color: '#374151',
      border: '1px solid #9CA3AF',
    };
  }
  const hsl = getTeacherHslColor(t.teacher_name);
  return {
    backgroundColor: hsl.bg,
    color: hsl.color,
    border: `1px solid ${hsl.border}`,
  };
}

function openSlotModal(slot, targetColumn = null) {
  activeSlot.value = {
    index: slot.index,
    timeRange: slot.timeRange,
    date: selectedDate.value,
    targetColumn,
  };
  showSlotModal.value = true;
}

onMounted(() => {
  loadDates();
});
</script>
