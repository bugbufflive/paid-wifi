<template>
  <div>
    <div class="stat-grid">
      <div class="stat-card"><div class="label">今日收益</div><div class="value primary">{{ formatMoney(stats.todayRevenue) }}</div></div>
      <div class="stat-card"><div class="label">今日订单</div><div class="value">{{ stats.todayOrders }}</div></div>
      <div class="stat-card"><div class="label">待确认</div><div class="value warn">{{ stats.pendingCount }}</div></div>
      <div class="stat-card"><div class="label">在线设备</div><div class="value success">{{ stats.onlineCount }}</div></div>
    </div>
    <div class="page-card">
      <div class="page-card-head"><h2>待确认订单</h2><span class="count">{{ stats.pendingCount }}</span><div class="spacer"></div></div>
      <el-table :data="pendingOrders" v-loading="loading" stripe>
        <el-table-column prop="id" label="订单号" width="180" />
        <el-table-column prop="package_name" label="套餐" width="100" />
        <el-table-column label="金额" width="100"><template #default="{ row }">{{ formatMoney(row.amount) }}</template></el-table-column>
        <el-table-column prop="user_contact" label="用户" width="120" />
        <el-table-column label="操作" width="140" align="right">
          <template #default="{ row }"><el-button type="success" size="small" @click="handleConfirm(row)">确认放行</el-button></template>
        </el-table-column>
        <template #empty><el-empty description="暂无待确认订单" :image-size="80" /></template>
      </el-table>
    </div>
  </div>
</template>
<script setup>
import { ref, onMounted } from 'vue';
import { ElMessage, ElMessageBox } from 'element-plus';
import { getStats } from '@/api/stats';
import { getOrders, confirmOrder } from '@/api/order';
import { formatMoney } from '@/utils/format';
const loading = ref(false);
const stats = ref({ todayRevenue: 0, todayOrders: 0, pendingCount: 0, onlineCount: 0 });
const pendingOrders = ref([]);
async function load() {
  loading.value = true;
  try {
    const [s, p] = await Promise.all([getStats(), getOrders({ status: 'paid', limit: 5 })]);
    stats.value = s; pendingOrders.value = p;
  } finally { loading.value = false; }
}
async function handleConfirm(row) {
  try {
    await ElMessageBox.confirm(`确认放行 ${row.id}？`, '确认', { type: 'warning' });
    await confirmOrder(row.id);
    ElMessage.success('已放行');
    load();
  } catch (e) {}
}
onMounted(load);
</script>
