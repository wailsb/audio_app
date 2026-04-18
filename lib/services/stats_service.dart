import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/audio_track.dart';

class StatsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _goalKey = 'monthly_goal_hours';

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

    // Mettre à jour stats journalières
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
  }

  // Récupérer stats du mois en cours (minutes par jour)
  Future<Map<String, double>> getMonthlyDailyMinutes(String uid) async {
    final now = DateTime.now();
    final monthPrefix =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';

    final snapshot = await _db
        .collection('users')
        .doc(uid)
        .collection('daily_stats')
        .where('date', isGreaterThanOrEqualTo: '$monthPrefix-01')
        .where('date', isLessThanOrEqualTo: '$monthPrefix-31')
        .get();

    final Map<String, double> result = {};
    for (final doc in snapshot.docs) {
      result[doc.id] = (doc.data()['minutes'] as num).toDouble();
    }
    return result;
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
    final snapshot = await _db
        .collection('users')
        .doc(uid)
        .collection('track_stats')
        .orderBy('playCount', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map((d) => d.data()).toList();
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
}
