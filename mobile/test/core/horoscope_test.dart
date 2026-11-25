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

  test('Julian day of 1 January 2000 at 12:00 UT is 2451545.0', () {
    expect(julianDay(DateTime.utc(2000, 1, 1, 12)), closeTo(2451545.0, 1e-6));
  });

  test('tropical sun is near 280 degrees on 1 January 2000', () {
    final lon = sunLongitude(julianDay(DateTime.utc(2000, 1, 1, 12)));
    expect(lon, closeTo(280.4, 0.2));
  });

  test('Vedic sun sign: the sun is in Mesha (Aries) by late April in 2000', () {
    // Tropical sun about 30 degrees on 20 April; minus the ayanamsa (about 23.85) it is still inside Mesha.
    final report = horoscopeFor(DateTime(2000, 4, 20));
    expect(report.sunRashi, rashiNames[0]);
    expect(report.hasBirthTime, isFalse);
    expect(report.moonRashi, isNull, reason: 'the moon needs a birth time');
    expect(report.nakshatra, isNull);
  });

  test('Vedic sun sign in January 2000 is Dhanu (Sagittarius)', () {
    expect(horoscopeFor(DateTime(2000, 1, 1)).sunRashi, rashiNames[8]);
  });

  test('with a birth time the moon sign and nakshatra are filled in and within range', () {
    final report = horoscopeFor(DateTime(1990, 6, 15, 14, 30), hasBirthTime: true, utcOffsetHours: 5.5);
    expect(rashiNames, contains(report.moonRashi));
    expect(nakshatraNames, contains(report.nakshatra));
    expect(report.nakshatraPada, inInclusiveRange(1, 4));
  });

  test('the moon moves forward about 13 degrees a day', () {
    final a = moonLongitude(julianDay(DateTime.utc(2000, 1, 1, 0)));
    final b = moonLongitude(julianDay(DateTime.utc(2000, 1, 2, 0)));
    final step = (b - a + 360) % 360;
    expect(step, inInclusiveRange(11.5, 15.0));
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
}
