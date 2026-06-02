import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../app_theme.dart';
import '../widgets/nl_widgets.dart';
import '../state/profile_provider.dart';
import '../state/diary_provider.dart';
import '../state/test_results_provider.dart';
import '../models/test_result.dart';
import '../services/analytics_service.dart';
import '../services/export_service.dart';

enum _ExportFormat { csv, pdf }

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  String _period = '30 дн';
  bool _diary = true;
  bool _tests = true;
  bool _analytics = true;
  bool _signals = true;
  bool _loading = false;
  _ExportFormat _format = _ExportFormat.csv;

  int? get _periodDays => _period == '7 дн'
      ? 7
      : _period == '30 дн'
      ? 30
      : null;

  String get _periodLabel => _period == '7 дн'
      ? '7 дней'
      : _period == '30 дн'
      ? '30 дней'
      : 'Все данные';

  String _fmtShortDate(DateTime dt) {
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

  Rect _sharePositionOrigin(BuildContext context) {
    final renderObject = context.findRenderObject();
    if (renderObject is RenderBox &&
        renderObject.hasSize &&
        !renderObject.size.isEmpty) {
      return renderObject.localToGlobal(Offset.zero) & renderObject.size;
    }

    final screenSize = MediaQuery.sizeOf(context);
    return Rect.fromLTWH(screenSize.width / 2, screenSize.height / 2, 1, 1);
  }

  Future<void> _export(BuildContext context, BuildContext shareContext) async {
    final profile = context.read<ProfileProvider>().profile;
    final allDiary = context.read<DiaryProvider>().diaryEntriesSorted;
    final allTests = context.read<TestResultsProvider>().results;
    final sharePositionOrigin = _sharePositionOrigin(shareContext);

    final filteredDiary = ExportService.filterDiaryByPeriod(
      allDiary,
      _periodDays,
    );
    final filteredTests = ExportService.filterTestsByPeriod(
      allTests,
      _periodDays,
    );

    // Always export all filtered data so the analytics summary is complete.
    // The include toggles control the section counts shown to the user.
    setState(() => _loading = true);
    // Capture messenger before any async gap to satisfy context safety rules.
    final messenger = ScaffoldMessenger.of(context);
    try {
      final file = _format == _ExportFormat.pdf
          ? await ExportService.exportPdf(
              profile: profile,
              diaryEntries: filteredDiary,
              testResults: filteredTests,
              periodLabel: _periodLabel,
            )
          : await ExportService.exportCsv(
              profile: profile,
              diaryEntries: filteredDiary,
              testResults: filteredTests,
              periodLabel: _periodLabel,
            );
      await Share.shareXFiles(
        [
          XFile.fromData(
            file.bytes,
            name: file.filename,
            mimeType: file.mimeType,
          ),
        ],
        text: _format == _ExportFormat.pdf
            ? 'NeuroLife — PDF-отчёт пациента'
            : 'NeuroLife — отчёт пациента',
        sharePositionOrigin: sharePositionOrigin,
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Ошибка экспорта: $e'),
          backgroundColor: NLColors.bad,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final diary = context.watch<DiaryProvider>();
    final tests = context.watch<TestResultsProvider>();

    final filteredDiary = ExportService.filterDiaryByPeriod(
      diary.diaryEntriesSorted,
      _periodDays,
    );
    final filteredTests = ExportService.filterTestsByPeriod(
      tests.results,
      _periodDays,
    );

    final tappingCount = filteredTests
        .where((r) => r.type == TestType.tapping)
        .length;
    final reactionCount = filteredTests
        .where((r) => r.type == TestType.reaction)
        .length;
    final signalCount = AnalyticsService.generateSignals(
      filteredDiary,
      filteredTests,
    ).length;

    final now = DateTime.now();
    final from = _periodDays != null
        ? now.subtract(Duration(days: _periodDays! - 1))
        : null;

    // Earliest entry date for 'Всё' period.
    DateTime? earliestDate;
    if (_periodDays == null) {
      final allDates = [
        ...diary.diaryEntriesSorted.map((e) => e.dateTime),
        ...tests.results.map((r) => r.dateTime),
      ];
      if (allDates.isNotEmpty) {
        earliestDate = allDates.reduce((a, b) => a.isBefore(b) ? a : b);
      }
    }

    final dateFrom = from ?? earliestDate;

    return Scaffold(
      backgroundColor: NLColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NLTopBar(leading: NLBackBtn(), title: 'Экспорт данных'),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Отчёт для врача',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.8,
                        color: NLColors.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Готовый файл с дневником и тестами',
                      style: TextStyle(
                        fontSize: 14,
                        color: NLColors.muted,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Period
                    NLCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Период',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: NLColors.ink,
                            ),
                          ),
                          const SizedBox(height: 12),
                          NLSegmented(
                            items: const ['7 дн', '30 дн', 'Всё'],
                            active: _period,
                            onChange: (v) => setState(() => _period = v),
                          ),
                          const NLDivider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                dateFrom != null
                                    ? 'С ${_fmtShortDate(dateFrom)}'
                                    : 'Все записи',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: NLColors.muted,
                                ),
                              ),
                              Text(
                                'по ${_fmtShortDate(now)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: NLColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Include toggles with real counts
                    NLCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Включить',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: NLColors.ink,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _IncludeRow(
                            label: 'Записи дневника',
                            sub: filteredDiary.isEmpty
                                ? 'Нет записей'
                                : '${filteredDiary.length} записей',
                            value: _diary,
                            onChanged: (v) => setState(() => _diary = v),
                          ),
                          _IncludeRow(
                            label: 'Результаты тестов',
                            sub: filteredTests.isEmpty
                                ? 'Нет данных'
                                : 'Таппинг $tappingCount · Реакция $reactionCount',
                            value: _tests,
                            onChanged: (v) => setState(() => _tests = v),
                          ),
                          _IncludeRow(
                            label: 'Аналитика и сводка',
                            sub: 'Средние показатели за период',
                            value: _analytics,
                            onChanged: (v) => setState(() => _analytics = v),
                          ),
                          _IncludeRow(
                            label: 'Сигналы и инсайты',
                            sub: signalCount == 0
                                ? 'Активных сигналов нет'
                                : '$signalCount активных сигналов',
                            value: _signals,
                            onChanged: (v) => setState(() => _signals = v),
                            last: true,
                          ),
                        ],
                      ),
                    ),

                    const NLSectionTitle('Формат'),
                    Row(
                      children: [
                        Expanded(
                          child: _FormatCard(
                            label: 'CSV',
                            sub: 'Таблица · UTF-8',
                            icon: Icons.table_chart_outlined,
                            selected: _format == _ExportFormat.csv,
                            onTap: () =>
                                setState(() => _format = _ExportFormat.csv),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _FormatCard(
                            label: 'PDF',
                            sub: 'Документ · PDF',
                            icon: Icons.picture_as_pdf_outlined,
                            selected: _format == _ExportFormat.pdf,
                            onTap: () =>
                                setState(() => _format = _ExportFormat.pdf),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    Builder(
                      builder: (shareContext) => NLButton(
                        label: _loading ? 'Формирую...' : 'Сформировать отчёт',
                        full: true,
                        icon: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.download_outlined,
                                size: 18,
                                color: Colors.white,
                              ),
                        onTap: _loading
                            ? null
                            : () => _export(context, shareContext),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IncludeRow extends StatelessWidget {
  final String label;
  final String sub;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool last;

  const _IncludeRow({
    required this.label,
    required this.sub,
    required this.value,
    required this.onChanged,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: NLColors.line2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: NLColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: const TextStyle(fontSize: 12, color: NLColors.muted),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => onChanged(!value),
            child: NLToggle(on: value),
          ),
        ],
      ),
    );
  }
}

class _FormatCard extends StatelessWidget {
  final String label;
  final String sub;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _FormatCard({
    required this.label,
    required this.sub,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: NLColors.surface,
          borderRadius: BorderRadius.all(NLRadius.md),
          border: Border.all(
            color: selected ? NLColors.ink : NLColors.line,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: shadowCard,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 22,
              color: selected ? NLColors.ink : NLColors.muted,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: selected ? NLColors.ink : NLColors.muted,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sub,
              style: const TextStyle(fontSize: 11, color: NLColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
