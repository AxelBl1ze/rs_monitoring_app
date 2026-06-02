import 'dart:math' as math;
import '../models/diary_entry.dart';
import '../models/test_result.dart';

class AnalysisSignal {
  final String title;
  final String description;
  // 'high', 'warn', 'info'
  final String severity;
  final DateTime dateTime;

  const AnalysisSignal({
    required this.title,
    required this.description,
    required this.severity,
    required this.dateTime,
  });
}

class DeteriorationEpisode {
  final String id;
  final DateTime startDate;
  final String triggerReason;
  final List<String> changedIndicators;
  // 'high', 'warn', 'info'
  final String severity;
  final bool sentToDoctor;
  final String? doctorComment;

  const DeteriorationEpisode({
    required this.id,
    required this.startDate,
    required this.triggerReason,
    required this.changedIndicators,
    required this.severity,
    this.sentToDoctor = false,
    this.doctorComment,
  });
}

class HealthIndexPrediction {
  final int predictedIndex;
  final int latestIndex;
  final double slopePerEntry;
  final double rSquared;
  final int sampleCount;
  final List<int> observedIndices;

  const HealthIndexPrediction({
    required this.predictedIndex,
    required this.latestIndex,
    required this.slopePerEntry,
    required this.rSquared,
    required this.sampleCount,
    required this.observedIndices,
  });
}

class AnalyticsService {
  // ── Descriptive statistics ──────────────────────────────────────────────

  static double? mean(List<double> values) {
    if (values.isEmpty) return null;
    return values.fold(0.0, (s, v) => s + v) / values.length;
  }

  static double? median(List<double> values) {
    if (values.isEmpty) return null;
    final sorted = List<double>.from(values)..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[mid]
        : (sorted[mid - 1] + sorted[mid]) / 2;
  }

  static double? minValue(List<double> values) {
    if (values.isEmpty) return null;
    return values.reduce(math.min);
  }

  static double? maxValue(List<double> values) {
    if (values.isEmpty) return null;
    return values.reduce(math.max);
  }

  /// Sample standard deviation (n-1 denominator).
  static double? standardDeviation(List<double> values) {
    if (values.length < 2) return null;
    final avg = mean(values)!;
    final variance =
        values.fold(0.0, (s, v) => s + (v - avg) * (v - avg)) /
        (values.length - 1);
    return math.sqrt(variance);
  }

  // ── Time series helpers ─────────────────────────────────────────────────

  /// Moving average; output length equals input length.
  static List<double> movingAverage(List<double> values, int window) {
    if (values.isEmpty || window <= 0) return [];
    return List.generate(values.length, (i) {
      final start = math.max(0, i - window + 1);
      final slice = values.sublist(start, i + 1);
      return slice.fold(0.0, (s, v) => s + v) / slice.length;
    });
  }

  static double? percentChange(double? current, double? previous) {
    if (current == null || previous == null || previous == 0) return null;
    return (current - previous) / previous * 100;
  }

  static List<DiaryEntry> entriesForLastDays(
    List<DiaryEntry> entries,
    int days,
  ) {
    final from = DateTime.now().subtract(Duration(days: days - 1));
    final start = DateTime(from.year, from.month, from.day);
    return entries.where((e) => !e.dateTime.isBefore(start)).toList();
  }

  static List<DiaryEntry> entriesForPreviousDays(
    List<DiaryEntry> entries,
    int days,
  ) {
    final now = DateTime.now();
    final windowEnd = now.subtract(Duration(days: days));
    final windowStart = now.subtract(Duration(days: days * 2));
    final start = DateTime(
      windowStart.year,
      windowStart.month,
      windowStart.day,
    );
    final end = DateTime(
      windowEnd.year,
      windowEnd.month,
      windowEnd.day,
      23,
      59,
      59,
    );
    return entries
        .where((e) => !e.dateTime.isBefore(start) && !e.dateTime.isAfter(end))
        .toList();
  }

  static List<TestResult> testResultsForLastDays(
    List<TestResult> results,
    int days,
    String type,
  ) {
    final from = DateTime.now().subtract(Duration(days: days));
    return results
        .where((r) => r.type == type && !r.dateTime.isBefore(from))
        .toList();
  }

  static List<TestResult> testResultsForPreviousDays(
    List<TestResult> results,
    int days,
    String type,
  ) {
    final now = DateTime.now();
    final to = now.subtract(Duration(days: days));
    final from = now.subtract(Duration(days: days * 2));
    return results
        .where(
          (r) =>
              r.type == type &&
              !r.dateTime.isBefore(from) &&
              !r.dateTime.isAfter(to),
        )
        .toList();
  }

  // ── Metric extraction ───────────────────────────────────────────────────

  static List<double> fatigueValues(List<DiaryEntry> entries) =>
      entries.map((e) => e.fatigue.toDouble()).toList();

  static List<double> painValues(List<DiaryEntry> entries) =>
      entries.map((e) => e.pain.toDouble()).toList();

  static List<double> moodValues(List<DiaryEntry> entries) =>
      entries.map((e) => e.mood.toDouble()).toList();

  static List<double> numbnessValues(List<DiaryEntry> entries) =>
      entries.map((e) => e.numbness.toDouble()).toList();

  static List<double> coordinationValues(List<DiaryEntry> entries) =>
      entries.map((e) => e.coordination.toDouble()).toList();

  static List<double> visionValues(List<DiaryEntry> entries) =>
      entries.map((e) => e.vision.toDouble()).toList();

  static List<double> weaknessValues(List<DiaryEntry> entries) =>
      entries.map((e) => e.weakness.toDouble()).toList();

  static List<double> stressValues(List<DiaryEntry> entries) =>
      entries.map((e) => e.stress.toDouble()).toList();

  static List<double> sleepValues(List<DiaryEntry> entries) =>
      entries.map((e) => e.sleepHours).toList();

  // ── Composite condition index ───────────────────────────────────────────
  // This index is intended only for self-monitoring and is not a medical diagnosis.
  //
  // Formula:
  //   fatigueNorm  = fatigue / 10
  //   painNorm     = pain / 10
  //   moodBadNorm  = 1 − mood / 10
  //   scoreBad     = 0.4·fatigueNorm + 0.3·painNorm + 0.3·moodBadNorm
  //   index        = round((1 − scoreBad) × 100)

  static int? calculateCompositeIndexFromEntry(DiaryEntry entry) {
    return calculateCompositeIndexFromAverages(
      fatigue: entry.fatigue.toDouble(),
      pain: entry.pain.toDouble(),
      mood: entry.mood.toDouble(),
      numbness: entry.numbness.toDouble(),
      coordination: entry.coordination.toDouble(),
      vision: entry.vision.toDouble(),
      weakness: entry.weakness.toDouble(),
      stress: entry.stress.toDouble(),
    );
  }

  static int? calculateCompositeIndexFromAverages({
    required double fatigue,
    required double pain,
    required double mood,
    double numbness = 0,
    double coordination = 0,
    double vision = 0,
    double weakness = 0,
    double stress = 0,
  }) {
    final fatigueNorm = fatigue / 10;
    final painNorm = pain / 10;
    final neuroBadNorm = (numbness + coordination + vision + weakness) / 40;
    final stressNorm = stress / 10;
    final moodBadNorm = 1 - mood / 10;
    final scoreBad =
        0.25 * fatigueNorm +
        0.2 * painNorm +
        0.25 * neuroBadNorm +
        0.15 * stressNorm +
        0.15 * moodBadNorm;
    return ((1 - scoreBad) * 100).round();
  }

  static double? calculateAverageCompositeIndex(List<DiaryEntry> entries) {
    if (entries.isEmpty) return null;
    final indices = entries
        .map(calculateCompositeIndexFromEntry)
        .whereType<int>()
        .toList();
    if (indices.isEmpty) return null;
    return indices.fold(0.0, (s, v) => s + v) / indices.length;
  }

  static HealthIndexPrediction? predictNextCompositeIndex(
    List<DiaryEntry> entries, {
    int minEntries = 3,
  }) {
    final sorted = List<DiaryEntry>.from(entries)
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final values = sorted
        .map(calculateCompositeIndexFromEntry)
        .whereType<int>()
        .map((value) => value.toDouble())
        .toList();
    if (values.length < minEntries) return null;

    final n = values.length;
    final xMean = (n - 1) / 2;
    final yMean = values.fold(0.0, (sum, value) => sum + value) / n;
    var numerator = 0.0;
    var denominator = 0.0;

    for (var i = 0; i < n; i++) {
      final x = i.toDouble();
      numerator += (x - xMean) * (values[i] - yMean);
      denominator += (x - xMean) * (x - xMean);
    }
    if (denominator == 0) return null;

    final slope = numerator / denominator;
    final intercept = yMean - slope * xMean;
    final predicted = (intercept + slope * n).clamp(0.0, 100.0);

    var residualSum = 0.0;
    var totalSum = 0.0;
    for (var i = 0; i < n; i++) {
      final fitted = intercept + slope * i;
      residualSum += (values[i] - fitted) * (values[i] - fitted);
      totalSum += (values[i] - yMean) * (values[i] - yMean);
    }
    final rSquared = totalSum == 0
        ? 1.0
        : (1 - residualSum / totalSum).clamp(0.0, 1.0).toDouble();

    return HealthIndexPrediction(
      predictedIndex: predicted.round(),
      latestIndex: values.last.round(),
      slopePerEntry: slope,
      rSquared: rSquared,
      sampleCount: n,
      observedIndices: values.map((value) => value.round()).toList(),
    );
  }

  // ── Signals ─────────────────────────────────────────────────────────────

  static List<AnalysisSignal> generateSignals(
    List<DiaryEntry> entries,
    List<TestResult> testResults,
  ) {
    final signals = <AnalysisSignal>[];
    final now = DateTime.now();

    final sorted = List<DiaryEntry>.from(entries)
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

    // A. Fatigue streak: fatigue >= 7 for 3 latest entries
    if (sorted.length >= 3 && sorted.take(3).every((e) => e.fatigue >= 7)) {
      signals.add(
        AnalysisSignal(
          title: 'Усталость растёт',
          description:
              'Усталость ≥ 7 в течение 3 записей подряд. '
              'Следите за состоянием и при необходимости обсудите изменения с врачом.',
          severity: 'high',
          dateTime: now,
        ),
      );
    }

    // B. Fatigue trend: avg last 7 days increased >= 20% vs previous 7 days
    final last7Fatigue = mean(fatigueValues(entriesForLastDays(entries, 7)));
    final prev7Fatigue = mean(
      fatigueValues(entriesForPreviousDays(entries, 7)),
    );
    final fatigueChange = percentChange(last7Fatigue, prev7Fatigue);
    if (fatigueChange != null && fatigueChange >= 20) {
      signals.add(
        AnalysisSignal(
          title: 'Усталость увеличивается',
          description:
              'Средняя усталость за 7 дней выросла на ${fatigueChange.round()}% '
              'по сравнению с предыдущей неделей. Возможный сигнал ухудшения. '
              'Следите за состоянием и при необходимости обратитесь к врачу.',
          severity: 'warn',
          dateTime: now,
        ),
      );
    }

    // C. Pain trend: avg last 7 days increased >= 20% vs previous 7 days
    final last7Pain = mean(painValues(entriesForLastDays(entries, 7)));
    final prev7Pain = mean(painValues(entriesForPreviousDays(entries, 7)));
    final painChange = percentChange(last7Pain, prev7Pain);
    if (painChange != null && painChange >= 20) {
      signals.add(
        AnalysisSignal(
          title: 'Боль увеличивается',
          description:
              'Средняя боль за 7 дней выросла на ${painChange.round()}% '
              'по сравнению с предыдущей неделей. Возможный сигнал ухудшения. '
              'Следите за состоянием и при необходимости обратитесь к врачу.',
          severity: 'warn',
          dateTime: now,
        ),
      );
    }

    final latest = sorted.isEmpty ? null : sorted.first;
    if (latest != null) {
      _addHighSymptomSignal(
        signals,
        now,
        value: latest.numbness,
        title: 'Онемение усилилось',
        label: 'онемение / чувствительность',
      );
      _addHighSymptomSignal(
        signals,
        now,
        value: latest.coordination,
        title: 'Координация ухудшилась',
        label: 'нарушение координации',
      );
      _addHighSymptomSignal(
        signals,
        now,
        value: latest.vision,
        title: 'Зрительные симптомы выражены',
        label: 'зрительные симптомы',
      );
      _addHighSymptomSignal(
        signals,
        now,
        value: latest.weakness,
        title: 'Мышечная слабость выражена',
        label: 'мышечная слабость',
      );
      _addHighSymptomSignal(
        signals,
        now,
        value: latest.stress,
        threshold: 8,
        title: 'Высокая нагрузка за день',
        label: 'стресс / нагрузка',
      );
    }

    _addSymptomTrendSignal(
      signals,
      now,
      entries,
      values: numbnessValues,
      title: 'Онемение увеличивается',
      label: 'онемение / чувствительность',
    );
    _addSymptomTrendSignal(
      signals,
      now,
      entries,
      values: coordinationValues,
      title: 'Координация ухудшается',
      label: 'нарушение координации',
    );
    _addSymptomTrendSignal(
      signals,
      now,
      entries,
      values: visionValues,
      title: 'Зрительные симптомы нарастают',
      label: 'зрительные симптомы',
    );
    _addSymptomTrendSignal(
      signals,
      now,
      entries,
      values: weaknessValues,
      title: 'Мышечная слабость нарастает',
      label: 'мышечная слабость',
    );
    _addSymptomTrendSignal(
      signals,
      now,
      entries,
      values: stressValues,
      title: 'Стресс и нагрузка растут',
      label: 'стресс / нагрузка',
    );

    // D. Reaction time trend: median/avg last 7 days increased >= 15% vs previous 7 days
    final last7React = testResultsForLastDays(
      testResults,
      7,
      TestType.reaction,
    );
    final prev7React = testResultsForPreviousDays(
      testResults,
      7,
      TestType.reaction,
    );
    if (last7React.isNotEmpty && prev7React.isNotEmpty) {
      final last7ReactAvg =
          last7React.fold(0.0, (s, r) => s + r.value) / last7React.length;
      final prev7ReactAvg =
          prev7React.fold(0.0, (s, r) => s + r.value) / prev7React.length;
      final reactChange = percentChange(last7ReactAvg, prev7ReactAvg);
      if (reactChange != null && reactChange >= 15) {
        signals.add(
          AnalysisSignal(
            title: 'Время реакции замедляется',
            description:
                'Медианное время реакции выросло на ${reactChange.round()}% за 7 дней. '
                'Возможный сигнал ухудшения. '
                'Следите за состоянием и при необходимости обратитесь к врачу.',
            severity: 'warn',
            dateTime: now,
          ),
        );
      }
    }

    // E. Tapping trend by hand: avg last 7 days decreased >= 15% vs previous 7 days
    for (final hand in [TestHand.left, TestHand.right]) {
      final last7Tapping = testResultsForLastDays(
        testResults,
        7,
        TestType.tapping,
      ).where((r) => r.hand == hand).toList();
      final prev7Tapping = testResultsForPreviousDays(
        testResults,
        7,
        TestType.tapping,
      ).where((r) => r.hand == hand).toList();

      if (last7Tapping.isNotEmpty && prev7Tapping.isNotEmpty) {
        final last7Avg =
            last7Tapping.fold(0.0, (s, r) => s + r.value) / last7Tapping.length;
        final prev7Avg =
            prev7Tapping.fold(0.0, (s, r) => s + r.value) / prev7Tapping.length;
        final tappingChange = percentChange(last7Avg, prev7Avg);
        if (tappingChange != null && tappingChange <= -15) {
          final handLabel = hand == TestHand.left ? 'левой' : 'правой';
          signals.add(
            AnalysisSignal(
              title: 'Таппинг $handLabel руки снижается',
              description:
                  'Средний результат таппинг-теста для $handLabel руки снизился '
                  'на ${tappingChange.abs().round()}% по сравнению с предыдущей неделей. '
                  'Отслеживайте динамику и при необходимости обсудите изменения с врачом.',
              severity: 'warn',
              dateTime: now,
            ),
          );
        }
      }
    }

    // F. Sleep + fatigue: sleep avg < 6h AND fatigue avg >= 7 during last 7 days
    final last7Entries = entriesForLastDays(entries, 7);
    final last7Sleep = mean(sleepValues(last7Entries));
    final last7FatigueAvg = mean(fatigueValues(last7Entries));
    final last7Stress = mean(stressValues(last7Entries));
    if (last7Sleep != null &&
        last7FatigueAvg != null &&
        last7Sleep < 6 &&
        last7FatigueAvg >= 7) {
      signals.add(
        AnalysisSignal(
          title: 'Недосыпание и усталость',
          description:
              'Среднее время сна менее 6 ч и высокая усталость за последние 7 дней. '
              'Возможный сигнал ухудшения. '
              'Следите за состоянием и при необходимости обратитесь к врачу.',
          severity: 'warn',
          dateTime: now,
        ),
      );
    }

    if (last7Stress != null &&
        last7FatigueAvg != null &&
        last7Stress >= 7 &&
        last7FatigueAvg >= 7) {
      signals.add(
        AnalysisSignal(
          title: 'Стресс и усталость',
          description:
              'Средние стресс/нагрузка и усталость за последние 7 дней находятся на высоком уровне. '
              'Это может усиливать симптомы и требует внимания к режиму восстановления.',
          severity: 'warn',
          dateTime: now,
        ),
      );
    }

    return signals;
  }

  static void _addHighSymptomSignal(
    List<AnalysisSignal> signals,
    DateTime now, {
    required int value,
    required String title,
    required String label,
    int threshold = 7,
  }) {
    if (value < threshold) return;
    signals.add(
      AnalysisSignal(
        title: title,
        description:
            'Показатель "$label" достиг $value/10. '
            'Если это новое или необычное изменение, зафиксируйте детали и обсудите динамику с врачом.',
        severity: value >= 9 ? 'high' : 'warn',
        dateTime: now,
      ),
    );
  }

  static void _addSymptomTrendSignal(
    List<AnalysisSignal> signals,
    DateTime now,
    List<DiaryEntry> entries, {
    required List<double> Function(List<DiaryEntry>) values,
    required String title,
    required String label,
  }) {
    final current = mean(values(entriesForLastDays(entries, 7)));
    final previous = mean(values(entriesForPreviousDays(entries, 7)));
    final change = percentChange(current, previous);
    if (change == null || change < 20) return;
    signals.add(
      AnalysisSignal(
        title: title,
        description:
            'Средний показатель "$label" за 7 дней вырос на ${change.round()}% '
            'по сравнению с предыдущей неделей. Это может быть важным изменением в динамике РС-симптомов.',
        severity: 'warn',
        dateTime: now,
      ),
    );
  }

  // ── Deterioration episodes ──────────────────────────────────────────────

  static List<DeteriorationEpisode> generateDeteriorationEpisodes(
    List<DiaryEntry> entries,
    List<TestResult> testResults,
  ) {
    final episodes = <DeteriorationEpisode>[];
    final seen = <String>{};

    void addEpisode(DeteriorationEpisode episode) {
      if (seen.add(episode.id)) {
        episodes.add(episode);
      }
    }

    final chronologicalEntries = List<DiaryEntry>.from(entries)
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    for (final entry in chronologicalEntries.where((e) => e.flareFlag)) {
      addEpisode(
        DeteriorationEpisode(
          id: 'manual-${_dateKey(entry.dateTime)}',
          startDate: entry.dateTime,
          triggerReason: 'Пациент отметил эпизод обострения в дневнике',
          changedIndicators: _entrySnapshot(entry),
          severity: 'high',
        ),
      );
    }

    _addFatigueStreakEpisodes(chronologicalEntries, addEpisode);
    _addSymptomStreakEpisodes(chronologicalEntries, addEpisode);
    _addDiaryTrendEpisodes(chronologicalEntries, addEpisode);
    _addTestTrendEpisodes(testResults, addEpisode);

    episodes.sort((a, b) => b.startDate.compareTo(a.startDate));
    return episodes;
  }

  static void _addFatigueStreakEpisodes(
    List<DiaryEntry> entries,
    void Function(DeteriorationEpisode episode) addEpisode,
  ) {
    final streak = <DiaryEntry>[];

    void flush() {
      if (streak.length >= 3) {
        final first = streak.first;
        final last = streak.last;
        addEpisode(
          DeteriorationEpisode(
            id: 'fatigue-streak-${_dateKey(first.dateTime)}',
            startDate: first.dateTime,
            triggerReason:
                'Усталость ≥ 7 в течение ${streak.length} записей подряд',
            changedIndicators: _changedIndicators(first, last),
            severity: 'high',
          ),
        );
      }
      streak.clear();
    }

    for (final entry in entries) {
      if (entry.fatigue >= 7) {
        streak.add(entry);
      } else {
        flush();
      }
    }
    flush();
  }

  static void _addSymptomStreakEpisodes(
    List<DiaryEntry> entries,
    void Function(DeteriorationEpisode episode) addEpisode,
  ) {
    _addMetricStreakEpisode(
      entries,
      addEpisode,
      idPrefix: 'numbness-streak',
      label: 'Чувствительность',
      triggerLabel: 'онемение / чувствительность',
      value: (entry) => entry.numbness,
    );
    _addMetricStreakEpisode(
      entries,
      addEpisode,
      idPrefix: 'coordination-streak',
      label: 'Координация',
      triggerLabel: 'нарушение координации',
      value: (entry) => entry.coordination,
    );
    _addMetricStreakEpisode(
      entries,
      addEpisode,
      idPrefix: 'vision-streak',
      label: 'Зрение',
      triggerLabel: 'зрительные симптомы',
      value: (entry) => entry.vision,
    );
    _addMetricStreakEpisode(
      entries,
      addEpisode,
      idPrefix: 'weakness-streak',
      label: 'Слабость',
      triggerLabel: 'мышечная слабость',
      value: (entry) => entry.weakness,
    );
    _addMetricStreakEpisode(
      entries,
      addEpisode,
      idPrefix: 'stress-streak',
      label: 'Стресс',
      triggerLabel: 'стресс / нагрузка',
      value: (entry) => entry.stress,
      threshold: 8,
    );
  }

  static void _addMetricStreakEpisode(
    List<DiaryEntry> entries,
    void Function(DeteriorationEpisode episode) addEpisode, {
    required String idPrefix,
    required String label,
    required String triggerLabel,
    required int Function(DiaryEntry entry) value,
    int threshold = 7,
  }) {
    final streak = <DiaryEntry>[];

    void flush() {
      if (streak.length >= 2) {
        final first = streak.first;
        final last = streak.last;
        addEpisode(
          DeteriorationEpisode(
            id: '$idPrefix-${_dateKey(first.dateTime)}',
            startDate: first.dateTime,
            triggerReason:
                '$triggerLabel ≥ $threshold в течение ${streak.length} записей подряд',
            changedIndicators: [
              if (value(first) == value(last))
                '$label ${value(last)}/10'
              else
                '$label ${value(first)} → ${value(last)}',
            ],
            severity: value(last) >= 9 ? 'high' : 'warn',
          ),
        );
      }
      streak.clear();
    }

    for (final entry in entries) {
      if (value(entry) >= threshold) {
        streak.add(entry);
      } else {
        flush();
      }
    }
    flush();
  }

  static void _addDiaryTrendEpisodes(
    List<DiaryEntry> entries,
    void Function(DeteriorationEpisode episode) addEpisode,
  ) {
    if (entries.length < 4) return;
    DateTime? lastFatigueEpisode;
    DateTime? lastPainEpisode;
    DateTime? lastNumbnessEpisode;
    DateTime? lastCoordinationEpisode;
    DateTime? lastVisionEpisode;
    DateTime? lastWeaknessEpisode;
    DateTime? lastStressEpisode;
    DateTime? lastSleepEpisode;

    final days =
        entries
            .map(
              (e) =>
                  DateTime(e.dateTime.year, e.dateTime.month, e.dateTime.day),
            )
            .toSet()
            .toList()
          ..sort();

    for (final day in days) {
      final currentStart = day.subtract(const Duration(days: 6));
      final previousStart = day.subtract(const Duration(days: 13));
      final previousEnd = currentStart.subtract(const Duration(seconds: 1));
      final currentEnd = DateTime(day.year, day.month, day.day, 23, 59, 59);

      final current = _entriesBetween(entries, currentStart, currentEnd);
      final previous = _entriesBetween(entries, previousStart, previousEnd);
      if (current.isEmpty || previous.isEmpty) continue;

      final currentFatigue = mean(fatigueValues(current));
      final previousFatigue = mean(fatigueValues(previous));
      final fatigueChange = percentChange(currentFatigue, previousFatigue);
      if (fatigueChange != null &&
          fatigueChange >= 20 &&
          _canAddTrend(day, lastFatigueEpisode)) {
        lastFatigueEpisode = day;
        addEpisode(
          DeteriorationEpisode(
            id: 'fatigue-trend-${_dateKey(currentStart)}',
            startDate: currentStart,
            triggerReason:
                'Средняя усталость выросла на ${fatigueChange.round()}% к прошлой неделе',
            changedIndicators: [
              'Усталость ${_fmt(previousFatigue)} → ${_fmt(currentFatigue)}',
            ],
            severity: 'warn',
          ),
        );
      }

      final currentPain = mean(painValues(current));
      final previousPain = mean(painValues(previous));
      final painChange = percentChange(currentPain, previousPain);
      if (painChange != null &&
          painChange >= 20 &&
          _canAddTrend(day, lastPainEpisode)) {
        lastPainEpisode = day;
        addEpisode(
          DeteriorationEpisode(
            id: 'pain-trend-${_dateKey(currentStart)}',
            startDate: currentStart,
            triggerReason:
                'Средняя боль выросла на ${painChange.round()}% к прошлой неделе',
            changedIndicators: [
              'Боль ${_fmt(previousPain)} → ${_fmt(currentPain)}',
            ],
            severity: 'warn',
          ),
        );
      }

      lastNumbnessEpisode = _addMetricTrendEpisode(
        current: current,
        previous: previous,
        addEpisode: addEpisode,
        currentStart: currentStart,
        day: day,
        previousEpisodeDay: lastNumbnessEpisode,
        idPrefix: 'numbness-trend',
        label: 'Чувствительность',
        triggerLabel: 'Онемение / чувствительность',
        values: numbnessValues,
      );
      lastCoordinationEpisode = _addMetricTrendEpisode(
        current: current,
        previous: previous,
        addEpisode: addEpisode,
        currentStart: currentStart,
        day: day,
        previousEpisodeDay: lastCoordinationEpisode,
        idPrefix: 'coordination-trend',
        label: 'Координация',
        triggerLabel: 'Нарушение координации',
        values: coordinationValues,
      );
      lastVisionEpisode = _addMetricTrendEpisode(
        current: current,
        previous: previous,
        addEpisode: addEpisode,
        currentStart: currentStart,
        day: day,
        previousEpisodeDay: lastVisionEpisode,
        idPrefix: 'vision-trend',
        label: 'Зрение',
        triggerLabel: 'Зрительные симптомы',
        values: visionValues,
      );
      lastWeaknessEpisode = _addMetricTrendEpisode(
        current: current,
        previous: previous,
        addEpisode: addEpisode,
        currentStart: currentStart,
        day: day,
        previousEpisodeDay: lastWeaknessEpisode,
        idPrefix: 'weakness-trend',
        label: 'Слабость',
        triggerLabel: 'Мышечная слабость',
        values: weaknessValues,
      );
      lastStressEpisode = _addMetricTrendEpisode(
        current: current,
        previous: previous,
        addEpisode: addEpisode,
        currentStart: currentStart,
        day: day,
        previousEpisodeDay: lastStressEpisode,
        idPrefix: 'stress-trend',
        label: 'Стресс',
        triggerLabel: 'Стресс / нагрузка',
        values: stressValues,
      );

      final currentSleep = mean(sleepValues(current));
      final previousSleep = mean(sleepValues(previous));
      final sleepChange = percentChange(currentSleep, previousSleep);
      if (sleepChange != null &&
          sleepChange <= -15 &&
          (currentSleep ?? 0) < 6 &&
          _canAddTrend(day, lastSleepEpisode)) {
        lastSleepEpisode = day;
        addEpisode(
          DeteriorationEpisode(
            id: 'sleep-trend-${_dateKey(currentStart)}',
            startDate: currentStart,
            triggerReason: 'Сон снизился и среднее значение стало ниже 6 часов',
            changedIndicators: [
              'Сон ${_fmt(previousSleep)} → ${_fmt(currentSleep)} ч',
            ],
            severity: 'warn',
          ),
        );
      }
    }
  }

  static DateTime? _addMetricTrendEpisode({
    required List<DiaryEntry> current,
    required List<DiaryEntry> previous,
    required void Function(DeteriorationEpisode episode) addEpisode,
    required DateTime currentStart,
    required DateTime day,
    required DateTime? previousEpisodeDay,
    required String idPrefix,
    required String label,
    required String triggerLabel,
    required List<double> Function(List<DiaryEntry>) values,
  }) {
    final currentMean = mean(values(current));
    final previousMean = mean(values(previous));
    final change = percentChange(currentMean, previousMean);
    if (change == null ||
        change < 20 ||
        !_canAddTrend(day, previousEpisodeDay)) {
      return previousEpisodeDay;
    }
    addEpisode(
      DeteriorationEpisode(
        id: '$idPrefix-${_dateKey(currentStart)}',
        startDate: currentStart,
        triggerReason:
            'Показатель "$triggerLabel" вырос на ${change.round()}% к прошлой неделе',
        changedIndicators: [
          '$label ${_fmt(previousMean)} → ${_fmt(currentMean)}',
        ],
        severity: 'warn',
      ),
    );
    return day;
  }

  static void _addTestTrendEpisodes(
    List<TestResult> testResults,
    void Function(DeteriorationEpisode episode) addEpisode,
  ) {
    final sorted = List<TestResult>.from(testResults)
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    _addResultPairEpisodes(
      sorted.where((r) => r.type == TestType.reaction).toList(),
      addEpisode,
      idPrefix: 'reaction',
      trigger: 'Время реакции ухудшилось относительно прошлого теста',
      label: 'Реакция',
      unit: 'мс',
      worsened: (change) => change >= 15,
      severity: 'warn',
    );

    for (final hand in [TestHand.left, TestHand.right]) {
      final handLabel = hand == TestHand.left ? 'левая рука' : 'правая рука';
      _addResultPairEpisodes(
        sorted
            .where((r) => r.type == TestType.tapping && r.hand == hand)
            .toList(),
        addEpisode,
        idPrefix: 'tapping-$hand',
        trigger: 'Таппинг ($handLabel) снизился относительно прошлого теста',
        label: 'Таппинг, $handLabel',
        unit: 'уд/с',
        worsened: (change) => change <= -15,
        severity: 'warn',
      );
    }
  }

  static void _addResultPairEpisodes(
    List<TestResult> results,
    void Function(DeteriorationEpisode episode) addEpisode, {
    required String idPrefix,
    required String trigger,
    required String label,
    required String unit,
    required bool Function(double change) worsened,
    required String severity,
  }) {
    for (var i = 1; i < results.length; i++) {
      final previous = results[i - 1];
      final current = results[i];
      final change = percentChange(current.value, previous.value);
      if (change == null || !worsened(change)) continue;
      addEpisode(
        DeteriorationEpisode(
          id: '$idPrefix-${_dateKey(current.dateTime)}',
          startDate: current.dateTime,
          triggerReason: '$trigger (${change.abs().round()}%)',
          changedIndicators: [
            '$label ${_fmt(previous.value)} → ${_fmt(current.value)} $unit',
          ],
          severity: severity,
        ),
      );
    }
  }

  static List<DiaryEntry> _entriesBetween(
    List<DiaryEntry> entries,
    DateTime start,
    DateTime end,
  ) => entries
      .where((e) => !e.dateTime.isBefore(start) && !e.dateTime.isAfter(end))
      .toList();

  static bool _canAddTrend(DateTime day, DateTime? previousEpisodeDay) =>
      previousEpisodeDay == null ||
      day.difference(previousEpisodeDay).inDays >= 7;

  static List<String> _entrySnapshot(DiaryEntry entry) => [
    'Усталость ${entry.fatigue}/10',
    'Боль ${entry.pain}/10',
    'Настроение ${entry.mood}/10',
    'Чувствительность ${entry.numbness}/10',
    'Координация ${entry.coordination}/10',
    'Зрение ${entry.vision}/10',
    'Слабость ${entry.weakness}/10',
    'Стресс ${entry.stress}/10',
    'Сон ${entry.sleepHours.toStringAsFixed(1)} ч',
  ];

  static List<String> _changedIndicators(DiaryEntry first, DiaryEntry last) {
    final indicators = <String>[];
    if (first.fatigue != last.fatigue) {
      indicators.add('Усталость ${first.fatigue} → ${last.fatigue}');
    } else {
      indicators.add('Усталость ${last.fatigue}/10');
    }
    if (first.pain != last.pain) {
      indicators.add('Боль ${first.pain} → ${last.pain}');
    }
    if (first.mood != last.mood) {
      indicators.add('Настроение ${first.mood} → ${last.mood}');
    }
    if (first.numbness != last.numbness) {
      indicators.add('Чувствительность ${first.numbness} → ${last.numbness}');
    }
    if (first.coordination != last.coordination) {
      indicators.add(
        'Координация ${first.coordination} → ${last.coordination}',
      );
    }
    if (first.vision != last.vision) {
      indicators.add('Зрение ${first.vision} → ${last.vision}');
    }
    if (first.weakness != last.weakness) {
      indicators.add('Слабость ${first.weakness} → ${last.weakness}');
    }
    if (first.stress != last.stress) {
      indicators.add('Стресс ${first.stress} → ${last.stress}');
    }
    if ((first.sleepHours - last.sleepHours).abs() >= 0.1) {
      indicators.add(
        'Сон ${first.sleepHours.toStringAsFixed(1)} → ${last.sleepHours.toStringAsFixed(1)} ч',
      );
    }
    return indicators;
  }

  static String _dateKey(DateTime date) =>
      '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';

  static String _fmt(double? value) =>
      value == null ? '-' : value.toStringAsFixed(1);

  // ── Correlations ────────────────────────────────────────────────────────

  /// Pearson correlation coefficient. Returns null if fewer than 5 pairs.
  static double? pearsonCorrelation(List<double> x, List<double> y) {
    if (x.length != y.length || x.length < 5) return null;
    final n = x.length;
    final mx = mean(x)!;
    final my = mean(y)!;
    double num = 0, dx2 = 0, dy2 = 0;
    for (int i = 0; i < n; i++) {
      num += (x[i] - mx) * (y[i] - my);
      dx2 += (x[i] - mx) * (x[i] - mx);
      dy2 += (y[i] - my) * (y[i] - my);
    }
    final denom = math.sqrt(dx2 * dy2);
    if (denom == 0) return null;
    return (num / denom).clamp(-1.0, 1.0);
  }

  /// Spearman rank correlation. Returns null if fewer than 5 pairs.
  static double? spearmanCorrelation(List<double> x, List<double> y) {
    if (x.length != y.length || x.length < 5) return null;
    return pearsonCorrelation(_ranks(x), _ranks(y));
  }

  /// Computes average ranks (handles ties).
  static List<double> _ranks(List<double> values) {
    final indexed = List.generate(values.length, (i) => MapEntry(i, values[i]));
    indexed.sort((a, b) => a.value.compareTo(b.value));
    final ranks = List<double>.filled(values.length, 0);
    int i = 0;
    while (i < indexed.length) {
      int j = i;
      while (j < indexed.length - 1 &&
          indexed[j + 1].value == indexed[i].value) {
        j++;
      }
      final rank = (i + j + 2) / 2.0; // 1-based average rank
      for (int k = i; k <= j; k++) {
        ranks[indexed[k].key] = rank;
      }
      i = j + 1;
    }
    return ranks;
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  /// Human-readable interpretation of correlation strength.
  static String correlationLabel(double r) {
    final abs = r.abs();
    if (abs < 0.3) return 'слабая связь';
    if (abs < 0.5) return 'умеренная связь';
    return 'заметная связь';
  }

  /// Sign description.
  static String correlationSign(double r) {
    if (r > 0.05) return 'прямая';
    if (r < -0.05) return 'обратная';
    return 'нет связи';
  }
}
