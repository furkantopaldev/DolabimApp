import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dolabim/data/models.dart';
import 'package:dolabim/state/app_state.dart';

AppState _state() => AppState(wardrobe: [
      Garment.user(
        id: 'u1',
        name: 'Eski ad',
        category: 'Üst',
        photoPath: '/yok/u1.jpg',
      ),
      Garment.user(
        id: 'u2',
        name: 'Diğer',
        category: 'Alt',
        photoPath: '/yok/u2.jpg',
      ),
    ]);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('güncelleme ad ve türü değiştirir, silüeti türe göre ayarlar', () async {
    final s = _state();
    await s.updateGarment('u1', name: 'Krem blazer', category: 'Dış giyim');
    final g = s.wardrobe.firstWhere((x) => x.id == 'u1');
    expect(g.name, 'Krem blazer');
    expect(g.category, 'Dış giyim');
    expect(g.shape, GarmentShape.blazer);
    expect(g.photoPath, '/yok/u1.jpg');
    expect(s.wardrobe.length, 2);
  });

  test('silme sadece seçilen parçayı çıkarır', () async {
    final s = _state();
    var notified = 0;
    s.addListener(() => notified++);
    await s.removeGarment('u1');
    expect(s.wardrobe.map((g) => g.id), ['u2']);
    expect(notified, 1);
  });

  test('olmayan parça için işlem sessizce geçilir', () async {
    final s = _state();
    await s.updateGarment('yok', name: 'x', category: 'Üst');
    await s.removeGarment('yok');
    expect(s.wardrobe.length, 2);
  });
}
