import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/models.dart';
import '../data/sample_data.dart';
import '../services/color_analysis.dart';
import '../services/ai_service.dart';
import '../state/app_state.dart';
import '../widgets/ai_status.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import '../widgets/color_badge.dart';
import '../widgets/common.dart';
import '../widgets/garment_tile.dart';

void openAdd(BuildContext context) =>
    Navigator.of(context).push(slideUpRoute(const AddScreen()));

/// Kıyafet ekleme: kamerayla çek ya da galeriden seç, adını ve türünü
/// belirle, dolaba kaydet. Otomatik tanıma (yapay zeka) sonraki adımda gelecek.
class AddScreen extends StatefulWidget {
  const AddScreen({super.key});

  @override
  State<AddScreen> createState() => _AddScreenState();
}

class _AddScreenState extends State<AddScreen>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _name = TextEditingController();
  late final AnimationController _scan = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat(reverse: true);

  XFile? _photo;
  Uint8List? _bytes;
  AiStatus _ai = AiStatus.off;
  String? _aiMessage;
  Color? _color;
  final Set<EventType> _events = {};
  String _category = 'Üst';
  bool _front = false;
  bool _picking = false;
  bool _saving = false;

  @override
  void dispose() {
    _scan.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1400,
        imageQuality: 85,
        preferredCameraDevice: _front ? CameraDevice.front : CameraDevice.rear,
      );
      if (!mounted) return;
      if (file != null) {
        setState(() {
          _photo = file;
          _color = null;
          _events.clear();
          _name.clear();
          _category = 'Üst';
        });
        // Baskın rengi cihazda çıkar, panel açılırken arka planda hesaplanır.
        final bytes = await file.readAsBytes();
        if (!mounted || _photo != file) return;
        _bytes = bytes;
        final color = await ColorAnalysis.dominantColor(bytes);
        if (mounted && _photo == file) setState(() => _color = color);
        // Anahtar girilmişse parça yapay zekâ ile de tanınır.
        if (mounted && _photo == file && AppScope.of(context).aiReady) {
          await _analyze();
        }
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fotoğrafa erişilemedi. Kamera ve galeri iznini kontrol et.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  /// Fotoğrafı yapay zekâya gönderip ad, tür ve etkinlikleri doldurur.
  /// Kullanıcı sonucu her zaman düzenleyebilir.
  Future<void> _analyze() async {
    final bytes = _bytes;
    final photo = _photo;
    if (bytes == null || photo == null) return;
    final app = AppScope.of(context);
    final categories = SampleData.categories(app.gender).skip(1).toList();
    setState(() {
      _ai = AiStatus.loading;
      _aiMessage = null;
    });
    try {
      final a = await app.analyzeGarment(bytes, categories);
      if (!mounted || _photo != photo) return;
      setState(() {
        _name.text = a.name;
        _category = a.category;
        _events
          ..clear()
          ..addAll(a.events);
        _ai = AiStatus.done;
      });
    } on AiException catch (e) {
      if (!mounted || _photo != photo) return;
      setState(() {
        _ai = AiStatus.error;
        _aiMessage = e.message;
      });
    } catch (_) {
      if (!mounted || _photo != photo) return;
      setState(() {
        _ai = AiStatus.error;
        _aiMessage = 'Yapay zekâ ile tanıma başarısız oldu.';
      });
    }
  }

  Future<void> _save() async {
    final photo = _photo;
    if (photo == null || _saving) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final state = AppScope.of(context);
    final name = _name.text.trim().isEmpty ? _category : _name.text.trim();
    try {
      await state.addGarment(
        name: name,
        category: _category,
        sourcePath: photo.path,
        color: _color,
        events: {..._events},
      );
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Dolabına eklendi.')));
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Kaydedilemedi, tekrar dene.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final gender = AppScope.of(context).gender;
    final categories = SampleData.categories(gender).skip(1).toList();
    final media = MediaQuery.of(context);
    final hasPhoto = _photo != null;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [p.ink, p.deep],
          ),
        ),
        child: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        CircleIconButton(
                          icon: Icons.close_rounded,
                          semanticLabel: 'Kapat',
                          dark: true,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                        Text('Yeni parça', style: serif(24, color: Colors.white)),
                        const SizedBox(width: 46),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: _Viewfinder(scan: _scan, photo: _photo),
                    ),
                  ),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 400),
                    opacity: hasPhoto ? 0 : 1,
                    child: IgnorePointer(
                      ignoring: hasPhoto,
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          Text(
                            'Kıyafeti düz bir yüzeye serip çerçeveye sığdır.',
                            style: TextStyle(
                              fontSize: 13.5,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(height: 22),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _SquareButton(
                                icon: Icons.photo_library_outlined,
                                label: 'Galeriden seç',
                                onTap: () => _pick(ImageSource.gallery),
                              ),
                              const SizedBox(width: 44),
                              PressScale(
                                semanticLabel: 'Fotoğraf çek',
                                onTap: () => _pick(ImageSource.camera),
                                child: Container(
                                  width: 84,
                                  height: 84,
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 4,
                                    ),
                                  ),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: p.accent,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 44),
                              _SquareButton(
                                icon: Icons.cameraswitch_outlined,
                                label: _front
                                    ? 'Arka kameraya geç'
                                    : 'Ön kameraya geç',
                                onTap: () => setState(() => _front = !_front),
                              ),
                            ],
                          ),
                          SizedBox(height: 28 + media.padding.bottom),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: media.viewInsets.bottom,
              child: IgnorePointer(
                ignoring: !hasPhoto,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  offset: hasPhoto ? Offset.zero : const Offset(0, 1.1),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: media.size.height -
                          media.viewInsets.bottom -
                          media.padding.top -
                          90,
                    ),
                    child: _DetailsSheet(
                      nameController: _name,
                      categories: categories,
                      category: _category,
                      ai: AppScope.of(context).aiReady ? _ai : AiStatus.off,
                      aiMessage: _aiMessage,
                      onRetryAi: _analyze,
                      color: _color,
                      events: _events,
                      onEvent: (e) => setState(() {
                        if (!_events.add(e)) _events.remove(e);
                      }),
                      bottomPadding: media.viewInsets.bottom > 0
                          ? 16
                          : media.padding.bottom,
                      saving: _saving,
                      onCategory: (c) => setState(() => _category = c),
                      onRetake: () => setState(() {
                        _photo = null;
                        _bytes = null;
                        _ai = AiStatus.off;
                        _aiMessage = null;
                      }),
                      onSave: _save,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SquareButton extends StatelessWidget {
  const _SquareButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      semanticLabel: label,
      onTap: onTap,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.white.withValues(alpha: 0.12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}

class _Viewfinder extends StatelessWidget {
  const _Viewfinder({required this.scan, required this.photo});

  final Animation<double> scan;
  final XFile? photo;

  Widget _corner(Alignment a) {
    const side = BorderSide(color: Colors.white, width: 3);
    final top = a.y < 0;
    final left = a.x < 0;
    return Positioned(
      top: top ? 18 : null,
      bottom: top ? null : 18,
      left: left ? 18 : null,
      right: left ? null : 18,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          border: Border(
            top: top ? side : BorderSide.none,
            bottom: top ? BorderSide.none : side,
            left: left ? side : BorderSide.none,
            right: left ? BorderSide.none : side,
          ),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(top && left ? 12 : 0),
            topRight: Radius.circular(top && !left ? 12 : 0),
            bottomLeft: Radius.circular(!top && left ? 12 : 0),
            bottomRight: Radius.circular(!top && !left ? 12 : 0),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.2),
            radius: 1,
            colors: [p.deep2, p.deep3],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, c) => Stack(
            children: [
              if (photo == null)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.checkroom_rounded,
                        size: 96,
                        color: p.rose1.withValues(alpha: 0.55),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Fotoğraf çek ya da galeriden seç',
                        style: TextStyle(
                          fontSize: 13.5,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Positioned.fill(child: PhotoImage(path: photo!.path)),
              if (photo == null)
                AnimatedBuilder(
                  animation: scan,
                  builder: (context, _) {
                    final t = Curves.easeInOut.transform(scan.value);
                    return Positioned(
                      left: c.maxWidth * 0.06,
                      right: c.maxWidth * 0.06,
                      top: c.maxHeight * (0.08 + 0.8 * t),
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(1),
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0),
                              Colors.white,
                              Colors.white.withValues(alpha: 0),
                            ],
                          ),
                          boxShadow: [BoxShadow(color: p.blob, blurRadius: 18)],
                        ),
                      ),
                    );
                  },
                ),
              _corner(Alignment.topLeft),
              _corner(Alignment.topRight),
              _corner(Alignment.bottomLeft),
              _corner(Alignment.bottomRight),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailsSheet extends StatelessWidget {
  const _DetailsSheet({
    required this.nameController,
    required this.categories,
    required this.category,
    required this.ai,
    required this.aiMessage,
    required this.onRetryAi,
    required this.color,
    required this.events,
    required this.onEvent,
    required this.bottomPadding,
    required this.saving,
    required this.onCategory,
    required this.onRetake,
    required this.onSave,
  });

  final TextEditingController nameController;
  final List<String> categories;
  final String category;
  final AiStatus ai;
  final String? aiMessage;
  final VoidCallback onRetryAi;
  final Color? color;
  final Set<EventType> events;
  final ValueChanged<EventType> onEvent;
  final double bottomPadding;
  final bool saving;
  final ValueChanged<String> onCategory;
  final VoidCallback onRetake;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 40,
            offset: const Offset(0, -18),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 14, 24, 24 + bottomPadding),
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Parçayı tanımla',
                    style: serif(26, weight: FontWeight.w700),
                  ),
                ),
                if (ai == AiStatus.done) const AiBadge(label: 'Yapay zekâ doldurdu'),
              ],
            ),
            if (ai != AiStatus.off) ...[
              const SizedBox(height: 10),
              AiStatusLine(status: ai, message: aiMessage, onRetry: onRetryAi),
            ],
            const SizedBox(height: 14),
            Text(
              'Adı',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: p.muted,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: p.border),
              ),
              child: TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(fontSize: 14.5, color: p.ink),
                cursorColor: p.act,
                decoration: InputDecoration(
                  hintText: 'Örn. Krem blazer',
                  hintStyle: TextStyle(fontSize: 14.5, color: p.muted),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Türü',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: p.muted,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in categories)
                  PillChip(
                    label: c,
                    height: 38,
                    selected: c == category,
                    onTap: () => onCategory(c),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Uygun olduğu etkinlikler',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: p.muted,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Boş bırakırsan her etkinliğe uygun sayılır.',
              style: TextStyle(fontSize: 12, color: p.muted),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in EventType.values)
                  PillChip(
                    label: e.label,
                    height: 38,
                    selected: events.contains(e),
                    onTap: () => onEvent(e),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            ColorBadge(color: color, pending: color == null),
            const SizedBox(height: 22),
            Row(
              children: [
                GhostButton(label: 'Tekrar çek', height: 54, onTap: onRetake),
                const SizedBox(width: 10),
                Expanded(
                  child: GradientButton(
                    label: saving ? 'Ekleniyor' : 'Dolaba ekle',
                    height: 54,
                    onTap: onSave,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
