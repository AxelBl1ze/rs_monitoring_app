import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../widgets/nl_widgets.dart';
import '../models/diary_entry.dart';
import '../state/diary_provider.dart';
import '../state/settings_provider.dart';
import 'diary_entry_screen.dart';

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
const _dows = ['П', 'В', 'С', 'Ч', 'П', 'С', 'В']; // Mon–Sun

class HistoryCalendarScreen extends StatefulWidget {
  const HistoryCalendarScreen({super.key});

  @override
  State<HistoryCalendarScreen> createState() => _HistoryCalendarScreenState();
}

class _HistoryCalendarScreenState extends State<HistoryCalendarScreen> {
  // First day of the currently displayed month
  late DateTime _month;
  // Selected day number within _month, or null
  int? _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month, 1);
    _selectedDay = now.day; // pre-select today
  }

  // ── Navigation ──────────────────────────────────────────────────────────

  void _prevMonth() {
    setState(() {
      _month = DateTime(_month.year, _month.month - 1, 1);
      _selectedDay = null;
    });
  }

  void _nextMonth() {
    final next = DateTime(_month.year, _month.month + 1, 1);
    final now = DateTime.now();
    // Do not navigate past the current month
    if (next.year > now.year ||
        (next.year == now.year && next.month > now.month)) {
      return;
    }
    setState(() {
      _month = next;
      _selectedDay = null;
    });
  }

  bool get _canGoNext {
    final now = DateTime.now();
    return !(_month.year == now.year && _month.month == now.month);
  }

  // ── Calendar cells ──────────────────────────────────────────────────────

  List<int?> _buildCells() {
    // weekday: 1=Mon … 7=Sun → offset = weekday-1
    final offset = _month.weekday - 1;
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final cells = <int?>[
      ...List.filled(offset, null),
      ...List.generate(daysInMonth, (i) => i + 1),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return cells;
  }

  // ── Condition level ─────────────────────────────────────────────────────

  // 1 = good (green), 2 = medium (orange), 3 = bad (red)
  int _level(DiaryEntry e) {
    final msMax = [
      e.numbness,
      e.coordination,
      e.vision,
      e.weakness,
    ].reduce((a, b) => a > b ? a : b);
    if (e.fatigue <= 4 &&
        e.pain <= 3 &&
        e.mood >= 6 &&
        msMax <= 3 &&
        e.stress <= 4) {
      return 1;
    }
    if (e.fatigue >= 7 ||
        e.pain >= 7 ||
        e.mood <= 3 ||
        msMax >= 7 ||
        e.stress >= 8) {
      return 3;
    }
    return 2;
  }

  Color _bgForLevel(int lvl) {
    if (lvl == 1) return NLColors.mintSoft;
    if (lvl == 3) return NLColors.roseSoft;
    return NLColors.peachSoft;
  }

  Color _dotForLevel(int lvl) {
    if (lvl == 1) return NLColors.good;
    if (lvl == 3) return NLColors.bad;
    return NLColors.warn;
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final diary = context.watch<DiaryProvider>();
    final settings = context.watch<SettingsProvider>().settings;

    // Build a day→entry map for the displayed month
    final entryMap = <int, DiaryEntry>{};
    for (final e in diary.entries) {
      if (e.dateTime.year == _month.year && e.dateTime.month == _month.month) {
        entryMap[e.dateTime.day] = e;
      }
    }

    final cells = _buildCells();
    final now = DateTime.now();
    final isCurrentMonth = _month.year == now.year && _month.month == now.month;
    final selectedEntry = _selectedDay != null ? entryMap[_selectedDay] : null;

    return Scaffold(
      backgroundColor: NLColors.bg,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const NLTopBar(leading: NLBackBtn(), title: 'История'),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NLSegmented(
                      items: const ['Список', 'Календарь'],
                      active: 'Календарь',
                      onChange: (value) {
                        if (value == 'Список') {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                    const SizedBox(height: 14),

                    // ── Calendar card ──────────────────────────────────────
                    NLCard(
                      child: Column(
                        children: [
                          // Month navigation header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GestureDetector(
                                onTap: _prevMonth,
                                child: const Icon(
                                  Icons.chevron_left_rounded,
                                  color: NLColors.muted,
                                ),
                              ),
                              Text(
                                '${_monthNames[_month.month]} ${_month.year}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: NLColors.ink,
                                ),
                              ),
                              GestureDetector(
                                onTap: _canGoNext ? _nextMonth : null,
                                child: Icon(
                                  Icons.chevron_right_rounded,
                                  color: _canGoNext
                                      ? NLColors.muted
                                      : NLColors.line,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Day-of-week headers
                          Row(
                            children: _dows
                                .map(
                                  (d) => Expanded(
                                    child: Center(
                                      child: Text(
                                        d,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: NLColors.muted,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 6),

                          // Calendar grid
                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 7,
                            mainAxisSpacing: 6,
                            crossAxisSpacing: 6,
                            children: cells.map((day) {
                              if (day == null) return const SizedBox();

                              final entry = entryMap[day];
                              final isToday = isCurrentMonth && day == now.day;
                              final isSelected = day == _selectedDay;
                              final hasEntry = entry != null;
                              final lvl = hasEntry ? _level(entry) : 0;

                              Color bg;
                              if (isSelected && !isToday) {
                                bg = NLColors.accentSoft;
                              } else if (isToday) {
                                bg = NLColors.ink;
                              } else if (hasEntry) {
                                bg = _bgForLevel(lvl);
                              } else {
                                bg = NLColors.surface2;
                              }

                              return GestureDetector(
                                onTap: () => setState(() => _selectedDay = day),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: bg,
                                    borderRadius: BorderRadius.circular(10),
                                    border: isSelected
                                        ? Border.all(
                                            color: NLColors.accent,
                                            width: 1.5,
                                          )
                                        : Border.all(color: NLColors.line2),
                                  ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Text(
                                        '$day',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: isToday
                                              ? Colors.white
                                              : NLColors.ink,
                                        ),
                                      ),
                                      if (!isToday && hasEntry)
                                        Positioned(
                                          bottom: 4,
                                          child: Container(
                                            width: 4,
                                            height: 4,
                                            decoration: BoxDecoration(
                                              color: _dotForLevel(lvl),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 14),

                          // Legend
                          Row(
                            children: [
                              _Legend(color: NLColors.good, label: 'Хорошо'),
                              const SizedBox(width: 12),
                              _Legend(color: NLColors.warn, label: 'Средне'),
                              const SizedBox(width: 12),
                              _Legend(color: NLColors.bad, label: 'Плохо'),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // ── Selected day detail ────────────────────────────────
                    if (_selectedDay != null) ...[
                      NLSectionTitle(
                        'Выбрано · $_selectedDay ${_monthsShort[_month.month]}',
                        action: selectedEntry != null ? 'Изменить ›' : null,
                      ),
                      if (selectedEntry != null)
                        GestureDetector(
                          onTap: () async {
                            final diaryProvider = context.read<DiaryProvider>();
                            await Navigator.of(context).push<bool?>(
                              MaterialPageRoute(
                                builder: (_) =>
                                    DiaryEntryScreen(entry: selectedEntry),
                              ),
                            );
                            await diaryProvider.load();
                          },
                          child: NLCard(
                            child: Column(
                              children: [
                                _DetailRow(
                                  'Усталость',
                                  '${settings.formatSymptomValue(selectedEntry.fatigue)} ${settings.symptomScaleSuffix}',
                                ),
                                const SizedBox(height: 10),
                                _DetailRow(
                                  'Боль',
                                  '${settings.formatSymptomValue(selectedEntry.pain)} ${settings.symptomScaleSuffix}',
                                ),
                                const SizedBox(height: 10),
                                _DetailRow(
                                  'Настроение',
                                  '${settings.formatSymptomValue(selectedEntry.mood)} ${settings.symptomScaleSuffix}',
                                ),
                                const SizedBox(height: 10),
                                _DetailRow(
                                  'Чувствительность',
                                  '${settings.formatSymptomValue(selectedEntry.numbness)} ${settings.symptomScaleSuffix}',
                                ),
                                const SizedBox(height: 10),
                                _DetailRow(
                                  'Координация',
                                  '${settings.formatSymptomValue(selectedEntry.coordination)} ${settings.symptomScaleSuffix}',
                                ),
                                const SizedBox(height: 10),
                                _DetailRow(
                                  'Зрение',
                                  '${settings.formatSymptomValue(selectedEntry.vision)} ${settings.symptomScaleSuffix}',
                                ),
                                const SizedBox(height: 10),
                                _DetailRow(
                                  'Слабость',
                                  '${settings.formatSymptomValue(selectedEntry.weakness)} ${settings.symptomScaleSuffix}',
                                ),
                                const SizedBox(height: 10),
                                _DetailRow(
                                  'Стресс',
                                  '${settings.formatSymptomValue(selectedEntry.stress)} ${settings.symptomScaleSuffix}',
                                ),
                                const SizedBox(height: 10),
                                _DetailRow(
                                  'Сон',
                                  '${settings.formatSleepValue(selectedEntry.sleepHours)} ${settings.sleepUnit}',
                                ),
                                if (selectedEntry.flareFlag) ...[
                                  const SizedBox(height: 10),
                                  _DetailRow('Эпизод', '⚠ Обострение'),
                                ],
                                if (selectedEntry.note.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      selectedEntry.note,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: NLColors.ink2,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )
                      else
                        NLCard(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Column(
                                children: [
                                  const Icon(
                                    Icons.calendar_today_outlined,
                                    size: 28,
                                    color: NLColors.muted,
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Нет записи за этот день',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: NLColors.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Выберите другой день или добавьте запись',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: NLColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
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

// ── Local widgets ─────────────────────────────────────────────────────────────

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: NLColors.muted),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: NLColors.muted),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: NLColors.ink,
          ),
        ),
      ],
    );
  }
}
