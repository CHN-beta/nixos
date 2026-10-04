import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import { api } from '../api/client';

export const useAuthStore = defineStore('auth', () => {
  const token = ref(localStorage.getItem('token') || '');
  const username = ref(localStorage.getItem('username') || '');

  const isAuthenticated = computed(() => !!token.value);

  async function login(name, password) {
    const res = await api.login(name, password);
    token.value = res.token;
    username.value = res.username;
    localStorage.setItem('token', res.token);
    localStorage.setItem('username', res.username);
    return res;
  }

  function logout() {
    token.value = '';
    username.value = '';
    localStorage.removeItem('token');
    localStorage.removeItem('username');
  }

  async function checkAuth() {
    if (!token.value) return false;
    try {
      const res = await api.getMe();
      username.value = res.username;
      localStorage.setItem('username', res.username);
      return true;
    } catch {
      logout();
      return false;
    }
  }

  return {
    token,
    username,
    isAuthenticated,
    login,
    logout,
    checkAuth,
  };
});
