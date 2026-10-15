# Dolabım

Kıyafetlerinin fotoğrafını çek, yapay zeka hava durumuna ve etkinliğe göre kombin önersin.
Alışverişte "bu neyle gider?" diye de bakabilsin. Android ve iOS için Flutter ile yazıldı.

## Ekranlar

- **Seni tanıyalım:** Kadın ya da erkek seçimi. Seçim anında uygulamanın paleti yumuşakça değişir (kadın: pudra pembe, erkek: mavi). Seçim cihazda saklanır.
- **Ana sayfa:** Hava durumu, "bugün ne var?" seçimi ve bugünün kombini.
- **Dolabım:** Arama, kategori filtresi ve kıyafet kartları.
- **Kıyafet ekle:** Kamera ekranı ve yapay zekanın tanıdığı parçanın paneli.
- **Kombin öner:** İş, buluşma, davet için kombin önerisi.
- **Neyle gider?:** Mağazada taranan parçanın dolapla uyumu.

## İlk çalıştırma

Flutter SDK kurulu olmalı (https://docs.flutter.dev/get-started/install).

Bu klasörde Android ve iOS platform dosyaları henüz yok. Flutter'ın onları üretmesi için:

```bash
flutter create --platforms=android,ios --project-name dolabim .
flutter pub get
flutter run
```

`flutter create` komutu `lib/` klasörüne dokunmaz ama yine de çalıştırdıktan sonra `lib/main.dart` dosyasının
bizim `DolabimApp` sınıfını içerdiğini kontrol et. Örnek bir `test/widget_test.dart` oluşursa silebilirsin.

iOS için Mac ve Xcode gerekir. Android için Android Studio ya da bir telefon yeterli.

## Yapay zekâyı açma

Yapay zekâ ile tanıma için **kendi sunucun** gerekir (`server/` klasöründe hazır, Cloudflare Workers).
Yapay zekâ anahtarı sadece sunucuda durur, uygulamanın içinde ve telefonda bulunmaz.

1. Sunucuyu yayınla: `server/README.md` içindeki adımları izle (Cloudflare hesabı ve Gemini anahtarı sen oluşturursun).
2. Çıkan adresi proje klasöründeki `secrets.json` dosyasına yaz (bu dosya git'e girmez):

   ```json
   {
     "AI_SERVER_URL": "https://dolabim-ai.hesap-adin.workers.dev"
   }
   ```

3. Uygulamayı bu dosyayla çalıştır:

```bash
flutter run --dart-define-from-file=secrets.json
flutter build apk --dart-define-from-file=secrets.json
```

VS Code'da `.vscode/launch.json` içindeki "Dolabim (secrets.json ile)" ayarı bunu otomatik yapar.
`secrets.json` boşsa yapay zekâ kapalı kalır, uygulama yine tam çalışır (ad ve tür elle girilir).

Yalnızca geliştirmede, sunucu kurmadan denemek için `secrets.json` içine `"GEMINI_API_KEY"` yazılabilir.
Bu durumda anahtar uygulamanın içine girer ve çıkarılabilir, dağıtılan hiçbir sürümde kullanma.

## Mevcut durum

- **Kamera ve galeri** gerçek (`image_picker`). Eklediğin parçalar fotoğrafıyla birlikte cihazda saklanır.
- **Renk algılama** cihazda çalışır: fotoğrafın ortasındaki baskın renk bulunur ve "Lacivert", "Bej" gibi bir ad alır. Yapay zeka kullanmaz.
- **Etkinlik etiketi:** Her parçaya uygun olduğu etkinlikleri (İş, Buluşma, Davet, Spor) işaretleyebilirsin. Boş bırakırsan her etkinliğe uygun sayılır.
- **Gerçek hava durumu** (Open-Meteo, anahtar gerektirmez). Ana sayfadaki karta dokunup şehri seçersin, seçim saklanır. **Konumumu kullan** düğmesi izin isteyip yaklaşık konumdan şehri bulur (şehir adı için koordinatlar yaklaşık 1 km'ye yuvarlanıp BigDataCloud'a gönderilir). İzin verilmezse ya da konum alınamazsa şehri elle seçebilirsin.
- **Yapay zekâ ile tanıma (isteğe bağlı):** Kıyafet fotoğrafından ad, tür ve etkinlik otomatik doldurulur, mağaza taramasında tür otomatik bulunur. Fotoğraf kendi sunucuna gider, sunucu yapay zekâ servisini kendi anahtarıyla çağırır (yukarıda "Yapay zekâyı açma"). Sunucu yoksa özellik kapalı kalır. **Gizlilik:** Fotoğraf bir yapay zekâ servisine gönderilir. Ücretsiz katmanda servis sağlayıcı içeriği ürünlerini geliştirmek için kullanabilir ve insanlar inceleyebilir, kişilerin göründüğü fotoğrafları gönderme.
- **Stilist motoru** (`lib/stylist/stylist.dart`): kombinleri senin parçalarından üretir. Renk uyumuna (nötr, aynı aile, zıt renkler), etkinliğe ve havaya bakar. Soğukta (gün ya da akşam 17°'nin altında) dış parça ekler, sıcakta eklemez. Kombin kurmaya yetecek parçan yoksa (üst + alt ya da elbise) örnek parçalar gösterilir ve ekranda bunu söyler.
- **Mağaza taraması:** Mağazada ürünün fotoğrafını çek, türünü seç. Dolabındaki parçalarla renk uyumuna göre eşleşir ve kaç kombin çıkacağı hesaplanır. Dolabın boşsa örnek dolapla karşılaştırılır.
- Dolapta kendi parçana dokunarak adını, türünü ve etkinliklerini değiştirebilir ya da silebilirsin (örnek parçalar düzenlenemez).

## Sonraki adımlar

1. Kombin yorumunu da yapay zekâya yazdırmak (şu an kurallarla üretiliyor).
2. Kombini "bugün giydim" diye kaydetme ve geçmiş, aynı kombini üst üste önermeme.
3. Gerçek telefonda ve iOS'ta deneme. Konum alma ve Gemini ile tanıma gerçek cihazda henüz denenmedi, emülatörde sadece izin akışı ve hata yolları denendi.

## Yapı

```
lib/
  main.dart            giriş, tema ve cinsiyet durumu
  theme/               palet (kadın/erkek) ve yazı stilleri
  state/               cinsiyet, dolap, şehir ve hava durumu durumu
  services/            renk analizi, hava durumu, konum, Gemini ve güvenli anahtar deposu
  stylist/             kombin üreten motor
server/                yapay zekâ sunucusu (Cloudflare Workers), anahtar burada durur
  data/                modeller ve örnek veri
  widgets/             ortak bileşenler, animasyonlar, kıyafet silüetleri
  screens/             altı ekran ve alt menü
```
