enum Gender { male, female }

class PrayerNotificationSettings {
  final bool isEnabled;
  final String sound;

  const PrayerNotificationSettings({
    this.isEnabled = true,
    this.sound = 'default',
  });

  Map<String, dynamic> toJson() => {'isEnabled': isEnabled, 'sound': sound};

  factory PrayerNotificationSettings.fromJson(Map<String, dynamic> json) {
    return PrayerNotificationSettings(
      isEnabled: json['isEnabled'] ?? true,
      sound: json['sound'] ?? 'default',
    );
  }
}

class UserSettings {
  final Gender? gender;
  final DateTime? dateOfBirth;
  final String? avatarPath;
  final Map<String, int> iqamaTimes;
  final Map<String, PrayerNotificationSettings> prayerSettings;
  final String calculationMethod;
  final String madhab;
  final String? displayName;
  final double interfaceScale;
  final String locale;

  UserSettings({
    this.gender,
    this.dateOfBirth,
    this.avatarPath,
    this.iqamaTimes = const {
      'Fajr': 15,
      'Dhuhr': 10,
      'Asr': 10,
      'Maghrib': 5,
      'Isha': 15,
    },
    this.prayerSettings = const {
      'Fajr': PrayerNotificationSettings(),
      'Dhuhr': PrayerNotificationSettings(),
      'Asr': PrayerNotificationSettings(),
      'Maghrib': PrayerNotificationSettings(),
      'Isha': PrayerNotificationSettings(),
    },
    this.calculationMethod = 'muslim_world_league',
    this.madhab = 'shafi',
    this.displayName,
    this.interfaceScale = 0.92,
    this.locale = 'system',
  });

  factory UserSettings.fromCloudProfileJson(Map<String, dynamic> json) {
    final rawDateOfBirth = json['date_of_birth'] ?? json['dateOfBirth'];
    final parsedDateOfBirth =
        rawDateOfBirth is String && rawDateOfBirth.isNotEmpty
        ? DateTime.tryParse(rawDateOfBirth)
        : null;

    return UserSettings(
      gender: json['gender'] == 'male'
          ? Gender.male
          : json['gender'] == 'female'
          ? Gender.female
          : null,
      dateOfBirth: parsedDateOfBirth,
      avatarPath: json['avatar_url'] ?? json['avatarPath'],
      calculationMethod:
          json['calculation_method'] ??
          json['calculationMethod'] ??
          'muslim_world_league',
      madhab: json['madhab'] ?? 'shafi',
      interfaceScale: ((json['interface_scale'] ?? json['interfaceScale'] ?? json['uiScale'] ?? 0.92) as num)
          .toDouble()
          .clamp(0.70, 1.20),
    );
  }

  bool get isSetupComplete => gender != null && dateOfBirth != null;

  int get obligationStartAge => gender == Gender.male ? 12 : 9;

  UserSettings copyWith({
    Gender? gender,
    DateTime? dateOfBirth,
    String? avatarPath,
    Map<String, int>? iqamaTimes,
    Map<String, PrayerNotificationSettings>? prayerSettings,
    String? calculationMethod,
    String? madhab,
    String? displayName,
    double? interfaceScale,
    String? locale,
  }) {
    return UserSettings(
      displayName: displayName ?? this.displayName,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      avatarPath: avatarPath ?? this.avatarPath,
      iqamaTimes: iqamaTimes ?? this.iqamaTimes,
      prayerSettings: prayerSettings ?? this.prayerSettings,
      calculationMethod: calculationMethod ?? this.calculationMethod,
      madhab: madhab ?? this.madhab,
      interfaceScale: interfaceScale ?? this.interfaceScale,
      locale: locale ?? this.locale,
    );
  }

  UserSettings mergeCloudProfile(
    UserSettings cloudProfile, {
    bool preferCloudBackedSettings = false,
  }) {
    return UserSettings(
      gender: gender ?? cloudProfile.gender,
      displayName: displayName ?? cloudProfile.displayName,
      dateOfBirth: dateOfBirth ?? cloudProfile.dateOfBirth,
      avatarPath: avatarPath ?? cloudProfile.avatarPath,
      iqamaTimes: iqamaTimes,
      prayerSettings: prayerSettings,
      calculationMethod: preferCloudBackedSettings
          ? cloudProfile.calculationMethod
          : calculationMethod,
      madhab: preferCloudBackedSettings ? cloudProfile.madhab : madhab,
      interfaceScale: interfaceScale,
      locale: locale,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'gender': gender?.name,
      'displayName': displayName,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'avatarPath': avatarPath,
      'iqamaTimes': iqamaTimes,
      'prayerSettings': prayerSettings.map((k, v) => MapEntry(k, v.toJson())),
      'calculationMethod': calculationMethod,
      'madhab': madhab,
      'interfaceScale': interfaceScale,
      'locale': locale,
    };
  }

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      displayName: json['displayName'],
      gender: json['gender'] == 'male'
          ? Gender.male
          : json['gender'] == 'female'
          ? Gender.female
          : null,
      dateOfBirth: json['dateOfBirth'] != null
          ? DateTime.parse(json['dateOfBirth'])
          : null,
      avatarPath: json['avatarPath'],
      iqamaTimes: Map<String, int>.from(json['iqamaTimes'] ?? {}),
      prayerSettings: json['prayerSettings'] != null
          ? (json['prayerSettings'] as Map<String, dynamic>).map(
              (k, v) => MapEntry(k, PrayerNotificationSettings.fromJson(v)),
            )
          : const {
              'Fajr': PrayerNotificationSettings(),
              'Dhuhr': PrayerNotificationSettings(),
              'Asr': PrayerNotificationSettings(),
              'Maghrib': PrayerNotificationSettings(),
              'Isha': PrayerNotificationSettings(),
            },
      calculationMethod: json['calculationMethod'] ?? 'muslim_world_league',
      madhab: json['madhab'] ?? 'shafi',
      interfaceScale: ((json['interfaceScale'] ?? json['uiScale'] ?? 0.92) as num).toDouble().clamp(0.70, 1.20),
      locale: json['locale'] ?? 'system',
    );
  }
}
