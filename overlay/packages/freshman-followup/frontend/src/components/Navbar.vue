<template>
  <header class="bg-white border-b border-slate-200 sticky top-0 z-30 shadow-sm">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="flex items-center justify-between h-14">
        <!-- Logo & Title -->
        <div class="flex items-center space-x-2.5">
          <div class="w-8 h-8 rounded-lg bg-emerald-600 flex items-center justify-center text-white shadow-sm">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4"></path>
            </svg>
          </div>
          <h1 class="text-base font-semibold text-slate-800 leading-tight">新生回访系统</h1>
        </div>

        <!-- Desktop Navigation Tabs -->
        <nav class="hidden md:flex items-center space-x-1">
          <RouterLink
            to="/students"
            class="px-3 py-1.5 rounded-md text-sm font-medium transition-colors"
            :class="$route.path === '/students' ? 'bg-emerald-50 text-emerald-700' : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100'"
          >
            学生回访
          </RouterLink>
          <RouterLink
            to="/schedule"
            class="px-3 py-1.5 rounded-md text-sm font-medium transition-colors"
            :class="$route.path === '/schedule' ? 'bg-emerald-50 text-emerald-700' : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100'"
          >
            老师排班
          </RouterLink>
        </nav>

        <!-- User profile & Logout -->
        <div class="flex items-center space-x-3">
          <div class="flex items-center space-x-2 bg-slate-50 border border-slate-200 px-2.5 py-1 rounded-full text-xs text-slate-600">
            <span class="w-2 h-2 rounded-full bg-emerald-500"></span>
            <span class="font-medium max-w-[100px] truncate">{{ authStore.username || '助理' }}</span>
          </div>

          <button
            @click="handleLogout"
            class="text-xs text-slate-500 hover:text-rose-600 transition-colors p-1.5 rounded-md hover:bg-slate-100"
            title="退出登录"
          >
            退出
          </button>
        </div>
      </div>
    </div>
  </header>

  <!-- Mobile Bottom Tab Bar -->
  <nav class="md:hidden fixed bottom-0 left-0 right-0 bg-white border-t border-slate-200 z-30 shadow-lg px-6 py-2 flex justify-around items-center">
    <RouterLink
      to="/students"
      class="flex flex-col items-center text-xs space-y-1 transition-colors"
      :class="$route.path === '/students' ? 'text-emerald-600 font-semibold' : 'text-slate-500 hover:text-slate-800'"
    >
      <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z"></path>
      </svg>
      <span>回访名单</span>
    </RouterLink>

    <RouterLink
      to="/schedule"
      class="flex flex-col items-center text-xs space-y-1 transition-colors"
      :class="$route.path === '/schedule' ? 'text-emerald-600 font-semibold' : 'text-slate-500 hover:text-slate-800'"
    >
      <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"></path>
      </svg>
      <span>老师排班</span>
    </RouterLink>

  </nav>
</template>

<script setup>
import { useRouter } from 'vue-router';
import { useAuthStore } from '../stores/auth';

const router = useRouter();
const authStore = useAuthStore();

function handleLogout() {
  if (confirm('确认退出系统吗？')) {
    authStore.logout();
    router.push('/login');
  }
}
</script>
