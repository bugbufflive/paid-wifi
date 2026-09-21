import request from './request';
export function getPackages() { return request.get('/admin/packages'); }
export function createPackage(data) { return request.post('/admin/packages', data); }
export function updatePackage(id, data) { return request.put(`/admin/packages/${id}`, data); }
export function togglePackage(id) { return request.post(`/admin/packages/${id}/toggle`); }
