import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Inscription
  Future<UserModel?> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required DateTime birthDate,
  }) async {
    // Vérification âge >= 13 ans
    final age = DateTime.now().difference(birthDate).inDays ~/ 365;
    if (age < 13) throw Exception('Vous devez avoir au moins 13 ans.');

    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = UserModel(
      uid: credential.user!.uid,
      email: email,
      firstName: firstName,
      lastName: lastName,
      birthDate: birthDate,
    );

    // Sauvegarder dans Firestore
    try {
      await _db.collection('users').doc(user.uid).set(user.toMap());
    } catch (_) {
      // Firestore peut être désactivé ou les règles peuvent bloquer l'écriture.
      // On continue quand même pour permettre la connexion.
    }

    return user;
  }

  // Connexion
  Future<UserModel?> login({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = credential.user?.uid;
    if (uid == null) return null;

    try {
      final userData = await getUserData(uid);
      if (userData != null) return userData;
    } catch (_) {
      // Firestore indisponible ou document manquant.
    }

    final fallbackUser = UserModel(
      uid: uid,
      email: credential.user?.email ?? email,
      firstName: '',
      lastName: '',
      birthDate: DateTime(1970, 1, 1),
    );

    // Essayer de créer le profil si Firestore est disponible.
    try {
      await _db.collection('users').doc(uid).set(fallbackUser.toMap(), SetOptions(merge: true));
    } catch (_) {
      // Ignorer si Firestore est désactivé.
    }

    return fallbackUser;
  }

  // Récupérer les données utilisateur
  Future<UserModel?> getUserData(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!);
  }

  // Récupérer ou créer un profil local (fallback si Firestore indisponible)
  Future<UserModel> getUserDataOrFallback(User user) async {
    final uid = user.uid;
    try {
      final userData = await getUserData(uid);
      if (userData != null) return userData;
    } catch (_) {
      // Ignorer les erreurs Firestore
    }

    final fallbackUser = UserModel(
      uid: uid,
      email: user.email ?? '',
      firstName: '',
      lastName: '',
      birthDate: DateTime(1970, 1, 1),
    );

    try {
      await _db
          .collection('users')
          .doc(uid)
          .set(fallbackUser.toMap(), SetOptions(merge: true));
    } catch (_) {
      // Ignorer si Firestore est désactivé
    }

    return fallbackUser;
  }

  // Réinitialisation du mot de passe
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // Déconnexion
  Future<void> logout() async {
    await _auth.signOut();
  }
}
