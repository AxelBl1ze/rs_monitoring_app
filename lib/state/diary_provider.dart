import 'package:flutter/foundation.dart';
import '../models/diary_entry.dart';
import '../services/supabase_service.dart';

class DiaryProvider extends ChangeNotifier {
  List<DiaryEntry> _entries = [];
  bool _loading = false;
  String? _error;

  /// All entries, newest first.
  List<DiaryEntry> get entries => _entries;
  List<DiaryEntry> get diaryEntriesSorted => _entries;

  bool get loading => _loading;
  String? get error => _error;
  bool get hasAnyData => _entries.isNotEmpty;

  // ─── Computed helpers ────────────────────────────────────────────────────

  DiaryEntry? get todayDiaryEntry {
    final today = DateTime.now();
    for (final e in _entries) {
      if (e.dateTime.year == today.year &&
          e.dateTime.month == today.month &&
          e.dateTime.day == today.day) {
        return e;
      }
    }
    return null;
  }

  bool get hasTodayDiaryEntry => todayDiaryEntry != null;

  List<DiaryEntry> getByPeriod(DateTime from, DateTime to) {
    return _entries
        .where((e) => !e.dateTime.isBefore(from) && !e.dateTime.isAfter(to))
        .toList();
  }

  List<DiaryEntry> lastDays(int days) {
    final from = DateTime.now().subtract(Duration(days: days - 1));
    final start = DateTime(from.year, from.month, from.day);
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    return getByPeriod(start, end);
  }

  double? averageLastDays(double Function(DiaryEntry) metric, int days) {
    final subset = lastDays(days);
    if (subset.isEmpty) return null;
    return subset.fold<double>(0, (s, e) => s + metric(e)) / subset.length;
  }

  double? percentChange(double Function(DiaryEntry) metric, int windowDays) {
    final now = DateTime.now();
    final mid = now.subtract(Duration(days: windowDays));
    final start = now.subtract(Duration(days: windowDays * 2));

    final current = getByPeriod(mid, now);
    final previous = getByPeriod(
      start,
      mid.subtract(const Duration(seconds: 1)),
    );
    if (current.isEmpty || previous.isEmpty) return null;

    final avgCurrent =
        current.fold<double>(0, (s, e) => s + metric(e)) / current.length;
    final avgPrevious =
        previous.fold<double>(0, (s, e) => s + metric(e)) / previous.length;
    if (avgPrevious == 0) return null;
    return ((avgCurrent - avgPrevious) / avgPrevious * 100);
  }

  // ─── Load ────────────────────────────────────────────────────────────────

  Future<void> load({bool silent = false}) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    if (!silent) {
      _loading = true;
      notifyListeners();
    }
    try {
      _entries = await SupabaseService.getDiaryEntries(userId);
      _error = null;
    } catch (e) {
      _error = 'Не удалось загрузить записи дневника';
    } finally {
      if (!silent) {
        _loading = false;
      }
    }
    notifyListeners();
  }

  // ─── Write ───────────────────────────────────────────────────────────────

  Future<void> add(DiaryEntry entry) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      _error = 'Не удалось сохранить запись';
      notifyListeners();
      throw StateError('Пользователь не авторизован');
    }
    try {
      await load(silent: true);
      // Prevent creating duplicate entries for the same calendar day.
      final existingIdx = _entries.indexWhere(
        (e) =>
            e.dateTime.year == entry.dateTime.year &&
            e.dateTime.month == entry.dateTime.month &&
            e.dateTime.day == entry.dateTime.day,
      );
      if (existingIdx != -1) {
        // Update the existing entry instead of inserting a new one.
        final existing = _entries[existingIdx];
        final updated = DiaryEntry(
          id: existing.id,
          dateTime: entry.dateTime,
          fatigue: entry.fatigue,
          pain: entry.pain,
          mood: entry.mood,
          numbness: entry.numbness,
          coordination: entry.coordination,
          vision: entry.vision,
          weakness: entry.weakness,
          stress: entry.stress,
          sleepHours: entry.sleepHours,
          note: entry.note,
          flareFlag: entry.flareFlag,
        );
        await SupabaseService.updateDiaryEntry(userId, updated);
        // Refresh from server to pick up any server-side changes.
        await load();
        return;
      } else {
        await SupabaseService.insertDiaryEntry(userId, entry);
        // Refresh from server so we get server-assigned fields (id/timestamps).
        await load();
        return;
      }
    } catch (e) {
      _error = 'Не удалось сохранить запись';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> update(DiaryEntry entry) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      _error = 'Не удалось обновить запись';
      notifyListeners();
      throw StateError('Пользователь не авторизован');
    }
    try {
      await SupabaseService.updateDiaryEntry(userId, entry);
      // Refresh to ensure server-side canonical data is reflected.
      await load();
      return;
    } catch (e) {
      _error = 'Не удалось обновить запись';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    try {
      await SupabaseService.deleteDiaryEntry(userId, id);
      _entries.removeWhere((e) => e.id == id);
      _error = null;
    } catch (e) {
      _error = 'Не удалось удалить запись';
    }
    notifyListeners();
  }

  Future<void> deleteAll() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    try {
      await SupabaseService.deleteAllDiaryEntries(userId);
      _entries = [];
      _error = null;
    } catch (e) {
      _error = 'Не удалось очистить записи';
    }
    notifyListeners();
  }

  void clear() {
    _entries = [];
    _error = null;
    notifyListeners();
  }
}
