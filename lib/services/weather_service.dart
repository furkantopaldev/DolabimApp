import 'dart:convert';

import 'package:http/http.dart' as http;

/// Hava durumunun genel türü. Simge ve metin bu türe göre seçilir.
enum WeatherKind { clear, partly, cloudy, fog, rain, snow, storm }

class City {
  const City({
    required this.name,
    required this.lat,
    required this.lon,
    this.region,
  });

  factory City.fromJson(Map<String, dynamic> j) => City(
        name: j['name'] as String,
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
        region: j['region'] as String?,
      );

  static const istanbul = City(name: 'İstanbul', lat: 41.0082, lon: 28.9784);

  final String name;
  final double lat;
  final double lon;
  final String? region;

  /// Listede gösterilen ad: "Kadıköy, İstanbul" gibi.
  String get label =>
      (region == null || region == name || region!.isEmpty) ? name : '$name, $region';

  Map<String, dynamic> toJson() =>
      {'name': name, 'lat': lat, 'lon': lon, 'region': region};
}

class Weather {
  const Weather({
    required this.temp,
    required this.eveningTemp,
    required this.min,
    required this.max,
    required this.rainChance,
    required this.code,
  });

  /// Şu anki sıcaklık (°C).
  final double temp;

  /// Akşam saat 20:00 tahmini (°C).
  final double eveningTemp;
  final double min;
  final double max;

  /// Bugünkü en yüksek yağış ihtimali (yüzde).
  final int rainChance;

  /// WMO hava durumu kodu.
  final int code;

  WeatherKind get kind {
    if (code == 0) return WeatherKind.clear;
    if (code <= 2) return WeatherKind.partly;
    if (code == 3) return WeatherKind.cloudy;
    if (code == 45 || code == 48) return WeatherKind.fog;
    if (code >= 95) return WeatherKind.storm;
    if ((code >= 71 && code <= 77) || code == 85 || code == 86) {
      return WeatherKind.snow;
    }
    if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) {
      return WeatherKind.rain;
    }
    return WeatherKind.cloudy;
  }

  String get summary => switch (code) {
        0 => 'Açık',
        1 => 'Az bulutlu',
        2 => 'Parçalı bulutlu',
        3 => 'Kapalı',
        45 || 48 => 'Sisli',
        >= 51 && <= 57 => 'Çiseleme',
        >= 61 && <= 67 => 'Yağmurlu',
        >= 71 && <= 77 => 'Karlı',
        >= 80 && <= 82 => 'Sağanak yağışlı',
        85 || 86 => 'Kar yağışlı',
        >= 95 => 'Fırtınalı',
        _ => 'Bulutlu',
      };

  bool get rainy =>
      rainChance >= 50 || kind == WeatherKind.rain || kind == WeatherKind.storm;

  /// Bugünkü kombin için belirleyici sıcaklık: gün içinde ve akşam en düşük olan.
  double get effectiveTemp => temp < eveningTemp ? temp : eveningTemp;

  /// Kombin notunda kullanılan, sıcaklığa göre kısa öneri cümlesi.
  String get advice {
    final t = effectiveTemp;
    final base = t < 8
        ? 'Hava soğuk, katmanlı ve kalın giyinmekte fayda var.'
        : t < 15
            ? 'Hava serin, bir dış parça iyi gider.'
            : t < 22
                ? 'Hava ılıman, ince bir katman yeterli.'
                : t < 28
                    ? 'Hava sıcak, hafif parçalar rahat ettirir.'
                    : 'Hava çok sıcak, en hafif parçaları seç.';
    return rainy ? '$base Yağış ihtimali var, kapalı ayakkabı ve koyu tonlar iyi olur.' : base;
  }
}

class WeatherException implements Exception {
  WeatherException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Open-Meteo üzerinden hava durumu ve şehir arama. Anahtar gerektirmez.
class WeatherService {
  WeatherService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<Weather> fetch(City city) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': '${city.lat}',
      'longitude': '${city.lon}',
      'current': 'temperature_2m,weather_code',
      'hourly': 'temperature_2m',
      'daily': 'temperature_2m_max,temperature_2m_min,precipitation_probability_max',
      'timezone': 'auto',
      'forecast_days': '1',
    });
    final res = await _client.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw WeatherException('Hava durumu alınamadı (${res.statusCode}).');
    }
    return parse(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static Weather parse(Map<String, dynamic> json) {
    try {
      final current = json['current'] as Map<String, dynamic>;
      final daily = json['daily'] as Map<String, dynamic>;
      final hourly = json['hourly'] as Map<String, dynamic>;
      final times = (hourly['time'] as List<dynamic>).cast<String>();
      final temps = (hourly['temperature_2m'] as List<dynamic>);
      var evening = times.indexWhere((t) => t.endsWith('T20:00'));
      if (evening < 0) evening = temps.length - 1;
      final temp = (current['temperature_2m'] as num).toDouble();
      return Weather(
        temp: temp,
        eveningTemp: (temps[evening] as num?)?.toDouble() ?? temp,
        min: ((daily['temperature_2m_min'] as List<dynamic>).first as num).toDouble(),
        max: ((daily['temperature_2m_max'] as List<dynamic>).first as num).toDouble(),
        rainChance:
            (((daily['precipitation_probability_max'] as List<dynamic>?)?.first) as num?)
                    ?.round() ??
                0,
        code: (current['weather_code'] as num).toInt(),
      );
    } catch (_) {
      throw WeatherException('Hava durumu yanıtı okunamadı.');
    }
  }

  /// Koordinattan şehir adı bulur (BigDataCloud, anahtar gerektirmez).
  /// Gizlilik için koordinatlar yaklaşık 1 km'ye yuvarlanıp gönderilir.
  /// Ad bulunamazsa "Konumum" adıyla aynı koordinatlar döner.
  Future<City> reverseCity(double lat, double lon) async {
    final rLat = double.parse(lat.toStringAsFixed(2));
    final rLon = double.parse(lon.toStringAsFixed(2));
    try {
      final uri = Uri.https('api.bigdatacloud.net', '/data/reverse-geocode-client', {
        'latitude': '$rLat',
        'longitude': '$rLon',
        'localityLanguage': 'tr',
      });
      final res = await _client.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        return parseReverse(jsonDecode(res.body) as Map<String, dynamic>, lat, lon);
      }
    } catch (_) {
      // Ad bulunamazsa koordinatla devam edilir.
    }
    return City(name: 'Konumum', lat: lat, lon: lon);
  }

  static City parseReverse(Map<String, dynamic> j, double lat, double lon) {
    String? pick(String key) {
      final v = j[key];
      return (v is String && v.trim().isNotEmpty) ? v.trim() : null;
    }

    final name = pick('city') ?? pick('locality') ?? pick('principalSubdivision');
    if (name == null) return City(name: 'Konumum', lat: lat, lon: lon);
    return City(
      name: name,
      lat: lat,
      lon: lon,
      region: pick('principalSubdivision'),
    );
  }

  Future<List<City>> searchCities(String query) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    final uri = Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
      'name': q,
      'count': '6',
      'language': 'tr',
    });
    final res = await _client.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw WeatherException('Şehir aranamadı (${res.statusCode}).');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final results = (body['results'] as List<dynamic>?) ?? const [];
    return [
      for (final r in results)
        City(
          name: (r as Map<String, dynamic>)['name'] as String,
          lat: (r['latitude'] as num).toDouble(),
          lon: (r['longitude'] as num).toDouble(),
          region: r['admin1'] as String?,
        ),
    ];
  }
}
