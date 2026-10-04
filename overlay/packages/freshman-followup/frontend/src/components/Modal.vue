<template>
  <Teleport to="body">
    <Transition name="fade">
      <div
        v-if="modelValue"
        class="fixed inset-0 z-50 flex items-end sm:items-center justify-center p-0 sm:p-4 bg-slate-900/40 backdrop-blur-sm"
        @click.self="handleClose"
      >
        <div
          class="bg-white w-full sm:max-w-lg rounded-t-2xl sm:rounded-xl shadow-xl flex flex-col max-h-[90vh] sm:max-h-[85vh] transition-all transform animate-in overflow-hidden border border-slate-100"
          :class="customWidth"
        >
          <!-- Header -->
          <div class="px-5 py-4 border-b border-slate-100 flex items-center justify-between shrink-0">
            <h3 class="text-base font-semibold text-slate-800">
              <slot name="title">{{ title }}</slot>
            </h3>
            <button
              @click="handleClose"
              type="button"
              class="text-slate-400 hover:text-slate-600 p-1 rounded-lg hover:bg-slate-100 transition-colors"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
              </svg>
            </button>
          </div>

          <!-- Body -->
          <div class="p-5 overflow-y-auto flex-1">
            <slot></slot>
          </div>

          <!-- Footer -->
          <div v-if="$slots.footer" class="px-5 py-3.5 bg-slate-50 border-t border-slate-100 flex items-center justify-end space-x-3 shrink-0">
            <slot name="footer"></slot>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<script setup>
const props = defineProps({
  modelValue: {
    type: Boolean,
    default: false,
  },
  title: {
    type: String,
    default: '',
  },
  customWidth: {
    type: String,
    default: 'sm:max-w-lg',
  },
});

const emit = defineEmits(['update:modelValue', 'close']);

function handleClose() {
  emit('update:modelValue', false);
  emit('close');
}
</script>

<style scoped>
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.2s ease;
}

.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}
</style>
