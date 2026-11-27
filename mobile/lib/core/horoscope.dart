/// Birth details worked out on the device from the date, time and UTC offset. Nothing is sent anywhere.
///
/// Western sun sign: from the date.
/// Vedic (sidereal) sun, moon sign and nakshatra: from the birth time and place offset, using low-precision
/// lunar and solar formulas (Meeus) and the Lahiri ayanamsa. Accuracy is about a fraction of a degree, so a moon
/// near a nakshatra boundary can differ from a full ephemeris. Treat these as guidance, not an exact chart.
library;

import 'dart:math' as math;

class SunSign {
  const SunSign(this.name, this.dates, this.element, this.ruler, this.traits);

  final String name;
  final String dates;
  final String element;
  final String ruler;
  final String traits;
}

class HoroscopeReport {
  const HoroscopeReport({
    required this.western,
    required this.sunRashi,
    required this.moonRashi,
    required this.nakshatra,
    required this.nakshatraPada,
    required this.chineseAnimal,
    required this.chineseElement,
    required this.lifePath,
    required this.lifePathMeaning,
    required this.hasBirthTime,
  });

  final SunSign western;

  /// Vedic sun sign (Rashi). Exact to the minute when the birth time is known.
  final String sunRashi;

  /// Vedic moon sign. Null when no birth time was given, because the moon moves about 13 degrees a day.
  final String? moonRashi;

  /// Nakshatra of the moon. Null without a birth time.
  final String? nakshatra;
  final int? nakshatraPada;

  final String chineseAnimal;
  final String chineseElement;
  final int lifePath;
  final String lifePathMeaning;
  final bool hasBirthTime;
}

const _westernSigns = [
  // Ordered from 21 March, so a date can be matched by scanning down the list.
  SunSign('Aries', '21 Mar - 19 Apr', 'Fire', 'Mars', 'Bold, quick to start things, direct and energetic.'),
  SunSign('Taurus', '20 Apr - 20 May', 'Earth', 'Venus', 'Patient, dependable, loves comfort and steady progress.'),
  SunSign('Gemini', '21 May - 20 Jun', 'Air', 'Mercury', 'Curious, quick with words, adapts easily, enjoys variety.'),
  SunSign('Cancer', '21 Jun - 22 Jul', 'Water', 'Moon', 'Caring and intuitive, deeply loyal to family and home.'),
  SunSign('Leo', '23 Jul - 22 Aug', 'Fire', 'Sun', 'Warm, generous, confident, likes to lead and be appreciated.'),
  SunSign('Virgo', '23 Aug - 22 Sep', 'Earth', 'Mercury', 'Careful, practical, detail-minded, helps others improve.'),
  SunSign('Libra', '23 Sep - 22 Oct', 'Air', 'Venus', 'Fair-minded, social, values harmony and good partnerships.'),
  SunSign('Scorpio', '23 Oct - 21 Nov', 'Water', 'Mars and Pluto', 'Intense, private, determined, loyal once trust is earned.'),
  SunSign('Sagittarius', '22 Nov - 21 Dec', 'Fire', 'Jupiter', 'Optimistic, adventurous, honest, enjoys learning and travel.'),
  SunSign('Capricorn', '22 Dec - 19 Jan', 'Earth', 'Saturn', 'Disciplined, ambitious, responsible, builds slowly and well.'),
  SunSign('Aquarius', '20 Jan - 18 Feb', 'Air', 'Saturn and Uranus', 'Independent, inventive, friendly, thinks about the bigger picture.'),
  SunSign('Pisces', '19 Feb - 20 Mar', 'Water', 'Jupiter and Neptune', 'Compassionate, imaginative, gentle, sensitive to moods.'),
];

/// Western sun sign for a date. Boundaries are the usual ones; days on the edge can differ by one by year.
SunSign westernSign(DateTime d) {
  final md = d.month * 100 + d.day;
  if (md >= 321 && md <= 419) return _westernSigns[0];
  if (md >= 420 && md <= 520) return _westernSigns[1];
  if (md >= 521 && md <= 620) return _westernSigns[2];
  if (md >= 621 && md <= 722) return _westernSigns[3];
  if (md >= 723 && md <= 822) return _westernSigns[4];
  if (md >= 823 && md <= 922) return _westernSigns[5];
  if (md >= 923 && md <= 1022) return _westernSigns[6];
  if (md >= 1023 && md <= 1121) return _westernSigns[7];
  if (md >= 1122 && md <= 1221) return _westernSigns[8];
  if (md >= 1222 || md <= 119) return _westernSigns[9];
  if (md >= 120 && md <= 218) return _westernSigns[10];
  return _westernSigns[11];
}

const rashiNames = [
  'Mesha (Aries)', 'Vrishabha (Taurus)', 'Mithuna (Gemini)', 'Karka (Cancer)', 'Simha (Leo)', 'Kanya (Virgo)',
  'Tula (Libra)', 'Vrishchika (Scorpio)', 'Dhanu (Sagittarius)', 'Makara (Capricorn)', 'Kumbha (Aquarius)', 'Meena (Pisces)',
];

const nakshatraNames = [
  'Ashwini', 'Bharani', 'Krittika', 'Rohini', 'Mrigashira', 'Ardra', 'Punarvasu', 'Pushya', 'Ashlesha',
  'Magha', 'Purva Phalguni', 'Uttara Phalguni', 'Hasta', 'Chitra', 'Swati', 'Vishakha', 'Anuradha', 'Jyeshtha',
  'Mula', 'Purva Ashadha', 'Uttara Ashadha', 'Shravana', 'Dhanishta', 'Shatabhisha', 'Purva Bhadrapada',
  'Uttara Bhadrapada', 'Revati',
];

/// Julian day for a UTC moment (Meeus, chapter 7).
double julianDay(DateTime utc) {
  var y = utc.year;
  var m = utc.month;
  final day = utc.day + (utc.hour + utc.minute / 60 + utc.second / 3600) / 24;
  if (m <= 2) {
    y -= 1;
    m += 12;
  }
  final a = (y / 100).floor();
  final b = 2 - a + (a / 4).floor();
  return (365.25 * (y + 4716)).floor() + (30.6001 * (m + 1)).floor() + day + b - 1524.5;
}

double _norm(double deg) {
  final x = deg % 360;
  return x < 0 ? x + 360 : x;
}

double _sin(double deg) => math.sin(deg * math.pi / 180);

/// Moon's tropical longitude in degrees (Meeus, main periodic terms; accuracy about 0.3 degrees).
double moonLongitude(double jd) {
  final t = (jd - 2451545.0) / 36525;
  final lp = 218.3164477 + 481267.88123421 * t;
  final d = 297.8501921 + 445267.1114034 * t;
  final m = 357.5291092 + 35999.0502909 * t;
  final mp = 134.9633964 + 477198.8675055 * t;
  final f = 93.2720950 + 483202.0175233 * t;
  final lon = lp +
      6.288774 * _sin(mp) +
      1.274027 * _sin(2 * d - mp) +
      0.658314 * _sin(2 * d) +
      0.213618 * _sin(2 * mp) -
      0.185116 * _sin(m) -
      0.114332 * _sin(2 * f) +
      0.058793 * _sin(2 * d - 2 * mp) +
      0.057066 * _sin(2 * d - m - mp) +
      0.053322 * _sin(2 * d + mp) +
      0.045758 * _sin(2 * d - m) -
      0.040923 * _sin(m - mp) -
      0.034720 * _sin(d) -
      0.030383 * _sin(m + mp);
  return _norm(lon);
}

/// Sun's apparent tropical longitude in degrees (Meeus, low precision; accuracy about 0.01 degrees).
double sunLongitude(double jd) {
  final t = (jd - 2451545.0) / 36525;
  final l0 = 280.46646 + 36000.76983 * t;
  final m = 357.52911 + 35999.05029 * t;
  final c = (1.914602 - 0.004817 * t) * _sin(m) + 0.019993 * _sin(2 * m) + 0.000289 * _sin(3 * m);
  return _norm(l0 + c - 0.00569);
}

/// Lahiri ayanamsa: the offset between tropical and sidereal zodiacs, in degrees, for a given year.
double lahiriAyanamsa(double jd) {
  final year = 2000 + (jd - 2451545.0) / 365.25;
  return 23.853 + 0.013969 * (year - 2000);
}

String _rashiOf(double siderealDeg) => rashiNames[(siderealDeg / 30).floor() % 12];

class _Nakshatra {
  const _Nakshatra(this.name, this.pada);

  final String name;
  final int pada;
}

_Nakshatra _nakshatraOf(double siderealDeg) {
  const span = 360 / 27;
  final index = (siderealDeg / span).floor() % 27;
  final inside = siderealDeg - index * span;
  final pada = (inside / (span / 4)).floor().clamp(0, 3) + 1;
  return _Nakshatra(nakshatraNames[index], pada);
}

/// Chinese zodiac from the calendar year. Dates before Lunar New Year belong to the previous animal; that is not handled here.
const _chineseAnimals = [
  'Rat', 'Ox', 'Tiger', 'Rabbit', 'Dragon', 'Snake', 'Horse', 'Goat', 'Monkey', 'Rooster', 'Dog', 'Pig',
];

String chineseAnimal(int year) => _chineseAnimals[(year - 4) % 12];

String chineseElement(int year) {
  const elements = ['Metal', 'Water', 'Wood', 'Fire', 'Earth'];
  // Each element covers two consecutive years, starting with metal for years ending in 0 and 1.
  return switch (year % 10) {
    0 || 1 => elements[0],
    2 || 3 => elements[1],
    4 || 5 => elements[2],
    6 || 7 => elements[3],
    _ => elements[4],
  };
}

/// Life path number: add every digit of the date, repeat until one digit. 11, 22 and 33 are kept as master numbers.
int lifePathNumber(DateTime d) {
  var n = _digitSum('${d.day}${d.month}${d.year}');
  while (n > 9 && n != 11 && n != 22 && n != 33) {
    n = _digitSum('$n');
  }
  return n;
}

int _digitSum(String s) => s.split('').fold(0, (sum, ch) => sum + (int.tryParse(ch) ?? 0));

const _lifePathMeanings = {
  1: 'Independent and driven, a natural starter.',
  2: 'Cooperative, diplomatic, good at partnership.',
  3: 'Expressive, social, creative with words.',
  4: 'Practical, disciplined, builds lasting foundations.',
  5: 'Adventurous, adaptable, loves freedom and change.',
  6: 'Caring, responsible, drawn to home and family.',
  7: 'Thoughtful, analytical, seeks depth and quiet.',
  8: 'Ambitious, organised, strong with money and goals.',
  9: 'Compassionate, generous, works for a wider good.',
  11: 'Master number: intuitive and inspiring.',
  22: 'Master number: a builder who turns big plans into reality.',
  33: 'Master number: a teacher and healer at heart.',
};

/// Full birth details. [birth] is the local date and time of birth. [utcOffsetHours] is the place's offset (India: 5.5).
/// Without a birth time (hasBirthTime false), the time is ignored and the moon sign is left empty.
HoroscopeReport horoscopeFor(DateTime birth, {bool hasBirthTime = false, double utcOffsetHours = 5.5}) {
  final offsetMinutes = (utcOffsetHours * 60).round();
  final utc = DateTime.utc(birth.year, birth.month, birth.day, hasBirthTime ? birth.hour : 12, hasBirthTime ? birth.minute : 0)
      .subtract(Duration(minutes: offsetMinutes));
  final jd = julianDay(utc);
  final ayan = lahiriAyanamsa(jd);
  final sunSid = _norm(sunLongitude(jd) - ayan);
  final life = lifePathNumber(birth);

  String? moonRashi;
  String? nakshatra;
  int? pada;
  if (hasBirthTime) {
    final moonSid = _norm(moonLongitude(jd) - ayan);
    moonRashi = _rashiOf(moonSid);
    final n = _nakshatraOf(moonSid);
    nakshatra = n.name;
    pada = n.pada;
  }

  return HoroscopeReport(
    western: westernSign(birth),
    sunRashi: _rashiOf(sunSid),
    moonRashi: moonRashi,
    nakshatra: nakshatra,
    nakshatraPada: pada,
    chineseAnimal: chineseAnimal(birth.year),
    chineseElement: chineseElement(birth.year),
    lifePath: life,
    lifePathMeaning: _lifePathMeanings[life] ?? '',
    hasBirthTime: hasBirthTime,
  );
}
