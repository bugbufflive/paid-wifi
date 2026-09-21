<template>
  <div class="sidebar">
    <div class="brand">
      <div class="logo"><el-icon :size="20" color="#fff"><Connection /></el-icon></div>
      <div><div class="name">付费WiFi</div><div class="sub">管理控制台</div></div>
    </div>
    <el-menu :default-active="$route.path" router background-color="#111827" text-color="#94a3b8" active-text-color="#fff" class="menu">
      <div class="group">运营</div>
      <el-menu-item index="/dashboard"><el-icon><DataLine /></el-icon><span>数据概览</span></el-menu-item>
      <el-menu-item index="/pending"><el-icon><Clock /></el-icon><span>待确认订单</span></el-menu-item>
      <el-menu-item index="/orders"><el-icon><Tickets /></el-icon><span>全部订单</span></el-menu-item>
      <el-menu-item index="/sessions"><el-icon><User /></el-icon><span>在线用户</span></el-menu-item>
      <div class="group">配置</div>
      <el-menu-item index="/packages"><el-icon><Box /></el-icon><span>套餐管理</span></el-menu-item>
      <el-menu-item index="/routers"><el-icon><Connection /></el-icon><span>路由器管理</span></el-menu-item>
      <el-menu-item index="/settings"><el-icon><Setting /></el-icon><span>系统设置</span></el-menu-item>
    </el-menu>
    <div class="foot">
      <div class="avatar">{{ initial }}</div>
      <div class="info">
        <div class="n">{{ userStore.username || '管理员' }}</div>
        <div class="r">超级管理员</div>
      </div>
    </div>
  </div>
</template>
<script setup>
import { computed } from 'vue';
import { useUserStore } from '@/stores/user';
const userStore = useUserStore();
const initial = computed(() => (userStore.username || '管')[0].toUpperCase());
</script>
<style scoped>
.sidebar { display: flex; flex-direction: column; height: 100%; }
.brand { display: flex; align-items: center; gap: 11px; padding: 22px 20px 20px; border-bottom: 1px solid rgba(255,255,255,0.07); }
.logo { width: 38px; height: 38px; border-radius: 11px; background: linear-gradient(135deg, #4f46e5, #7c3aed); display: flex; align-items: center; justify-content: center; }
.brand .name { font-size: 14.5px; font-weight: 700; color: #f8fafc; }
.brand .sub { font-size: 11px; color: #64748b; margin-top: 2px; }
.menu { flex: 1; border-right: none; padding: 12px; }
.menu :deep(.el-menu-item) { height: 42px; line-height: 42px; border-radius: 10px; margin-bottom: 2px; font-size: 13.5px; }
.menu :deep(.el-menu-item.is-active) { background: linear-gradient(135deg, rgba(79,70,229,0.22), rgba(124,58,237,0.14)) !important; font-weight: 600; }
.group { font-size: 10.5px; font-weight: 700; color: #475569; letter-spacing: 1.2px; padding: 14px 12px 8px; }
.foot { display: flex; align-items: center; gap: 10px; padding: 14px 16px; border-top: 1px solid rgba(255,255,255,0.07); }
.foot .avatar { width: 32px; height: 32px; border-radius: 9px; background: linear-gradient(135deg, #6366f1, #a855f7); display: flex; align-items: center; justify-content: center; color: #fff; font-size: 12.5px; font-weight: 700; }
.foot .n { font-size: 12.5px; color: #e2e8f0; font-weight: 600; }
.foot .r { font-size: 10.5px; color: #64748b; }
</style>
