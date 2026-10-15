import 'package:flutter/material.dart';

import '../services/location_service.dart';
import '../services/weather_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import 'common.dart';

IconData weatherIcon(WeatherKind kind) => switch (kind) {
      WeatherKind.clear => Icons.wb_sunny_outlined,
      WeatherKind.partly => Icons.wb_cloudy_outlined,
      WeatherKind.cloudy => Icons.cloud_outlined,
      WeatherKind.fog => Icons.foggy,
      WeatherKind.rain => Icons.grain_rounded,
      WeatherKind.snow => Icons.ac_unit_rounded,
      WeatherKind.storm => Icons.thunderstorm_outlined,
    };

String _deg(double t) => '${t.round()}°';

/// Ana sayfadaki büyük hava durumu kartı. Dokununca şehir seçilir.
class WeatherCard extends StatelessWidget {
  const WeatherCard({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final app = AppScope.of(context);
    final w = app.weather;

    final Widget content;
    if (w != null) {
      content = Row(
        children: [
          Floaty(
            child: Icon(weatherIcon(w.kind), size: 46, color: p.deep2),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_deg(w.temp), style: serif(38, weight: FontWeight.w700, height: 1)),
              Text(w.summary, style: TextStyle(fontSize: 12.5, color: p.deep)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Akşam ${_deg(w.eveningTemp)}. ${_short(w)}',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 12.5, height: 1.4, color: p.deep),
            ),
          ),
        ],
      );
    } else {
      content = Row(
        children: [
          Icon(
            app.weatherFailed ? Icons.cloud_off_rounded : Icons.cloud_sync_outlined,
            size: 40,
            color: p.deep2,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              app.weatherFailed
                  ? 'Hava durumu alınamadı. Dokunup tekrar dene.'
                  : 'Hava durumu getiriliyor',
              style: TextStyle(fontSize: 13.5, height: 1.4, color: p.deep),
            ),
          ),
        ],
      );
    }

    return PressScale(
      scale: 0.98,
      semanticLabel: 'Şehri değiştir',
      onTap: () => showCitySheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [p.w1, p.w2],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            content,
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.place_outlined, size: 14, color: p.deep),
                const SizedBox(width: 4),
                Text(
                  app.city.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: p.deep,
                  ),
                ),
                const Spacer(),
                if (app.weatherLoading)
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: p.deep),
                  )
                else
                  Text('Şehri değiştir', style: TextStyle(fontSize: 12, color: p.deep)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _short(Weather w) {
    final t = w.effectiveTemp;
    if (w.rainy) return 'Şemsiye al.';
    if (t < 8) return 'Kalın giyin.';
    if (t < 15) return 'Bir ceket iyi gider.';
    if (t < 22) return 'İnce bir katman yeter.';
    return 'Hafif giyin.';
  }
}

/// Kombin ekranındaki tek satırlık hava durumu çubuğu.
class WeatherPill extends StatelessWidget {
  const WeatherPill({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final app = AppScope.of(context);
    final w = app.weather;
    final text = w != null
        ? '${_deg(w.temp)} ${w.summary.toLowerCase()}, akşam ${_deg(w.eveningTemp)}'
        : (app.weatherFailed ? 'Hava durumu alınamadı' : 'Hava durumu getiriliyor');
    return PressScale(
      scale: 0.98,
      semanticLabel: 'Şehri değiştir',
      onTap: () => showCitySheet(context),
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(23),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [p.w1, p.w2],
          ),
        ),
        child: Row(
          children: [
            Icon(
              w != null ? weatherIcon(w.kind) : Icons.cloud_outlined,
              size: 22,
              color: p.deep2,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: p.deep,
                ),
              ),
            ),
            Text(app.city.name, style: TextStyle(fontSize: 13, color: p.deep)),
          ],
        ),
      ),
    );
  }
}

Future<void> showCitySheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (_) => const _CitySheet(),
  );
}

class _CitySheet extends StatefulWidget {
  const _CitySheet();

  @override
  State<_CitySheet> createState() => _CitySheetState();
}

class _CitySheetState extends State<_CitySheet> {
  final TextEditingController _query = TextEditingController();
  List<City> _results = const [];
  bool _searching = false;
  String? _error;
  int _token = 0;
  bool _locating = false;
  String? _locMessage;
  bool _needsSettings = false;

  Future<void> _useLocation() async {
    if (_locating) return;
    final state = AppScope.of(context);
    setState(() {
      _locating = true;
      _locMessage = null;
      _needsSettings = false;
    });
    final status = await state.useCurrentLocation();
    if (!mounted) return;
    if (status == LocationStatus.ok) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _locating = false;
      _needsSettings = status == LocationStatus.deniedForever;
      _locMessage = switch (status) {
        LocationStatus.denied =>
          'Konum izni verilmedi. İstersen aşağıdan şehri elle seçebilirsin.',
        LocationStatus.deniedForever =>
          'Konum izni kapalı. Ayarlardan izni açabilir ya da şehri elle seçebilirsin.',
        LocationStatus.serviceDisabled =>
          'Cihazının konum servisi kapalı. Açıp tekrar dene ya da şehri elle seç.',
        _ => 'Konum alınamadı. Tekrar dene ya da şehri elle seç.',
      };
    });
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    final token = ++_token;
    if (q.trim().length < 2) {
      setState(() {
        _results = const [];
        _error = null;
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    try {
      final r = await AppScope.of(context).searchCities(q);
      if (!mounted || token != _token) return;
      setState(() {
        _results = r;
        _error = r.isEmpty ? 'Sonuç bulunamadı.' : null;
        _searching = false;
      });
    } catch (_) {
      if (!mounted || token != _token) return;
      setState(() {
        _results = const [];
        _error = 'Şehir aranamadı, bağlantını kontrol et.';
        _searching = false;
      });
    }
  }

  Future<void> _pick(City c) async {
    final state = AppScope.of(context);
    Navigator.of(context).pop();
    await state.setCity(c);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.8),
        child: Container(
          decoration: BoxDecoration(
            color: p.bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(24, 14, 24, 24 + media.padding.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: p.border,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Şehir seç', style: serif(26, weight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  'Hava durumu ve kombinler bu şehre göre hazırlanır.',
                  style: TextStyle(fontSize: 13, color: p.muted),
                ),
                const SizedBox(height: 16),
                PressScale(
                  onTap: _useLocation,
                  semanticLabel: 'Konumumu kullan',
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: p.accent,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_locating)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        else
                          const Icon(Icons.my_location_rounded, size: 20, color: Colors.white),
                        const SizedBox(width: 10),
                        Text(
                          _locating ? 'Konum alınıyor' : 'Konumumu kullan',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_locMessage != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _locMessage!,
                    style: TextStyle(fontSize: 12.5, height: 1.45, color: p.muted),
                  ),
                  if (_needsSettings)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: AppScope.of(context).openLocationSettings,
                        child: Text(
                          'Ayarları aç',
                          style: TextStyle(color: p.act, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: Divider(color: p.border)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('ya da', style: TextStyle(fontSize: 12, color: p.muted)),
                    ),
                    Expanded(child: Divider(color: p.border)),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: p.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, color: p.muted, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _query,
                          onChanged: _search,
                          style: TextStyle(fontSize: 14.5, color: p.ink),
                          cursorColor: p.act,
                          decoration: InputDecoration(
                            hintText: 'Şehir ara (örn. Ankara)',
                            hintStyle: TextStyle(fontSize: 14.5, color: p.muted),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      if (_searching)
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: p.act),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(_error!, style: TextStyle(fontSize: 13, color: p.muted)),
                  ),
                for (final c in _results)
                  PressScale(
                    onTap: () => _pick(c),
                    semanticLabel: c.label,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.place_outlined, size: 20, color: p.act),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              c.label,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
