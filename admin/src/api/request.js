import axios from 'axios';
import { ElMessage } from 'element-plus';
import router from '@/router';

const service = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL || '/api',
  timeout: 15000,
});

service.interceptors.request.use((config) => {
  const token = localStorage.getItem('admin_token');
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

service.interceptors.response.use(
  (response) => {
    const res = response.data;
    if (res.ok === false) {
      ElMessage.error(res.error || '请求失败');
      return Promise.reject(new Error(res.error));
    }
    return res.data;
  },
  (error) => {
    const status = error.response?.status;
    if (status === 401) {
      ElMessage.error('登录已过期');
      localStorage.removeItem('admin_token');
      router.push('/login');
    } else {
      ElMessage.error(error.response?.data?.error || '网络异常');
    }
    return Promise.reject(error);
  }
);

export default service;
