import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/sample_data.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import 'color_badge.dart';
import 'common.dart';
import 'garment_tile.dart';

/// Kullanıcının kendi parçasını düzenleme ve silme paneli.
Future<void> showEditGarmentSheet(BuildContext context, Garment garment) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (_) => _EditGarmentSheet(garment: garment),
  );
}

class _EditGarmentSheet extends StatefulWidget {
  const _EditGarmentSheet({required this.garment});

  final Garment garment;

  @override
  State<_EditGarmentSheet> createState() => _EditGarmentSheetState();
}

class _EditGarmentSheetState extends State<_EditGarmentSheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.garment.name);
  late String _category = widget.garment.category;
  late final Set<EventType> _events = {...widget.garment.events};
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final state = AppScope.of(context);
    final name = _name.text.trim().isEmpty ? _category : _name.text.trim();
    await state.updateGarment(
      widget.garment.id,
      name: name,
      category: _category,
      events: {..._events},
    );
    navigator.pop();
    messenger.showSnackBar(const SnackBar(content: Text('Parça güncellendi.')));
  }

  Future<void> _delete() async {
    final p = context.pal;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text('Parça silinsin mi?', style: serif(24, weight: FontWeight.w700)),
        content: Text(
          '“${widget.garment.name}” dolabından ve cihazdan silinecek. Bu işlem geri alınamaz.',
          style: TextStyle(fontSize: 14, height: 1.5, color: p.body),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Vazgeç', style: TextStyle(color: p.deep2, fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Sil',
              style: TextStyle(color: Color(0xFFB3261E), fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final state = AppScope.of(context);
    await state.removeGarment(widget.garment.id);
    navigator.pop();
    messenger.showSnackBar(const SnackBar(content: Text('Parça dolabından silindi.')));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final media = MediaQuery.of(context);
    final gender = AppScope.of(context).gender;
    final categories = SampleData.categories(gender).skip(1).toList();
    // Eski kayıt erkek modunda "Elbise" gibi listede olmayan bir türdeyse de
    // seçili görünsün.
    if (!categories.contains(_category)) categories.add(_category);

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.85),
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
                Row(
                  children: [
                    SizedBox(
                      width: 92,
                      height: 108,
                      child: GarmentTile(garment: widget.garment, iconSize: 64),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Parçayı düzenle',
                        style: serif(26, weight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
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
                    controller: _name,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(fontSize: 14.5, color: p.ink),
                    cursorColor: p.act,
                    decoration: const InputDecoration(border: InputBorder.none),
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
                        selected: c == _category,
                        onTap: () => setState(() => _category = c),
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
                        selected: _events.contains(e),
                        onTap: () => setState(() {
                          if (!_events.add(e)) _events.remove(e);
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                ColorBadge(color: widget.garment.color),
                const SizedBox(height: 22),
                GradientButton(label: 'Kaydet', height: 54, onTap: _save),
                const SizedBox(height: 6),
                Center(
                  child: TextButton.icon(
                    onPressed: _busy ? null : _delete,
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      size: 20,
                      color: Color(0xFFB3261E),
                    ),
                    label: const Text(
                      'Parçayı sil',
                      style: TextStyle(
                        color: Color(0xFFB3261E),
                        fontWeight: FontWeight.w700,
                      ),
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
