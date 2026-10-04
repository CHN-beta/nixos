<template>
  <Modal
    :model-value="modelValue"
    @update:model-value="val => $emit('update:modelValue', val)"
    title="更改学生回访状态"
    custom-width="sm:max-w-md"
  >
    <div v-if="student" class="space-y-4">
      <div class="bg-slate-50 p-3 rounded-xl border border-slate-200 flex items-center justify-between text-xs">
        <div>
          <span class="font-bold text-slate-800 text-sm">{{ student.name }}</span>
          <span class="text-slate-500 ml-2 font-mono">({{ student.student_no }})</span>
        </div>
        <div class="flex items-center space-x-1.5">
          <span class="text-slate-500">当前状态:</span>
          <span class="px-2 py-0.5 rounded font-medium" :class="getStatusBadgeClass(student.status)">
            {{ student.status }}
          </span>
        </div>
      </div>

      <div class="text-xs font-semibold text-slate-600">请选择新的回访状态：</div>

      <!-- Status Options Grid -->
      <div class="grid grid-cols-2 gap-2.5">
        <button
          v-for="st in statusOptions"
          :key="st.name"
          @click="onSelectStatus(st.name)"
          type="button"
          class="p-3 rounded-xl border text-left transition-all relative overflow-hidden flex flex-col justify-between"
          :class="[
            st.name === '成功预约'
              ? 'border-emerald-300 bg-emerald-50/60 hover:bg-emerald-100/60 hover:border-emerald-400'
              : 'border-slate-200 bg-white hover:bg-slate-50 hover:border-slate-300',
            student.status === st.name ? 'ring-2 ring-emerald-500 ring-offset-1' : ''
          ]"
        >
          <div class="flex items-center justify-between mb-1">
            <span class="font-bold text-xs" :class="st.textClass">{{ st.name }}</span>
            <span v-if="student.status === st.name" class="text-[10px] bg-slate-200 text-slate-700 px-1.5 py-0.2 rounded font-normal">
              当前
            </span>
          </div>
          <span class="text-[11px] text-slate-500 leading-tight">{{ st.desc }}</span>
        </button>
      </div>

      <div v-if="errorMessage" class="p-2.5 bg-rose-50 border border-rose-200 rounded-lg text-rose-700 text-xs">
        {{ errorMessage }}
      </div>
    </div>

    <!-- Secondary Confirmation Dialog for Non-booking Statuses -->
    <Modal
      :model-value="showConfirmDialog"
      @update:model-value="showConfirmDialog = $event"
      title="确认状态更改"
      custom-width="sm:max-w-sm"
    >
      <div class="space-y-3 text-xs text-slate-700">
        <p class="text-sm">
          确认将学生 <strong class="text-slate-900">{{ student?.name }}</strong> 的状态更改为
          <strong class="text-emerald-700 font-bold">「{{ targetStatus }}」</strong> 吗？
        </p>

        <div v-if="student?.status === '成功预约'" class="p-2.5 bg-amber-50 border border-amber-200 rounded-lg text-amber-800 text-[11px] space-y-1">
          <div class="font-bold">⚠️ 注意：</div>
          <div>该学生原已预约排班（{{ student.schedule_date }} {{ student.schedule_teacher_name }}），更改状态将<strong>自动释放原占用的老师排班</strong>为空闲状态。</div>
        </div>
      </div>

      <template #footer>
        <button
          @click="showConfirmDialog = false"
          type="button"
          class="px-3.5 py-2 rounded-lg text-xs font-medium text-slate-600 hover:bg-slate-100"
        >
          取消
        </button>
        <button
          @click="confirmStatusChange"
          :disabled="submitting"
          type="button"
          class="px-4 py-2 rounded-lg text-xs font-medium bg-emerald-600 hover:bg-emerald-700 text-white shadow-sm flex items-center space-x-1.5 disabled:opacity-50"
        >
          <span v-if="submitting" class="animate-spin h-3.5 w-3.5 border-2 border-white border-t-transparent rounded-full"></span>
          <span>确认更改</span>
        </button>
      </template>
    </Modal>
  </Modal>
</template>

<script setup>
import { ref } from 'vue';
import Modal from './Modal.vue';
import { api } from '../api/client';

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

const emit = defineEmits(['update:modelValue', 'selectSuccessAppointment', 'success']);

const showConfirmDialog = ref(false);
const targetStatus = ref('');
const submitting = ref(false);
const errorMessage = ref('');

const statusOptions = [
  { name: '未联系', textClass: 'text-slate-700', desc: '新分配或尚未致电联系' },
  { name: '成功预约', textClass: 'text-emerald-700', desc: '强绑定并选定空闲老师排班' },
  { name: '暂时没空', textClass: 'text-amber-700', desc: '学生表示暂忙，待后续跟进' },
  { name: '拒绝回访', textClass: 'text-rose-700', desc: '学生主动表示不需咨询或拒绝' },
  { name: '空号', textClass: 'text-red-700', desc: '手机号停机、空号或无法接通' },
  { name: '未接通', textClass: 'text-orange-700', desc: '电话无人接听、挂断或占线' },
  { name: '其它', textClass: 'text-purple-700', desc: '休学、退学或特殊情况' },
];

function onSelectStatus(statusName) {
  errorMessage.value = '';
  if (statusName === '成功预约') {
    // 成功预约强绑定：唤起排班选择器
    emit('update:modelValue', false);
    emit('selectSuccessAppointment', props.student);
    return;
  }

  targetStatus.value = statusName;
  showConfirmDialog.value = true;
}

async function confirmStatusChange() {
  if (!props.student || !targetStatus.value) return;

  submitting.value = true;
  errorMessage.value = '';

  try {
    const res = await api.updateStudentStatus(props.student.id, {
      status: targetStatus.value,
      schedule_id: null,
    });

    showConfirmDialog.value = false;
    emit('update:modelValue', false);
    emit('success', res);
  } catch (err) {
    errorMessage.value = err.message || '更改状态失败';
    showConfirmDialog.value = false;
  } finally {
    submitting.value = false;
  }
}

function getStatusBadgeClass(status) {
  switch (status) {
    case '成功预约':
      return 'bg-emerald-100 text-emerald-800 border border-emerald-200';
    case '未联系':
      return 'bg-slate-100 text-slate-700 border border-slate-200';
    case '暂时没空':
      return 'bg-amber-100 text-amber-800 border border-amber-200';
    case '拒绝回访':
      return 'bg-rose-100 text-rose-800 border border-rose-200';
    case '空号':
      return 'bg-red-100 text-red-800 border border-red-200';
    case '未接通':
      return 'bg-orange-100 text-orange-800 border border-orange-200';
    default:
      return 'bg-purple-100 text-purple-800 border border-purple-200';
  }
}
</script>
