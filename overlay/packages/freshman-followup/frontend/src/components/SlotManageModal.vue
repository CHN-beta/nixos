<template>
  <Modal
    :model-value="modelValue"
    @update:model-value="val => $emit('update:modelValue', val)"
    title="时段排班管理"
    custom-width="sm:max-w-xl"
  >
    <div v-if="slotInfo" class="space-y-4">
      <!-- Slot Info Header -->
      <div class="bg-slate-50 p-3.5 rounded-xl border border-slate-200 flex flex-wrap items-center justify-between gap-2 text-xs">
        <div class="flex items-center space-x-2">
          <span class="w-6 h-6 rounded-full bg-emerald-600 text-white font-mono font-bold flex items-center justify-center text-xs">
            {{ slotInfo.index + 1 }}
          </span>
          <div>
            <div class="font-bold text-slate-800 text-sm">{{ slotInfo.date }}</div>
            <div class="font-mono text-emerald-700 font-semibold">{{ slotInfo.timeRange }}</div>
          </div>
        </div>

        <div class="flex items-center space-x-1.5 bg-white px-2.5 py-1 rounded-lg border border-slate-200">
          <span class="text-slate-500">当前排班人数:</span>
          <span class="font-bold" :class="teachers.length >= 8 ? 'text-rose-600' : 'text-slate-800'">
            {{ teachers.length }} / 8
          </span>
        </div>
      </div>

      <!-- Error banner -->
      <div v-if="errorMessage" class="p-3 bg-rose-50 border border-rose-200 rounded-lg text-rose-700 text-xs flex items-center space-x-2">
        <svg class="w-4 h-4 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
        </svg>
        <span>{{ errorMessage }}</span>
      </div>

      <!-- Add Teacher Form (With Column Coordinate Selection) -->
      <div class="bg-white p-3.5 rounded-xl border border-slate-200 space-y-2.5">
        <div class="flex items-center justify-between text-xs">
          <label class="font-semibold text-slate-700">添加排班老师</label>
          <span class="text-slate-400">支持指定房间（房间一至八）</span>
        </div>

        <div v-if="teachers.length >= 8" class="text-xs text-amber-700 bg-amber-50 p-2.5 rounded-lg border border-amber-200">
          该时段已排满 8 位老师，达到单个时段排班上限。若需调整请先删除空闲排班。
        </div>

        <form v-else @submit.prevent="handleAddTeacher" class="flex flex-col sm:flex-row gap-2">
          <!-- Column Selector -->
          <div class="sm:w-32 shrink-0">
            <select
              v-model="selectedColumn"
              class="w-full px-2.5 py-2 text-xs rounded-lg border border-slate-200 bg-slate-50/50 focus:bg-white focus:outline-none focus:ring-2 focus:ring-emerald-500 font-medium text-slate-700"
            >
              <option
                v-for="col in 8"
                :key="col - 1"
                :value="col - 1"
                :disabled="isColumnOccupied(col - 1)"
              >
                房间{{ roomNames[col - 1] }} {{ isColumnOccupied(col - 1) ? '(已占)' : '' }}
              </option>
            </select>
          </div>

          <input
            v-model="newTeacherName"
            type="text"
            placeholder="输入老师姓名 (例如：张老师)"
            class="flex-1 px-3 py-2 text-xs rounded-lg border border-slate-200 bg-slate-50/50 focus:bg-white focus:outline-none focus:ring-2 focus:ring-emerald-500"
          />
          <button
            type="submit"
            :disabled="adding || !newTeacherName.trim()"
            class="px-4 py-2 bg-emerald-600 hover:bg-emerald-700 active:bg-emerald-800 text-white text-xs font-medium rounded-lg shadow-sm transition-all disabled:opacity-50 flex items-center justify-center space-x-1 shrink-0"
          >
            <span v-if="adding" class="animate-spin h-3.5 w-3.5 border-2 border-white border-t-transparent rounded-full"></span>
            <span>添加</span>
          </button>
        </form>
      </div>

      <!-- Existing Teachers List -->
      <div class="space-y-2">
        <div class="text-xs font-semibold text-slate-600">本时段已排老师列表：</div>

        <div v-if="teachers.length === 0" class="p-6 bg-slate-50 rounded-xl border border-dashed border-slate-200 text-center text-xs text-slate-400">
          该时段暂无排班老师，请在上方输入添加
        </div>

        <div v-else class="space-y-2">
          <div
            v-for="t in sortedTeachers"
            :key="t.id"
            class="p-3 bg-white rounded-xl border border-slate-200 shadow-2xs flex items-center justify-between gap-2"
          >
            <!-- Teacher info badge -->
            <div class="flex items-center space-x-2.5 min-w-0">
              <span class="px-2 py-0.5 rounded text-[11px] font-mono bg-slate-100 text-slate-600 font-semibold border border-slate-200 shrink-0">
                房间{{ roomNames[t.column_index] }}
              </span>

              <span
                class="px-2.5 py-1 rounded-md text-xs font-medium shadow-2xs shrink-0"
                :style="getTeacherBadgeStyle(t)"
              >
                {{ t.teacher_name }}
              </span>

              <!-- Booking status -->
              <div class="min-w-0 text-xs">
                <template v-if="t.student_id !== null">
                  <div class="flex items-center space-x-1.5 text-slate-800">
                    <span class="w-2 h-2 rounded-full bg-emerald-500 shrink-0"></span>
                    <span class="font-bold truncate">已预约: {{ t.student_name || '学生' }}</span>
                    <span class="text-slate-400 font-mono text-[11px]">({{ t.student_no }})</span>
                  </div>
                  <div class="text-[11px] text-slate-500 mt-0.5 truncate">
                    {{ t.student_college }} · <a :href="'tel:' + t.student_phone" class="text-emerald-700 underline">{{ t.student_phone }}</a>
                  </div>
                </template>
                <template v-else>
                  <span class="text-slate-400 flex items-center space-x-1">
                    <span class="w-1.5 h-1.5 rounded-full bg-slate-300"></span>
                    <span>空闲待预约</span>
                  </span>
                </template>
              </div>
            </div>

            <!-- Delete action & Anti-deletion Protection -->
            <div class="shrink-0 flex items-center">
              <div v-if="t.student_id !== null" class="flex items-center space-x-1 text-slate-400" title="已预约的排班不可被删除">
                <span class="text-[11px] text-amber-700 bg-amber-50 border border-amber-200 px-2 py-0.5 rounded">
                  已预约锁定
                </span>
                <button
                  disabled
                  class="p-1.5 text-slate-300 cursor-not-allowed opacity-50"
                  title="已有预约，禁止删除"
                >
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path>
                  </svg>
                </button>
              </div>

              <button
                v-else
                @click="handleDeleteTeacher(t)"
                :disabled="deletingId === t.id"
                class="p-1.5 text-slate-400 hover:text-rose-600 hover:bg-rose-50 rounded-lg transition-colors"
                title="删除此排班"
              >
                <svg v-if="deletingId !== t.id" class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path>
                </svg>
                <span v-else class="animate-spin h-4 w-4 border-2 border-rose-500 border-t-transparent rounded-full inline-block"></span>
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>

    <template #footer>
      <button
        @click="$emit('update:modelValue', false)"
        type="button"
        class="px-4 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 text-xs font-medium rounded-lg"
      >
        完成
      </button>
    </template>
  </Modal>
</template>

<script setup>
import { ref, computed, watch } from 'vue';
import Modal from './Modal.vue';
import { api } from '../api/client';
import { getTeacherHslColor } from '../utils/color';
const roomNames = ['一', '二', '三', '四', '五', '六', '七', '八'];

const props = defineProps({
  modelValue: {
    type: Boolean,
    default: false,
  },
  slotInfo: {
    type: Object,
    default: null,
  },
  teachers: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['update:modelValue', 'refresh']);

const newTeacherName = ref('');
const selectedColumn = ref(0);
const adding = ref(false);
const deletingId = ref(null);
const errorMessage = ref('');

const sortedTeachers = computed(() => {
  return [...props.teachers].sort((a, b) => a.column_index - b.column_index);
});

function isColumnOccupied(col) {
  return props.teachers.some(t => t.column_index === col);
}

// When opening modal or teachers change, pre-pick the target or first free column
watch(
  [() => props.modelValue, () => props.slotInfo, () => props.teachers],
  ([isOpen]) => {
    if (isOpen) {
      errorMessage.value = '';
      if (props.slotInfo?.targetColumn !== undefined && !isColumnOccupied(props.slotInfo.targetColumn)) {
        selectedColumn.value = props.slotInfo.targetColumn;
      } else {
        const freeCol = [0, 1, 2, 3, 4, 5, 6, 7].find(c => !isColumnOccupied(c));
        selectedColumn.value = freeCol !== undefined ? freeCol : 0;
      }
    }
  }
);

function getTeacherBadgeStyle(t) {
  if (t.student_id !== null) {
    return {
      backgroundColor: '#D1D5DB',
      color: '#4B5563',
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

async function handleAddTeacher() {
  const name = newTeacherName.value.trim();
  if (!name || !props.slotInfo) return;

  if (props.teachers.length >= 8) {
    errorMessage.value = '该时段排班已达上限（最多8位老师）';
    return;
  }

  if (isColumnOccupied(selectedColumn.value)) {
    errorMessage.value = `房间${roomNames[selectedColumn.value]} 已被占用，请选择其他房间`;
    return;
  }

  adding.value = true;
  errorMessage.value = '';

  try {
    await api.createSchedule({
      date: props.slotInfo.date,
      slot_index: props.slotInfo.index,
      column_index: selectedColumn.value,
      teacher_name: name,
    });

    newTeacherName.value = '';
    emit('refresh');
  } catch (err) {
    errorMessage.value = err.message || '添加排班失败';
  } finally {
    adding.value = false;
  }
}

async function handleDeleteTeacher(teacher) {
  if (teacher.student_id !== null) {
    alert('该排班已被学生预约，无法删除！请先将学生改期或解除预约。');
    return;
  }

  if (!confirm(`确认删除「${teacher.teacher_name}」在该时段的排班吗？`)) {
    return;
  }

  deletingId.value = teacher.id;
  errorMessage.value = '';

  try {
    await api.deleteSchedule(teacher.id);
    emit('refresh');
  } catch (err) {
    errorMessage.value = err.message || '删除排班失败';
  } finally {
    deletingId.value = null;
  }
}
</script>
