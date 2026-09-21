import request from './request';
export function getSessions(params = {}) { return request.get('/admin/sessions', { params }); }
export function kickSession(mac) { return request.post(`/admin/sessions/${mac}/kick`); }
