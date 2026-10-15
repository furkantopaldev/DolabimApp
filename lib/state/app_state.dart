import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models.dart';
import '../data/sample_data.dart';
import '../services/ai_service.dart';
import '../services/location_service.dart';
import '../services/weather_service.dart';
import '../stylist/stylist.dart';
import '../theme/palette.dart';

enum Gender { female, male }

/// Kullanıcının cinsiyet seçimi, ilk açılış durumu, kendi eklediği
/// kıyafetler, şehri ve hava durumu. Seçimler cihazda saklanır.
class AppState extends ChangeNotifier {
  AppState({
    this.gender = Gender.female,
    this.onboarded = false,
    List<Garment>? wardrobe,
    this.city = City.istanbul,
    WeatherService? weatherService,
    LocationService locationService = const LocationService(),
    AiService? ai,
  })  : wardrobe = wardrobe ?? [],
        _weatherService = weatherService ?? WeatherService(),
        _location = locationService,
        _ai = ai ?? AiService();

  Gender gender;
  bool onboarded;

  /// Kullanıcının fotoğrafla eklediği parçalar, en yenisi başta.
  final List<Garment> wardrobe;

  City city;
  Weather? weather;
  bool weatherLoading = false;
  bool weatherFailed = false;
  final WeatherService _weatherService;
  final LocationService _location;
  final AiService _ai;

  /// Yapay zekâ ile tanıma kullanılabilir mi? Sunucu adresi (ya da geliştirmede
  /// anahtar) derleme sırasında verilmediyse özellik kapalıdır.
  bool get aiReady => _ai.config.usable;

  AppPalette get palette =>
      gender == Gender.male ? AppPalette.male : AppPalette.female;

  /// Kombinlerin hazırlandığı dolap. Kullanıcının parçaları kombin kurmaya
  /// yetiyorsa sadece onlar, yetmiyorsa örnek parçalar kullanılır.
  List<Garment> get stylistWardrobe =>
      Stylist.canForm(wardrobe) ? wardrobe : SampleData.wardrobe(gender);

  /// Kombinler örnek parçalarla mı hazırlanıyor?
  bool get usingSamples => !Stylist.canForm(wardrobe);

  static Future<AppState> load() async {
    final prefs = await SharedPreferences.getInstance();
    final items = <Garment>[];
    // Web'de fotoğraf yolları geçici olduğu için kalıcı saklanmaz.
    if (!kIsWeb) {
      final raw = prefs.getString('wardrobe');
      if (raw != null) {
        try {
          for (final j in jsonDecode(raw) as List<dynamic>) {
            final g = Garment.fromJson(j as Map<String, dynamic>);
            if (File(g.photoPath!).existsSync()) items.add(g);
          }
        } catch (_) {
          // Bozuk kayıt varsa boş dolapla devam et.
        }
      }
    }
    var city = City.istanbul;
    final rawCity = prefs.getString('city');
    if (rawCity != null) {
      try {
        city = City.fromJson(jsonDecode(rawCity) as Map<String, dynamic>);
      } catch (_) {
        // Bozuk kayıt varsa varsayılan şehir.
      }
    }
    return AppState(
      gender: prefs.getString('gender') == 'male' ? Gender.male : Gender.female,
      onboarded: prefs.getBool('onboarded') ?? false,
      wardrobe: items,
      city: city,
    );
  }

  /// Fotoğraftaki parçayı yapay zekâ ile tanır. Yapay zekâ kapalıysa hata fırlatır.
  Future<GarmentAnalysis> analyzeGarment(
    Uint8List bytes,
    List<String> categories,
  ) {
    if (!aiReady) throw _aiOff();
    return _ai.analyzeGarment(bytes: bytes, categories: categories);
  }

  /// Yapay zekâ bağlantısını küçük bir istekle dener.
  Future<void> testAi() {
    if (!aiReady) throw _aiOff();
    return _ai.ping();
  }

  static AiException _aiOff() => AiException(
        AiErrorKind.auth,
        'Yapay zekâ bu sürümde kapalı.',
      );

  Future<void> setGender(Gender g) async {
    if (g == gender) return;
    gender = g;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gender', g.name);
  }

  Future<void> finishOnboarding() async {
    onboarded = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarded', true);
  }

  /// Seçili şehrin hava durumunu getirir. Başarısız olursa eski veri kalır.
  Future<void> refreshWeather() async {
    weatherLoading = true;
    weatherFailed = false;
    notifyListeners();
    try {
      weather = await _weatherService.fetch(city);
    } catch (_) {
      weatherFailed = true;
    }
    weatherLoading = false;
    notifyListeners();
  }

  Future<List<City>> searchCities(String query) =>
      _weatherService.searchCities(query);

  Future<void> setCity(City c) async {
    city = c;
    weather = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('city', jsonEncode(c.toJson()));
    await refreshWeather();
  }

  /// Cihazın yaklaşık konumunu (izinle) alıp şehri ona göre ayarlar.
  /// Başarısız olursa nedenini döndürür, şehir değişmez.
  Future<LocationStatus> useCurrentLocation() async {
    final out = await _location.current();
    if (out.status != LocationStatus.ok) return out.status;
    final c = await _weatherService.reverseCity(out.lat!, out.lon!);
    await setCity(c);
    return LocationStatus.ok;
  }

  Future<void> openLocationSettings() => _location.openSettings();

  /// Seçilen fotoğrafı uygulamanın kendi klasörüne kopyalayıp dolaba ekler.
  Future<void> addGarment({
    required String name,
    required String category,
    required String sourcePath,
    Color? color,
    Set<EventType> events = const {},
  }) async {
    final id = 'u${DateTime.now().millisecondsSinceEpoch}';
    var path = sourcePath;
    if (!kIsWeb) {
      final dir = await getApplicationDocumentsDirectory();
      final folder = Directory('${dir.path}/garments');
      await folder.create(recursive: true);
      path = '${folder.path}/$id.jpg';
      await File(sourcePath).copy(path);
    }
    wardrobe.insert(
      0,
      Garment.user(
        id: id,
        name: name,
        category: category,
        photoPath: path,
        color: color,
        events: events,
      ),
    );
    notifyListeners();
    await _saveWardrobe();
  }

  /// Kullanıcının kendi parçasının adını, türünü ve etkinliklerini günceller.
  Future<void> updateGarment(
    String id, {
    required String name,
    required String category,
    Set<EventType> events = const {},
  }) async {
    final i = wardrobe.indexWhere((g) => g.id == id);
    if (i < 0) return;
    wardrobe[i] = wardrobe[i].edited(
      name: name,
      category: category,
      events: events,
    );
    notifyListeners();
    await _saveWardrobe();
  }

  /// Parçayı dolaptan ve cihazdan (fotoğraf dosyası dahil) siler.
  Future<void> removeGarment(String id) async {
    final i = wardrobe.indexWhere((g) => g.id == id);
    if (i < 0) return;
    final removed = wardrobe.removeAt(i);
    notifyListeners();
    await _saveWardrobe();
    if (!kIsWeb) {
      try {
        await File(removed.photoPath!).delete();
      } catch (_) {
        // Dosya zaten yoksa sorun değil.
      }
    }
  }

  Future<void> _saveWardrobe() async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'wardrobe',
      jsonEncode([for (final g in wardrobe) g.toJson()]),
    );
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
