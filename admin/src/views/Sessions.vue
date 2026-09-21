<template>
  <div class="page-card">
    <div class="page-card-head"><h2>在线用户</h2><span class="count">{{ list.length }}</span></div>
    <el-table :data="list" v-loading="loading" stripe>
      <el-table-column label="MAC" width="200"><template #default="{ row }"><span class="mono">{{ row.user_mac }}</span></template></el-table-column>
      <el-table-column prop="package_name" label="套餐" width="100" />
      <el-table-column label="开始时间" width="170"><template #default="{ row }">{{ formatDateTime(row.started_at) }}</template></el-table-column>
      <el-table-column label="到期时间" width="170"><template #default="{ row }">{{ formatDateTime(row.expires_at) }}</template></el-table-column>
      <el-table-column label="剩余" width="140"><template #default="{ row }">{{ remainText(row.expires_at) }}</template></el-table-column>
      <el-table-column label="操作" align="right">
        <template #default="{ row }"><el-button type="danger" size="small" @click="handleKick(row)">强制下线</el-button></template>
      </el-table-column>
      <template #empty><el-empty description="当前没有在线设备" :image-size="100" /></template>
    </el-table>
  </div>
</template>
<script setup>
import { ref, onMounted } from 'vue';
import { ElMessage, ElMessageBox } from 'element-plus';
import { getSessions, kickSession } from '@/api/session';
import { formatDateTime, remainText } from '@/utils/format';
const loading = ref(false);
const list = ref([]);
async function load() {
  loading.value = true;
  try { list.value = await getSessions({ active: 1 }); } finally { loading.value = false; }
}
async function handleKick(row) {
  try {
    await ElMessageBox.confirm(`强制下线 ${row.user_mac}？`, '确认', { type: 'warning' });
    await kickSession(row.user_mac);
    ElMessage.success('已下发');
    load();
  } catch (e) {}
}
onMounted(load);
</script>
