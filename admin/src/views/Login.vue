<template>
  <div class="login-page">
    <div class="login-box">
      <h1>付费WiFi管理后台</h1>
      <p class="sub">请登录后继续操作</p>
      <el-form ref="formRef" :model="form" :rules="rules" size="large">
        <el-form-item prop="username"><el-input v-model="form.username" placeholder="用户名" /></el-form-item>
        <el-form-item prop="password"><el-input v-model="form.password" type="password" placeholder="密码" show-password @keyup.enter="handleLogin" /></el-form-item>
        <el-button type="primary" size="large" :loading="loading" style="width:100%;height:46px;" @click="handleLogin">登 录</el-button>
      </el-form>
    </div>
  </div>
</template>
<script setup>
import { ref, reactive } from 'vue';
import { useRouter } from 'vue-router';
import { ElMessage } from 'element-plus';
import { useUserStore } from '@/stores/user';
const router = useRouter();
const userStore = useUserStore();
const formRef = ref();
const loading = ref(false);
const form = reactive({ username: 'admin', password: '' });
const rules = {
  username: [{ required: true, message: '请输入用户名', trigger: 'blur' }],
  password: [{ required: true, message: '请输入密码', trigger: 'blur' }],
};
async function handleLogin() {
  await formRef.value.validate();
  loading.value = true;
  try {
    await userStore.login(form.username, form.password);
    ElMessage.success('登录成功');
    router.push('/dashboard');
  } catch (e) {} finally { loading.value = false; }
}
</script>
<style scoped>
.login-page { height: 100vh; display: flex; align-items: center; justify-content: center; background: radial-gradient(circle at 30% 30%, rgba(99,102,241,0.16), transparent 45%), #0f172a; padding: 24px; }
.login-box { width: 100%; max-width: 380px; background: #fff; border-radius: 20px; padding: 40px 34px 30px; box-shadow: 0 24px 60px rgba(0,0,0,0.3); text-align: center; }
h1 { font-size: 21px; font-weight: 800; color: #0f172a; margin-bottom: 6px; }
.sub { font-size: 13px; color: #94a3b8; margin-bottom: 28px; }
</style>
