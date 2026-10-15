# Dolabım yapay zekâ sunucusu

Uygulama, kıyafet fotoğrafını bu sunucuya gönderir. Sunucu Gemini'yi kendi anahtarıyla çağırır.
**Anahtar sadece sunucuda durur, telefonda ve APK'da bulunmaz.** Cloudflare Workers üzerinde
çalışır, ücretsiz katman bu iş için yeterlidir.

## Ne yapar

| Uç nokta | Açıklama |
| --- | --- |
| `GET /health` | `{ "ok": true }` döner, bağlantı denemesi için. |
| `POST /analyze` | `{ image (base64), mimeType, categories }` alır, `{ name, category, color, events }` döner. |

Sunucu genel bir Gemini aktarıcısı **değildir**:

- Yönerge ve şema sunucuda sabittir. Uygulama sadece fotoğraf ve izin verilen türleri gönderebilir, kendi yönergesini gönderemez. Bu yüzden anahtarın ele geçse bile keyfi sorgu çalıştırılamaz.
- Gelen veri doğrulanır: base64 biçimi, fotoğraf türü (jpeg, png, webp), tür listesi, boyut sınırı (yaklaşık 3,7 MB).
- İstek sayısı sınırlanır (`wrangler.toml` içinde dakikada 20, aynı yerden).
- İsteğe bağlı uygulama jetonu (`APP_TOKEN`) ile sadece uygulamanın istek atması istenebilir.
- Gemini'den gelen hata ayrıntıları dışarı verilmez, günlüklere fotoğraf ve anahtar yazılmaz.

## Yayınlama (ilk kez)

Gerekenler: ücretsiz bir [Cloudflare hesabı](https://dash.cloudflare.com/sign-up) ve Node.js.
Hesabı ve Gemini anahtarını sen oluşturursun.

```bash
cd server
npm install
npx wrangler login
npx wrangler secret put GEMINI_API_KEY
npx wrangler deploy
```

- `secret put` anahtarı sorar, yazdığın değer ekranda görünmez ve hiçbir dosyaya kaydedilmez.
- `deploy` sonunda `https://dolabim-ai.<hesap-adın>.workers.dev` gibi bir adres verir.
- Doğru çalıştığını denemek için tarayıcıda `<adres>/health` aç, `{"ok":true}` görmelisin.

## Uygulamaya bağlama

Proje klasöründeki `secrets.json` dosyasına sunucu adresini yaz (anahtar yazma):

```json
{
  "AI_SERVER_URL": "https://dolabim-ai.hesap-adin.workers.dev"
}
```

```bash
flutter run --dart-define-from-file=secrets.json
flutter build apk --dart-define-from-file=secrets.json
```

### Uygulama jetonu (önerilir)

Sunucuyu sadece uygulamanın kullanabilmesi için rastgele uzun bir değer üret:

```bash
npx wrangler secret put APP_TOKEN
```

Aynı değeri `secrets.json` içine `"AI_APP_TOKEN"` olarak ekle. Jeton uygulamanın içinde bulunduğu
için çıkarılabilir, bu yüzden tek başına koruma değildir. Hız sınırıyla birlikte rastgele
kullanımı zorlaştırır. Daha güçlü koruma için ileride Play Integrity / App Attest doğrulaması eklenebilir.

## Modeli değiştirmek

`wrangler.toml` içindeki `GEMINI_MODEL` değerini düzenleyip `npx wrangler deploy` çalıştır.
Uygulamayı güncellemek gerekmez. Model adı değişirse ya da eskirse bu tek yerden düzeltilir.

## Yerelde denemek (hesap gerekmez)

`server/.dev.vars` dosyası oluştur (git'e girmez):

```
GEMINI_API_KEY=anahtarini-buraya-yaz
```

```bash
cd server
node dev-server.mjs
```

Emülatörde uygulama için `secrets.json` içine `"AI_SERVER_URL": "http://10.0.2.2:8787"` yaz
(debug sürümü bu düz HTTP adresine izin verir, yayın sürümü sadece HTTPS ile çalışır).

## Testler

```bash
cd server
npm test
```

## Güvenlik notları

- `GEMINI_API_KEY`, `APP_TOKEN` ve `.dev.vars` hiçbir zaman git'e girmemeli (`.gitignore` içinde).
- Ücretsiz katmanda Google gönderilen fotoğrafları ürünlerini geliştirmek için kullanabilir. Ücretli
  katmana geçersen bu geçerli olmaz. Uygulamanın gizlilik metnini buna göre güncelle.
- Hız sınırı Cloudflare'in konum başına, "eventually consistent" sayacıdır, kesin bir kota değildir.
  Toplam harcamayı sınırlamak için Google tarafında anahtara kota koy.
