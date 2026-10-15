import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dolabim/config/ai_config.dart';
import 'package:dolabim/data/models.dart';
import 'package:dolabim/services/ai_service.dart';
import 'package:dolabim/services/location_service.dart';
import 'package:dolabim/services/weather_service.dart';
import 'package:dolabim/state/app_state.dart';

const categories = ['Üst', 'Alt', 'Elbise', 'Dış giyim', 'Ayakkabı', 'Çanta'];
const fakeKey = 'TEST-KEY-NOT-REAL';
const direct = AiConfig(apiKey: fakeKey);
const server = AiConfig(serverUrl: 'https://ai.example.com/');

Map<String, dynamic> reply(String text) => {
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': text},
            ],
          },
        },
      ],
    };

http.Response json(Object body, [int code = 200]) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      code,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Yanıt çözümü (doğrudan mod)', () {
    test('normal yanıt', () {
      final a = AiService.parseAnalysis(
        reply('{"name":"Krem blazer","category":"Dış giyim","color":"Krem","events":["İş","Davet"]}'),
        categories,
      );
      expect(a.name, 'Krem blazer');
      expect(a.category, 'Dış giyim');
      expect(a.colorName, 'Krem');
      expect(a.events, {EventType.work, EventType.party});
    });

    test('kod bloğu içine sarılmış JSON da okunur', () {
      final a = AiService.parseAnalysis(
        reply('```json\n{"name":"Beyaz gömlek","category":"üst"}\n```'),
        categories,
      );
      expect(a.name, 'Beyaz gömlek');
      expect(a.category, 'Üst');
      expect(a.events, isEmpty);
    });

    test('bilinmeyen tür Üst olur, bilinmeyen etkinlik atlanır', () {
      final a = AiService.parseAnalysis(
        reply('{"name":"Atkı","category":"Aksesuar","events":["Düğün","Spor"]}'),
        categories,
      );
      expect(a.category, 'Üst');
      expect(a.events, {EventType.sport});
    });

    test('büyük harfli Türkçe karakterler doğru eşleşir', () {
      expect(trLower('DIŞ GİYİM'), 'dış giyim');
      final a = AiService.parseAnalysis(
        reply('{"name":"Ceket","category":"DIŞ GİYİM","events":["İŞ","BULUŞMA"]}'),
        categories,
      );
      expect(a.category, 'Dış giyim');
      expect(a.events, {EventType.work, EventType.date});
    });

    test('boş ad, bozuk metin, boş aday ve engellenen içerik hata verir', () {
      AiErrorKind kind(Map<String, dynamic> r) {
        try {
          AiService.parseAnalysis(r, categories);
        } on AiException catch (e) {
          return e.kind;
        }
        fail('hata bekleniyordu');
      }

      expect(kind(reply('{"name":"  ","category":"Üst"}')), AiErrorKind.parse);
      expect(kind(reply('JSON değil')), AiErrorKind.parse);
      expect(kind({'candidates': []}), AiErrorKind.parse);
      expect(kind({'promptFeedback': {'blockReason': 'SAFETY'}}), AiErrorKind.blocked);
    });
  });

  group('Doğrudan mod (sadece geliştirme)', () {
    test('istek gövdesi fotoğrafı, türleri ve etkinlikleri içerir, anahtarı içermez', () {
      final req = AiService.buildRequest(
        bytes: Uint8List.fromList([1, 2, 3]),
        categories: categories,
      );
      final text = jsonEncode(req);
      expect(text, contains('inline_data'));
      expect(text, contains(base64Encode([1, 2, 3])));
      expect(text, contains('Dış giyim'));
      expect(text, contains('Buluşma'));
      expect(text, isNot(contains(fakeKey)));
      final cfg = req['generationConfig'] as Map<String, dynamic>;
      expect(cfg['responseMimeType'], 'application/json');
    });

    test('anahtar başlıkta gider, model adı adreste olur, adrese yazılmaz', () async {
      late http.Request seen;
      final service = AiService(
        config: direct,
        model: 'test-model',
        client: MockClient((r) async {
          seen = r;
          return json(reply('{"name":"Bej chino","category":"Alt"}'));
        }),
      );
      final a = await service.analyzeGarment(
        bytes: Uint8List.fromList([9]),
        categories: categories,
      );
      expect(a.category, 'Alt');
      expect(seen.url.host, 'generativelanguage.googleapis.com');
      expect(seen.headers['x-goog-api-key'], fakeKey);
      expect(seen.url.path, '/v1beta/models/test-model:generateContent');
      expect(seen.url.toString(), isNot(contains(fakeKey)));
    });

    test('HTTP hataları anlaşılır türlere çevrilir', () async {
      Future<AiErrorKind> kindFor(http.Response r) async {
        final service = AiService(config: direct, client: MockClient((_) async => r));
        try {
          await service.ping();
        } on AiException catch (e) {
          return e.kind;
        }
        fail('hata bekleniyordu');
      }

      expect(
        await kindFor(json({'error': {'message': 'API key not valid.'}}, 400)),
        AiErrorKind.auth,
      );
      expect(await kindFor(json({'error': {'message': 'x'}}, 403)), AiErrorKind.auth);
      expect(await kindFor(json({'error': {'message': 'x'}}, 404)), AiErrorKind.model);
      expect(await kindFor(json({'error': {'message': 'x'}}, 429)), AiErrorKind.quota);
      expect(await kindFor(json({'error': {'message': 'x'}}, 503)), AiErrorKind.network);
    });

    test('bağlantı hatası ağ hatası olur, ping başarılı yanıtta hata vermez', () async {
      final down = AiService(
        config: direct,
        client: MockClient((_) async => throw Exception('çevrimdışı')),
      );
      expect(
        () => down.ping(),
        throwsA(isA<AiException>().having((e) => e.kind, 'kind', AiErrorKind.network)),
      );
      final up = AiService(config: direct, client: MockClient((_) async => json(reply('tamam'))));
      await up.ping();
    });
  });

  group('Sunucu modu (yayın sürümü)', () {
    test('fotoğraf sunucuya gider, anahtar ve Google adresi kullanılmaz', () async {
      late http.Request seen;
      final service = AiService(
        config: const AiConfig(serverUrl: 'https://ai.example.com/', appToken: 'jeton', apiKey: fakeKey),
        client: MockClient((r) async {
          seen = r;
          return json({
            'name': 'Açık mavi blazer',
            'category': 'Dış giyim',
            'color': 'açık mavi',
            'events': ['İş', 'Davet'],
          });
        }),
      );
      final a = await service.analyzeGarment(
        bytes: Uint8List.fromList([7, 8]),
        categories: categories,
        mimeType: 'image/png',
      );
      expect(a.name, 'Açık mavi blazer');
      expect(a.category, 'Dış giyim');
      expect(a.colorName, 'açık mavi');
      expect(a.events, {EventType.work, EventType.party});

      expect(seen.method, 'POST');
      expect(seen.url.toString(), 'https://ai.example.com/analyze');
      expect(seen.headers['x-app-token'], 'jeton');
      expect(seen.headers.containsKey('x-goog-api-key'), isFalse);
      final body = jsonDecode(seen.body) as Map<String, dynamic>;
      expect(body['image'], base64Encode([7, 8]));
      expect(body['mimeType'], 'image/png');
      expect(body['categories'], categories);
      // Yönerge ve şema sunucudadır, istemci göndermez.
      expect(body.keys.toSet(), {'image', 'mimeType', 'categories'});
      expect(seen.body, isNot(contains(fakeKey)));
    });

    test('jeton verilmemişse başlık gönderilmez, ping sağlık ucuna gider', () async {
      late http.Request seen;
      final service = AiService(
        config: server,
        client: MockClient((r) async {
          seen = r;
          return json({'ok': true});
        }),
      );
      await service.ping();
      expect(seen.method, 'GET');
      expect(seen.url.toString(), 'https://ai.example.com/health');
      expect(seen.headers.containsKey('x-app-token'), isFalse);
    });

    test('sunucu hataları kullanıcıya uygun hatalara çevrilir', () async {
      Future<AiException> errorFor(int code, [Map<String, dynamic>? body]) async {
        final service = AiService(
          config: server,
          client: MockClient((_) async => json(body ?? {'error': 'x', 'message': 'm'}, code)),
        );
        try {
          await service.analyzeGarment(bytes: Uint8List(1), categories: categories);
        } on AiException catch (e) {
          return e;
        }
        fail('hata bekleniyordu');
      }

      expect((await errorFor(401)).kind, AiErrorKind.auth);
      expect((await errorFor(403)).kind, AiErrorKind.auth);
      expect((await errorFor(422)).kind, AiErrorKind.blocked);
      expect((await errorFor(413)).kind, AiErrorKind.parse);
      expect((await errorFor(502)).kind, AiErrorKind.network);
      final limited = await errorFor(
        429,
        {'error': 'rate_limited', 'message': 'Çok fazla istek. Biraz bekleyip tekrar dene.'},
      );
      expect(limited.kind, AiErrorKind.quota);
      expect(limited.message, 'Çok fazla istek. Biraz bekleyip tekrar dene.');
    });

    test('sunucu yanıtında eksik ad hata verir, bilinmeyen tür Üst olur', () async {
      AiService svc(Map<String, dynamic> body) =>
          AiService(config: server, client: MockClient((_) async => json(body)));
      expect(
        () => svc({'category': 'Üst'}).analyzeGarment(bytes: Uint8List(1), categories: categories),
        throwsA(isA<AiException>()),
      );
      final a = await svc({'name': 'Atkı', 'category': 'Aksesuar', 'events': <String>[]})
          .analyzeGarment(bytes: Uint8List(1), categories: categories);
      expect(a.category, 'Üst');
    });
  });

  group('Yapay zekâ yapılandırması', () {
    test('sunucu adresi ya da (geliştirmede) anahtar yoksa kullanılamaz', () {
      expect(const AiConfig().usable, isFalse);
      expect(const AiConfig(apiKey: '   ').usable, isFalse);
      expect(const AiConfig(serverUrl: '  ').usable, isFalse);
      expect(direct.usable, isTrue);
      expect(server.usable, isTrue);
      expect(server.usesServer, isTrue);
      expect(direct.usesServer, isFalse);
    });

    test('yapılandırma verilmeyen derlemede yapay zekâ kapalıdır', () {
      // Testler --dart-define olmadan çalışır.
      expect(AiConfig.fromBuild.usable, isFalse);
      expect(AppState().aiReady, isFalse);
    });

    test('kapalıyken analiz ve test anlaşılır hata verir', () {
      final app = AppState();
      expect(() => app.analyzeGarment(Uint8List(1), categories), throwsA(isA<AiException>()));
      expect(() => app.testAi(), throwsA(isA<AiException>()));
    });

    test('açıkken analiz sunucu üzerinden yapılır', () async {
      late http.Request seen;
      final app = AppState(
        ai: AiService(
          config: server,
          client: MockClient((r) async {
            seen = r;
            return json({'name': 'Kot', 'category': 'Alt'});
          }),
        ),
      );
      expect(app.aiReady, isTrue);
      final a = await app.analyzeGarment(Uint8List.fromList([5]), categories);
      expect(a.name, 'Kot');
      expect(seen.url.path, '/analyze');
    });
  });

  group('Konum', () {
    test('koordinattan şehir adı çözülür', () {
      final c = WeatherService.parseReverse(
        {'city': 'Çankaya', 'principalSubdivision': 'Ankara'},
        39.9,
        32.8,
      );
      expect(c.label, 'Çankaya, Ankara');
      expect(c.lat, 39.9);
    });

    test('ad yoksa Konumum olur', () {
      expect(WeatherService.parseReverse({'city': ''}, 1, 2).name, 'Konumum');
    });

    test('ters arama başarısız olursa Konumum adıyla koordinat korunur', () async {
      final service = WeatherService(client: MockClient((_) async => json({}, 500)));
      final c = await service.reverseCity(39.93, 32.86);
      expect(c.name, 'Konumum');
      expect(c.lat, 39.93);
    });

    test('ters aramaya yuvarlanmış koordinat gider', () async {
      late Uri seen;
      final service = WeatherService(
        client: MockClient((r) async {
          seen = r.url;
          return json({'city': 'Bursa', 'principalSubdivision': 'Bursa'});
        }),
      );
      final c = await service.reverseCity(40.18276, 29.06612);
      expect(c.name, 'Bursa');
      expect(seen.queryParameters['latitude'], '40.18');
      expect(seen.queryParameters['longitude'], '29.07');
    });

    test('izin verilirse şehir konuma göre değişir ve hava durumu yenilenir', () async {
      final app = AppState(
        locationService: _FakeLocation(const LocationOutcome(LocationStatus.ok, lat: 39.93, lon: 32.86)),
        weatherService: WeatherService(
          client: MockClient((r) async {
            if (r.url.host == 'api.bigdatacloud.net') {
              return json({'city': 'Ankara', 'principalSubdivision': 'Ankara'});
            }
            return json(_forecast());
          }),
        ),
      );
      final status = await app.useCurrentLocation();
      expect(status, LocationStatus.ok);
      expect(app.city.name, 'Ankara');
      expect(app.weather, isNotNull);
      expect(app.weather!.temp, 12.0);
    });

    test('izin verilmezse şehir değişmez ve neden döner', () async {
      for (final s in [
        LocationStatus.denied,
        LocationStatus.deniedForever,
        LocationStatus.serviceDisabled,
        LocationStatus.failed,
      ]) {
        final app = AppState(locationService: _FakeLocation(LocationOutcome(s)));
        expect(await app.useCurrentLocation(), s);
        expect(app.city.name, 'İstanbul');
      }
    });
  });
}

class _FakeLocation implements LocationService {
  _FakeLocation(this.outcome);

  final LocationOutcome outcome;

  @override
  Future<LocationOutcome> current() async => outcome;

  @override
  Future<void> openSettings() async {}
}

Map<String, dynamic> _forecast() => {
      'current': {'temperature_2m': 12.0, 'weather_code': 3},
      'hourly': {
        'time': ['2026-10-15T20:00'],
        'temperature_2m': [9.0],
      },
      'daily': {
        'temperature_2m_max': [14.0],
        'temperature_2m_min': [7.0],
        'precipitation_probability_max': [10],
      },
    };
