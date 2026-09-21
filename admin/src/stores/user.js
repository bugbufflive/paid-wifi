import { defineStore } from 'pinia';
import { login as loginApi } from '@/api/auth';

export const useUserStore = defineStore('user', {
  state: () => ({
    token: localStorage.getItem('admin_token') || '',
    username: localStorage.getItem('admin_username') || '',
    pendingCount: 0,
  }),
  getters: { isLoggedIn: (s) => !!s.token },
  actions: {
    async login(username, password) {
      const data = await loginApi({ username, password });
      this.token = data.token;
      this.username = data.username;
      localStorage.setItem('admin_token', data.token);
      localStorage.setItem('admin_username', data.username);
      return data;
    },
    logout() {
      this.token = '';
      this.username = '';
      localStorage.removeItem('admin_token');
      localStorage.removeItem('admin_username');
    },
  },
});
