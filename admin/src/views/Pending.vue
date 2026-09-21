<template>
  <div class="page-card">
    <div class="page-card-head"><h2>待确认订单</h2><span class="count">{{ list.length }}</span></div>
    <el-table :data="list" v-loading="loading" stripe>
      <el-table-column prop="id" label="订单号" width="180" />
      <el-table-column prop="package_name" label="套餐" width="100" />
      <el-table-column label="金额" width="100"><template #default="{ row }">{{ formatMoney(row.amount) }}</template></el-table-column>
      <el-table-column prop="user_contact" label="用户" width="120" />
      <el-table-column label="MAC" width="180"><template #default="{ row }"><span class="mono">{{ row.user_mac }}</span></template></el-table-column>
      <el-table-column label="操作" width="200" align="right">
        <template #default="{ row }">
          <el-button size="small" @click="handleReject(row)">拒绝</el-button>
          <el-button type="success" size="small" @click="handleConfirm(row)">放行</el-button>
        </template>
      </el-table-column>
      <template #empty><el-empty description="全部处理完毕" :image-size="100" /></template>
    </el-table>
  </div>
</template>
<script setup>
import { ref, onMounted } from 'vue';
import { ElMessage, ElMessageBox } from 'element-plus';
import { getOrders, confirmOrder, rejectOrder } from '@/api/order';
import { formatMoney } from '@/utils/format';
const loading = ref(false);
const list = ref([]);
async function load() {
  loading.value = true;
  try { list.value = await getOrders({ status: 'paid', limit: 200 }); } finally { loading.value = false; }
}
async function handleConfirm(row) {
  try {
    await ElMessageBox.confirm(`确认放行 ${row.id}？`, '确认', { type: 'warning' });
    await confirmOrder(row.id);
    ElMessage.success('已放行');
    load();
  } catch (e) {}
}
async function handleReject(row) {
  try {
    await ElMessageBox.confirm(`拒绝 ${row.id}？`, '拒绝', { type: 'warning' });
    await rejectOrder(row.id);
    ElMessage.success('已拒绝');
    load();
  } catch (e) {}
}
onMounted(load);
</script>
