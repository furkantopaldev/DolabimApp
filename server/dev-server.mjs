// Sunucuyu bilgisayarında hızlıca denemek için (Cloudflare hesabı gerekmez):
//
//   cd server
//   node dev-server.mjs
//
// Sırlar `server/.dev.vars` dosyasından okunur (git'e girmez):
//   GEMINI_API_KEY=...
//   APP_TOKEN=...        (isteğe bağlı)
//   GEMINI_MODEL=...     (isteğe bağlı)
//
// Emülatörden bu sunucuya http://10.0.2.2:8787 adresiyle bağlanılır.
// Asıl yayın için `npx wrangler deploy` kullan, bu betik sadece geliştirme içindir.

import http from 'node:http';
import { readFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

import { handle } from './src/index.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const env = {};
const varsFile = path.join(here, '.dev.vars');
if (existsSync(varsFile)) {
  for (const line of readFileSync(varsFile, 'utf8').split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$/);
    if (m) env[m[1]] = m[2].replace(/^["']|["']$/g, '');
  }
}
for (const k of ['GEMINI_API_KEY', 'APP_TOKEN', 'GEMINI_MODEL']) {
  if (process.env[k]) env[k] = process.env[k];
}
if (!env.GEMINI_API_KEY) {
  console.error('GEMINI_API_KEY bulunamadı. server/.dev.vars dosyasına yaz.');
  process.exit(1);
}

const port = Number(process.env.PORT || 8787);

http
  .createServer(async (req, res) => {
    const started = Date.now();
    try {
      const chunks = [];
      for await (const c of req) chunks.push(c);
      const body = Buffer.concat(chunks);
      const request = new Request(`http://localhost:${port}${req.url}`, {
        method: req.method,
        headers: req.headers,
        body: ['GET', 'HEAD'].includes(req.method) ? undefined : body,
      });
      const response = await handle(request, env, fetch);
      const out = Buffer.from(await response.arrayBuffer());
      res.writeHead(response.status, Object.fromEntries(response.headers));
      res.end(out);
      // Günlüğe fotoğraf ve sır yazılmaz, sadece yol, durum ve süre.
      console.log(`${req.method} ${req.url} -> ${response.status} (${Date.now() - started} ms, ${body.length} bayt)`);
    } catch (e) {
      console.error('Sunucu hatası:', e && e.message);
      res.writeHead(500, { 'content-type': 'application/json' });
      res.end(JSON.stringify({ error: 'internal', message: 'Sunucu hatası.' }));
    }
  })
  .listen(port, '0.0.0.0', () => console.log(`Dolabım yapay zekâ sunucusu http://localhost:${port} adresinde`));
