<template>
  <div class="page-card">
    <div class="page-card-head">
      <h2>全部订单</h2>
      <div class="spacer"></div>
      <el-select v-model="status" style="width: 130px;" @change="load">
        <el-option label="全部" value="all" />
        <el-option label="待确认" value="paid" />
        <el-option label="已开通" value="confirmed" />
        <el-option label="已过期" value="expired" />
      </el-select>
    </div>
    <el-table :data="list" v-loading="loading" stripe>
      <el-table-column prop="id" label="订单号" width="180" />
      <el-table-column prop="package_name" label="套餐" width="100" />
      <el-table-column label="金额" width="100"><template #default="{ row }">{{ formatMoney(row.amount) }}</template></el-table-column>
      <el-table-column prop="user_contact" label="用户" width="120" />
      <el-table-column label="状态" width="100"><template #default="{ row }"><el-tag :type="statusInfo(row.status).type" size="small">{{ statusInfo(row.status).text }}</el-tag></template></el-table-column>
      <el-table-column label="创建时间" width="170"><template #default="{ row }">{{ formatDateTime(row.created_at) }}</template></el-table-column>
      <el-table-column label="操作" align="right">
        <template #default="{ row }">
          <el-button v-if="row.status === 'paid'" type="success" size="small" @click="handleConfirm(row)">放行</el-button>
        </template>
      </el-table-column>
    </el-table>
  </div>
</template>
<script setup>
import { ref, onMounted } from 'vue';
import { ElMessage, ElMessageBox } from 'element-plus';
import { getOrders, confirmOrder } from '@/api/order';
import { formatDateTime, formatMoney, statusInfo } from '@/utils/format';
const loading = ref(false);
const list = ref([]);
const status = ref('all');
async function load() {
  loading.value = true;
  try { list.value = await getOrders({ status: status.value, limit: 200 }); } finally { loading.value = false; }
}
async function handleConfirm(row) {
  try {
    await ElMessageBox.confirm(`放行 ${row.id}？`, '确认', { type: 'warning' });
    await confirmOrder(row.id);
    ElMessage.success('已放行');
    load();
  } catch (e) {}
}
onMounted(load);
</script>
