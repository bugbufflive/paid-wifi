<template>
  <div class="header">
    <h1>{{ pageTitle }}</h1>
    <div class="right">
      <el-button :icon="Refresh" @click="refresh">刷新</el-button>
      <el-dropdown @command="handleCommand">
        <el-button text>
          <el-icon><User /></el-icon>
          <span style="margin-left:4px;">{{ userStore.username }}</span>
        </el-button>
        <template #dropdown>
          <el-dropdown-menu>
            <el-dropdown-item command="settings">系统设置</el-dropdown-item>
            <el-dropdown-item command="logout" divided>退出登录</el-dropdown-item>
          </el-dropdown-menu>
        </template>
      </el-dropdown>
    </div>
  </div>
</template>
<script setup>
import { computed } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { ElMessage } from 'element-plus';
import { Refresh, User } from '@element-plus/icons-vue';
import { useUserStore } from '@/stores/user';
const route = useRoute();
const router = useRouter();
const userStore = useUserStore();
const pageTitle = computed(() => route.meta.title || '');
function refresh() { window.location.reload(); }
function handleCommand(cmd) {
  if (cmd === 'logout') {
    userStore.logout();
    ElMessage.success('已退出');
    router.push('/login');
  } else if (cmd === 'settings') {
    router.push('/settings');
  }
}
</script>
<style scoped>
.header { height: 100%; display: flex; align-items: center; padding: 0 24px; gap: 12px; }
h1 { font-size: 17px; font-weight: 700; color: #1e293b; }
.right { margin-left: auto; display: flex; align-items: center; gap: 12px; }
</style>
