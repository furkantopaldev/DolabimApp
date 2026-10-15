import 'package:flutter_test/flutter_test.dart';

import 'package:dolabim/data/models.dart';

void main() {
  test('kullanıcı parçası JSON ile gidip gelir', () {
    final g = Garment.user(
      id: 'u1',
      name: 'Krem blazer',
      category: 'Dış giyim',
      photoPath: '/tmp/u1.jpg',
    );
    final back = Garment.fromJson(g.toJson());
    expect(back.id, 'u1');
    expect(back.name, 'Krem blazer');
    expect(back.photoPath, '/tmp/u1.jpg');
    expect(back.shape, GarmentShape.blazer);
  });

  test('tür silüete eşlenir, bilinmeyen tür üst olur', () {
    expect(Garment.shapeForCategory('Alt'), GarmentShape.trousers);
    expect(Garment.shapeForCategory('Ayakkabı'), GarmentShape.shoe);
    expect(Garment.shapeForCategory('Bilinmeyen'), GarmentShape.top);
  });
}
