import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/audio_track.dart';

class FavoritesService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Récupérer les favoris en temps réel
  Stream<List<AudioTrack>> favoritesStream(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => AudioTrack.fromMap(d.data())).toList());
  }

  // Ajouter aux favoris
  Future<void> addFavorite(String uid, AudioTrack track) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .doc(track.id)
        .set(track.toMap());
  }

  // Supprimer des favoris (nécessite biométrie — appelée depuis l'UI)
  Future<void> removeFavorite(String uid, String trackId) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .doc(trackId)
        .delete();
  }

  // Vérifier si un morceau est dans les favoris
  Future<bool> isFavorite(String uid, String trackId) async {
    final doc = await _db
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .doc(trackId)
        .get();
    return doc.exists;
  }
}
