class DiaryEntry {
  final String id;
  final DateTime dateTime;
  // All symptom scores are 0–10
  final int fatigue;
  final int pain;
  final int mood;
  final int numbness;
  final int coordination;
  final int vision;
  final int weakness;
  final int stress;
  final double sleepHours;
  final String note;
  final bool flareFlag;

  const DiaryEntry({
    required this.id,
    required this.dateTime,
    required this.fatigue,
    required this.pain,
    required this.mood,
    this.numbness = 0,
    this.coordination = 0,
    this.vision = 0,
    this.weakness = 0,
    this.stress = 0,
    required this.sleepHours,
    this.note = '',
    this.flareFlag = false,
  });

  /// Composite wellness index 0–100. Higher = better day.
  /// Formula: combines general symptoms, MS-specific burden, stress, mood, and sleep.
  int get compositeIndex {
    // Invert symptom burden (lower is better), keep mood as-is.
    final fatigueScore = (10 - fatigue) * 10;
    final painScore = (10 - pain) * 10;
    final neuroScore =
        (10 - ((numbness + coordination + vision + weakness) / 4)) * 10;
    final stressScore = (10 - stress) * 10;
    final moodScore = mood * 10;
    // Sleep bonus: 7–9h is optimal
    final sleepScore = (sleepHours >= 7 && sleepHours <= 9)
        ? 100
        : (sleepHours * 10).clamp(0, 100).toInt();
    return ((fatigueScore +
                painScore +
                neuroScore +
                stressScore +
                moodScore +
                sleepScore) /
            6)
        .round();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'dateTime': dateTime.toIso8601String(),
    'fatigue': fatigue,
    'pain': pain,
    'mood': mood,
    'numbness': numbness,
    'coordination': coordination,
    'vision': vision,
    'weakness': weakness,
    'stress': stress,
    'sleepHours': sleepHours,
    'note': note,
    'flareFlag': flareFlag,
  };

  factory DiaryEntry.fromJson(Map<String, dynamic> json) => DiaryEntry(
    id: json['id'] as String,
    dateTime: DateTime.parse(json['dateTime'] as String).toLocal(),
    fatigue: json['fatigue'] as int,
    pain: json['pain'] as int,
    mood: json['mood'] as int,
    numbness: json['numbness'] as int? ?? 0,
    coordination: json['coordination'] as int? ?? 0,
    vision: json['vision'] as int? ?? 0,
    weakness: json['weakness'] as int? ?? 0,
    stress: json['stress'] as int? ?? 0,
    sleepHours: (json['sleepHours'] as num).toDouble(),
    note: json['note'] as String? ?? '',
    flareFlag: json['flareFlag'] as bool? ?? false,
  );

  DiaryEntry copyWith({
    int? fatigue,
    int? pain,
    int? mood,
    int? numbness,
    int? coordination,
    int? vision,
    int? weakness,
    int? stress,
    double? sleepHours,
    String? note,
    bool? flareFlag,
  }) => DiaryEntry(
    id: id,
    dateTime: dateTime,
    fatigue: fatigue ?? this.fatigue,
    pain: pain ?? this.pain,
    mood: mood ?? this.mood,
    numbness: numbness ?? this.numbness,
    coordination: coordination ?? this.coordination,
    vision: vision ?? this.vision,
    weakness: weakness ?? this.weakness,
    stress: stress ?? this.stress,
    sleepHours: sleepHours ?? this.sleepHours,
    note: note ?? this.note,
    flareFlag: flareFlag ?? this.flareFlag,
  );
}
