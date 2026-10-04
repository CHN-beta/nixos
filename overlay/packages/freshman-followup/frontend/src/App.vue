<template>
  <div class="min-h-screen bg-slate-50 flex flex-col font-sans">
    <Navbar v-if="showNavbar" />

    <main class="flex-1 w-full" :class="{ 'pb-20 md:pb-8': showNavbar }">
      <RouterView />
    </main>
  </div>
</template>

<script setup>
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import Navbar from './components/Navbar.vue';

const route = useRoute();
const showNavbar = computed(() => route.name !== 'Login');
</script>
