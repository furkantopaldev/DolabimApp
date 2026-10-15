/// Yapay zekâ bağlantı ayarı. Değerler derleme sırasında gömülür, kaynak
/// kodda yazmaz:
///
///   flutter run --dart-define-from-file=secrets.json
///
/// İki çalışma biçimi vardır:
///
/// * **Sunucu (önerilen, yayın sürümü):** `AI_SERVER_URL` verilir. Uygulama
///   fotoğrafı kendi sunucuna gönderir, yapay zekâ anahtarı sadece sunucuda
///   durur, telefonda anahtar bulunmaz. `server/` klasöründe hazır sunucu var.
///   `AI_APP_TOKEN` verilirse her istekte başlıkta gönderilir.
/// * **Doğrudan (sadece geliştirme):** `GEMINI_API_KEY` verilir, uygulama
///   Google'a doğrudan bağlanır. Anahtar uygulamanın içinde bulunur ve
///   çıkarılabilir, bu yüzden dağıtılan sürümlerde kullanılmamalıdır.
///
/// `secrets.json` git'e girmez. İkisi de verilmezse yapay zekâ kapalı kalır.
class AiConfig {
  const AiConfig({this.apiKey = '', this.serverUrl = '', this.appToken = ''});

  /// Derleme sırasında `--dart-define` ile verilen yapılandırma.
  static const fromBuild = AiConfig(
    apiKey: String.fromEnvironment('GEMINI_API_KEY'),
    serverUrl: String.fromEnvironment('AI_SERVER_URL'),
    appToken: String.fromEnvironment('AI_APP_TOKEN'),
  );

  /// Sadece geliştirmede, Google'a doğrudan bağlanırken kullanılan anahtar.
  final String apiKey;

  /// Kendi yapay zekâ sunucunun adresi (örn. https://dolabim-ai.ornek.workers.dev).
  final String serverUrl;

  /// Sunucunun istediği uygulama jetonu (isteğe bağlı).
  final String appToken;

  bool get usesServer => serverUrl.trim().isNotEmpty;

  /// Yapay zekâ kullanılabilir mi: ya sunucu adresi ya da (geliştirme için)
  /// anahtar verilmiş olmalı.
  bool get usable => usesServer || apiKey.trim().isNotEmpty;
}
