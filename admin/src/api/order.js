import request from './request';
export function getOrders(params) { return request.get('/admin/orders', { params }); }
export function confirmOrder(id) { return request.post(`/admin/orders/${id}/confirm`); }
export function rejectOrder(id) { return request.post(`/admin/orders/${id}/reject`); }
