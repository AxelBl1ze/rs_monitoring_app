import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';
import '../models/doctor_models.dart';
import '../models/diary_entry.dart';
import '../models/test_result.dart';
import '../models/app_settings.dart';

class SupabaseService {
  static SupabaseClient get _client => Supabase.instance.client;

  static DateTime? _parseOptionalDate(dynamic value) {
    if (value == null) return null;
    final text = value as String;
    if (text.isEmpty) return null;
    return DateTime.parse(text);
  }

  // ─── Auth ─────────────────────────────────────────────────────────────────

  static User? get currentUser => _client.auth.currentUser;
  static String? get currentUserId => _client.auth.currentUser?.id;

  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String name,
    required String role,
    DateTime? observationStartDate,
    String phone = '',
    String doctorSpecialty = '',
    String clinicName = '',
  }) => _client.auth.signUp(
    email: email,
    password: password,
    data: {
      'name': name,
      'role': role,
      'observation_start_date': (observationStartDate ?? DateTime.now())
          .toIso8601String(),
      'phone': phone,
      'doctor_specialty': doctorSpecialty,
      'clinic_name': clinicName,
    },
  );

  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) => _client.auth.signInWithPassword(email: email, password: password);

  static Future<void> signOut() => _client.auth.signOut();

  // ─── Profiles ─────────────────────────────────────────────────────────────

  static UserProfile _profileFromRow(Map<String, dynamic> data) => UserProfile(
    id: data['id'] as String,
    name: data['name'] as String,
    email: data['email'] as String,
    role: data['role'] as String? ?? UserRole.patient,
    observationStartDate: DateTime.parse(
      data['observation_start_date'] as String,
    ),
    birthDate: _parseOptionalDate(data['birth_date']),
    sex: data['sex'] as String? ?? '',
    phone: data['phone'] as String? ?? '',
    msType: data['ms_type'] as String? ?? '',
    diagnosisDate: _parseOptionalDate(data['diagnosis_date']),
    currentTherapy: data['current_therapy'] as String? ?? '',
    doctorId: data['doctor_id'] as String?,
    doctorName: data['doctor_name'] as String? ?? '',
    doctorSpecialty: data['doctor_specialty'] as String? ?? '',
    clinicName: data['clinic_name'] as String? ?? '',
    emergencyContactName: data['emergency_contact_name'] as String? ?? '',
    emergencyContactPhone: data['emergency_contact_phone'] as String? ?? '',
    baselineFatigue: data['baseline_fatigue'] as int? ?? 5,
    baselinePain: data['baseline_pain'] as int? ?? 3,
    baselineSleep: (data['baseline_sleep'] as num?)?.toDouble() ?? 7.0,
    pinEnabled: data['pin_enabled'] as bool? ?? false,
    faceIdEnabled: data['face_id_enabled'] as bool? ?? false,
  );

  static Future<UserProfile?> getProfile(String userId) async {
    final data = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (data == null) return null;
    return _profileFromRow(data);
  }

  static Future<void> upsertProfile(UserProfile profile) async {
    await _client.from('profiles').upsert({
      'id': profile.id,
      'name': profile.name,
      'email': profile.email,
      'role': profile.role,
      'observation_start_date': profile.observationStartDate.toIso8601String(),
      'birth_date': profile.birthDate?.toIso8601String(),
      'sex': profile.sex,
      'phone': profile.phone,
      'ms_type': profile.msType,
      'diagnosis_date': profile.diagnosisDate?.toIso8601String(),
      'current_therapy': profile.currentTherapy,
      'doctor_id': profile.doctorId,
      'doctor_name': profile.doctorName,
      'doctor_specialty': profile.doctorSpecialty,
      'clinic_name': profile.clinicName,
      'emergency_contact_name': profile.emergencyContactName,
      'emergency_contact_phone': profile.emergencyContactPhone,
      'baseline_fatigue': profile.baselineFatigue,
      'baseline_pain': profile.baselinePain,
      'baseline_sleep': profile.baselineSleep,
      'pin_enabled': profile.pinEnabled,
      'face_id_enabled': profile.faceIdEnabled,
    }, onConflict: 'id');
  }

  static Future<void> deleteProfile(String userId) async {
    await _client.from('profiles').delete().eq('id', userId);
  }

  static Future<List<DoctorListItem>> getDoctors() async {
    final data = await _client
        .from('profiles')
        .select('id,name,email,phone,doctor_specialty,clinic_name')
        .eq('role', UserRole.doctor)
        .order('name');
    return (data as List).map((row) {
      final m = row as Map<String, dynamic>;
      return DoctorListItem(
        id: m['id'] as String,
        name: m['name'] as String,
        email: m['email'] as String,
        phone: m['phone'] as String? ?? '',
        specialty: m['doctor_specialty'] as String? ?? '',
        clinicName: m['clinic_name'] as String? ?? '',
      );
    }).toList();
  }

  static Future<DoctorListItem?> getDoctorListItem(String doctorId) async {
    final data = await _client
        .from('profiles')
        .select('id,name,email,phone,doctor_specialty,clinic_name')
        .eq('id', doctorId)
        .eq('role', UserRole.doctor)
        .maybeSingle();
    if (data == null) return null;
    return DoctorListItem(
      id: data['id'] as String,
      name: data['name'] as String,
      email: data['email'] as String,
      phone: data['phone'] as String? ?? '',
      specialty: data['doctor_specialty'] as String? ?? '',
      clinicName: data['clinic_name'] as String? ?? '',
    );
  }

  static Future<List<DoctorPatientOverview>> getDoctorPatientOverviews(
    String doctorId,
  ) async {
    final data = await _client
        .from('profiles')
        .select()
        .eq('role', UserRole.patient)
        .eq('doctor_id', doctorId)
        .order('name');
    final patients = (data as List)
        .map((row) => _profileFromRow(row as Map<String, dynamic>))
        .toList();

    final overviews = <DoctorPatientOverview>[];
    for (final patient in patients) {
      final results = await Future.wait([
        getDiaryEntries(patient.id),
        getTestResults(patient.id),
        getActiveTreatmentPlan(doctorId: doctorId, patientId: patient.id),
      ]);
      overviews.add(
        DoctorPatientOverview(
          patient: patient,
          diaryEntries: (results[0] as List<DiaryEntry>).take(30).toList(),
          testResults: (results[1] as List<TestResult>).take(30).toList(),
          treatmentPlan: results[2] as TreatmentPlan?,
        ),
      );
    }
    return overviews;
  }

  static TreatmentPlan _treatmentPlanFromRow(Map<String, dynamic> m) =>
      TreatmentPlan(
        id: m['id'] as String,
        doctorId: m['doctor_id'] as String,
        patientId: m['patient_id'] as String,
        title: m['title'] as String? ?? '',
        medication: m['medication'] as String? ?? '',
        dosage: m['dosage'] as String? ?? '',
        recommendations: m['recommendations'] as String? ?? '',
        contactNote: m['contact_note'] as String? ?? '',
        nextVisitAt: _parseOptionalDate(m['next_visit_at']),
        active: m['active'] as bool? ?? true,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  static Future<TreatmentPlan?> getActiveTreatmentPlan({
    required String doctorId,
    required String patientId,
  }) async {
    final data = await _client
        .from('treatment_plans')
        .select()
        .eq('doctor_id', doctorId)
        .eq('patient_id', patientId)
        .eq('active', true)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (data == null) return null;
    return _treatmentPlanFromRow(data);
  }

  static Future<void> saveTreatmentPlan(TreatmentPlan plan) async {
    await _client.from('treatment_plans').upsert({
      'id': plan.id,
      'doctor_id': plan.doctorId,
      'patient_id': plan.patientId,
      'title': plan.title,
      'medication': plan.medication,
      'dosage': plan.dosage,
      'recommendations': plan.recommendations,
      'contact_note': plan.contactNote,
      'next_visit_at': plan.nextVisitAt?.toIso8601String(),
      'active': plan.active,
    }, onConflict: 'id');
  }

  static Future<TreatmentPlan?> getPatientActiveTreatmentPlan(
    String patientId,
  ) async {
    final data = await _client
        .from('treatment_plans')
        .select()
        .eq('patient_id', patientId)
        .eq('active', true)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (data == null) return null;
    return _treatmentPlanFromRow(data);
  }

  // ─── Chat & Notifications ────────────────────────────────────────────────

  static ChatMessage _chatMessageFromRow(Map<String, dynamic> m) => ChatMessage(
    id: m['id'] as String,
    senderId: m['sender_id'] as String,
    receiverId: m['receiver_id'] as String,
    body: m['body'] as String,
    createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
    readAt: _parseOptionalDate(m['read_at'])?.toLocal(),
  );

  static Future<List<ChatMessage>> getChatMessages(String otherUserId) async {
    final userId = currentUserId;
    if (userId == null) return const [];
    final data = await _client
        .from('chat_messages')
        .select()
        .or(
          'and(sender_id.eq.$userId,receiver_id.eq.$otherUserId),and(sender_id.eq.$otherUserId,receiver_id.eq.$userId)',
        )
        .order('created_at', ascending: true);
    return (data as List)
        .map((row) => _chatMessageFromRow(row as Map<String, dynamic>))
        .toList();
  }

  static Future<void> sendChatMessage({
    required String receiverId,
    required String body,
  }) async {
    final senderId = currentUserId;
    if (senderId == null) return;
    await _client.from('chat_messages').insert({
      'sender_id': senderId,
      'receiver_id': receiverId,
      'body': body,
    });
  }

  static Future<void> markChatAsRead(String otherUserId) async {
    final userId = currentUserId;
    if (userId == null) return;
    await _client
        .from('chat_messages')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('sender_id', otherUserId)
        .eq('receiver_id', userId)
        .filter('read_at', 'is', null);
  }

  static Future<int> getUnreadChatCount(String otherUserId) async {
    final userId = currentUserId;
    if (userId == null) return 0;
    final data = await _client
        .from('chat_messages')
        .select('id')
        .eq('sender_id', otherUserId)
        .eq('receiver_id', userId)
        .filter('read_at', 'is', null);
    return (data as List).length;
  }

  static AppNotification _notificationFromRow(Map<String, dynamic> m) =>
      AppNotification(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        actorId: m['actor_id'] as String?,
        type: m['type'] as String,
        title: m['title'] as String,
        body: m['body'] as String,
        treatmentPlanId: m['treatment_plan_id'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
        readAt: _parseOptionalDate(m['read_at']),
      );

  static Future<List<AppNotification>> getNotifications() async {
    final userId = currentUserId;
    if (userId == null) return const [];
    final data = await _client
        .from('app_notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(50);
    return (data as List)
        .map((row) => _notificationFromRow(row as Map<String, dynamic>))
        .toList();
  }

  static Future<int> getUnreadNotificationCount() async {
    final userId = currentUserId;
    if (userId == null) return 0;
    final data = await _client
        .from('app_notifications')
        .select('id')
        .eq('user_id', userId)
        .filter('read_at', 'is', null);
    return (data as List).length;
  }

  static Future<void> createNotification({
    required String userId,
    required String type,
    required String title,
    required String body,
    String? treatmentPlanId,
  }) async {
    await _client.from('app_notifications').insert({
      'user_id': userId,
      'actor_id': currentUserId,
      'type': type,
      'title': title,
      'body': body,
      'treatment_plan_id': treatmentPlanId,
    });
  }

  static Future<void> markNotificationRead(String notificationId) async {
    await _client
        .from('app_notifications')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('id', notificationId);
  }

  static Future<void> markAllNotificationsRead() async {
    final userId = currentUserId;
    if (userId == null) return;
    await _client
        .from('app_notifications')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('user_id', userId)
        .filter('read_at', 'is', null);
  }

  // ─── Diary Entries ─────────────────────────────────────────────────────────

  static Future<List<DiaryEntry>> getDiaryEntries(String userId) async {
    final data = await _client
        .from('diary_entries')
        .select()
        .eq('user_id', userId)
        .order('date_time', ascending: false);
    return (data as List).map((row) {
      final m = row as Map<String, dynamic>;
      return DiaryEntry(
        id: m['id'] as String,
        dateTime: DateTime.parse(m['date_time'] as String).toLocal(),
        fatigue: m['fatigue'] as int,
        pain: m['pain'] as int,
        mood: m['mood'] as int,
        numbness: m['numbness'] as int? ?? 0,
        coordination: m['coordination'] as int? ?? 0,
        vision: m['vision'] as int? ?? 0,
        weakness: m['weakness'] as int? ?? 0,
        stress: m['stress'] as int? ?? 0,
        sleepHours: (m['sleep_hours'] as num).toDouble(),
        note: m['note'] as String? ?? '',
        flareFlag: m['flare_flag'] as bool? ?? false,
      );
    }).toList();
  }

  static Future<void> insertDiaryEntry(String userId, DiaryEntry entry) async {
    await _client.from('diary_entries').insert({
      'id': entry.id,
      'user_id': userId,
      'date_time': entry.dateTime.toUtc().toIso8601String(),
      'fatigue': entry.fatigue,
      'pain': entry.pain,
      'mood': entry.mood,
      'numbness': entry.numbness,
      'coordination': entry.coordination,
      'vision': entry.vision,
      'weakness': entry.weakness,
      'stress': entry.stress,
      'sleep_hours': entry.sleepHours,
      'note': entry.note,
      'flare_flag': entry.flareFlag,
    });
  }

  static Future<void> updateDiaryEntry(String userId, DiaryEntry entry) async {
    final updated = await _client
        .from('diary_entries')
        .update({
          'date_time': entry.dateTime.toUtc().toIso8601String(),
          'fatigue': entry.fatigue,
          'pain': entry.pain,
          'mood': entry.mood,
          'numbness': entry.numbness,
          'coordination': entry.coordination,
          'vision': entry.vision,
          'weakness': entry.weakness,
          'stress': entry.stress,
          'sleep_hours': entry.sleepHours,
          'note': entry.note,
          'flare_flag': entry.flareFlag,
        })
        .eq('id', entry.id)
        .eq('user_id', userId)
        .select('id')
        .maybeSingle();

    if (updated == null) {
      throw StateError(
        'Запись не найдена или недоступна для текущего пользователя',
      );
    }
  }

  static Future<void> deleteDiaryEntry(String userId, String id) async {
    await _client
        .from('diary_entries')
        .delete()
        .eq('id', id)
        .eq('user_id', userId);
  }

  static Future<void> deleteAllDiaryEntries(String userId) async {
    await _client.from('diary_entries').delete().eq('user_id', userId);
  }

  // ─── Test Results ──────────────────────────────────────────────────────────

  static Future<List<TestResult>> getTestResults(String userId) async {
    final data = await _client
        .from('test_results')
        .select()
        .eq('user_id', userId)
        .order('date_time', ascending: false);
    return (data as List).map((row) {
      final m = row as Map<String, dynamic>;
      return TestResult(
        id: m['id'] as String,
        type: m['type'] as String,
        dateTime: DateTime.parse(m['date_time'] as String),
        value: (m['value'] as num).toDouble(),
        durationSeconds: m['duration_seconds'] as int,
        hand: m['hand'] as String?,
        metadataJson: m['metadata_json'] as String?,
      );
    }).toList();
  }

  static Future<void> insertTestResult(String userId, TestResult result) async {
    await _client.from('test_results').insert({
      'id': result.id,
      'user_id': userId,
      'type': result.type,
      'date_time': result.dateTime.toIso8601String(),
      'value': result.value,
      'duration_seconds': result.durationSeconds,
      'hand': result.hand,
      'metadata_json': result.metadataJson,
    });
  }

  static Future<void> deleteTestResult(String userId, String id) async {
    await _client
        .from('test_results')
        .delete()
        .eq('id', id)
        .eq('user_id', userId);
  }

  static Future<void> deleteAllTestResults(String userId) async {
    await _client.from('test_results').delete().eq('user_id', userId);
  }

  // ─── App Settings ──────────────────────────────────────────────────────────

  static Future<AppSettings> getSettings(String userId) async {
    final data = await _client
        .from('app_settings')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (data == null) return const AppSettings();
    return AppSettings(
      diaryReminderEnabled: data['diary_reminder_enabled'] as bool? ?? true,
      tappingReminderEnabled: data['tapping_reminder_enabled'] as bool? ?? true,
      reactionReminderEnabled:
          data['reaction_reminder_enabled'] as bool? ?? true,
      diaryReminderTime: data['diary_reminder_time'] as String? ?? '20:00',
      tappingReminderTime: data['tapping_reminder_time'] as String? ?? '10:00',
      reactionReminderTime:
          data['reaction_reminder_time'] as String? ?? '11:00',
      notificationsEnabled: data['notifications_enabled'] as bool? ?? true,
      symptomScaleMax: AppSettings.fromJson({
        'symptomScaleMax': data['symptom_scale_max'],
      }).symptomScaleMax,
      symptomScaleUnit: data['symptom_scale_unit'] as String? ?? 'баллов',
      sleepUnit: data['sleep_unit'] as String? ?? 'ч',
      tappingUnit: data['tapping_unit'] as String? ?? 'уд/с',
    );
  }

  static Future<void> upsertSettings(
    String userId,
    AppSettings settings,
  ) async {
    await _client.from('app_settings').upsert({
      'user_id': userId,
      'diary_reminder_enabled': settings.diaryReminderEnabled,
      'tapping_reminder_enabled': settings.tappingReminderEnabled,
      'reaction_reminder_enabled': settings.reactionReminderEnabled,
      'diary_reminder_time': settings.diaryReminderTime,
      'tapping_reminder_time': settings.tappingReminderTime,
      'reaction_reminder_time': settings.reactionReminderTime,
      'notifications_enabled': settings.notificationsEnabled,
      'symptom_scale_max': settings.symptomScaleMax,
      'symptom_scale_unit': settings.symptomScaleUnit,
      'sleep_unit': settings.sleepUnit,
      'tapping_unit': settings.tappingUnit,
    }, onConflict: 'user_id');
  }

  static Future<void> upsertScaleUnitSettings(
    String userId, {
    required int symptomScaleMax,
    required String symptomScaleUnit,
    required String sleepUnit,
    required String tappingUnit,
  }) async {
    await _client.from('app_settings').upsert({
      'user_id': userId,
      'symptom_scale_max': symptomScaleMax,
      'symptom_scale_unit': symptomScaleUnit,
      'sleep_unit': sleepUnit,
      'tapping_unit': tappingUnit,
    }, onConflict: 'user_id');
  }
}
