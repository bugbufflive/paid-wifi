<template>
  <el-container class="layout">
    <el-aside width="232px" class="aside"><Sidebar /></el-aside>
    <el-container>
      <el-header height="62px" class="header"><Header /></el-header>
      <el-main class="main">
        <router-view v-slot="{ Component }">
          <transition name="fade" mode="out-in">
            <component :is="Component" />
          </transition>
        </router-view>
      </el-main>
    </el-container>
  </el-container>
</template>
<script setup>
import Sidebar from './Sidebar.vue';
import Header from './Header.vue';
</script>
<style scoped>
.layout { height: 100vh; }
.aside { background: #111827; overflow: hidden; }
.header { background: #fff; border-bottom: 1px solid #e8ecf3; padding: 0; }
.main { background: #f5f6fa; padding: 24px; overflow-y: auto; }
.fade-enter-active, .fade-leave-active { transition: opacity 0.2s ease; }
.fade-enter-from, .fade-leave-to { opacity: 0; }
</style>
