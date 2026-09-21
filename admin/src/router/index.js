import { createRouter, createWebHistory } from 'vue-router';

const routes = [
  { path: '/login', name: 'Login', component: () => import('@/views/Login.vue'), meta: { public: true } },
  {
    path: '/',
    component: () => import('@/layout/index.vue'),
    redirect: '/dashboard',
    children: [
      { path: 'dashboard', component: () => import('@/views/Dashboard.vue'), meta: { title: '数据概览' } },
      { path: 'pending', component: () => import('@/views/Pending.vue'), meta: { title: '待确认订单' } },
      { path: 'orders', component: () => import('@/views/Orders.vue'), meta: { title: '全部订单' } },
      { path: 'sessions', component: () => import('@/views/Sessions.vue'), meta: { title: '在线用户' } },
      { path: 'packages', component: () => import('@/views/Packages.vue'), meta: { title: '套餐管理' } },
      { path: 'routers', component: () => import('@/views/Routers.vue'), meta: { title: '路由器管理' } },
      { path: 'settings', component: () => import('@/views/Settings.vue'), meta: { title: '系统设置' } },
    ],
  },
  { path: '/:pathMatch(.*)*', redirect: '/dashboard' },
];

const router = createRouter({ history: createWebHistory(), routes });

router.beforeEach((to, from, next) => {
  const token = localStorage.getItem('admin_token');
  if (to.meta.public) {
    if (token && to.path === '/login') return next('/dashboard');
    return next();
  }
  if (!token) return next('/login');
  next();
});

export default router;
