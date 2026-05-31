import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../app_theme.dart';
import '../models/diary_entry.dart';
import '../models/doctor_models.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';
import '../state/profile_provider.dart';
import '../widgets/nl_widgets.dart';
import 'chat_screen.dart';
import 'lock_screen.dart';
import 'settings_screen.dart';

const _uuid = Uuid();

int _maxMsSymptom(DiaryEntry entry) => [
  entry.numbness,
  entry.coordination,
  entry.vision,
  entry.weakness,
].reduce((a, b) => a > b ? a : b);

class DoctorHomeScreen extends StatefulWidget {
  const DoctorHomeScreen({super.key});

  @override
  State<DoctorHomeScreen> createState() => _DoctorHomeScreenState();
}

class _DoctorHomeScreenState extends State<DoctorHomeScreen>
    with WidgetsBindingObserver {
  List<DoctorPatientOverview> _patients = [];
  bool _loading = true;
  String? _error;
  bool _lockOnResume = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _lockOnResume = true;
      return;
    }
    if (state == AppLifecycleState.resumed) {
      if (_lockOnResume) {
        _lockOnResume = false;
        if (_lockIfNeeded()) return;
      }
      _load();
    }
  }

  bool _lockIfNeeded() {
    if (!mounted) return false;
    if (!hasAppPin()) return false;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LockScreen(destination: DoctorHomeScreen()),
      ),
      (_) => false,
    );
    return true;
  }

  Future<void> _load() async {
    final doctorId = SupabaseService.currentUserId;
    if (doctorId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final patients = await SupabaseService.getDoctorPatientOverviews(
        doctorId,
      );
      if (!mounted) return;
      setState(() => _patients = patients);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Не удалось загрузить пациентов');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _warningPatients =>
      _patients.where((patient) => patient.warningCount > 0).length;

  int get _patientsWithPlan =>
      _patients.where((patient) => patient.treatmentPlan != null).length;

  Future<void> _openPatient(DoctorPatientOverview overview) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            DoctorPatientScreen(overview: overview, onChanged: _load),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>().profile;
    final name = profile?.name ?? 'Врач';

    return Scaffold(
      backgroundColor: NLColors.bg,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: NLColors.accent,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              NLHeader(
                greeting: 'Кабинет врача',
                title: name,
                actions: [
                  const SizedBox(width: 8),
                  NLCircleBtn(
                    onTap: () => performLogout(context),
                    child: const Icon(
                      Icons.logout_rounded,
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
                    Row(
                      children: [
                        Expanded(
                          child: _DoctorMetricCard(
                            label: 'Пациентов',
                            value: '${_patients.length}',
                            icon: Icons.groups_2_outlined,
                            color: NLColors.accent,
                            bg: NLColors.accentSoft,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _DoctorMetricCard(
                            label: 'Сигналов',
                            value: '$_warningPatients',
                            icon: Icons.monitor_heart_outlined,
                            color: _warningPatients > 0
                                ? NLColors.bad
                                : NLColors.good,
                            bg: _warningPatients > 0
                                ? NLColors.roseSoft
                                : NLColors.mintSoft,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _DoctorMetricCard(
                      label: 'Активных назначений',
                      value: '$_patientsWithPlan',
                      icon: Icons.medication_outlined,
                      color: NLColors.ink,
                      bg: NLColors.surface,
                      wide: true,
                    ),
                    const NLSectionTitle('Пациенты'),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: NLColors.accent,
                          ),
                        ),
                      )
                    else if (_error != null)
                      NLCard(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: NLColors.bad),
                        ),
                      )
                    else if (_patients.isEmpty)
                      const NLCard(
                        child: Column(
                          children: [
                            Icon(
                              Icons.person_search_outlined,
                              size: 36,
                              color: NLColors.muted,
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Пациенты не закреплены',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: NLColors.ink,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Пациент появится здесь после выбора вас лечащим врачом в своём профиле.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: NLColors.muted,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      NLList(
                        children: [
                          for (var i = 0; i < _patients.length; i++)
                            GestureDetector(
                              onTap: () => _openPatient(_patients[i]),
                              child: _PatientListRow(
                                overview: _patients[i],
                                last: i == _patients.length - 1,
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
      ),
    );
  }
}

class DoctorPatientScreen extends StatefulWidget {
  final DoctorPatientOverview overview;
  final Future<void> Function() onChanged;

  const DoctorPatientScreen({
    super.key,
    required this.overview,
    required this.onChanged,
  });

  @override
  State<DoctorPatientScreen> createState() => _DoctorPatientScreenState();
}

class _DoctorPatientScreenState extends State<DoctorPatientScreen> {
  TreatmentPlan? _plan;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _plan = widget.overview.treatmentPlan;
  }

  String _date(DateTime? value) {
    if (value == null) return 'Не указано';
    return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
  }

  String _metric(double? value) =>
      value == null ? '-' : value.toStringAsFixed(1);

  Future<void> _showContacts() async {
    final patient = widget.overview.patient;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: NLColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Контакты пациента',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: NLColors.ink,
                ),
              ),
              const SizedBox(height: 14),
              NLList(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            otherUserId: patient.id,
                            otherUserName: patient.name,
                            subtitle: 'Пациент',
                          ),
                        ),
                      );
                    },
                    child: NLListRow(
                      icon: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 16,
                        color: NLColors.accent,
                      ),
                      iconBg: NLColors.accentSoft,
                      title: 'Чат с пациентом',
                      sub: 'Сообщения сохраняются в приложении',
                    ),
                  ),
                  NLListRow(
                    icon: const Icon(
                      Icons.mail_outline_rounded,
                      size: 16,
                      color: NLColors.accent,
                    ),
                    iconBg: NLColors.accentSoft,
                    title: patient.email,
                    sub: 'Email',
                  ),
                  NLListRow(
                    icon: const Icon(
                      Icons.phone_outlined,
                      size: 16,
                      color: NLColors.good,
                    ),
                    iconBg: NLColors.mintSoft,
                    title: patient.phone.isEmpty ? 'Не указан' : patient.phone,
                    sub: 'Телефон',
                  ),
                  NLListRow(
                    icon: const Icon(
                      Icons.emergency_outlined,
                      size: 16,
                      color: NLColors.bad,
                    ),
                    iconBg: NLColors.roseSoft,
                    title: patient.emergencyContactName.isEmpty
                        ? 'Не указан'
                        : patient.emergencyContactName,
                    sub: patient.emergencyContactPhone.isEmpty
                        ? 'Экстренный контакт'
                        : patient.emergencyContactPhone,
                    last: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showTreatmentDialog() async {
    final titleCtrl = TextEditingController(text: _plan?.title ?? '');
    final medicationCtrl = TextEditingController(text: _plan?.medication ?? '');
    final dosageCtrl = TextEditingController(text: _plan?.dosage ?? '');
    final recommendationsCtrl = TextEditingController(
      text: _plan?.recommendations ?? '',
    );
    final contactNoteCtrl = TextEditingController(
      text: _plan?.contactNote ?? '',
    );
    DateTime? nextVisitAt = _plan?.nextVisitAt;

    try {
      await showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: NLColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Назначение лечения',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: NLColors.ink,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _DoctorTextField(
                    label: 'Цель назначения',
                    controller: titleCtrl,
                    hintText: 'Например, коррекция терапии',
                  ),
                  const SizedBox(height: 12),
                  _DoctorTextField(
                    label: 'Препарат / терапия',
                    controller: medicationCtrl,
                  ),
                  const SizedBox(height: 12),
                  _DoctorTextField(label: 'Дозировка', controller: dosageCtrl),
                  const SizedBox(height: 12),
                  _DoctorTextField(
                    label: 'Рекомендации',
                    controller: recommendationsCtrl,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  _DoctorTextField(
                    label: 'Заметка контакта',
                    controller: contactNoteCtrl,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: nextVisitAt ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 730)),
                      );
                      if (picked != null) {
                        setDialogState(() => nextVisitAt = picked);
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: NLColors.surface2,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Следующий визит: ${_date(nextVisitAt)}',
                              style: const TextStyle(color: NLColors.ink),
                            ),
                          ),
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 18,
                            color: NLColors.muted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text(
                  'Отмена',
                  style: TextStyle(color: NLColors.muted),
                ),
              ),
              TextButton(
                onPressed: _saving
                    ? null
                    : () async {
                        final doctorId = SupabaseService.currentUserId;
                        if (doctorId == null) return;
                        setState(() => _saving = true);
                        final plan = TreatmentPlan(
                          id: _plan?.id ?? _uuid.v4(),
                          doctorId: doctorId,
                          patientId: widget.overview.patient.id,
                          title: titleCtrl.text.trim().isEmpty
                              ? 'План лечения'
                              : titleCtrl.text.trim(),
                          medication: medicationCtrl.text.trim(),
                          dosage: dosageCtrl.text.trim(),
                          recommendations: recommendationsCtrl.text.trim(),
                          contactNote: contactNoteCtrl.text.trim(),
                          nextVisitAt: nextVisitAt,
                          createdAt: _plan?.createdAt ?? DateTime.now(),
                        );
                        try {
                          await SupabaseService.saveTreatmentPlan(plan);
                          final isNew = _plan == null;
                          final visitChanged =
                              plan.nextVisitAt != null &&
                              _plan?.nextVisitAt != plan.nextVisitAt;
                          await SupabaseService.createNotification(
                            userId: plan.patientId,
                            type: isNew
                                ? 'treatment_assigned'
                                : 'treatment_updated',
                            title: isNew
                                ? 'Назначено лечение'
                                : 'Лечение обновлено',
                            body: isNew
                                ? 'Ваш врач добавил план лечения.'
                                : 'Ваш врач скорректировал план лечения.',
                            treatmentPlanId: plan.id,
                          );
                          if (visitChanged) {
                            await SupabaseService.createNotification(
                              userId: plan.patientId,
                              type: 'visit_scheduled',
                              title: 'Назначен визит',
                              body:
                                  'Следующий визит: ${_date(plan.nextVisitAt)}.',
                              treatmentPlanId: plan.id,
                            );
                          }
                          await widget.onChanged();
                          if (!mounted) return;
                          setState(() => _plan = plan);
                          if (ctx.mounted) Navigator.of(ctx).pop();
                        } finally {
                          if (mounted) setState(() => _saving = false);
                        }
                      },
                child: const Text(
                  'Сохранить',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: NLColors.accent,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } finally {
      titleCtrl.dispose();
      medicationCtrl.dispose();
      dosageCtrl.dispose();
      recommendationsCtrl.dispose();
      contactNoteCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final overview = widget.overview;
    final patient = overview.patient;
    final latest = overview.latestDiaryEntry;
    final tapping = overview.latestTappingResult;
    final reaction = overview.latestReactionResult;

    return Scaffold(
      backgroundColor: NLColors.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            NLHeader(
              greeting: 'Пациент',
              title: patient.name,
              actions: [
                const SizedBox(width: 8),
                NLCircleBtn(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(
                    Icons.close_rounded,
                    color: NLColors.ink,
                    size: 20,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: NLButton(
                          label: 'Связаться',
                          full: true,
                          primary: false,
                          icon: const Icon(
                            Icons.forum_outlined,
                            size: 18,
                            color: NLColors.ink,
                          ),
                          onTap: _showContacts,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: NLButton(
                          label: 'Лечение',
                          full: true,
                          icon: const Icon(
                            Icons.medication_outlined,
                            size: 18,
                            color: Colors.white,
                          ),
                          onTap: _showTreatmentDialog,
                        ),
                      ),
                    ],
                  ),
                  const NLSectionTitle('Анализ за 7 дней'),
                  Row(
                    children: [
                      Expanded(
                        child: _SmallMetric(
                          label: 'Усталость',
                          value: _metric(overview.averageFatigue(7)),
                          color: NLColors.peach,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SmallMetric(
                          label: 'Боль',
                          value: _metric(overview.averagePain(7)),
                          color: NLColors.rose,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SmallMetric(
                          label: 'Настроение',
                          value: _metric(overview.averageMood(7)),
                          color: NLColors.good,
                        ),
                      ),
                    ],
                  ),
                  const NLSectionTitle('Последняя запись'),
                  if (latest == null)
                    const NLCard(
                      child: Text(
                        'Пациент пока не добавлял записи дневника.',
                        style: TextStyle(color: NLColors.muted),
                      ),
                    )
                  else
                    NLCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _date(latest.dateTime),
                            style: const TextStyle(
                              fontSize: 13,
                              color: NLColors.muted,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Усталость ${latest.fatigue} · Боль ${latest.pain} · РС ${_maxMsSymptom(latest)} · Стресс ${latest.stress} · Сон ${latest.sleepHours.toStringAsFixed(1)} ч',
                            style: const TextStyle(
                              fontSize: 15,
                              color: NLColors.ink,
                            ),
                          ),
                          if (latest.note.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              latest.note,
                              style: const TextStyle(
                                fontSize: 13,
                                color: NLColors.ink2,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  const NLSectionTitle('Тесты'),
                  NLList(
                    children: [
                      NLListRow(
                        icon: const Icon(
                          Icons.ads_click_rounded,
                          color: NLColors.accent,
                          size: 18,
                        ),
                        iconBg: NLColors.accentSoft,
                        title: 'Таппинг',
                        sub: tapping == null
                            ? 'Нет результатов'
                            : '${tapping.value.toStringAsFixed(1)} уд/с · ${_date(tapping.dateTime)}',
                      ),
                      NLListRow(
                        icon: const Icon(
                          Icons.bolt_rounded,
                          color: NLColors.peach,
                          size: 18,
                        ),
                        iconBg: NLColors.peachSoft,
                        title: 'Реакция',
                        sub: reaction == null
                            ? 'Нет результатов'
                            : '${reaction.value.round()} мс · ${_date(reaction.dateTime)}',
                        last: true,
                      ),
                    ],
                  ),
                  const NLSectionTitle('Назначение'),
                  _TreatmentPlanCard(plan: _plan),
                  const NLSectionTitle('Профиль пациента'),
                  NLList(
                    children: [
                      NLListRow(
                        title: 'Текущая терапия',
                        sub: patient.currentTherapy.isEmpty
                            ? 'Не указана'
                            : patient.currentTherapy,
                      ),
                      NLListRow(
                        title: 'Клиника',
                        sub: patient.clinicName.isEmpty
                            ? 'Не указана'
                            : patient.clinicName,
                      ),
                      NLListRow(
                        title: 'Дата диагноза',
                        sub: _date(patient.diagnosisDate),
                        last: true,
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

class _PatientListRow extends StatelessWidget {
  final DoctorPatientOverview overview;
  final bool last;

  const _PatientListRow({required this.overview, required this.last});

  String _latestText() {
    final latest = overview.latestDiaryEntry;
    if (latest == null) return 'Нет записей дневника';
    return 'Усталость ${latest.fatigue} · Боль ${latest.pain} · РС ${_maxMsSymptom(latest)} · Стресс ${latest.stress}';
  }

  @override
  Widget build(BuildContext context) {
    final warnings = overview.warningCount;
    return NLListRow(
      icon: Icon(
        warnings > 0
            ? Icons.monitor_heart_outlined
            : Icons.person_outline_rounded,
        color: warnings > 0 ? NLColors.bad : NLColors.accent,
        size: 18,
      ),
      iconBg: warnings > 0 ? NLColors.roseSoft : NLColors.accentSoft,
      title: overview.patient.name,
      sub: _latestText(),
      right: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (warnings > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: NLColors.roseSoft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$warnings',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: NLColors.bad,
                ),
              ),
            ),
          const SizedBox(width: 8),
          const Icon(
            Icons.chevron_right_rounded,
            color: NLColors.muted,
            size: 20,
          ),
        ],
      ),
      last: last,
    );
  }
}

class _DoctorMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color bg;
  final bool wide;

  const _DoctorMetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.bg,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    return NLCard(
      color: bg,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          SizedBox(width: wide ? 14 : 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: NLColors.muted),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SmallMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return NLCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: NLColors.muted),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _TreatmentPlanCard extends StatelessWidget {
  final TreatmentPlan? plan;

  const _TreatmentPlanCard({required this.plan});

  String _date(DateTime? value) {
    if (value == null) return 'Не указано';
    return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (plan == null) {
      return const NLCard(
        child: Text(
          'Активное назначение пока не создано.',
          style: TextStyle(color: NLColors.muted),
        ),
      );
    }

    return NLCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            plan!.title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: NLColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          if (plan!.medication.isNotEmpty)
            _PlanLine(label: 'Терапия', value: plan!.medication),
          if (plan!.dosage.isNotEmpty)
            _PlanLine(label: 'Дозировка', value: plan!.dosage),
          if (plan!.recommendations.isNotEmpty)
            _PlanLine(label: 'Рекомендации', value: plan!.recommendations),
          _PlanLine(label: 'Следующий визит', value: _date(plan!.nextVisitAt)),
          if (plan!.contactNote.isNotEmpty)
            _PlanLine(label: 'Контакт', value: plan!.contactNote),
        ],
      ),
    );
  }
}

class _PlanLine extends StatelessWidget {
  final String label;
  final String value;

  const _PlanLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            fontSize: 13,
            height: 1.35,
            color: NLColors.ink2,
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _DoctorTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hintText;
  final int maxLines;

  const _DoctorTextField({
    required this.label,
    required this.controller,
    this.hintText,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: NLColors.muted),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(color: NLColors.muted),
            filled: true,
            fillColor: NLColors.surface2,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }
}
