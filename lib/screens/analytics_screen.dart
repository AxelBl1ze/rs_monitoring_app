import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../widgets/nl_widgets.dart';
import '../state/diary_provider.dart';
import '../state/test_results_provider.dart';
import '../models/diary_entry.dart';
import '../models/test_result.dart';
import '../services/analytics_service.dart';
import 'export_screen.dart';
import 'signals_screen.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NLColors.bg,
      body: SafeArea(bottom: false, child: const AnalyticsBody()),
    );
  }
}

class AnalyticsBody extends StatefulWidget {
  const AnalyticsBody({super.key});

  @override
  State<AnalyticsBody> createState() => _AnalyticsBodyState();
}

class _AnalyticsBodyState extends State<AnalyticsBody> {
  String _period = '7 дней';

  int get _days => _period == '7 дней'
      ? 7
      : _period == '30 дней'
      ? 30
      : 90;

  // Entries for current period sorted oldest→newest.
  List<DiaryEntry> _currentEntries(DiaryProvider diary) {
    final e = AnalyticsService.entriesForLastDays(
      diary.diaryEntriesSorted,
      _days,
    );
    return e..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  // Entries for the previous equal-length window sorted oldest→newest.
  List<DiaryEntry> _prevEntries(DiaryProvider diary) {
    final e = AnalyticsService.entriesForPreviousDays(
      diary.diaryEntriesSorted,
      _days,
    );
    return e..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  // Up to 7 evenly-spaced x-axis date labels for the chart.
  List<String>? _xLabels(List<DiaryEntry> sorted) {
    if (sorted.length < 2) return null;
    if (sorted.length <= 7) {
      return sorted.map((e) => '${e.dateTime.day}').toList();
    }
    const maxLabels = 5;
    final n = sorted.length;
    final step = (n - 1) / (maxLabels - 1);
    return List.generate(maxLabels, (i) {
      final idx = (i * step).round().clamp(0, n - 1);
      return '${sorted[idx].dateTime.day}';
    });
  }

  String _fmt(double? v, {int decimals = 1}) =>
      v != null ? v.toStringAsFixed(decimals) : '-';

  List<TestResult> _currentTests(
    TestResultsProvider tests,
    String type, {
    String? hand,
  }) {
    final from = DateTime.now().subtract(Duration(days: _days - 1));
    final start = DateTime(from.year, from.month, from.day);
    final results = tests.results
        .where(
          (r) =>
              r.type == type &&
              (hand == null || r.hand == hand) &&
              !r.dateTime.isBefore(start),
        )
        .toList();
    return results..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  DateTime _periodStart() {
    final from = DateTime.now().subtract(Duration(days: _days - 1));
    return DateTime(from.year, from.month, from.day);
  }

  List<TestResult> _prevTests(
    TestResultsProvider tests,
    String type, {
    String? hand,
  }) {
    final now = DateTime.now();
    final windowEnd = now.subtract(Duration(days: _days));
    final windowStart = now.subtract(Duration(days: _days * 2));
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
    final results = tests.results
        .where(
          (r) =>
              r.type == type &&
              (hand == null || r.hand == hand) &&
              !r.dateTime.isBefore(start) &&
              !r.dateTime.isAfter(end),
        )
        .toList();
    return results..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  List<String>? _testXLabels(List<TestResult> sorted) {
    if (sorted.length < 2) return null;
    if (sorted.length <= 7) {
      return sorted.map((r) => '${r.dateTime.day}').toList();
    }
    const maxLabels = 5;
    final n = sorted.length;
    final step = (n - 1) / (maxLabels - 1);
    return List.generate(maxLabels, (i) {
      final idx = (i * step).round().clamp(0, n - 1);
      return '${sorted[idx].dateTime.day}';
    });
  }

  double _chartMax(List<double> values) {
    if (values.isEmpty) return 10;
    final max = AnalyticsService.maxValue(values) ?? 10;
    return (max * 1.15).clamp(10, double.infinity).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final diary = context.watch<DiaryProvider>();
    final tests = context.watch<TestResultsProvider>();
    final current = _currentEntries(diary);
    final prev = _prevEntries(diary);
    final indexPrediction = AnalyticsService.predictNextCompositeIndex(current);

    final fatigueVals = AnalyticsService.fatigueValues(current);
    final painVals = AnalyticsService.painValues(current);
    final moodVals = AnalyticsService.moodValues(current);
    final numbnessVals = AnalyticsService.numbnessValues(current);
    final coordinationVals = AnalyticsService.coordinationValues(current);
    final visionVals = AnalyticsService.visionValues(current);
    final weaknessVals = AnalyticsService.weaknessValues(current);
    final stressVals = AnalyticsService.stressValues(current);

    final fatigueMean = AnalyticsService.mean(fatigueVals);
    final fatigueMedian = AnalyticsService.median(fatigueVals);
    final painMean = AnalyticsService.mean(painVals);
    final painSd = AnalyticsService.standardDeviation(painVals);
    final moodMean = AnalyticsService.mean(moodVals);
    final moodSd = AnalyticsService.standardDeviation(moodVals);

    final prevFatigueMean = AnalyticsService.mean(
      AnalyticsService.fatigueValues(prev),
    );
    final prevPainMean = AnalyticsService.mean(
      AnalyticsService.painValues(prev),
    );
    final prevMoodMean = AnalyticsService.mean(
      AnalyticsService.moodValues(prev),
    );
    final prevNumbnessVals = AnalyticsService.numbnessValues(prev);
    final prevCoordinationVals = AnalyticsService.coordinationValues(prev);
    final prevVisionVals = AnalyticsService.visionValues(prev);
    final prevWeaknessVals = AnalyticsService.weaknessValues(prev);
    final prevStressVals = AnalyticsService.stressValues(prev);

    final fatigueDelta = AnalyticsService.percentChange(
      fatigueMean,
      prevFatigueMean,
    );
    final painDelta = AnalyticsService.percentChange(painMean, prevPainMean);
    final moodDelta = AnalyticsService.percentChange(moodMean, prevMoodMean);

    // Comparison section uses fatigue as the primary metric.
    final compPrev = prevFatigueMean;
    final compCurrent = fatigueMean;
    final compDeltaAbs = (compCurrent != null && compPrev != null)
        ? compCurrent - compPrev
        : null;

    final leftTapping = _currentTests(
      tests,
      TestType.tapping,
      hand: TestHand.left,
    );
    final rightTapping = _currentTests(
      tests,
      TestType.tapping,
      hand: TestHand.right,
    );
    final reaction = _currentTests(tests, TestType.reaction);
    final hasDiaryData = current.isNotEmpty;
    final hasTestData =
        leftTapping.isNotEmpty ||
        rightTapping.isNotEmpty ||
        reaction.isNotEmpty;
    final hasData = hasDiaryData || hasTestData;
    final episodes = AnalyticsService.generateDeteriorationEpisodes(
      diary.diaryEntriesSorted,
      tests.results,
    ).where((episode) => !episode.startDate.isBefore(_periodStart())).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NLHeader(
            greeting: 'Анализ',
            title: 'Динамика',
            actions: [
              const SizedBox(width: 8),
              NLCircleBtn(
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const ExportScreen())),
                child: const Icon(
                  Icons.download_outlined,
                  color: NLColors.ink,
                  size: 18,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NLSegmented(
                  items: const ['7 дней', '30 дней', '90 дней'],
                  active: _period,
                  onChange: (v) => setState(() => _period = v),
                ),
                const SizedBox(height: 14),

                if (!hasData)
                  NLCard(
                    child: Column(
                      children: const [
                        Icon(
                          Icons.bar_chart_rounded,
                          size: 36,
                          color: NLColors.muted,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Недостаточно данных для анализа',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: NLColors.ink,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Добавьте записи в дневник или пройдите тест',
                          style: TextStyle(fontSize: 13, color: NLColors.muted),
                        ),
                      ],
                    ),
                  )
                else ...[
                  if (hasDiaryData) ...[
                    const NLSectionTitle('Прогноз состояния'),
                    _HealthIndexForecastCard(
                      prediction: indexPrediction,
                      entriesCount: current.length,
                    ),
                    const SizedBox(height: 12),

                    // Усталость
                    NLCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: const BoxDecoration(
                                            color: NLColors.peach,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Усталость',
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w600,
                                            color: NLColors.ink,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Среднее ${_fmt(fatigueMean)} · медиана ${_fmt(fatigueMedian)}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: NLColors.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (fatigueDelta != null)
                                NLStat(delta: fatigueDelta.round()),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (fatigueVals.length >= 2)
                            NLChart(
                              data: fatigueVals,
                              threshold: 7,
                              color: NLColors.peach,
                              tinted: NLColors.peachSoft,
                              height: 120,
                              xLabels: _xLabels(current),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Боль
                    NLCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: const BoxDecoration(
                                            color: NLColors.rose,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Боль',
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w600,
                                            color: NLColors.ink,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Среднее ${_fmt(painMean)} · σ ${_fmt(painSd)}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: NLColors.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (painDelta != null)
                                NLStat(delta: painDelta.round()),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (painVals.length >= 2)
                            NLChart(
                              data: painVals,
                              color: NLColors.rose,
                              tinted: NLColors.roseSoft,
                              height: 100,
                              xLabels: _xLabels(current),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Настроение
                    NLCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: const BoxDecoration(
                                            color: NLColors.accent,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Настроение',
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w600,
                                            color: NLColors.ink,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Среднее ${_fmt(moodMean)} · σ ${_fmt(moodSd)}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: NLColors.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Negate: mood increase is good, NLStat treats positive as bad.
                              if (moodDelta != null)
                                NLStat(delta: (-moodDelta).round()),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (moodVals.length >= 2)
                            NLChart(
                              data: moodVals,
                              color: NLColors.accent,
                              tinted: NLColors.accentSoft,
                              height: 100,
                              xLabels: _xLabels(current),
                            ),
                        ],
                      ),
                    ),

                    const NLSectionTitle('РС-симптомы'),
                    _DiaryMetricTrendCard(
                      title: 'Онемение / чувствительность',
                      subtitle: 'Сенсорные изменения',
                      values: numbnessVals,
                      previousValues: prevNumbnessVals,
                      xLabels: _xLabels(current),
                      color: NLColors.mint,
                      tinted: NLColors.mintSoft,
                      threshold: 7,
                    ),
                    const SizedBox(height: 12),
                    _DiaryMetricTrendCard(
                      title: 'Нарушение координации',
                      subtitle: 'Баланс и точность движений',
                      values: coordinationVals,
                      previousValues: prevCoordinationVals,
                      xLabels: _xLabels(current),
                      color: NLColors.sky,
                      tinted: NLColors.skySoft,
                      threshold: 7,
                    ),
                    const SizedBox(height: 12),
                    _DiaryMetricTrendCard(
                      title: 'Зрительные симптомы',
                      subtitle: 'Зрение и зрительный дискомфорт',
                      values: visionVals,
                      previousValues: prevVisionVals,
                      xLabels: _xLabels(current),
                      color: NLColors.accent,
                      tinted: NLColors.accentSoft,
                      threshold: 7,
                    ),
                    const SizedBox(height: 12),
                    _DiaryMetricTrendCard(
                      title: 'Мышечная слабость',
                      subtitle: 'Сила и выносливость мышц',
                      values: weaknessVals,
                      previousValues: prevWeaknessVals,
                      xLabels: _xLabels(current),
                      color: NLColors.peach,
                      tinted: NLColors.peachSoft,
                      threshold: 7,
                    ),
                    const SizedBox(height: 12),
                    _DiaryMetricTrendCard(
                      title: 'Стресс / нагрузка за день',
                      subtitle: 'Фактор, который может усиливать симптомы',
                      values: stressVals,
                      previousValues: prevStressVals,
                      xLabels: _xLabels(current),
                      color: NLColors.rose,
                      tinted: NLColors.roseSoft,
                      threshold: 8,
                    ),

                    const NLSectionTitle('Сравнение окон'),
                    NLCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Прошлые $_days дней',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: NLColors.muted,
                                ),
                              ),
                              Text(
                                _fmt(compPrev),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: NLColors.ink,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Последние $_days дней',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: NLColors.muted,
                                ),
                              ),
                              Text(
                                _fmt(compCurrent),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: NLColors.ink,
                                ),
                              ),
                            ],
                          ),
                          const NLDivider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Δ среднее (усталость)',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: NLColors.ink,
                                ),
                              ),
                              Text(
                                compDeltaAbs != null && fatigueDelta != null
                                    ? '${compDeltaAbs >= 0 ? '+' : ''}${_fmt(compDeltaAbs)} · ${fatigueDelta >= 0 ? '+' : ''}${fatigueDelta.round()}%'
                                    : '-',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color:
                                      compDeltaAbs != null && compDeltaAbs > 0
                                      ? NLColors.bad
                                      : NLColors.good,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  const NLSectionTitle('Эпизоды ухудшения'),
                  _EpisodesPreviewCard(
                    episodes: episodes,
                    onOpenAll: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            const SignalsScreen(initialTab: 'Эпизоды'),
                      ),
                    ),
                  ),
                  if (hasTestData) ...[
                    const NLSectionTitle('Результаты тестов'),
                    if (leftTapping.isNotEmpty) ...[
                      _TestTrendCard(
                        title: 'Таппинг · левая рука',
                        valueLabel: 'уд/с',
                        values: leftTapping.map((r) => r.value).toList(),
                        previousValues: _prevTests(
                          tests,
                          TestType.tapping,
                          hand: TestHand.left,
                        ).map((r) => r.value).toList(),
                        xLabels: _testXLabels(leftTapping),
                        color: NLColors.sky,
                        tinted: NLColors.skySoft,
                        threshold: 5.0,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (rightTapping.isNotEmpty) ...[
                      _TestTrendCard(
                        title: 'Таппинг · правая рука',
                        valueLabel: 'уд/с',
                        values: rightTapping.map((r) => r.value).toList(),
                        previousValues: _prevTests(
                          tests,
                          TestType.tapping,
                          hand: TestHand.right,
                        ).map((r) => r.value).toList(),
                        xLabels: _testXLabels(rightTapping),
                        color: NLColors.accent,
                        tinted: NLColors.accentSoft,
                        threshold: 5.0,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (reaction.isNotEmpty)
                      _TestTrendCard(
                        title: 'Реакция',
                        valueLabel: 'мс',
                        values: reaction.map((r) => r.value).toList(),
                        previousValues: _prevTests(
                          tests,
                          TestType.reaction,
                        ).map((r) => r.value).toList(),
                        xLabels: _testXLabels(reaction),
                        color: NLColors.mint,
                        tinted: NLColors.mintSoft,
                        maxY: _chartMax(reaction.map((r) => r.value).toList()),
                        positiveIsGood: false,
                      ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthIndexForecastCard extends StatelessWidget {
  final HealthIndexPrediction? prediction;
  final int entriesCount;

  const _HealthIndexForecastCard({
    required this.prediction,
    required this.entriesCount,
  });

  Color _indexColor(int index) {
    if (index >= 70) return NLColors.good;
    if (index >= 45) return NLColors.warn;
    return NLColors.bad;
  }

  String _indexLabel(int index) {
    if (index >= 70) return 'Хорошее';
    if (index >= 45) return 'Умеренное';
    return 'Требует внимания';
  }

  String _signed(double value) =>
      '${value > 0 ? '+' : ''}${value.toStringAsFixed(1)}';

  @override
  Widget build(BuildContext context) {
    final prediction = this.prediction;
    if (prediction == null) {
      return NLCard(
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: NLColors.accentSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.timeline_rounded,
                size: 22,
                color: NLColors.accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Прогноз появится позже',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: NLColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Линейная регрессия требует минимум 3 записи · сейчас $entriesCount',
                    style: const TextStyle(
                      fontSize: 12,
                      color: NLColors.muted,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final color = _indexColor(prediction.predictedIndex);
    final trendIsStable = prediction.slopePerEntry.abs() < 0.4;
    final trendColor = trendIsStable
        ? NLColors.muted
        : prediction.slopePerEntry > 0
        ? NLColors.good
        : NLColors.bad;
    final trendBg = trendIsStable
        ? NLColors.surface2
        : prediction.slopePerEntry > 0
        ? NLColors.mintSoft
        : NLColors.roseSoft;
    final trendLabel = trendIsStable
        ? 'Стабильно'
        : prediction.slopePerEntry > 0
        ? 'Рост'
        : 'Снижение';
    final chartData = [
      ...prediction.observedIndices.map((index) => index / 10),
      prediction.predictedIndex / 10,
    ];

    return NLCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Следующий health index',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: NLColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Линейная регрессия · ${prediction.sampleCount} записей · R² ${(prediction.rSquared * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 13,
                        color: NLColors.muted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: trendBg,
                  borderRadius: BorderRadius.all(NLRadius.pill),
                ),
                child: Text(
                  trendLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: trendColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${prediction.predictedIndex}',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1,
                  color: color,
                  height: 0.95,
                ),
              ),
              const SizedBox(width: 4),
              const Padding(
                padding: EdgeInsets.only(bottom: 5),
                child: Text(
                  '/100',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: NLColors.muted,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _indexLabel(prediction.predictedIndex),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'последний ${prediction.latestIndex} · ${_signed(prediction.slopePerEntry)} п/запись',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 12,
                        color: NLColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          NLChart(
            data: chartData,
            threshold: 5,
            color: color,
            tinted: color.withValues(alpha: 0.14),
            height: 100,
            maxY: 10,
          ),
        ],
      ),
    );
  }
}

class _TestTrendCard extends StatelessWidget {
  final String title;
  final String valueLabel;
  final List<double> values;
  final List<double> previousValues;
  final List<String>? xLabels;
  final Color color;
  final Color tinted;
  final double? threshold;
  final double maxY;
  final bool positiveIsGood;

  const _TestTrendCard({
    required this.title,
    required this.valueLabel,
    required this.values,
    required this.previousValues,
    required this.xLabels,
    required this.color,
    required this.tinted,
    this.threshold,
    this.maxY = 10,
    this.positiveIsGood = true,
  });

  String _fmt(double? v) => v == null ? '-' : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final mean = AnalyticsService.mean(values);
    final previousMean = AnalyticsService.mean(previousValues);
    final delta = AnalyticsService.percentChange(mean, previousMean);

    return NLCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: NLColors.ink,
                  ),
                ),
              ),
              if (delta != null)
                _ChangePill(delta: delta, positiveIsGood: positiveIsGood),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Среднее ${_fmt(mean)} $valueLabel · ${values.length} изм.',
            style: const TextStyle(fontSize: 13, color: NLColors.muted),
          ),
          const SizedBox(height: 12),
          if (values.length >= 2)
            NLChart(
              data: values,
              threshold: threshold,
              color: color,
              tinted: tinted,
              height: 110,
              xLabels: xLabels,
              maxY: maxY,
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'Недостаточно измерений для графика',
                style: TextStyle(fontSize: 13, color: NLColors.muted),
              ),
            ),
        ],
      ),
    );
  }
}

class _DiaryMetricTrendCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<double> values;
  final List<double> previousValues;
  final List<String>? xLabels;
  final Color color;
  final Color tinted;
  final double threshold;

  const _DiaryMetricTrendCard({
    required this.title,
    required this.subtitle,
    required this.values,
    required this.previousValues,
    required this.xLabels,
    required this.color,
    required this.tinted,
    required this.threshold,
  });

  String _fmt(double? v) => v == null ? '-' : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final mean = AnalyticsService.mean(values);
    final previousMean = AnalyticsService.mean(previousValues);
    final delta = AnalyticsService.percentChange(mean, previousMean);
    final max = AnalyticsService.maxValue(values);
    final sd = AnalyticsService.standardDeviation(values);

    return NLCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 7),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: NLColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$subtitle · среднее ${_fmt(mean)} · максимум ${_fmt(max)} · σ ${_fmt(sd)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: NLColors.muted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (delta != null)
                _ChangePill(delta: delta, positiveIsGood: false),
            ],
          ),
          const SizedBox(height: 12),
          if (values.length >= 2)
            NLChart(
              data: values,
              threshold: threshold,
              color: color,
              tinted: tinted,
              height: 100,
              xLabels: xLabels,
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'Недостаточно записей для графика',
                style: TextStyle(fontSize: 13, color: NLColors.muted),
              ),
            ),
        ],
      ),
    );
  }
}

class _EpisodesPreviewCard extends StatelessWidget {
  final List<DeteriorationEpisode> episodes;
  final VoidCallback onOpenAll;

  const _EpisodesPreviewCard({required this.episodes, required this.onOpenAll});

  @override
  Widget build(BuildContext context) {
    if (episodes.isEmpty) {
      return NLCard(
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: NLColors.mintSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                size: 22,
                color: NLColors.good,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'За период эпизодов нет',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: NLColors.ink,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'История появится при заметных изменениях показателей.',
                    style: TextStyle(fontSize: 12, color: NLColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final preview = episodes.take(3).toList();
    return NLCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${episodes.length} ${_episodeWord(episodes.length)} за период',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: NLColors.ink,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onOpenAll,
                behavior: HitTestBehavior.opaque,
                child: const Text(
                  'Все',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: NLColors.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...preview.asMap().entries.map((entry) {
            final index = entry.key;
            final episode = entry.value;
            return _EpisodePreviewRow(
              episode: episode,
              last: index == preview.length - 1,
            );
          }),
        ],
      ),
    );
  }
}

class _EpisodePreviewRow extends StatelessWidget {
  final DeteriorationEpisode episode;
  final bool last;

  const _EpisodePreviewRow({required this.episode, required this.last});

  @override
  Widget build(BuildContext context) {
    final isHigh = episode.severity == 'high';
    final color = isHigh ? NLColors.bad : NLColors.warn;

    return Container(
      padding: EdgeInsets.only(bottom: last ? 0 : 12),
      margin: EdgeInsets.only(bottom: last ? 0 : 12),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: NLColors.line2, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 7),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_formatEpisodeDate(episode.startDate)} · ${episode.triggerReason}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: NLColors.ink,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  episode.changedIndicators.join(' · '),
                  style: const TextStyle(
                    fontSize: 12,
                    color: NLColors.muted,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Врачу: ${episode.sentToDoctor ? 'отправлено' : 'не отправлено'} · '
                  '${episode.doctorComment ?? 'комментария пока нет'}',
                  style: const TextStyle(fontSize: 12, color: NLColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatEpisodeDate(DateTime dt) {
  const months = [
    'янв',
    'фев',
    'мар',
    'апр',
    'май',
    'июн',
    'июл',
    'авг',
    'сен',
    'окт',
    'ноя',
    'дек',
  ];
  return '${dt.day} ${months[dt.month - 1]}';
}

String _episodeWord(int count) {
  final mod10 = count % 10;
  final mod100 = count % 100;
  if (mod10 == 1 && mod100 != 11) return 'эпизод';
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
    return 'эпизода';
  }
  return 'эпизодов';
}

class _ChangePill extends StatelessWidget {
  final double delta;
  final bool positiveIsGood;

  const _ChangePill({required this.delta, required this.positiveIsGood});

  @override
  Widget build(BuildContext context) {
    final isUp = delta > 0;
    final isGood = delta == 0 ? false : isUp == positiveIsGood;
    final bg = delta == 0
        ? NLColors.surface2
        : isGood
        ? NLColors.mintSoft
        : NLColors.roseSoft;
    final fg = delta == 0
        ? NLColors.muted
        : isGood
        ? NLColors.good
        : NLColors.bad;
    final arrow = isUp
        ? '↑'
        : delta < 0
        ? '↓'
        : '–';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.all(NLRadius.pill),
      ),
      child: Text(
        '$arrow ${delta.abs().round()}%',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}
