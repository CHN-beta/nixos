<template>
  <div class="min-h-screen flex items-center justify-center p-4 bg-gradient-to-br from-slate-50 via-slate-100 to-emerald-50/30">
    <div class="w-full max-w-sm bg-white rounded-2xl shadow-xl border border-slate-100 p-8">
      <!-- Header -->
      <div class="text-center mb-8">
        <h2 class="text-2xl font-bold text-slate-800 tracking-tight">登 录</h2>
        <p class="text-xs text-slate-400 mt-1.5">请使用您的账号与密码登录系统</p>
      </div>

      <!-- Error message -->
      <div
        v-if="errorMessage"
        class="mb-5 p-3 rounded-lg bg-rose-50 border border-rose-200 text-rose-700 text-xs flex items-center space-x-2"
      >
        <svg class="w-4 h-4 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
        </svg>
        <span>{{ errorMessage }}</span>
      </div>

      <!-- Login Form -->
      <form @submit.prevent="handleLogin" class="space-y-4">
        <div>
          <label class="block text-xs font-medium text-slate-700 mb-1">账号</label>
          <input
            v-model="username"
            type="text"
            required
            autocomplete="username"
            placeholder="请输入账号"
            class="w-full px-3.5 py-2.5 rounded-lg border border-slate-200 bg-slate-50/50 text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
          />
        </div>

        <div>
          <label class="block text-xs font-medium text-slate-700 mb-1">密码</label>
          <input
            v-model="password"
            type="password"
            required
            autocomplete="current-password"
            placeholder="请输入密码"
            class="w-full px-3.5 py-2.5 rounded-lg border border-slate-200 bg-slate-50/50 text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
          />
        </div>

        <button
          type="submit"
          :disabled="loading"
          class="w-full mt-2 py-2.5 px-4 rounded-lg bg-emerald-600 hover:bg-emerald-700 active:bg-emerald-800 text-white font-medium text-sm shadow-sm transition-all flex items-center justify-center space-x-2 disabled:opacity-50 disabled:cursor-not-allowed"
        >
          <svg
            v-if="loading"
            class="animate-spin h-4 w-4 text-white"
            xmlns="http://www.w3.org/2000/svg"
            fill="none"
            viewBox="0 0 24 24"
          >
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z"></path>
          </svg>
          <span>{{ loading ? '正在登录...' : '登 录' }}</span>
        </button>
      </form>

    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue';
import { useRouter } from 'vue-router';
import { useAuthStore } from '../stores/auth';

const router = useRouter();
const authStore = useAuthStore();

const username = ref('');
const password = ref('');
const loading = ref(false);
const errorMessage = ref('');

async function handleLogin() {
  if (!username.value || !password.value) return;

  loading.value = true;
  errorMessage.value = '';

  try {
    await authStore.login(username.value, password.value);
    router.push('/students');
  } catch (err) {
    errorMessage.value = err.message || '登录失败，请检查账号和密码';
  } finally {
    loading.value = false;
  }
}
</script>
