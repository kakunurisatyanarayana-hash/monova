/// Birth details worked out from the date of birth alone, on the device. Nothing is sent anywhere.
/// What is NOT here: the Vedic moon sign (rashi from the moon) and nakshatra, which need the birth time and place.
library;

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
    required this.vedic,
    required this.chineseAnimal,
    required this.chineseElement,
    required this.lifePath,
    required this.lifePathMeaning,
  });

  final SunSign western;
  final String vedic;
  final String chineseAnimal;
  final String chineseElement;
  final int lifePath;
  final String lifePathMeaning;
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

// The sun enters each sidereal (Vedic) sign about 24 days behind the tropical date. These are the usual entry days.
const _vedicEntries = [
  (1, 14, 'Makara (Capricorn)'),
  (2, 13, 'Kumbha (Aquarius)'),
  (3, 14, 'Meena (Pisces)'),
  (4, 14, 'Mesha (Aries)'),
  (5, 15, 'Vrishabha (Taurus)'),
  (6, 15, 'Mithuna (Gemini)'),
  (7, 16, 'Karka (Cancer)'),
  (8, 16, 'Simha (Leo)'),
  (9, 16, 'Kanya (Virgo)'),
  (10, 16, 'Tula (Libra)'),
  (11, 15, 'Vrishchika (Scorpio)'),
  (12, 15, 'Dhanu (Sagittarius)'),
];

/// Approximate Vedic sun sign (sidereal). Can be a day off near the boundaries. It is not the moon sign.
String vedicSunSign(DateTime d) {
  final md = d.month * 100 + d.day;
  var name = _vedicEntries.last.$3;
  for (final e in _vedicEntries) {
    if (md >= e.$1 * 100 + e.$2) name = e.$3;
  }
  return name;
}

const _chineseAnimals = [
  'Rat', 'Ox', 'Tiger', 'Rabbit', 'Dragon', 'Snake', 'Horse', 'Goat', 'Monkey', 'Rooster', 'Dog', 'Pig',
];

/// Chinese zodiac from the calendar year. Dates before Lunar New Year belong to the previous animal; that is not handled here.
String chineseAnimal(int year) => _chineseAnimals[(year - 4) % 12];

String chineseElement(int year) {
  const elements = ['Metal', 'Water', 'Wood', 'Fire', 'Earth'];
  // Each element covers two consecutive years, starting with metal for years ending in 0 and 1.
  final last = year % 10;
  return switch (last) {
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

HoroscopeReport horoscopeFor(DateTime birth) {
  final life = lifePathNumber(birth);
  return HoroscopeReport(
    western: westernSign(birth),
    vedic: vedicSunSign(birth),
    chineseAnimal: chineseAnimal(birth.year),
    chineseElement: chineseElement(birth.year),
    lifePath: life,
    lifePathMeaning: _lifePathMeanings[life] ?? '',
  );
}
