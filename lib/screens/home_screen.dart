import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../widgets/nl_widgets.dart';
import '../models/diary_entry.dart';
import '../state/diary_provider.dart';
import '../state/profile_provider.dart';
import '../state/settings_provider.dart';
import '../state/test_results_provider.dart';
import '../services/analytics_service.dart';
import '../services/supabase_service.dart';
import 'diary_entry_screen.dart';
import 'history_list_screen.dart';
import 'analytics_screen.dart';
import 'settings_screen.dart';
import 'patient_care_screen.dart';
import 'tapping_test_screen.dart';
import 'reaction_test_screen.dart';
import 'signals_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _tab = 0;

  static const _keys = ['home', 'diary', 'chart', 'profile'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshDiary());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshDiary();
    }
  }

  Future<void> _refreshDiary() async {
    if (!mounted) return;
    await context.read<DiaryProvider>().load();
  }

  Widget _body() {
    switch (_tab) {
      case 1:
        return const SafeArea(bottom: false, child: HistoryListBody());
      case 2:
        return const SafeArea(bottom: false, child: AnalyticsBody());
      case 3:
        return const SafeArea(bottom: false, child: SettingsBody());
      default:
        return _HomeTab(onProfileTap: () => setState(() => _tab = 3));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NLColors.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _body(),
          NLTabBar(
            active: _keys[_tab],
            onTabChanged: (key) => setState(() => _tab = _keys.indexOf(key)),
            onFab: () async {
              final diary = context.read<DiaryProvider>();
              final today = diary.todayDiaryEntry;
              final result = await Navigator.of(context).push<bool?>(
                MaterialPageRoute(
                  builder: (_) => DiaryEntryScreen(entry: today),
                ),
              );
              if (result == true) {
                await diary.load();
              }
            },
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

String _formatHeaderDate(DateTime dt) {
  const weekdays = [
    'Воскресенье',
    'Понедельник',
    'Вторник',
    'Среда',
    'Четверг',
    'Пятница',
    'Суббота',
  ];
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
  return '${weekdays[dt.weekday % 7]} · ${dt.day} ${months[dt.month - 1]}';
}

int? _calcConditionIndex(DiaryProvider diary) {
  final avgFatigue = diary.averageLastDays((e) => e.fatigue.toDouble(), 7);
  final avgPain = diary.averageLastDays((e) => e.pain.toDouble(), 7);
  final avgMood = diary.averageLastDays((e) => e.mood.toDouble(), 7);
  final avgNumbness = diary.averageLastDays((e) => e.numbness.toDouble(), 7);
  final avgCoordination = diary.averageLastDays(
    (e) => e.coordination.toDouble(),
    7,
  );
  final avgVision = diary.averageLastDays((e) => e.vision.toDouble(), 7);
  final avgWeakness = diary.averageLastDays((e) => e.weakness.toDouble(), 7);
  final avgStress = diary.averageLastDays((e) => e.stress.toDouble(), 7);
  if (avgFatigue == null || avgPain == null || avgMood == null) return null;
  return AnalyticsService.calculateCompositeIndexFromAverages(
    fatigue: avgFatigue,
    pain: avgPain,
    mood: avgMood,
    numbness: avgNumbness ?? 0,
    coordination: avgCoordination ?? 0,
    vision: avgVision ?? 0,
    weakness: avgWeakness ?? 0,
    stress: avgStress ?? 0,
  );
}

class _PatientNotificationButton extends StatefulWidget {
  const _PatientNotificationButton();

  @override
  State<_PatientNotificationButton> createState() =>
      _PatientNotificationButtonState();
}

class _PatientNotificationButtonState
    extends State<_PatientNotificationButton> {
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = context.read<ProfileProvider>().profile;
    if (profile == null) return;
    final notifications = await SupabaseService.getUnreadNotificationCount();
    final messages = profile.doctorId == null
        ? 0
        : await SupabaseService.getUnreadChatCount(profile.doctorId!);
    if (!mounted) return;
    setState(() => _count = notifications + messages);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        NLCircleBtn(
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PatientCareScreen()),
            );
            if (mounted) _load();
          },
          child: const Icon(
            Icons.notifications_outlined,
            color: NLColors.ink,
            size: 18,
          ),
        ),
        if (_count > 0)
          Positioned(
            top: 8,
            right: 9,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: NLColors.bad,
                shape: BoxShape.circle,
                border: Border.all(color: NLColors.surface, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

NLSignalLevel _signalLevel(String severity) {
  if (severity == 'high') return NLSignalLevel.bad;
  if (severity == 'warn') return NLSignalLevel.warn;
  return NLSignalLevel.info;
}

// ─── Home Tab ────────────────────────────────────────────────────────────────

class _HomeTab extends StatelessWidget {
  final VoidCallback onProfileTap;

  const _HomeTab({required this.onProfileTap});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final diary = context.watch<DiaryProvider>();
    final settings = context.watch<SettingsProvider>().settings;
    final tests = context.watch<TestResultsProvider>();

    final now = DateTime.now();
    final greeting = profile.hasProfile
        ? 'Привет, ${profile.profile!.name}'
        : 'Привет';
    final avatarLetter = profile.avatarLetter;

    final avgFatigue = diary.averageLastDays((e) => e.fatigue.toDouble(), 7);
    final avgPain = diary.averageLastDays((e) => e.pain.toDouble(), 7);
    final avgMood = diary.averageLastDays((e) => e.mood.toDouble(), 7);
    final avgSleep = diary.averageLastDays((e) => e.sleepHours, 7);

    final fatigueDelta = diary.percentChange((e) => e.fatigue.toDouble(), 7);
    final painDelta = diary.percentChange((e) => e.pain.toDouble(), 7);
    final moodDelta = diary.percentChange((e) => e.mood.toDouble(), 7);
    final sleepDelta = diary.percentChange((e) => e.sleepHours, 7);

    final conditionIndex = _calcConditionIndex(diary);
    final signals = AnalyticsService.generateSignals(
      diary.diaryEntriesSorted,
      tests.results,
    );
    final signal = signals.isEmpty ? null : signals.first;

    final tapping = tests.latestTappingResult;
    final reaction = tests.latestReactionResult;

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NLHeader(
              greeting: _formatHeaderDate(now),
              title: greeting,
              actions: [
                const SizedBox(width: 8),
                const _PatientNotificationButton(),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onProfileTap,
                  behavior: HitTestBehavior.opaque,
                  child: NLAvatar(avatarLetter),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TodayCard(diary: diary),
                  const NLSectionTitle('Сводка за 7 дней'),
                  if (!diary.hasAnyData)
                    _EmptyDataCard()
                  else ...[
                    Row(
                      children: [
                        Expanded(
                          child: NLTile(
                            label: 'Усталость',
                            value: avgFatigue != null
                                ? settings.formatSymptomValue(avgFatigue)
                                : '-',
                            unit: settings.symptomScaleSuffix,
                            badge: fatigueDelta != null
                                ? NLStat(delta: fatigueDelta.round())
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: NLTile(
                            label: 'Боль',
                            value: avgPain != null
                                ? settings.formatSymptomValue(avgPain)
                                : '-',
                            unit: settings.symptomScaleSuffix,
                            badge: painDelta != null
                                ? NLStat(delta: painDelta.round())
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: NLTile(
                            label: 'Настроение',
                            value: avgMood != null
                                ? settings.formatSymptomValue(avgMood)
                                : '-',
                            unit: settings.symptomScaleSuffix,
                            // negate: mood increase is good, NLStat treats positive as bad
                            badge: moodDelta != null
                                ? NLStat(delta: (-moodDelta).round())
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: NLTile(
                            label: 'Сон',
                            value: avgSleep != null
                                ? settings.formatSleepValue(avgSleep)
                                : '-',
                            unit: settings.sleepUnit,
                            // negate: sleep increase is good
                            badge: sleepDelta != null
                                ? NLStat(delta: (-sleepDelta).round())
                                : null,
                          ),
                        ),
                      ],
                    ),
                    if (conditionIndex != null) ...[
                      const SizedBox(height: 8),
                      _ConditionIndexCard(index: conditionIndex),
                    ],
                  ],
                  NLSectionTitle(
                    'Сигнал',
                    action: 'Все →',
                    onActionTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SignalsScreen()),
                    ),
                  ),
                  signal != null
                      ? NLSignalRow(
                          title: signal.title,
                          body: signal.description,
                          level: _signalLevel(signal.severity),
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            color: NLColors.muted,
                            size: 20,
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SignalsScreen(),
                            ),
                          ),
                        )
                      : NLSignalRow(
                          title: 'Активных сигналов нет',
                          body: diary.hasAnyData
                              ? 'Продолжайте вести дневник для отслеживания изменений.'
                              : 'Создайте первую запись дневника, чтобы начать мониторинг.',
                          level: NLSignalLevel.info,
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            color: NLColors.muted,
                            size: 20,
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SignalsScreen(),
                            ),
                          ),
                        ),
                  const NLSectionTitle('Врач и лечение'),
                  const PatientCarePreviewCard(),
                  const NLSectionTitle('Тесты на сегодня'),
                  NLList(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const TappingTestScreen(),
                          ),
                        ),
                        child: NLListRow(
                          icon: const Icon(
                            Icons.ads_click_rounded,
                            color: NLColors.accent,
                            size: 18,
                          ),
                          iconBg: NLColors.accentSoft,
                          title: 'Таппинг-тест',
                          sub: tapping != null
                              ? 'Последний: ${tapping.value.toStringAsFixed(1)} ${settings.tappingUnit}'
                              : 'Моторика · 10 секунд',
                          right: const Icon(
                            Icons.chevron_right_rounded,
                            color: NLColors.muted,
                            size: 20,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ReactionTestScreen(),
                          ),
                        ),
                        child: NLListRow(
                          icon: const Icon(
                            Icons.bolt_rounded,
                            color: NLColors.peach,
                            size: 18,
                          ),
                          iconBg: NLColors.peachSoft,
                          title: 'Тест реакции',
                          sub: reaction != null
                              ? 'Последний: ${reaction.value.round()} мс'
                              : '5 попыток · 30 секунд',
                          last: true,
                          right: const Icon(
                            Icons.chevron_right_rounded,
                            color: NLColors.muted,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Today Card ──────────────────────────────────────────────────────────────

class _TodayCard extends StatelessWidget {
  final DiaryProvider diary;
  const _TodayCard({required this.diary});

  @override
  Widget build(BuildContext context) {
    final entry = diary.todayDiaryEntry;

    if (entry != null) {
      return GestureDetector(
        onTap: () async {
          final diaryProvider = context.read<DiaryProvider>();
          await Navigator.of(context).push<bool?>(
            MaterialPageRoute(builder: (_) => DiaryEntryScreen(entry: entry)),
          );
          await diaryProvider.load();
        },
        child: NLCard(
          color: NLColors.mintSoft,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'СЕГОДНЯ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: NLColors.good,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Запись сделана',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: NLColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Усталость ${entry.fatigue} · Боль ${entry.pain} · РС ${_maxMsSymptom(entry)} · Стресс ${entry.stress}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: NLColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: NLColors.ink,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.edit_outlined, size: 14, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'Изменить',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () async {
        final diaryProvider = context.read<DiaryProvider>();
        await Navigator.of(context).push<bool?>(
          MaterialPageRoute(builder: (_) => const DiaryEntryScreen()),
        );
        await diaryProvider.load();
      },
      child: NLCard(
        color: NLColors.accentSoft,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'СЕГОДНЯ',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: NLColors.accent,
                      letterSpacing: 1.1,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Запись не сделана',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: NLColors.ink,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Займёт около 30 секунд',
                    style: TextStyle(fontSize: 13, color: NLColors.muted),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: NLColors.ink,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: const [
                  Icon(Icons.add, size: 14, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    'Заполнить',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

int _maxMsSymptom(DiaryEntry entry) => [
  entry.numbness,
  entry.coordination,
  entry.vision,
  entry.weakness,
].reduce((a, b) => a > b ? a : b);

// ─── Condition Index Card ─────────────────────────────────────────────────────

class _ConditionIndexCard extends StatelessWidget {
  final int index;
  const _ConditionIndexCard({required this.index});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;
    if (index >= 70) {
      color = NLColors.good;
      label = 'Хорошее';
    } else if (index >= 45) {
      color = NLColors.warn;
      label = 'Умеренное';
    } else {
      color = NLColors.bad;
      label = 'Требует внимания';
    }

    return NLCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ИНДЕКС СОСТОЯНИЯ',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: NLColors.muted,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$index',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: color,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      '/100',
                      style: TextStyle(
                        fontSize: 14,
                        color: NLColors.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty State Card ─────────────────────────────────────────────────────────

class _EmptyDataCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return NLCard(
      child: Column(
        children: const [
          Icon(Icons.bar_chart_rounded, size: 36, color: NLColors.muted),
          SizedBox(height: 10),
          Text(
            'Пока нет данных для анализа',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: NLColors.ink,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Создайте первую запись дневника',
            style: TextStyle(fontSize: 13, color: NLColors.muted),
          ),
        ],
      ),
    );
  }
}
