<template>
  <div class="page-card">
    <div class="page-card-head"><h2>路由器列表</h2><span class="count">{{ list.length }}</span></div>
    <el-table :data="list" v-loading="loading" stripe>
      <el-table-column label="状态" width="90">
        <template #default="{ row }"><el-tag :type="row.status === 'online' ? 'success' : 'info'" size="small">{{ row.status === 'online' ? '在线' : '离线' }}</el-tag></template>
      </el-table-column>
      <el-table-column prop="name" label="名称" width="150" />
      <el-table-column prop="router_id" label="Router ID" width="120" />
      <el-table-column prop="location" label="位置" width="150" />
      <el-table-column label="操作" width="200" align="right">
        <template #default="{ row }">
          <el-button size="small" @click="resetToken(row)">重置 Token</el-button>
          <el-button size="small" @click="reboot(row)">重启</el-button>
        </template>
      </el-table-column>
    </el-table>
    <el-dialog v-model="tokenVisible" title="Router Token" width="500">
      <el-alert type="warning" :closable="false" title="只显示一次，请立即保存" style="margin-bottom:12px;" />
      <p><strong>Router ID：</strong><code>{{ tokenInfo.id }}</code></p>
      <p style="word-break:break-all;"><strong>Token：</strong><code>{{ tokenInfo.token }}</code></p>
    </el-dialog>
  </div>
</template>
<script setup>
import { ref, reactive, onMounted } from 'vue';
import { ElMessage, ElMessageBox } from 'element-plus';
import { getRouters, resetRouterToken, rebootRouter } from '@/api/router';
const loading = ref(false);
const list = ref([]);
const tokenVisible = ref(false);
const tokenInfo = reactive({ id: '', token: '' });
async function load() {
  loading.value = true;
  try { list.value = await getRouters(); } finally { loading.value = false; }
}
async function resetToken(row) {
  try {
    await ElMessageBox.confirm(`重置 ${row.name} 的 Token？`, '确认', { type: 'warning' });
    const res = await resetRouterToken(row.router_id);
    tokenInfo.id = row.router_id;
    tokenInfo.token = res.token;
    tokenVisible.value = true;
  } catch (e) {}
}
async function reboot(row) {
  try {
    await ElMessageBox.confirm(`重启 ${row.name}？`, '确认', { type: 'warning' });
    await rebootRouter(row.router_id);
    ElMessage.success('指令已下发');
  } catch (e) {}
}
onMounted(load);
</script>
