import dayjs from 'dayjs';

export function formatDateTime(s) {
  if (!s) return '—';
  return dayjs(s).format('YYYY-MM-DD HH:mm:ss');
}

export function formatMoney(v) {
  return '¥' + Number(v || 0).toFixed(2);
}

export function remainText(expiresAt) {
  if (!expiresAt) return '—';
  const diff = dayjs(expiresAt).diff(dayjs(), 'second');
  if (diff <= 0) return '已到期';
  const d = Math.floor(diff / 86400);
  const h = Math.floor((diff % 86400) / 3600);
  const m = Math.floor((diff % 3600) / 60);
  if (d > 0) return `${d} 天 ${h} 小时`;
  if (h > 0) return `${h} 小时 ${m} 分`;
  return `${m} 分钟`;
}

export const ORDER_STATUS = {
  pending: { text: '待支付', type: 'info' },
  paid: { text: '待确认', type: 'warning' },
  confirmed: { text: '已开通', type: 'success' },
  expired: { text: '已过期', type: 'info' },
  cancelled: { text: '已取消', type: 'danger' },
};

export function statusInfo(status) {
  return ORDER_STATUS[status] || { text: status, type: 'info' };
}
