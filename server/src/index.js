// Dolabım yapay zekâ sunucusu (Cloudflare Workers).
//
// Uygulama fotoğrafı bu sunucuya gönderir, sunucu Gemini'yi kendi anahtarıyla
// çağırır. Anahtar sadece burada (Worker sırrı olarak) durur, telefonda yoktur.
//
// Uç noktalar:
//   GET  /health   -> { ok: true }
//   POST /analyze  -> { image (base64), mimeType, categories } girer,
//                     { name, category, color, events } çıkar.
//
// Sunucu genel bir Gemini aktarıcısı değildir: yönerge ve şema burada sabittir,
// istemci sadece fotoğraf ve izin verilen türleri gönderebilir.

export const CATEGORIES = ['Üst', 'Alt', 'Elbise', 'Dış giyim', 'Ayakkabı', 'Çanta'];
export const EVENTS = ['İş', 'Buluşma', 'Davet', 'Spor'];
const MIME_TYPES = new Set(['image/jpeg', 'image/png', 'image/webp']);

// Uygulama fotoğrafı en fazla 1400 piksel genişlikte gönderir. Bu sınır
// kötüye kullanımı engellemek için bunun çok üstünde tutulur.
export const MAX_IMAGE_BASE64 = 5_000_000; // ~3.7 MB ham veri
const MAX_BODY_BYTES = MAX_IMAGE_BASE64 + 4_000;
const UPSTREAM_TIMEOUT_MS = 30_000;
const DEFAULT_MODEL = 'gemini-3.5-flash-lite';
const BASE64_RE = /^[A-Za-z0-9+/]+={0,2}$/;

export default {
  fetch(request, env) {
    return handle(request, env, fetch);
  },
};

/** Sınanabilmesi için bağımlılıkları (fetch) dışarıdan alan asıl işleyici. */
export async function handle(request, env, fetchImpl) {
  const url = new URL(request.url);

  if (url.pathname === '/health') {
    if (request.method !== 'GET') return fail(405, 'method_not_allowed', 'Yöntem desteklenmiyor.');
    return json({ ok: true });
  }

  if (url.pathname !== '/analyze') return fail(404, 'not_found', 'Bulunamadı.');
  if (request.method !== 'POST') return fail(405, 'method_not_allowed', 'Yöntem desteklenmiyor.');

  if (!env.GEMINI_API_KEY) {
    // Yapılandırma hatası sunucu tarafında kalır, istemciye ayrıntı verilmez.
    console.error('GEMINI_API_KEY tanımlı değil.');
    return fail(502, 'upstream', 'Yapay zekâ servisi şu an kullanılamıyor.');
  }

  if (env.APP_TOKEN && !safeEqual(request.headers.get('x-app-token') ?? '', env.APP_TOKEN)) {
    return fail(401, 'unauthorized', 'İzin yok.');
  }

  if (env.RATE) {
    const key = request.headers.get('cf-connecting-ip') || 'anonymous';
    const { success } = await env.RATE.limit({ key });
    if (!success) return fail(429, 'rate_limited', 'Çok fazla istek. Biraz bekleyip tekrar dene.');
  }

  const parsed = await readRequest(request);
  if (parsed.error) return parsed.error;

  const model = env.GEMINI_MODEL || DEFAULT_MODEL;
  let upstream;
  try {
    upstream = await fetchImpl(
      `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent`,
      {
        method: 'POST',
        headers: { 'content-type': 'application/json', 'x-goog-api-key': env.GEMINI_API_KEY },
        body: JSON.stringify(buildGeminiRequest(parsed)),
        signal: AbortSignal.timeout(UPSTREAM_TIMEOUT_MS),
      },
    );
  } catch (e) {
    console.error('Gemini isteği başarısız:', e && e.name);
    return fail(502, 'upstream', 'Yapay zekâ servisine ulaşılamadı.');
  }

  if (upstream.status === 429) {
    return fail(429, 'quota', 'Kullanım sınırına ulaşıldı. Biraz bekleyip tekrar dene.');
  }
  if (!upstream.ok) {
    // 400/403/404 gibi hatalar bizim yapılandırmamızdan gelir, ayrıntı sızdırılmaz.
    console.error('Gemini hata kodu:', upstream.status);
    return fail(502, 'upstream', 'Yapay zekâ servisi şu an kullanılamıyor.');
  }

  let body;
  try {
    body = await upstream.json();
  } catch {
    return fail(502, 'upstream', 'Yapay zekâ yanıtı okunamadı.');
  }

  if (body?.promptFeedback?.blockReason) {
    return fail(422, 'blocked', 'Bu fotoğraf analiz edilemedi.');
  }
  const result = normalize(body, parsed.categories);
  if (!result) return fail(502, 'upstream', 'Yapay zekâ parçayı tanıyamadı.');
  return json(result);
}

/** İstek gövdesini doğrular. Hata varsa { error: Response } döner. */
async function readRequest(request) {
  const declared = Number(request.headers.get('content-length') ?? '0');
  if (declared > MAX_BODY_BYTES) return { error: tooLarge() };

  let text;
  try {
    text = await request.text();
  } catch {
    return { error: fail(400, 'bad_request', 'İstek okunamadı.') };
  }
  if (text.length > MAX_BODY_BYTES) return { error: tooLarge() };

  let data;
  try {
    data = JSON.parse(text);
  } catch {
    return { error: fail(400, 'bad_request', 'Geçersiz JSON.') };
  }
  if (!data || typeof data !== 'object') {
    return { error: fail(400, 'bad_request', 'Geçersiz istek.') };
  }

  const image = data.image;
  if (typeof image !== 'string' || image.length < 8) {
    return { error: fail(400, 'bad_request', 'Fotoğraf eksik.') };
  }
  if (image.length > MAX_IMAGE_BASE64) return { error: tooLarge() };
  if (!BASE64_RE.test(image)) {
    return { error: fail(400, 'bad_request', 'Fotoğraf geçersiz.') };
  }

  const mimeType = data.mimeType ?? 'image/jpeg';
  if (!MIME_TYPES.has(mimeType)) {
    return { error: fail(400, 'bad_request', 'Fotoğraf türü desteklenmiyor.') };
  }

  let categories = CATEGORIES;
  if (data.categories !== undefined) {
    const c = data.categories;
    if (
      !Array.isArray(c) ||
      c.length === 0 ||
      c.length > CATEGORIES.length ||
      !c.every((x) => CATEGORIES.includes(x))
    ) {
      return { error: fail(400, 'bad_request', 'Türler geçersiz.') };
    }
    categories = [...new Set(c)];
  }
  return { image, mimeType, categories };
}

export function buildGeminiRequest({ image, mimeType, categories }) {
  return {
    contents: [
      {
        role: 'user',
        parts: [
          {
            text:
              'Bu fotoğraftaki tek bir kıyafeti ya da aksesuarı analiz et. Sadece JSON döndür. ' +
              'name: renk tonunu ve türü içeren kısa Türkçe ad, ton açık ya da koyuysa belirt ' +
              '(örn. "Krem blazer", "Açık mavi blazer", "Koyu yeşil kazak"). ' +
              `category: şunlardan biri: ${categories.join(', ')}. ` +
              'color: baskın renk tonu, Türkçe (örn. "açık mavi"). ' +
              `events: kıyafetin uygun olduğu etkinlikler, şunlardan seç: ${EVENTS.join(', ')}.`,
          },
          { inline_data: { mime_type: mimeType, data: image } },
        ],
      },
    ],
    generationConfig: {
      temperature: 0.2,
      responseMimeType: 'application/json',
      responseSchema: {
        type: 'OBJECT',
        properties: {
          name: { type: 'STRING' },
          category: { type: 'STRING', enum: categories },
          color: { type: 'STRING' },
          events: { type: 'ARRAY', items: { type: 'STRING', enum: EVENTS } },
        },
        required: ['name', 'category'],
      },
    },
  };
}

/** Gemini yanıtını temizleyip istemcinin beklediği biçime çevirir. */
export function normalize(body, categories = CATEGORIES) {
  let text;
  try {
    const parts = body.candidates[0].content.parts;
    text = parts.map((p) => (typeof p.text === 'string' ? p.text : '')).join('');
  } catch {
    return null;
  }
  const start = text.indexOf('{');
  const end = text.lastIndexOf('}');
  if (start < 0 || end < start) return null;

  let m;
  try {
    m = JSON.parse(text.slice(start, end + 1));
  } catch {
    return null;
  }

  const name = typeof m.name === 'string' ? m.name.trim().slice(0, 60) : '';
  if (!name) return null;

  const wanted = typeof m.category === 'string' ? trLower(m.category.trim()) : '';
  const category =
    categories.find((c) => trLower(c) === wanted) ??
    (categories.includes('Üst') ? 'Üst' : categories[0]);

  const events = Array.isArray(m.events)
    ? [...new Set(m.events.map((e) => trLower(String(e).trim())))]
        .map((e) => EVENTS.find((x) => trLower(x) === e))
        .filter(Boolean)
    : [];

  const color = typeof m.color === 'string' ? m.color.trim().slice(0, 30) : '';
  return { name, category, color: color || null, events };
}

/** Türkçe'ye uygun küçük harf (İ -> i, I -> ı). Varsayılan çevirme "İ"yi bozar. */
export function trLower(s) {
  return String(s).replace(/İ/g, 'i').replace(/I/g, 'ı').toLowerCase();
}

/** Zamanlama saldırılarına karşı sabit sürede karşılaştırma. */
export function safeEqual(a, b) {
  const x = new TextEncoder().encode(a);
  const y = new TextEncoder().encode(b);
  let diff = x.length ^ y.length;
  const len = Math.max(x.length, y.length);
  for (let i = 0; i < len; i++) diff |= (x[i] ?? 0) ^ (y[i] ?? 0);
  return diff === 0;
}

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store' },
  });
}

function fail(status, error, message) {
  return json({ error, message }, status);
}

function tooLarge() {
  return fail(413, 'too_large', 'Fotoğraf çok büyük.');
}
