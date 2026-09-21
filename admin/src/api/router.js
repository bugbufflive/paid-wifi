import request from './request';
export function getRouters() { return request.get('/admin/routers'); }
export function createRouter(data) { return request.post('/admin/routers', data); }
export function resetRouterToken(id) { return request.post(`/admin/routers/${id}/reset-token`); }
export function rebootRouter(id) { return request.post(`/admin/routers/${id}/reboot`); }
