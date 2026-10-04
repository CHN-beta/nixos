import { createRouter, createWebHistory } from 'vue-router';
import { useAuthStore } from '../stores/auth';

import LoginView from '../views/LoginView.vue';
import StudentsView from '../views/StudentsView.vue';
import ScheduleView from '../views/ScheduleView.vue';

const routes = [
  {
    path: '/',
    redirect: '/students',
  },
  {
    path: '/login',
    name: 'Login',
    component: LoginView,
    meta: { guestOnly: true },
  },
  {
    path: '/students',
    name: 'Students',
    component: StudentsView,
    meta: { requiresAuth: true },
  },
  {
    path: '/schedule',
    name: 'Schedule',
    component: ScheduleView,
    meta: { requiresAuth: true },
  },
  {
    path: '/:pathMatch(.*)*',
    redirect: '/students',
  },
];

const router = createRouter({
  history: createWebHistory('/ui/'),
  routes,
});

router.beforeEach(async (to, from, next) => {
  const authStore = useAuthStore();
  const token = localStorage.getItem('token');

  if (to.meta.requiresAuth && !token) {
    next({ name: 'Login' });
  } else if (to.meta.guestOnly && token) {
    next({ name: 'Students' });
  } else {
    next();
  }
});

export default router;
