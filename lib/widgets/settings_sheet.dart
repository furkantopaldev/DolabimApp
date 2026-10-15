import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/ai_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import 'common.dart';
import 'weather_widgets.dart';

Future<void> showSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (_) => const _SettingsSheet(),
  );
}

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet();

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  bool _testing = false;
  String? _testMessage;
  bool _testOk = false;

  Future<void> _test() async {
    final app = AppScope.of(context);
    setState(() {
      _testing = true;
      _testMessage = null;
    });
    try {
      await app.testAi();
      if (!mounted) return;
      setState(() {
        _testOk = true;
        _testMessage = 'Bağlantı çalışıyor.';
      });
    } on AiException catch (e) {
      if (!mounted) return;
      setState(() {
        _testOk = false;
        _testMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _testOk = false;
        _testMessage = 'Beklenmeyen bir hata oldu, tekrar dene.';
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Widget _label(String text, AppPalette p) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: p.muted),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final app = AppScope.of(context);
    final media = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.9),
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
                Text('Ayarlar', style: serif(30, weight: FontWeight.w700)),
                const SizedBox(height: 18),
                _label('Görünüm', p),
                Row(
                  children: [
                    Expanded(
                      child: PillChip(
                        label: 'Kadın paleti',
                        selected: app.gender == Gender.female,
                        onTap: () => app.setGender(Gender.female),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: PillChip(
                        label: 'Erkek paleti',
                        selected: app.gender == Gender.male,
                        onTap: () => app.setGender(Gender.male),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _label('Şehir', p),
                PressScale(
                  onTap: () => showCitySheet(context),
                  semanticLabel: 'Şehri değiştir',
                  child: Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: p.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.place_outlined, size: 20, color: p.act),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            app.city.label,
                            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text('Değiştir', style: TextStyle(fontSize: 13, color: p.act)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Yapay zekâ ile tanıma',
                        style: serif(24, weight: FontWeight.w700),
                      ),
                    ),
                    AiBadge(label: app.aiReady ? 'Açık' : 'Kapalı'),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  app.aiReady
                      ? 'Kıyafet fotoğrafı eklerken parçanın adı, türü ve uygun olduğu etkinlikler otomatik doldurulur. Sonucu her zaman değiştirebilirsin.'
                      : 'Bu sürümde yapay zekâ kapalı. Parçaların adını ve türünü kendin girersin, renk yine otomatik bulunur.',
                  style: TextStyle(fontSize: 13, height: 1.5, color: p.body),
                ),
                if (kDebugMode && !app.aiReady) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Geliştirici notu: açmak için uygulamayı AI_SERVER_URL içeren secrets.json ile çalıştır (--dart-define-from-file=secrets.json).',
                    style: TextStyle(fontSize: 12, height: 1.45, color: p.muted),
                  ),
                ],
                if (kDebugMode && app.aiReady) ...[
                  const SizedBox(height: 14),
                  GradientButton(
                    label: _testing ? 'Deneniyor' : 'Bağlantıyı dene',
                    height: 48,
                    onTap: _testing ? () {} : _test,
                  ),
                  if (_testMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _testMessage!,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: _testOk ? p.goldText : const Color(0xFFB3261E),
                      ),
                    ),
                  ],
                ],
                if (app.aiReady) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: p.gold,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      'Gizlilik: Yapay zekâ kullanıldığında fotoğraf, tanıma için bir yapay zekâ servisine gönderilir. İçinde kişilerin göründüğü fotoğrafları gönderme.',
                      style: TextStyle(fontSize: 12, height: 1.5, color: p.goldText),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
