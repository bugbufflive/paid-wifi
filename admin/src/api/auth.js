import request from './request';
export function login(data) { return request.post('/admin/login', data); }
