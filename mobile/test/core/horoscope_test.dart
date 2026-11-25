import 'package:flutter_test/flutter_test.dart';
import 'package:monova_app/core/horoscope.dart';

void main() {
  test('Western sun signs at the edges of each sign', () {
    expect(westernSign(DateTime(2000, 1, 1)).name, 'Capricorn');
    expect(westernSign(DateTime(2000, 1, 20)).name, 'Aquarius');
    expect(westernSign(DateTime(2000, 3, 20)).name, 'Pisces');
    expect(westernSign(DateTime(2000, 3, 21)).name, 'Aries');
    expect(westernSign(DateTime(2000, 12, 31)).name, 'Capricorn');
  });

  test('Chinese zodiac from the year, with the element from the last digit', () {
    expect(chineseAnimal(1990), 'Horse');
    expect(chineseElement(1990), 'Metal');
    expect(chineseAnimal(2000), 'Dragon');
    expect(chineseElement(2000), 'Metal');
  });

  test('life path number adds the digits of the date and keeps master numbers', () {
    expect(lifePathNumber(DateTime(2026, 11, 25)), 1); // 2+5+1+1+2+0+2+6 = 19 -> 10 -> 1
    expect(lifePathNumber(DateTime(1990, 1, 1)), 3); // 1+1+1+9+9+0 = 21 -> 3
  });

  test('approximate Vedic sun sign changes around mid April', () {
    expect(vedicSunSign(DateTime(2000, 4, 13)), 'Meena (Pisces)');
    expect(vedicSunSign(DateTime(2000, 4, 14)), 'Mesha (Aries)');
    expect(vedicSunSign(DateTime(2000, 1, 5)), 'Dhanu (Sagittarius)');
  });
}
