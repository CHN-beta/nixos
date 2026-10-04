<template>
  <Modal
    :model-value="modelValue"
    @update:model-value="val => $emit('update:modelValue', val)"
    title="编辑学生备注"
    custom-width="sm:max-w-md"
  >
    <div v-if="student" class="space-y-3">
      <div class="text-xs text-slate-500">
        正在为学生 <strong class="text-slate-800 font-semibold">{{ student.name }}</strong> ({{ student.student_no }}) 编辑回访备注：
      </div>

      <div>
        <textarea
          v-model="remarksText"
          rows="4"
          placeholder="请输入学生回访详情、沟通情况或后续跟进安排..."
          class="w-full p-3 text-xs sm:text-sm rounded-xl border border-slate-200 bg-slate-50/50 focus:bg-white focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
        ></textarea>
      </div>

      <div v-if="errorMessage" class="text-xs text-rose-600 bg-rose-50 p-2 rounded-lg">
        {{ errorMessage }}
      </div>
    </div>

    <template #footer>
      <button
        @click="$emit('update:modelValue', false)"
        type="button"
        class="px-3.5 py-2 rounded-lg text-xs font-medium text-slate-600 hover:bg-slate-100"
      >
        取消
      </button>
      <button
        @click="saveRemarks"
        :disabled="submitting"
        type="button"
        class="px-4 py-2 rounded-lg text-xs font-medium bg-emerald-600 hover:bg-emerald-700 text-white shadow-sm flex items-center space-x-1.5 disabled:opacity-50"
      >
        <span v-if="submitting" class="animate-spin h-3.5 w-3.5 border-2 border-white border-t-transparent rounded-full"></span>
        <span>保存备注</span>
      </button>
    </template>
  </Modal>
</template>

<script setup>
import { ref, watch } from 'vue';
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

const emit = defineEmits(['update:modelValue', 'success']);

const remarksText = ref('');
const submitting = ref(false);
const errorMessage = ref('');

watch(
  () => props.modelValue,
  (isOpen) => {
    if (isOpen && props.student) {
      remarksText.value = props.student.remarks || '';
      errorMessage.value = '';
    }
  }
);

async function saveRemarks() {
  if (!props.student) return;

  submitting.value = true;
  errorMessage.value = '';

  try {
    const res = await api.updateStudentRemarks(props.student.id, {
      remarks: remarksText.value,
    });

    emit('update:modelValue', false);
    emit('success', res);
  } catch (err) {
    errorMessage.value = err.message || '保存备注失败';
  } finally {
    submitting.value = false;
  }
}
</script>
