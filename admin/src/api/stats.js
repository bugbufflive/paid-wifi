import request from './request';
export function getStats(params) { return request.get('/admin/stats', { params }); }
