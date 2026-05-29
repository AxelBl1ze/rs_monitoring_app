import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../widgets/nl_widgets.dart';
import '../models/diary_entry.dart';
import '../state/diary_provider.dart';
import '../state/settings_provider.dart';
import 'history_calendar_screen.dart';
import 'diary_entry_screen.dart';

const _weekdayNames = [
  '',
  'Понедельник',
  'Вторник',
  'Среда',
  'Четверг',
  'Пятница',
  'Суббота',
  'Воскресенье',
];
const _monthNames = [
  '',
  'Январь',
  'Февраль',
  'Март',
  'Апрель',
  'Май',
  'Июнь',
  'Июль',
  'Август',
  'Сентябрь',
  'Октябрь',
  'Ноябрь',
  'Декабрь',
];
const _monthsShort = [
  '',
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

class HistoryListScreen extends StatelessWidget {
  const HistoryListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NLColors.bg,
      body: SafeArea(bottom: false, child: const HistoryListBody()),
    );
  }
}

class HistoryListBody extends StatefulWidget {
  const HistoryListBody({super.key});

  @override
  State<HistoryListBody> createState() => _HistoryListBodyState();
}

class _HistoryListBodyState extends State<HistoryListBody> {
  String _view = 'Список';

  String _dayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return 'Сегодня';
    if (diff == 1) return 'Вчера';
    return _weekdayNames[date.weekday];
  }

  String _monthSection(DateTime d) => '${_monthNames[d.month]} ${d.year}';

  // Group entries (already newest-first) by month label, preserving order.
  List<MapEntry<String, List<DiaryEntry>>> _grouped(List<DiaryEntry> entries) {
    final map = <String, List<DiaryEntry>>{};
    for (final e in entries) {
      final key = _monthSection(e.dateTime);
      map.putIfAbsent(key, () => []).add(e);
    }
    return map.entries.toList();
  }

  @override
  Widget build(BuildContext context) {
    final diary = context.watch<DiaryProvider>();
    final entries = diary.diaryEntriesSorted;
    final groups = _grouped(entries);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NLHeader(
            greeting: 'Все записи',
            title: 'История',
            actions: [
              const SizedBox(width: 8),
              NLCircleBtn(
                child: const Icon(
                  Icons.calendar_month_outlined,
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
                  items: const ['Список', 'Календарь'],
                  active: _view,
                  onChange: (v) {
                    if (v == 'Календарь') {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const HistoryCalendarScreen(),
                        ),
                      );
                    } else {
                      setState(() => _view = v);
                    }
                  },
                ),

                // ── Empty state ──────────────────────────────────────────
                if (entries.isEmpty) ...[
                  const SizedBox(height: 40),
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: NLColors.surface2,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.book_outlined,
                            size: 28,
                            color: NLColors.muted,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Записей пока нет',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: NLColors.ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Начните вести дневник\nнажав кнопку «+»',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: NLColors.muted,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // ── Month groups ─────────────────────────────────────────
                for (final group in groups) ...[
                  NLSectionTitle(group.key),
                  Container(
                    decoration: BoxDecoration(
                      color: NLColors.surface,
                      borderRadius: BorderRadius.all(NLRadius.lg),
                      boxShadow: shadowCard,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: group.value.asMap().entries.map((e) {
                        final isLast = e.key == group.value.length - 1;
                        return _EntryRow(
                          entry: e.value,
                          isLast: isLast,
                          dayLabel: _dayLabel(e.value.dateTime),
                          onDelete: () =>
                              context.read<DiaryProvider>().delete(e.value.id),
                          onTap: () async {
                            final diaryProvider = context.read<DiaryProvider>();
                            await Navigator.of(context).push<bool?>(
                              MaterialPageRoute(
                                builder: (_) =>
                                    DiaryEntryScreen(entry: e.value),
                              ),
                            );
                            await diaryProvider.load();
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Entry row with swipe-to-delete ──────────────────────────────────────────

class _EntryRow extends StatelessWidget {
  final DiaryEntry entry;
  final bool isLast;
  final String dayLabel;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _EntryRow({
    required this.entry,
    required this.isLast,
    required this.dayLabel,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>().settings;
    final d = entry.dateTime;
    final f = entry.fatigue;
    final p = entry.pain;
    final mood = entry.mood;
    final s = entry.sleepHours;
    final neuroMax = [
      entry.numbness,
      entry.coordination,
      entry.vision,
      entry.weakness,
    ].reduce((a, b) => a > b ? a : b);

    return Dismissible(
      key: Key(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: NLColors.bad,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
      onDismissed: (_) => onDelete(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: NLColors.surface,
            border: isLast
                ? null
                : const Border(bottom: BorderSide(color: NLColors.line2)),
          ),
          child: Row(
            children: [
              // Date column
              SizedBox(
                width: 44,
                child: Column(
                  children: [
                    Text(
                      '${d.day}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        color: NLColors.ink,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _monthsShort[d.month].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        color: NLColors.muted,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Summary column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dayLabel,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: NLColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'У ${settings.formatSymptomValue(f)}  Б ${settings.formatSymptomValue(p)}  Н ${settings.formatSymptomValue(mood)}  РС ${settings.formatSymptomValue(neuroMax)}  Ст ${settings.formatSymptomValue(entry.stress)}  ${settings.formatSleepValue(s)}${settings.sleepUnit}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: NLColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              // Condition mini-bars: fatigue, pain, inverted mood, MS burden, stress
              Row(
                children: [f, p, 10 - mood, neuroMax, entry.stress].map((v) {
                  final color = v >= 7
                      ? NLColors.bad
                      : v >= 4
                      ? NLColors.warn
                      : NLColors.good;
                  return Container(
                    width: 4,
                    height: (8 + v * 2).toDouble(),
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
