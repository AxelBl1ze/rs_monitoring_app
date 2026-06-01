import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../widgets/nl_widgets.dart';
import '../models/test_result.dart';
import '../state/test_results_provider.dart';
import 'tapping_test_screen.dart';

// ─── Helpers ─────────────────────────────────────────────────────────────────

/// Average taps/sec for results in the 7-day window before the last 7 days.
double? _prevPeriodAvg(TestResultsProvider tests, {String? hand}) {
  final now = DateTime.now();
  final mid = now.subtract(const Duration(days: 7));
  final start = now.subtract(const Duration(days: 14));
  final subset = tests.results
      .where(
        (r) =>
            r.type == TestType.tapping &&
            (hand == null || r.hand == hand) &&
            !r.dateTime.isBefore(start) &&
            r.dateTime.isBefore(mid),
      )
      .toList();
  if (subset.isEmpty) return null;
  return subset.fold<double>(0, (s, r) => s + r.value) / subset.length;
}

double? _avgLastDays(TestResultsProvider tests, int days, {String? hand}) {
  final from = DateTime.now().subtract(Duration(days: days));
  final subset = tests.results
      .where(
        (r) =>
            r.type == TestType.tapping &&
            (hand == null || r.hand == hand) &&
            !r.dateTime.isBefore(from),
      )
      .toList();
  if (subset.isEmpty) return null;
  return subset.fold<double>(0, (s, r) => s + r.value) / subset.length;
}

List<TestResult> _latestByHand(
  TestResultsProvider tests,
  String hand, {
  int limit = 7,
}) {
  return tests.results
      .where((r) => r.type == TestType.tapping && r.hand == hand)
      .take(limit)
      .toList()
      .reversed
      .toList();
}

TestResult? _latestResultByHand(TestResultsProvider tests, String hand) {
  for (final result in tests.results) {
    if (result.type == TestType.tapping && result.hand == hand) {
      return result;
    }
  }
  return null;
}

String _handLabel(String hand) => hand == TestHand.left ? 'Левая' : 'Правая';

String _fmtRate(double? value) =>
    value == null ? '–' : value.toStringAsFixed(1);

/// Percent change between two averages. Returns null if either is missing/zero.
double? _percentChange(double? current, double? previous) {
  if (current == null || previous == null || previous == 0) return null;
  return (current - previous) / previous * 100;
}

/// Colored arrow badge for the change tile.
/// For tapping, positive change is good (more taps = better motor function).
Widget _changeBadge(double? pct) {
  if (pct == null) return const SizedBox.shrink();
  final isGood = pct >= 0;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: isGood ? NLColors.mintSoft : NLColors.roseSoft,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      isGood ? '↑' : '↓',
      style: TextStyle(
        color: isGood ? NLColors.good : NLColors.bad,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _HandDynamicsCard extends StatelessWidget {
  final String hand;
  final TestResultsProvider tests;

  const _HandDynamicsCard({required this.hand, required this.tests});

  @override
  Widget build(BuildContext context) {
    final entries = _latestByHand(tests, hand);
    final data = entries.map((r) => r.value).toList();
    final xLabels = entries.map((r) => '${r.dateTime.day}').toList();
    final latest = _latestResultByHand(tests, hand);
    final avg7 = _avgLastDays(tests, 7, hand: hand);
    final prev7 = _prevPeriodAvg(tests, hand: hand);
    final pct = _percentChange(avg7, prev7);
    final color = hand == TestHand.left ? NLColors.sky : NLColors.accent;
    final tinted = hand == TestHand.left
        ? NLColors.skySoft
        : NLColors.accentSoft;

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
                  '${_handLabel(hand)} рука',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: NLColors.ink,
                  ),
                ),
              ),
              _changeBadge(pct),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _InlineMetric(
                  label: 'Последний',
                  value: _fmtRate(latest?.value),
                  unit: 'уд/с',
                ),
              ),
              Expanded(
                child: _InlineMetric(
                  label: 'Среднее 7д',
                  value: _fmtRate(avg7),
                  unit: 'уд/с',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (data.length >= 2)
            NLChart(
              data: data,
              threshold: 5.0,
              height: 110,
              color: color,
              tinted: tinted,
              xLabels: xLabels,
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'Недостаточно данных для графика по этой руке',
                style: TextStyle(fontSize: 13, color: NLColors.muted),
              ),
            ),
        ],
      ),
    );
  }
}

class _InlineMetric extends StatelessWidget {
  final String label;
  final String value;
  final String unit;

  const _InlineMetric({
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            color: NLColors.muted,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 3),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: NLColors.ink,
              ),
            ),
            const SizedBox(width: 3),
            Text(
              unit,
              style: const TextStyle(
                fontSize: 12,
                color: NLColors.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class TappingResultScreen extends StatelessWidget {
  const TappingResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tests = context.watch<TestResultsProvider>();
    final current = tests.latestTappingResult;

    // Total taps for current result (value is stored as taps/sec)
    final totalTaps = current != null
        ? (current.value * current.durationSeconds).round()
        : 0;

    // 7-day average in taps/sec → convert to total taps for display
    final avg7 = tests.averageLastDays(TestType.tapping, 7);
    final avg7Taps = avg7 != null ? (avg7 * 10).round() : null;

    // Percent change vs previous 7-day window
    final prev7 = _prevPeriodAvg(tests);
    final pct = _percentChange(avg7, prev7);
    final pctStr = pct != null ? '${pct >= 0 ? '+' : ''}${pct.round()}%' : '–';

    final currentHand = current?.hand;
    final currentHandAvg7 = currentHand != null
        ? _avgLastDays(tests, 7, hand: currentHand)
        : null;
    final currentHandAvg7Taps = currentHandAvg7 != null
        ? (currentHandAvg7 * 10).round()
        : null;
    final currentHandPrev7 = currentHand != null
        ? _prevPeriodAvg(tests, hand: currentHand)
        : null;
    final currentHandPct = _percentChange(currentHandAvg7, currentHandPrev7);
    final currentHandPctStr = currentHandPct != null
        ? '${currentHandPct >= 0 ? '+' : ''}${currentHandPct.round()}%'
        : '–';

    return Scaffold(
      backgroundColor: NLColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            NLTopBar(
              leading: NLBackBtn(),
              title: 'Результат',
              trailing: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                behavior: HitTestBehavior.opaque,
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Готово',
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(fontSize: 14, color: NLColors.muted),
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  children: [
                    const SizedBox(height: 18),
                    // Ring + total taps
                    SizedBox(
                      height: 180,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          NLRing(
                            value: totalTaps.toDouble(),
                            max: 80,
                            size: 180,
                            stroke: 14,
                            color: NLColors.accent,
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$totalTaps',
                                style: const TextStyle(
                                  fontSize: 56,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -2,
                                  color: NLColors.ink,
                                  height: 1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'нажатий за ${current?.durationSeconds ?? 10} сек',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: NLColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    // Summary tiles
                    Row(
                      children: [
                        Expanded(
                          child: NLTile(
                            label: currentHand == null
                                ? 'Среднее (7д)'
                                : '${_handLabel(currentHand)} (7д)',
                            value: currentHand == null
                                ? (avg7Taps != null ? '$avg7Taps' : '–')
                                : (currentHandAvg7Taps != null
                                      ? '$currentHandAvg7Taps'
                                      : '–'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: NLTile(
                            label: currentHand == null
                                ? 'Изменение'
                                : 'Изм. руки',
                            value: currentHand == null
                                ? pctStr
                                : currentHandPctStr,
                            badge: _changeBadge(
                              currentHand == null ? pct : currentHandPct,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const NLSectionTitle('Динамика по рукам'),
                    _HandDynamicsCard(hand: TestHand.left, tests: tests),
                    const SizedBox(height: 10),
                    _HandDynamicsCard(hand: TestHand.right, tests: tests),
                    const SizedBox(height: 18),
                    NLButton(
                      label: 'Повторить тест',
                      full: true,
                      onTap: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => const TappingTestScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
