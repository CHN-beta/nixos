<template>
  <Modal
    :model-value="modelValue"
    @update:model-value="val => $emit('update:modelValue', val)"
    title="选择排班（成功预约）"
    custom-width="sm:max-w-2xl"
  >
    <div class="space-y-4">
      <!-- Target Student Banner -->
      <div v-if="student" class="bg-emerald-50/70 border border-emerald-200/70 rounded-xl p-3 flex items-center justify-between">
        <div>
          <div class="flex items-center space-x-2">
            <span class="font-bold text-slate-800 text-sm">{{ student.name }}</span>
            <span class="text-xs text-slate-500 font-mono">({{ student.student_no }})</span>
            <span class="text-xs text-emerald-800 bg-emerald-100/80 px-2 py-0.5 rounded-full font-medium">{{ student.college }}</span>
          </div>
          <p class="text-xs text-emerald-700 mt-1">请在下方时间轴中选择一位空闲老师进行预约绑定</p>
        </div>
      </div>

      <!-- Date Dropdown Selector -->
      <div>
        <label class="block text-xs font-semibold text-slate-600 mb-1.5">选择排班日期</label>
        <div class="flex items-center space-x-2 overflow-x-auto pb-1">
          <button
            v-for="d in availableDates"
            :key="d.date"
            @click="selectDate(d.date)"
            type="button"
            class="px-3.5 py-2 rounded-lg text-xs font-medium transition-all shrink-0 border"
            :class="selectedDate === d.date
              ? 'bg-emerald-600 text-white border-emerald-600 shadow-sm'
              : 'bg-white text-slate-700 border-slate-200 hover:bg-slate-50'"
          >
            {{ formatDateLabel(d.date) }}
          </button>
        </div>
      </div>

      <!-- Error / Conflict banner -->
      <div v-if="errorMessage" class="p-3 bg-rose-50 border border-rose-200 rounded-lg text-rose-700 text-xs flex items-center space-x-2">
        <svg class="w-4 h-4 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
        </svg>
        <span>{{ errorMessage }}</span>
      </div>

      <!-- Legend -->
      <div class="flex items-center space-x-4 text-xs text-slate-500 pt-1 border-t border-slate-100">
        <div class="flex items-center space-x-1.5">
          <span class="w-3 h-3 rounded bg-emerald-500"></span>
          <span>专属颜色：可预约</span>
        </div>
        <div class="flex items-center space-x-1.5">
          <span class="w-3 h-3 rounded bg-[#D1D5DB]"></span>
          <span>浅灰：已被预约（不可选）</span>
        </div>
      </div>

      <!-- Vertical Timeline of 28 Slots -->
      <div class="border border-slate-200 rounded-xl overflow-hidden bg-slate-50 max-h-[50vh] overflow-y-auto divide-y divide-slate-100">
        <div v-if="loadingSchedules" class="py-12 text-center text-xs text-slate-400">
          <div class="inline-block animate-spin rounded-full h-6 w-6 border-2 border-emerald-500 border-t-transparent mb-2"></div>
          <div>加载排班数据中...</div>
        </div>

        <div v-else-if="slotsData.length === 0" class="py-8 text-center text-xs text-slate-400">
          该日期暂无任何老师排班
        </div>

        <div
          v-else
          v-for="slot in slotsData"
          :key="slot.index"
          class="p-2.5 sm:p-3 bg-white hover:bg-slate-50/60 transition-colors flex flex-col sm:flex-row sm:items-center space-y-2 sm:space-y-0"
        >
          <!-- Slot Time Label (Vertical Page Axis) -->
          <div class="sm:w-36 shrink-0 flex items-center space-x-2 text-xs font-semibold text-slate-700">
            <span class="w-5 h-5 rounded-full bg-slate-100 text-slate-500 flex items-center justify-center text-[10px] font-mono">
              {{ slot.index + 1 }}
            </span>
            <span class="font-mono text-slate-800">{{ slot.timeRange }}</span>
          </div>

          <!-- Teachers badges list -->
          <div class="flex-1 flex flex-wrap gap-1.5 items-center">
            <div v-if="slot.teachers.length === 0" class="text-xs text-slate-400 italic">
              暂无老师排班
            </div>

            <template v-else>
              <button
                v-for="t in slot.teachers"
                :key="t.id"
                :disabled="t.student_id !== null"
                @click="onSelectTeacher(t, slot)"
                type="button"
                class="px-2.5 py-1.5 rounded-lg text-xs font-medium transition-all flex items-center space-x-1.5 shadow-sm"
                :style="getTeacherStyle(t)"
                :class="t.student_id !== null ? 'opacity-70 cursor-not-allowed' : 'hover:scale-105 active:scale-95 cursor-pointer ring-1 ring-black/5'"
              >
                <span class="text-[10px] bg-black/15 px-1 py-0.2 rounded font-mono">
                  房间{{ roomNames[t.column_index] }}
                </span>
                <span>{{ t.teacher_name }}</span>
                <span v-if="t.student_id !== null" class="text-[10px] ml-1 bg-black/20 px-1 py-0.2 rounded">
                  已预约
                </span>
                <span v-else class="text-[10px] ml-1 bg-white/25 px-1 py-0.2 rounded">
                  空闲
                </span>
              </button>
            </template>
          </div>
        </div>
      </div>
    </div>

    <!-- Confirmation Modal / Nested Prompt -->
    <Modal
      :model-value="showConfirm"
      @update:model-value="showConfirm = $event"
      title="确认预约提交"
      custom-width="sm:max-w-md"
    >
      <div v-if="pendingTarget" class="space-y-3 text-sm text-slate-700">
        <p>确认将学生 <strong class="text-emerald-700 font-bold">{{ student?.name }}</strong> 预约在以下时段吗？</p>

        <div class="bg-slate-50 p-3.5 rounded-xl border border-slate-200 text-xs space-y-1.5">
          <div class="flex justify-between">
            <span class="text-slate-500">日期:</span>
            <span class="font-medium text-slate-800">{{ selectedDate }}</span>
          </div>
          <div class="flex justify-between">
            <span class="text-slate-500">时段:</span>
            <span class="font-medium text-slate-800">{{ pendingTarget.slot.timeRange }}</span>
          </div>
          <div class="flex justify-between">
            <span class="text-slate-500">排班位置 / 老师:</span>
            <span class="font-bold text-slate-900">
              房间{{ roomNames[pendingTarget.teacher.column_index] }} · {{ pendingTarget.teacher.teacher_name }}
            </span>
          </div>
        </div>
        <p class="text-xs text-slate-500">
          提交后系统将原子锁定该排班，若该学生之前已预约其他时段，原排班将自动释放为空闲状态。
        </p>
      </div>

      <template #footer>
        <button
          @click="showConfirm = false"
          type="button"
          class="px-3.5 py-2 rounded-lg text-xs font-medium text-slate-600 hover:bg-slate-100 transition-colors"
        >
          取消
        </button>
        <button
          @click="submitBooking"
          :disabled="submitting"
          type="button"
          class="px-4 py-2 rounded-lg text-xs font-medium bg-emerald-600 hover:bg-emerald-700 text-white shadow-sm transition-all disabled:opacity-50 flex items-center space-x-1.5"
        >
          <span v-if="submitting" class="animate-spin h-3.5 w-3.5 border-2 border-white border-t-transparent rounded-full"></span>
          <span>确认预约</span>
        </button>
      </template>
    </Modal>
  </Modal>
</template>

<script setup>
import { ref, watch, computed } from 'vue';
import Modal from './Modal.vue';
import { api } from '../api/client';
import { getTeacherHslColor, getAllSlots } from '../utils/color';
const roomNames = ['一', '二', '三', '四', '五', '六', '七', '八'];

const props = defineProps({
  modelValue: {
    type: Boolean,
    default: false,
  },
  student: {
    type: Object,
    default: null,
  },
});

const emit = defineEmits(['update:modelValue', 'success']);

const availableDates = ref([]);
const selectedDate = ref('');
const schedules = ref([]);
const loadingSchedules = ref(false);
const errorMessage = ref('');

const showConfirm = ref(false);
const pendingTarget = ref(null);
const submitting = ref(false);

const baseSlots = getAllSlots();

// Merge schedules into the 28 vertical slots
const slotsData = computed(() => {
  return baseSlots.map(slot => {
    const matchingTeachers = schedules.value
      .filter(s => s.slot_index === slot.index)
      .sort((a, b) => a.column_index - b.column_index);
    return {
      index: slot.index,
      timeRange: slot.timeRange,
      teachers: matchingTeachers,
    };
  });
});

watch(
  () => props.modelValue,
  async (isOpen) => {
    if (isOpen) {
      errorMessage.value = '';
      await loadDates();
    }
  }
);

async function loadDates() {
  try {
    const dates = await api.getAvailableDates();
    availableDates.value = dates;
    if (dates.length > 0) {
      // If student already has a booking date, prefer that date, else first
      if (props.student?.schedule_date && dates.some(d => d.date === props.student.schedule_date)) {
        selectedDate.value = props.student.schedule_date;
      } else {
        selectedDate.value = dates[0].date;
      }
      await loadSchedules();
    }
  } catch (err) {
    errorMessage.value = err.message || '加载可选日期失败';
  }
}

async function selectDate(date) {
  selectedDate.value = date;
  await loadSchedules();
}

async function loadSchedules() {
  if (!selectedDate.value) return;
  loadingSchedules.value = true;
  errorMessage.value = '';
  try {
    const data = await api.getSchedules(selectedDate.value);
    schedules.value = data;
  } catch (err) {
    errorMessage.value = err.message || '加载排班数据失败';
  } finally {
    loadingSchedules.value = false;
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
 * 老师标签颜色算法：
 * 已预约老师强制渲染为浅灰（#D1D5DB）且不可点击；未预约老师渲染专属颜色，点击即可选中。
 */
function getTeacherStyle(teacher) {
  if (teacher.student_id !== null) {
    return {
      backgroundColor: '#D1D5DB',
      color: '#4B5563',
      border: '1px solid #9CA3AF',
    };
  }

  const hsl = getTeacherHslColor(teacher.teacher_name);
  return {
    backgroundColor: hsl.bg,
    color: hsl.color,
    border: `1px solid ${hsl.border}`,
  };
}

function onSelectTeacher(teacher, slot) {
  if (teacher.student_id !== null) return;
  pendingTarget.value = { teacher, slot };
  showConfirm.value = true;
}

async function submitBooking() {
  if (!pendingTarget.value || !props.student) return;

  submitting.value = true;
  errorMessage.value = '';

  try {
    const res = await api.updateStudentStatus(props.student.id, {
      status: '成功预约',
      schedule_id: pendingTarget.value.teacher.id,
    });

    showConfirm.value = false;
    emit('update:modelValue', false);
    emit('success', res);
  } catch (err) {
    errorMessage.value = err.message || '预约提交失败，请重试';
    showConfirm.value = false;
    // Reload schedules in case it was occupied concurrently
    await loadSchedules();
  } finally {
    submitting.value = false;
  }
}
</script>
