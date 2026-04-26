class Prayer {
  final String name;
  final String nameArabic;
  final DateTime time;
  final DateTime iqamaTime;
  final bool isCompleted;

  Prayer({
    required this.name,
    required this.nameArabic,
    required this.time,
    required this.iqamaTime,
    this.isCompleted = false,
  });

  Prayer copyWith({
    String? name,
    String? nameArabic,
    DateTime? time,
    DateTime? iqamaTime,
    bool? isCompleted,
  }) {
    return Prayer(
      name: name ?? this.name,
      nameArabic: nameArabic ?? this.nameArabic,
      time: time ?? this.time,
      iqamaTime: iqamaTime ?? this.iqamaTime,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
