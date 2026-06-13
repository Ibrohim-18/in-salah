/// A surah entry from the AlQuran.cloud `/surah` list endpoint.
class Surah {
  final int number;
  final String nameArabic;
  final String englishName;
  final String englishTranslation;
  final int numberOfAyahs;
  final String revelationType; // 'Meccan' | 'Medinan'

  const Surah({
    required this.number,
    required this.nameArabic,
    required this.englishName,
    required this.englishTranslation,
    required this.numberOfAyahs,
    required this.revelationType,
  });

  bool get isMeccan => revelationType.toLowerCase() == 'meccan';

  factory Surah.fromJson(Map<String, dynamic> json) => Surah(
    number: (json['number'] as num).toInt(),
    nameArabic: json['name'] as String? ?? '',
    englishName: json['englishName'] as String? ?? '',
    englishTranslation: json['englishNameTranslation'] as String? ?? '',
    numberOfAyahs: (json['numberOfAyahs'] as num?)?.toInt() ?? 0,
    revelationType: json['revelationType'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'number': number,
    'name': nameArabic,
    'englishName': englishName,
    'englishNameTranslation': englishTranslation,
    'numberOfAyahs': numberOfAyahs,
    'revelationType': revelationType,
  };
}

/// A single ayah with its Arabic text, optional translation and audio URL.
class Ayah {
  final int numberInSurah;
  final String arabic;
  final String? translation;
  final String? audioUrl;

  const Ayah({
    required this.numberInSurah,
    required this.arabic,
    this.translation,
    this.audioUrl,
  });

  Ayah copyWith({String? translation, String? audioUrl}) => Ayah(
    numberInSurah: numberInSurah,
    arabic: arabic,
    translation: translation ?? this.translation,
    audioUrl: audioUrl ?? this.audioUrl,
  );

  Map<String, dynamic> toJson() => {
    'numberInSurah': numberInSurah,
    'arabic': arabic,
    if (translation != null) 'translation': translation,
    if (audioUrl != null) 'audioUrl': audioUrl,
  };

  factory Ayah.fromJson(Map<String, dynamic> json) => Ayah(
    numberInSurah: (json['numberInSurah'] as num).toInt(),
    arabic: json['arabic'] as String? ?? '',
    translation: json['translation'] as String?,
    audioUrl: json['audioUrl'] as String?,
  );
}

/// A reciter option for the audio player.
class Reciter {
  final String id; // AlQuran.cloud audio edition identifier, e.g. 'ar.alafasy'
  final String name;

  const Reciter({required this.id, required this.name});
}

/// Audio editions offered in the reader. Alafasy is the default.
const List<Reciter> kReciters = [
  Reciter(id: 'ar.alafasy', name: 'Mishary Alafasy'),
  Reciter(id: 'ar.abdurrahmaansudais', name: 'Abdurrahman As-Sudais'),
  Reciter(id: 'ar.husary', name: 'Mahmoud Al-Husary'),
  Reciter(id: 'ar.mahermuaiqly', name: 'Maher Al-Muaiqly'),
  Reciter(id: 'ar.shaatree', name: 'Abu Bakr Ash-Shaatree'),
];
