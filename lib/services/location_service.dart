import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

enum LocationStatus { ok, denied, deniedForever, serviceDisabled, failed }

class LocationOutcome {
  const LocationOutcome(this.status, {this.lat, this.lon});

  final LocationStatus status;
  final double? lat;
  final double? lon;
}

/// Cihazın yaklaşık konumunu izinle alır. Konum sadece kullanıcı
/// "Konumumu kullan" düğmesine bastığında istenir.
class LocationService {
  const LocationService();

  Future<LocationOutcome> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationOutcome(LocationStatus.serviceDisabled);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationOutcome(LocationStatus.deniedForever);
      }
      if (permission == LocationPermission.denied) {
        return const LocationOutcome(LocationStatus.denied);
      }
      // Önce standart yöntem (Android'de Google Play hizmetleri, ağ ve GPS'i
      // birlikte kullanır). Olmazsa cihazın kendi konum yöneticisi, o da
      // olmazsa son bilinen konum denenir.
      var pos = await _attempt(
        () => Geolocator.getCurrentPosition(locationSettings: _settings(false)),
      );
      if (pos == null && defaultTargetPlatform == TargetPlatform.android) {
        pos = await _attempt(
          () => Geolocator.getCurrentPosition(locationSettings: _settings(true)),
        );
      }
      pos ??= await _attempt(Geolocator.getLastKnownPosition);
      if (pos == null) return const LocationOutcome(LocationStatus.failed);
      return LocationOutcome(
        LocationStatus.ok,
        lat: pos.latitude,
        lon: pos.longitude,
      );
    } catch (_) {
      return const LocationOutcome(LocationStatus.failed);
    }
  }

  static Future<Position?> _attempt(Future<Position?> Function() get) async {
    try {
      return await get();
    } catch (_) {
      return null;
    }
  }

  /// Şehir bulmak için yaklaşık konum yeter, bu yüzden hassasiyet düşük tutulur.
  static LocationSettings _settings(bool forceLocationManager) {
    const limit = Duration(seconds: 8);
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: limit,
        forceLocationManager: forceLocationManager,
      );
    }
    return const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: limit);
  }

  /// Uygulamanın izin ayarlarını açar (izin kalıcı reddedildiyse).
  Future<void> openSettings() async {
    await Geolocator.openAppSettings();
  }
}
