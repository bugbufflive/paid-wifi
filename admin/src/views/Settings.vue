<template>
  <div class="page-card">
    <div class="page-card-head"><h2>系统设置</h2></div>
    <div class="page-card-body">
      <el-descriptions :column="1" border>
        <el-descriptions-item label="当前账号">{{ userStore.username }}</el-descriptions-item>
        <el-descriptions-item label="后端 API">{{ apiBase }}</el-descriptions-item>
        <el-descriptions-item label="前端版本">v1.0.0</el-descriptions-item>
      </el-descriptions>
      <el-button type="danger" style="margin-top:20px;" @click="handleLogout">退出登录</el-button>
    </div>
  </div>
</template>
<script setup>
import { useRouter } from 'vue-router';
import { ElMessage, ElMessageBox } from 'element-plus';
import { useUserStore } from '@/stores/user';
const router = useRouter();
const userStore = useUserStore();
const apiBase = import.meta.env.VITE_API_BASE_URL || '/api';
async function handleLogout() {
  try {
    await ElMessageBox.confirm('确认退出登录？', '提示', { type: 'warning' });
    userStore.logout();
    router.push('/login');
  } catch (e) {}
}
</script>
