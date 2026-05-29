import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../widgets/nl_widgets.dart';
import '../models/app_settings.dart';
import '../models/diary_entry.dart';
import '../services/storage_service.dart';
import '../state/diary_provider.dart';
import '../state/settings_provider.dart';

// Short month names for the title bar
const _monthsShort = [
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

class DiaryEntryScreen extends StatefulWidget {
  /// Pass an existing DiaryEntry to open in edit mode, or null for a new entry.
  final DiaryEntry? entry;
  const DiaryEntryScreen({super.key, this.entry});

  @override
  State<DiaryEntryScreen> createState() => _DiaryEntryScreenState();
}

class _DiaryEntryScreenState extends State<DiaryEntryScreen> {
  late int _fatigue;
  late int _pain;
  late int _mood;
  late int _numbness;
  late int _coordination;
  late int _vision;
  late int _weakness;
  late int _stress;
  late double _sleepHours; // stored in 0.5h increments (0.0 … 14.0)
  late bool _episode;
  late TextEditingController _noteCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _fatigue = e?.fatigue ?? 5;
    _pain = e?.pain ?? 3;
    _mood = e?.mood ?? 7;
    _numbness = e?.numbness ?? 0;
    _coordination = e?.coordination ?? 0;
    _vision = e?.vision ?? 0;
    _weakness = e?.weakness ?? 0;
    _stress = e?.stress ?? 3;
    // Round sleep to nearest 0.5h for the picker
    final rawSleep = e?.sleepHours ?? 7.0;
    _sleepHours = (rawSleep * 2).round() / 2;
    _episode = e?.flareFlag ?? false;
    _noteCtrl = TextEditingController(text: e?.note ?? '');
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  // ── Descriptors ─────────────────────────────────────────────────────────

  String _fatigueDesc(int v) {
    if (v <= 2) return 'Очень мало';
    if (v <= 4) return 'Умеренно';
    if (v <= 6) return 'Выше нормы';
    if (v <= 8) return 'Высокая';
    return 'Очень высокая';
  }

  String _painDesc(int v) {
    if (v <= 2) return 'Нет боли';
    if (v <= 4) return 'Лёгкая';
    if (v <= 6) return 'Умеренная';
    return 'Сильная';
  }

  String _moodDesc(int v) {
    if (v <= 2) return 'Очень плохое';
    if (v <= 4) return 'Плохое';
    if (v <= 6) return 'Нормальное';
    if (v <= 8) return 'Хорошее';
    return 'Отличное';
  }

  String _numbnessDesc(int v) {
    if (v <= 1) return 'Нет';
    if (v <= 3) return 'Лёгкое';
    if (v <= 6) return 'Заметное';
    if (v <= 8) return 'Сильное';
    return 'Очень сильное';
  }

  String _coordinationDesc(int v) {
    if (v <= 1) return 'Без нарушений';
    if (v <= 3) return 'Незначительно';
    if (v <= 6) return 'Заметно';
    if (v <= 8) return 'Сильно';
    return 'Очень сильно';
  }

  String _visionDesc(int v) {
    if (v <= 1) return 'Нет';
    if (v <= 3) return 'Лёгкие';
    if (v <= 6) return 'Умеренные';
    if (v <= 8) return 'Выраженные';
    return 'Очень выраженные';
  }

  String _weaknessDesc(int v) {
    if (v <= 1) return 'Нет';
    if (v <= 3) return 'Лёгкая';
    if (v <= 6) return 'Умеренная';
    if (v <= 8) return 'Сильная';
    return 'Очень сильная';
  }

  String _stressDesc(int v) {
    if (v <= 2) return 'Низкая';
    if (v <= 4) return 'Умеренная';
    if (v <= 6) return 'Заметная';
    if (v <= 8) return 'Высокая';
    return 'Очень высокая';
  }

  String _sleepLabel() {
    if (_sleepHours < 5) return 'Мало';
    if (_sleepHours < 7) return 'Достаточно';
    if (_sleepHours <= 9) return 'Хорошо';
    return 'Много';
  }

  // ── Composite index (mirrors DiaryEntry.compositeIndex) ─────────────────

  int get _compositeIndex {
    final fa = (10 - _fatigue) * 10;
    final pa = (10 - _pain) * 10;
    final neuro =
        (10 - ((_numbness + _coordination + _vision + _weakness) / 4)) * 10;
    final st = (10 - _stress) * 10;
    final mo = _mood * 10;
    final sl = (_sleepHours >= 7 && _sleepHours <= 9)
        ? 100
        : (_sleepHours * 10).clamp(0.0, 100.0).toInt();
    return ((fa + pa + neuro + st + mo + sl) / 6).round();
  }

  // ── Sleep picker helpers ─────────────────────────────────────────────────

  void _decrementSleep() =>
      setState(() => _sleepHours = (_sleepHours - 0.5).clamp(0.0, 14.0));

  void _incrementSleep() =>
      setState(() => _sleepHours = (_sleepHours + 0.5).clamp(0.0, 14.0));

  // ── Delta text vs 7-day average ─────────────────────────────────────────

  String _deltaText(
    double current,
    DiaryProvider diary,
    double Function(DiaryEntry) fn,
  ) {
    final avg = diary.averageLastDays(fn, 7);
    if (avg == null) return 'Нет данных за неделю';
    final diff = current - avg;
    final sign = diff > 0 ? '+' : '';
    return '$sign${diff.toStringAsFixed(1)} к среднему за 7 дней';
  }

  Widget _symptomScaleCard({
    required AppSettings settings,
    required DiaryProvider diary,
    required IconData icon,
    required Color color,
    required Color tint,
    required String label,
    required int value,
    required String leftLabel,
    required String rightLabel,
    required String descriptor,
    required String guide,
    required ValueChanged<int> onChanged,
    required double Function(DiaryEntry) metric,
  }) {
    return NLCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MetricHeader(icon: icon, color: color, tint: tint, label: label),
          const SizedBox(height: 16),
          NLScale(
            value: value,
            valueLabel: settings.formatSymptomValue(value),
            maxLabel: '${settings.symptomScaleMax}',
            color: color,
            tint: tint,
            leftLabel: leftLabel,
            rightLabel: rightLabel,
            descriptor: descriptor,
            onChanged: onChanged,
          ),
          const SizedBox(height: 10),
          _ScaleGuide(text: guide),
          const SizedBox(height: 10),
          Text(
            _deltaText(value.toDouble(), diary, metric),
            style: const TextStyle(fontSize: 12, color: NLColors.muted),
          ),
        ],
      ),
    );
  }

  // ── Save ────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_saving) return;
    // Basic validation
    if (_sleepHours < 0 || _sleepHours > 24) {
      _showError('Некорректное значение сна');
      return;
    }
    setState(() => _saving = true);

    final diary = context.read<DiaryProvider>();
    try {
      if (widget.entry != null) {
        await diary.update(
          widget.entry!.copyWith(
            fatigue: _fatigue,
            pain: _pain,
            mood: _mood,
            numbness: _numbness,
            coordination: _coordination,
            vision: _vision,
            weakness: _weakness,
            stress: _stress,
            sleepHours: _sleepHours,
            note: _noteCtrl.text.trim(),
            flareFlag: _episode,
          ),
        );
      } else {
        await diary.add(
          createDiaryEntry(
            dateTime: DateTime.now(),
            fatigue: _fatigue,
            pain: _pain,
            mood: _mood,
            numbness: _numbness,
            coordination: _coordination,
            vision: _vision,
            weakness: _weakness,
            stress: _stress,
            sleepHours: _sleepHours,
            note: _noteCtrl.text.trim(),
            flareFlag: _episode,
          ),
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showError(_saveErrorMessage(e));
    }
  }

  String _saveErrorMessage(Object error) {
    final text = error.toString();
    if (text.contains('numbness') ||
        text.contains('coordination') ||
        text.contains('vision') ||
        text.contains('weakness') ||
        text.contains('stress')) {
      return 'Не удалось сохранить РС-симптомы. Проверьте, что миграция 20260516000000_add_ms_symptom_scales.sql применена в Supabase.';
    }
    if (text.contains('Пользователь не авторизован')) {
      return 'Не удалось сохранить запись: нужно снова войти в аккаунт.';
    }
    if (text.contains('updated_at')) {
      return 'Не удалось сохранить запись. Проверьте, что миграция 20260516010000_fix_diary_entries_timestamps.sql применена в Supabase.';
    }
    return 'Не удалось сохранить запись. $text';
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Title date ───────────────────────────────────────────────────────────

  String get _titleDate {
    final d = widget.entry?.dateTime ?? DateTime.now();
    return 'Запись · ${d.day} ${_monthsShort[d.month - 1]}';
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final diary = context.watch<DiaryProvider>();
    final settings = context.watch<SettingsProvider>().settings;

    // Yesterday's composite index for delta badge
    final yd = DateTime.now().subtract(const Duration(days: 1));
    DiaryEntry? yesterday;
    for (final e in diary.entries) {
      if (e.dateTime.year == yd.year &&
          e.dateTime.month == yd.month &&
          e.dateTime.day == yd.day) {
        yesterday = e;
        break;
      }
    }
    final idxDelta = yesterday != null
        ? _compositeIndex - yesterday.compositeIndex
        : 0;

    final sleepH = _sleepHours.floor();
    final sleepM = ((_sleepHours % 1) * 60).round();

    return Scaffold(
      backgroundColor: NLColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            NLTopBar(
              leading: NLBackBtn(),
              title: _titleDate,
              trailing: GestureDetector(
                onTap: _saving ? null : _save,
                child: Text(
                  _saving ? '...' : 'Готово',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: NLColors.accent,
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      widget.entry != null
                          ? 'Редактировать запись'
                          : 'Как день?',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.8,
                        color: NLColors.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Точно отметь каждый показатель',
                      style: TextStyle(fontSize: 14, color: NLColors.muted),
                    ),
                    const SizedBox(height: 22),

                    // ── Усталость ──────────────────────────────────────────
                    NLCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _MetricHeader(
                            icon: Icons.battery_2_bar_rounded,
                            color: NLColors.peach,
                            tint: NLColors.peachSoft,
                            label: 'Усталость',
                          ),
                          const SizedBox(height: 16),
                          NLScale(
                            value: _fatigue,
                            valueLabel: settings.formatSymptomValue(_fatigue),
                            maxLabel: '${settings.symptomScaleMax}',
                            color: NLColors.peach,
                            tint: NLColors.peachSoft,
                            leftLabel: 'бодрая',
                            rightLabel: 'истощена',
                            descriptor: _fatigueDesc(_fatigue),
                            onChanged: (v) => setState(() => _fatigue = v),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _deltaText(
                              _fatigue.toDouble(),
                              diary,
                              (e) => e.fatigue.toDouble(),
                            ),
                            style: const TextStyle(
                              fontSize: 12,
                              color: NLColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Боль ──────────────────────────────────────────────
                    NLCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _MetricHeader(
                            icon: Icons.water_drop_outlined,
                            color: NLColors.rose,
                            tint: NLColors.roseSoft,
                            label: 'Боль',
                          ),
                          const SizedBox(height: 16),
                          NLScale(
                            value: _pain,
                            valueLabel: settings.formatSymptomValue(_pain),
                            maxLabel: '${settings.symptomScaleMax}',
                            color: NLColors.rose,
                            tint: NLColors.roseSoft,
                            leftLabel: 'нет боли',
                            rightLabel: 'невыносимо',
                            descriptor: _painDesc(_pain),
                            onChanged: (v) => setState(() => _pain = v),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _deltaText(
                              _pain.toDouble(),
                              diary,
                              (e) => e.pain.toDouble(),
                            ),
                            style: const TextStyle(
                              fontSize: 12,
                              color: NLColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Настроение ────────────────────────────────────────
                    NLCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _MetricHeader(
                            icon: Icons.sentiment_satisfied_alt_outlined,
                            color: NLColors.accent,
                            tint: NLColors.accentSoft,
                            label: 'Настроение',
                          ),
                          const SizedBox(height: 16),
                          NLScale(
                            value: _mood,
                            valueLabel: settings.formatSymptomValue(_mood),
                            maxLabel: '${settings.symptomScaleMax}',
                            color: NLColors.accent,
                            tint: NLColors.accentSoft,
                            leftLabel: 'плохое',
                            rightLabel: 'отличное',
                            descriptor: _moodDesc(_mood),
                            onChanged: (v) => setState(() => _mood = v),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _deltaText(
                              _mood.toDouble(),
                              diary,
                              (e) => e.mood.toDouble(),
                            ),
                            style: const TextStyle(
                              fontSize: 12,
                              color: NLColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    const NLSectionTitle('РС-симптомы'),
                    _symptomScaleCard(
                      settings: settings,
                      diary: diary,
                      icon: Icons.touch_app_outlined,
                      color: NLColors.mint,
                      tint: NLColors.mintSoft,
                      label: 'Онемение / чувствительность',
                      value: _numbness,
                      leftLabel: 'нет',
                      rightLabel: 'сильно',
                      descriptor: _numbnessDesc(_numbness),
                      guide:
                          'Оцени за последние сутки: 0 — нет; 1–3 — ощущается, но почти не мешает; 4–6 — заметно мешает делам; 7–10 — сильно ограничивает.',
                      onChanged: (v) => setState(() => _numbness = v),
                      metric: (e) => e.numbness.toDouble(),
                    ),
                    const SizedBox(height: 12),
                    _symptomScaleCard(
                      settings: settings,
                      diary: diary,
                      icon: Icons.sports_gymnastics_outlined,
                      color: NLColors.sky,
                      tint: NLColors.skySoft,
                      label: 'Нарушение координации',
                      value: _coordination,
                      leftLabel: 'ровно',
                      rightLabel: 'трудно',
                      descriptor: _coordinationDesc(_coordination),
                      guide:
                          '0 — идёшь и двигаешься как обычно; 1–3 — иногда неловко; 4–6 — заметно мешает ходьбе или точным движениям; 7–10 — трудно идти или удерживать равновесие.',
                      onChanged: (v) => setState(() => _coordination = v),
                      metric: (e) => e.coordination.toDouble(),
                    ),
                    const SizedBox(height: 12),
                    _symptomScaleCard(
                      settings: settings,
                      diary: diary,
                      icon: Icons.visibility_outlined,
                      color: NLColors.accent,
                      tint: NLColors.accentSoft,
                      label: 'Зрительные симптомы',
                      value: _vision,
                      leftLabel: 'нет',
                      rightLabel: 'сильно',
                      descriptor: _visionDesc(_vision),
                      guide:
                          '0 — зрение обычное; 1–3 — лёгкая размытость или дискомфорт; 4–6 — мешает читать или смотреть; 7–10 — выраженно ограничивает зрение.',
                      onChanged: (v) => setState(() => _vision = v),
                      metric: (e) => e.vision.toDouble(),
                    ),
                    const SizedBox(height: 12),
                    _symptomScaleCard(
                      settings: settings,
                      diary: diary,
                      icon: Icons.accessibility_new_rounded,
                      color: NLColors.peach,
                      tint: NLColors.peachSoft,
                      label: 'Мышечная слабость',
                      value: _weakness,
                      leftLabel: 'нет',
                      rightLabel: 'сильно',
                      descriptor: _weaknessDesc(_weakness),
                      guide:
                          '0 — слабости нет; 1–3 — быстрее устают мышцы; 4–6 — сложнее ходить, держать предметы или вставать; 7–10 — заметно ограничивает движение.',
                      onChanged: (v) => setState(() => _weakness = v),
                      metric: (e) => e.weakness.toDouble(),
                    ),
                    const SizedBox(height: 12),
                    _symptomScaleCard(
                      settings: settings,
                      diary: diary,
                      icon: Icons.bolt_outlined,
                      color: NLColors.rose,
                      tint: NLColors.roseSoft,
                      label: 'Стресс / нагрузка за день',
                      value: _stress,
                      leftLabel: 'спокойно',
                      rightLabel: 'перегрузка',
                      descriptor: _stressDesc(_stress),
                      guide:
                          '0 — спокойно; 1–3 — лёгкая нагрузка; 4–6 — день заметно напряжённый; 7–10 — перегрузка, трудно восстановиться.',
                      onChanged: (v) => setState(() => _stress = v),
                      metric: (e) => e.stress.toDouble(),
                    ),
                    const SizedBox(height: 12),

                    // ── Сон ───────────────────────────────────────────────
                    NLCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _MetricHeader(
                                icon: Icons.nightlight_round_outlined,
                                color: NLColors.sky,
                                tint: NLColors.skySoft,
                                label: 'Сон',
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: NLColors.skySoft,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  _sleepLabel(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: NLColors.sky,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _StepBtn(
                                icon: Icons.remove,
                                onTap: _decrementSleep,
                              ),
                              const SizedBox(width: 20),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    '$sleepH',
                                    style: const TextStyle(
                                      fontSize: 56,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -2,
                                      color: NLColors.ink,
                                      height: 1,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'ч',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: NLColors.muted,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    sleepM.toString().padLeft(2, '0'),
                                    style: const TextStyle(
                                      fontSize: 56,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -2,
                                      color: NLColors.ink,
                                      height: 1,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'мин',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: NLColors.muted,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 20),
                              _StepBtn(icon: Icons.add, onTap: _incrementSleep),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Center(
                            child: Text(
                              '7–9 часов — оптимально',
                              style: TextStyle(
                                fontSize: 12,
                                color: NLColors.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Индекс дня ────────────────────────────────────────
                    NLCard(
                      color: NLColors.accentSoft,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'ИНДЕКС ДНЯ',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: NLColors.accent,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      '$_compositeIndex',
                                      style: const TextStyle(
                                        fontSize: 36,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -1.2,
                                        color: NLColors.ink,
                                        height: 1,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      '/100',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: NLColors.muted,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (idxDelta != 0) NLStat(delta: idxDelta),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          NLRing(
                            value: _compositeIndex.toDouble(),
                            size: 64,
                            stroke: 6,
                            color: NLColors.accent,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Заметка ───────────────────────────────────────────
                    NLCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.notes_rounded,
                                size: 18,
                                color: NLColors.muted,
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Заметка',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: NLColors.ink,
                                ),
                              ),
                              const Spacer(),
                              ValueListenableBuilder<TextEditingValue>(
                                valueListenable: _noteCtrl,
                                builder: (_, v, _) => Text(
                                  '${v.text.length} / 300',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: NLColors.muted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _noteCtrl,
                            maxLines: 3,
                            maxLength: 300,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Как прошёл день?',
                              hintStyle: TextStyle(color: NLColors.muted),
                              counterText: '',
                              contentPadding: EdgeInsets.zero,
                            ),
                            style: const TextStyle(
                              fontSize: 14,
                              color: NLColors.ink2,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Эпизод обострения ─────────────────────────────────
                    NLCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Эпизод обострения',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: NLColors.ink,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Самооценка',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: NLColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _episode = !_episode),
                            child: NLToggle(on: _episode),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    NLButton(
                      label: _saving ? 'Сохранение...' : 'Сохранить запись',
                      full: true,
                      onTap: _saving ? null : _save,
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

// ── Helpers ──────────────────────────────────────────────────────────────────

class _MetricHeader extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color tint;
  final String label;
  const _MetricHeader({
    required this.icon,
    required this.color,
    required this.tint,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: tint,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: (MediaQuery.sizeOf(context).width - 120).clamp(
              120.0,
              360.0,
            ),
          ),
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: NLColors.ink,
            ),
          ),
        ),
      ],
    );
  }
}

class _ScaleGuide extends StatelessWidget {
  final String text;
  const _ScaleGuide({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 12, height: 1.35, color: NLColors.muted),
    );
  }
}

/// Round +/- button used for the sleep hour picker.
class _StepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StepBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          color: NLColors.surface2,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: NLColors.ink),
      ),
    );
  }
}
