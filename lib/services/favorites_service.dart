import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/audio_track.dart';

class FavoritesService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Map<String, StreamController<List<AudioTrack>>> _controllers = {};
  final Map<String, StreamSubscription> _subscriptions = {};

  String _localKey(String uid) => 'local_favorites_$uid';

  // Récupérer les favoris en temps réel
  Stream<List<AudioTrack>> favoritesStream(String uid) {
    final controller = _controllers.putIfAbsent(
      uid,
      () => StreamController<List<AudioTrack>>.broadcast(),
    );

    _emitLocalFavorites(uid);
    _ensureFirestoreListener(uid);
    return controller.stream;
  }

  // Ajouter aux favoris
  Future<void> addFavorite(String uid, AudioTrack track) async {
    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('favorites')
          .doc(track.id)
          .set(track.toMap());
    } catch (_) {
      // Firestore indisponible
    }

    await _saveLocalFavorite(uid, track);
    await _emitLocalFavorites(uid);
  }

  // Supprimer des favoris (nécessite biométrie — appelée depuis l'UI)
  Future<void> removeFavorite(String uid, String trackId) async {
    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('favorites')
          .doc(trackId)
          .delete();
    } catch (_) {
      // Firestore indisponible
    }

    await _removeLocalFavorite(uid, trackId);
    await _emitLocalFavorites(uid);
  }

  // Vérifier si un morceau est dans les favoris
  Future<bool> isFavorite(String uid, String trackId) async {
    try {
      final doc = await _db
          .collection('users')
          .doc(uid)
          .collection('favorites')
          .doc(trackId)
          .get();
      if (doc.exists) return true;
    } catch (_) {
      // Firestore indisponible
    }

    final local = await _getLocalFavorites(uid);
    return local.any((t) => t.id == trackId);
  }

  void _ensureFirestoreListener(String uid) {
    if (_subscriptions.containsKey(uid)) return;
    final sub = _db
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .snapshots()
        .listen((snap) async {
      final list = snap.docs.map((d) => AudioTrack.fromMap(d.data())).toList();
      await _saveLocalFavorites(uid, list);
      _controllers[uid]?.add(list);
    }, onError: (_) {
      // Ignorer les erreurs Firestore
    });
    _subscriptions[uid] = sub;
  }

  Future<void> _emitLocalFavorites(String uid) async {
    final local = await _getLocalFavorites(uid);
    _controllers[uid]?.add(local);
  }

  Future<List<AudioTrack>> _getLocalFavorites(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localKey(uid));
    if (raw == null) return [];
    final List<dynamic> data = jsonDecode(raw);
    return data
        .whereType<Map>()
        .map((e) => AudioTrack.fromMap(e.cast<String, dynamic>()))
        .toList();
  }

  Future<void> _saveLocalFavorites(String uid, List<AudioTrack> tracks) async {
    final prefs = await SharedPreferences.getInstance();
    final data = tracks.map((t) => t.toMap()).toList();
    await prefs.setString(_localKey(uid), jsonEncode(data));
  }

  Future<void> _saveLocalFavorite(String uid, AudioTrack track) async {
    final list = await _getLocalFavorites(uid);
    final updated = [
      ...list.where((t) => t.id != track.id),
      track,
    ];
    await _saveLocalFavorites(uid, updated);
  }

  Future<void> _removeLocalFavorite(String uid, String trackId) async {
    final list = await _getLocalFavorites(uid);
    final updated = list.where((t) => t.id != trackId).toList();
    await _saveLocalFavorites(uid, updated);
  }
}
