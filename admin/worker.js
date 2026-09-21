const VPS_ORIGIN = 'https://paid-wifi.diego.de5.net';

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors(url.origin) });
    if (url.pathname.startsWith('/api/') || url.pathname === '/health') return proxy(request, url);
    if (!env.ASSETS) return json({ ok: false, error: 'no assets' }, 500);
    try {
      const r = await env.ASSETS.fetch(request);
      if (r.status === 404) return index(request, env);
      const h = new Headers(r.headers);
      if (url.pathname.startsWith('/assets/')) h.set('Cache-Control', 'public, max-age=31536000, immutable');
      return new Response(r.body, { status: r.status, headers: h });
    } catch { return index(request, env); }
  },
};

async function proxy(request, url) {
  const target = VPS_ORIGIN + url.pathname + url.search;
  const h = new Headers(request.headers);
  h.set('X-Real-IP', request.headers.get('CF-Connecting-IP') || '');
  h.delete('cf-connecting-ip');
  h.delete('cf-ray');
  const init = { method: request.method, headers: h, redirect: 'manual' };
  if (!['GET', 'HEAD'].includes(request.method)) {
    init.body = request.body;
    init.duplex = 'half';
  }
  try {
    const r = await fetch(target, init);
    const rh = new Headers(r.headers);
    for (const [k, v] of Object.entries(cors(url.origin))) rh.set(k, v);
    rh.delete('server');
    return new Response(r.body, { status: r.status, headers: rh });
  } catch (e) {
    return json({ ok: false, error: 'VPS unreachable' }, 502);
  }
}

async function index(request, env) {
  const u = new URL('/index.html', request.url);
  const r = await env.ASSETS.fetch(new Request(u.toString(), { method: 'GET' }));
  const h = new Headers(r.headers);
  h.set('Content-Type', 'text/html; charset=utf-8');
  return new Response(r.body, { status: 200, headers: h });
}

function cors(o = '*') {
  return {
    'Access-Control-Allow-Origin': o,
    'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type,Authorization,X-Router-Token',
    'Access-Control-Max-Age': '86400',
  };
}

function json(d, s = 200) {
  return new Response(JSON.stringify(d), {
    status: s,
    headers: { 'Content-Type': 'application/json', ...cors() },
  });
}
