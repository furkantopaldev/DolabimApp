import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/ai_config.dart';
import '../data/models.dart';

enum AiErrorKind { auth, quota, model, network, blocked, parse }

class AiException implements Exception {
  AiException(this.kind, this.message);

  final AiErrorKind kind;
  final String message;

  @override
  String toString() => message;
}

/// Türkçe'ye uygun küçük harf (İ -> i, I -> ı). Varsayılan çevirme "İ"yi bozar.
String trLower(String s) => s.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();

/// Yapay zekânın bir kıyafet fotoğrafından çıkardığı bilgiler.
class GarmentAnalysis {
  const GarmentAnalysis({
    required this.name,
    required this.category,
    this.colorName,
    this.events = const {},
  });

  final String name;
  final String category;
  final String? colorName;
  final Set<EventType> events;
}

/// Kıyafet fotoğrafını yapay zekâ ile tanır.
///
/// [AiConfig] sunucu adresi verdiyse fotoğraf kendi sunucuna gider (anahtar
/// telefonda bulunmaz, yönerge sunucudadır). Yalnızca geliştirmede anahtar
/// verilirse Google'a doğrudan bağlanılır.
class AiService {
  AiService({
    http.Client? client,
    this.config = AiConfig.fromBuild,
    this.model = defaultModel,
  }) : _client = client ?? http.Client();

  final AiConfig config;

  /// Doğrudan (geliştirme) modunda kullanılan model. Sunucu modunda model
  /// sunucuda ayarlanır.
  final String model;

  static const defaultModel = 'gemini-3.5-flash-lite';
  static const _googleBase = 'https://generativelanguage.googleapis.com';
  static const _timeout = Duration(seconds: 40);

  final http.Client _client;

  Future<GarmentAnalysis> analyzeGarment({
    required Uint8List bytes,
    required List<String> categories,
    String mimeType = 'image/jpeg',
  }) async {
    if (config.usesServer) {
      final json = await _send(
        'POST',
        _serverUri('/analyze'),
        _serverHeaders(),
        jsonEncode({
          'image': base64Encode(bytes),
          'mimeType': mimeType,
          'categories': categories,
        }),
      );
      return analysisFromMap(json, categories);
    }
    final json = await _send(
      'POST',
      _googleUri(),
      _googleHeaders(),
      jsonEncode(buildRequest(bytes: bytes, categories: categories, mimeType: mimeType)),
    );
    return parseAnalysis(json, categories);
  }

  /// Bağlantının çalıştığını küçük bir istekle dener.
  Future<void> ping() async {
    if (config.usesServer) {
      await _send('GET', _serverUri('/health'), _serverHeaders(), null);
      return;
    }
    final json = await _send(
      'POST',
      _googleUri(),
      _googleHeaders(),
      jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': 'Sadece "tamam" yaz.'},
            ],
          },
        ],
      }),
    );
    _text(json); // Yanıt okunamazsa hata fırlatır.
  }

  // ---- adresler ve başlıklar ----

  Uri _serverUri(String path) {
    final base = config.serverUrl.trim().replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$base$path');
  }

  Map<String, String> _serverHeaders() => {
        'Content-Type': 'application/json',
        if (config.appToken.trim().isNotEmpty) 'x-app-token': config.appToken.trim(),
      };

  Uri _googleUri() => Uri.parse(
        '$_googleBase/v1beta/models/${Uri.encodeComponent(model)}:generateContent',
      );

  Map<String, String> _googleHeaders() => {
        'Content-Type': 'application/json',
        'x-goog-api-key': config.apiKey.trim(),
      };

  // ---- istek gönderme ----

  Future<Map<String, dynamic>> _send(
    String method,
    Uri uri,
    Map<String, String> headers,
    String? body,
  ) async {
    final http.Response res;
    try {
      res = await (method == 'GET'
              ? _client.get(uri, headers: headers)
              : _client.post(uri, headers: headers, body: body))
          .timeout(_timeout);
    } catch (_) {
      throw AiException(
        AiErrorKind.network,
        'Yapay zekâya bağlanılamadı. İnternet bağlantını kontrol et.',
      );
    }
    if (res.statusCode != 200) throw _errorFor(res, viaServer: config.usesServer);
    try {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw AiException(AiErrorKind.parse, 'Yapay zekâ yanıtı okunamadı.');
    }
  }

  static AiException _errorFor(http.Response res, {required bool viaServer}) {
    String detail = '';
    String serverMessage = '';
    try {
      final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final err = j['error'];
      if (err is Map<String, dynamic>) {
        detail = (err['message'] as String?) ?? '';
      } else if (err is String) {
        // Kendi sunucumuz {error: kod, message: Türkçe mesaj} döner.
        serverMessage = (j['message'] as String?) ?? '';
      }
    } catch (_) {
      // Gövde JSON değilse ayrıntı boş kalır.
    }
    final code = res.statusCode;

    if (viaServer) {
      if (code == 401 || code == 403) {
        return AiException(AiErrorKind.auth, 'Yapay zekâ servisine erişim izni yok.');
      }
      if (code == 429) {
        return AiException(
          AiErrorKind.quota,
          serverMessage.isEmpty
              ? 'Çok fazla istek gönderildi. Biraz bekleyip tekrar dene.'
              : serverMessage,
        );
      }
      if (code == 422) {
        return AiException(AiErrorKind.blocked, 'Bu fotoğraf analiz edilemedi.');
      }
      if (code == 413) {
        return AiException(AiErrorKind.parse, 'Fotoğraf çok büyük.');
      }
      if (code >= 500) {
        return AiException(
          AiErrorKind.network,
          'Yapay zekâ servisi şu an yanıt vermiyor. Biraz sonra tekrar dene.',
        );
      }
      return AiException(AiErrorKind.parse, 'İstek reddedildi ($code).');
    }

    if (code == 401 || code == 403 || (code == 400 && detail.contains('API key'))) {
      return AiException(
        AiErrorKind.auth,
        'Yapay zekâ anahtarı geçersiz ya da bu işleme izni yok.',
      );
    }
    if (code == 404) {
      return AiException(
        AiErrorKind.model,
        'Yapay zekâ modeli bulunamadı. Model adı güncel olmayabilir.',
      );
    }
    if (code == 429) {
      return AiException(
        AiErrorKind.quota,
        'Ücretsiz kullanım sınırına ulaşıldı. Biraz bekleyip tekrar dene.',
      );
    }
    if (code >= 500) {
      return AiException(
        AiErrorKind.network,
        'Yapay zekâ servisi şu an yanıt vermiyor. Biraz sonra tekrar dene.',
      );
    }
    final short = detail.length > 120 ? '${detail.substring(0, 120)}…' : detail;
    return AiException(
      AiErrorKind.parse,
      short.isEmpty ? 'İstek reddedildi ($code).' : 'İstek reddedildi: $short',
    );
  }

  // ---- doğrudan (geliştirme) modu: istek ve yanıt ----

  static Map<String, dynamic> buildRequest({
    required Uint8List bytes,
    required List<String> categories,
    String mimeType = 'image/jpeg',
  }) {
    final events = [for (final e in EventType.values) e.label];
    return {
      'contents': [
        {
          'role': 'user',
          'parts': [
            {
              'text': 'Bu fotoğraftaki tek bir kıyafeti ya da aksesuarı analiz et. '
                  'Sadece JSON döndür. '
                  'name: renk tonunu ve türü içeren kısa Türkçe ad, ton açık ya da koyuysa belirt '
                  '(örn. "Krem blazer", "Açık mavi blazer", "Koyu yeşil kazak"). '
                  'category: şunlardan biri: ${categories.join(', ')}. '
                  'color: baskın renk tonu, Türkçe (örn. "açık mavi"). '
                  'events: kıyafetin uygun olduğu etkinlikler, şunlardan seç: ${events.join(', ')}.',
            },
            {
              'inline_data': {'mime_type': mimeType, 'data': base64Encode(bytes)},
            },
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.2,
        'responseMimeType': 'application/json',
        'responseSchema': {
          'type': 'OBJECT',
          'properties': {
            'name': {'type': 'STRING'},
            'category': {'type': 'STRING', 'enum': categories},
            'color': {'type': 'STRING'},
            'events': {
              'type': 'ARRAY',
              'items': {'type': 'STRING', 'enum': events},
            },
          },
          'required': ['name', 'category'],
        },
      },
    };
  }

  static String _text(Map<String, dynamic> json) {
    final feedback = json['promptFeedback'];
    if (feedback is Map && feedback['blockReason'] != null) {
      throw AiException(
        AiErrorKind.blocked,
        'Bu fotoğraf yapay zekâ tarafından analiz edilemedi.',
      );
    }
    try {
      final parts = (((json['candidates'] as List).first as Map)['content'] as Map)['parts']
          as List;
      final text = [
        for (final p in parts)
          if ((p as Map)['text'] is String) p['text'] as String,
      ].join();
      if (text.trim().isEmpty) throw const FormatException();
      return text;
    } catch (_) {
      throw AiException(AiErrorKind.parse, 'Yapay zekâ yanıtı boş geldi.');
    }
  }

  /// Google'ın yanıtını uygulamanın anlayacağı bilgiye çevirir.
  static GarmentAnalysis parseAnalysis(
    Map<String, dynamic> response,
    List<String> categories,
  ) {
    final text = _text(response);
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    final Map<String, dynamic> m;
    try {
      m = jsonDecode(text.substring(start, end + 1)) as Map<String, dynamic>;
    } catch (_) {
      throw AiException(AiErrorKind.parse, 'Yapay zekâ yanıtı anlaşılamadı.');
    }
    return analysisFromMap(m, categories);
  }

  /// {name, category, color, events} biçimindeki sözlüğü temizleyip çevirir.
  /// Hem Google'ın içindeki JSON'u hem de kendi sunucumuzun yanıtı için kullanılır.
  static GarmentAnalysis analysisFromMap(
    Map<String, dynamic> m,
    List<String> categories,
  ) {
    final name = (m['name'] as String?)?.trim() ?? '';
    if (name.isEmpty) {
      throw AiException(AiErrorKind.parse, 'Yapay zekâ parçayı adlandıramadı.');
    }
    final rawCategory = (m['category'] as String?)?.trim();
    final category = categories.firstWhere(
      (c) => rawCategory != null && trLower(c) == trLower(rawCategory),
      orElse: () => 'Üst',
    );
    final events = <EventType>{};
    for (final e in (m['events'] as List<dynamic>? ?? const [])) {
      final s = trLower('$e'.trim());
      for (final v in EventType.values) {
        if (trLower(v.label) == s || v.name == s) events.add(v);
      }
    }
    final color = (m['color'] as String?)?.trim();
    return GarmentAnalysis(
      name: name,
      category: category,
      colorName: (color == null || color.isEmpty) ? null : color,
      events: events,
    );
  }
}
