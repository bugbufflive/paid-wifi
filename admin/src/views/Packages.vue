<template>
  <div class="page-card">
    <div class="page-card-head"><h2>套餐列表</h2><span class="count">{{ list.length }}</span></div>
    <div class="page-card-body">
      <el-row :gutter="16">
        <el-col v-for="pkg in list" :key="pkg.id" :xs="24" :sm="12" :md="8" :lg="6">
          <div class="pkg-card" :class="{ off: !pkg.enabled }">
            <div class="pkg-name">{{ pkg.name }}</div>
            <div class="pkg-desc">{{ pkg.description || '—' }}</div>
            <div class="pkg-price">¥{{ pkg.price }}</div>
            <div class="pkg-duration">{{ pkg.duration_minutes }} 分钟</div>
            <el-button size="small" @click="toggle(pkg)">{{ pkg.enabled ? '下架' : '上架' }}</el-button>
          </div>
        </el-col>
      </el-row>
    </div>
  </div>
</template>
<script setup>
import { ref, onMounted } from 'vue';
import { ElMessage } from 'element-plus';
import { getPackages, togglePackage } from '@/api/package';
const list = ref([]);
async function load() { list.value = await getPackages(); }
async function toggle(pkg) {
  await togglePackage(pkg.id);
  ElMessage.success(pkg.enabled ? '已下架' : '已上架');
  load();
}
onMounted(load);
</script>
<style scoped>
.pkg-card { border: 1px solid #e8ecf3; border-radius: 13px; padding: 17px; margin-bottom: 16px; background: #fff; }
.pkg-card.off { opacity: 0.55; }
.pkg-name { font-size: 15px; font-weight: 700; margin-bottom: 6px; }
.pkg-desc { font-size: 12px; color: #94a3b8; margin-bottom: 14px; }
.pkg-price { font-size: 25px; font-weight: 800; color: #4f46e5; }
.pkg-duration { font-size: 11.5px; color: #94a3b8; margin-bottom: 13px; }
</style>
