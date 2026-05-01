import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/audio_track.dart';

class StatsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _goalKey = 'monthly_goal_hours';
  static const String _dailyStatsKey = 'local_daily_stats';
  static const String _trackStatsKey = 'local_track_stats';

  // Enregistrer une session d'écoute
  Future<void> recordListening({
    required String uid,
    required AudioTrack track,
    required int secondsListened,
  }) async {
    if (secondsListened < 2) return; // ignorer les écoutes trop courtes

    final now = DateTime.now();
    final dateKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // Mettre à jour stats journalières (Firestore)
    try {
      final dayRef = _db
          .collection('users')
          .doc(uid)
          .collection('daily_stats')
          .doc(dateKey);

      await dayRef.set({
        'minutes': FieldValue.increment(secondsListened / 60),
        'date': dateKey,
      }, SetOptions(merge: true));

      // Mettre à jour compteur global du morceau
      final trackRef = _db
          .collection('users')
          .doc(uid)
          .collection('track_stats')
          .doc(track.id);

      await trackRef.set({
        'trackId': track.id,
        'title': track.title,
        'category': track.category,
        'playCount': FieldValue.increment(1),
        'totalSeconds': FieldValue.increment(secondsListened),
      }, SetOptions(merge: true));
    } catch (_) {
      // Ignorer si Firestore est indisponible
    }

    // Mettre à jour stats locales (fallback)
    await _updateLocalDailyStats(dateKey, secondsListened / 60);
    await _updateLocalTrackStats(track, secondsListened);
  }

  // Récupérer stats du mois en cours (minutes par jour)
  Future<Map<String, double>> getMonthlyDailyMinutes(String uid) async {
    final now = DateTime.now();
    final monthPrefix =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    try {
      final snapshot = await _db
          .collection('users')
          .doc(uid)
          .collection('daily_stats')
          .where('date', isGreaterThanOrEqualTo: '$monthPrefix-01')
          .where('date', isLessThanOrEqualTo: '$monthPrefix-31')
          .get()
          .timeout(const Duration(seconds: 4));

      final Map<String, double> result = {};
      for (final doc in snapshot.docs) {
        result[doc.id] = (doc.data()['minutes'] as num).toDouble();
      }
      if (result.isNotEmpty) return result;
    } catch (_) {
      // Fallback local
    }

    return _getLocalDailyMinutes(monthPrefix);
  }

  // Total heures/minutes du mois
  Future<Duration> getMonthlyTotal(String uid) async {
    final daily = await getMonthlyDailyMinutes(uid);
    final totalMinutes = daily.values.fold(0.0, (a, b) => a + b);
    return Duration(minutes: totalMinutes.round());
  }

  // Morceaux les plus écoutés
  Future<List<Map<String, dynamic>>> getTopTracks(String uid,
      {int limit = 5}) async {
    try {
      final snapshot = await _db
          .collection('users')
          .doc(uid)
          .collection('track_stats')
          .orderBy('playCount', descending: true)
          .limit(limit)
          .get()
          .timeout(const Duration(seconds: 4));

      final data = snapshot.docs.map((d) => d.data()).toList();
      if (data.isNotEmpty) return data;
    } catch (_) {
      // Fallback local
    }

    return _getLocalTopTracks(limit);
  }

  // Objectif mensuel (sauvegardé localement)
  Future<int> getMonthlyGoalHours() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_goalKey) ?? 20;
  }

  Future<void> setMonthlyGoalHours(int hours) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_goalKey, hours);
  }

  Future<Map<String, double>> _getLocalDailyMinutes(String monthPrefix) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_dailyStatsKey);
    if (raw == null) return {};
    final Map<String, dynamic> data = jsonDecode(raw);
    final Map<String, double> result = {};
    data.forEach((key, value) {
      if (key.startsWith(monthPrefix)) {
        result[key] = (value as num).toDouble();
      }
    });
    return result;
  }

  Future<void> _updateLocalDailyStats(String dateKey, double minutes) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_dailyStatsKey);
    final Map<String, dynamic> data =
        raw == null ? {} : (jsonDecode(raw) as Map<String, dynamic>);
    final current = (data[dateKey] as num?)?.toDouble() ?? 0.0;
    data[dateKey] = current + minutes;
    await prefs.setString(_dailyStatsKey, jsonEncode(data));
  }

  Future<void> _updateLocalTrackStats(
      AudioTrack track, int secondsListened) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_trackStatsKey);
    final Map<String, dynamic> data =
        raw == null ? {} : (jsonDecode(raw) as Map<String, dynamic>);

    final Map<String, dynamic> current =
        (data[track.id] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{
              'trackId': track.id,
              'title': track.title,
              'category': track.category,
              'playCount': 0,
              'totalSeconds': 0,
            };

    current['playCount'] = (current['playCount'] as num) + 1;
    current['totalSeconds'] =
        (current['totalSeconds'] as num) + secondsListened;
    data[track.id] = current;

    await prefs.setString(_trackStatsKey, jsonEncode(data));
  }

  Future<List<Map<String, dynamic>>> _getLocalTopTracks(int limit) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_trackStatsKey);
    if (raw == null) return [];
    final Map<String, dynamic> data = jsonDecode(raw);
    final list = data.values
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
    list.sort((a, b) =>
        (b['playCount'] as num).compareTo(a['playCount'] as num));
    return list.take(limit).toList();
  }
}
