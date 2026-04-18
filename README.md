# 🎵 AudioSecure — Guide de démarrage complet

## 📁 Structure du projet

```
lib/
├── main.dart                    # Point d'entrée
├── firebase_options.dart        # Configuration Firebase (À MODIFIER)
├── models/
│   ├── user_model.dart          # Modèle utilisateur
│   └── audio_track.dart        # Modèle morceau audio
├── services/
│   ├── auth_service.dart        # Firebase Auth
│   ├── biometric_service.dart   # Empreinte digitale
│   ├── audio_api_service.dart   # API Quran externe
│   ├── stats_service.dart       # Statistiques d'écoute
│   └── favorites_service.dart   # Favoris Firebase
└── screens/
    ├── biometric_screen.dart    # Écran 1 : Empreinte
    ├── login_screen.dart        # Écran 2a : Connexion
    ├── register_screen.dart     # Écran 2b : Inscription
    ├── home_screen.dart         # Écran 3 : Statistiques
    ├── player_screen.dart       # Écran 4 : Lecteur audio
    └── favorites_screen.dart   # Écran 5 : Favoris
assets/
└── sounds/
    └── success.mp3              # Son de succès (à ajouter)
```

---

## ⚙️ Étape 1 — Prérequis

Installez les outils suivants :
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (version 3.x)
- Android Studio avec un émulateur Android (API 28+) **ou** un vrai téléphone Android
- Un compte [Firebase](https://console.firebase.google.com/)

Vérifiez l'installation :
```bash
flutter doctor
```

---

## 🔥 Étape 2 — Configurer Firebase

### 2.1 Créer un projet Firebase
1. Allez sur https://console.firebase.google.com/
2. Cliquez "Ajouter un projet" → donnez un nom
3. Désactivez Google Analytics (optionnel) → "Créer le projet"

### 2.2 Activer Authentication
1. Dans Firebase Console → **Authentication** → "Commencer"
2. Onglet "Sign-in method" → Activez **Email/mot de passe**

### 2.3 Créer Firestore Database
1. Firebase Console → **Firestore Database** → "Créer une base de données"
2. Choisissez "Mode test" (pour développement)
3. Sélectionnez la région `europe-west` (plus proche de l'Algérie)

### 2.4 Ajouter l'app Android
1. Firebase Console → icône engrenage → "Paramètres du projet"
2. Onglet "Vos applications" → icône Android
3. Nom du package : `com.audioapp.audio_app`
4. Téléchargez `google-services.json`
5. Placez-le dans `android/app/google-services.json`

### 2.5 Générer firebase_options.dart
```bash
# Installer FlutterFire CLI
dart pub global activate flutterfire_cli

# Dans le dossier du projet :
flutterfire configure
```
Cela va **remplacer automatiquement** votre `firebase_options.dart` avec les vraies valeurs.

---

## 📦 Étape 3 — Installer les dépendances

```bash
cd audio_app
flutter pub get
```

---

## 🎵 Étape 4 — Ajouter le son de succès

Téléchargez un fichier MP3 court (son de succès) et placez-le ici :
```
assets/sounds/success.mp3
```
Vous pouvez utiliser n'importe quel son court (ex: depuis freesound.org).
Si vous n'en avez pas, le code fonctionnera quand même (le son est optionnel).

---

## 📱 Étape 5 — Configurer Android

### 5.1 Modifier android/app/src/main/AndroidManifest.xml

Ouvrez ce fichier et ajoutez ces permissions **avant** la balise `<application>` :

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.USE_BIOMETRIC"/>
<uses-permission android:name="android.permission.USE_FINGERPRINT"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
```

Et dans `<application>`, ajoutez le service audio :
```xml
<service
    android:name="com.ryanheise.just_audio.AudioService"
    android:exported="false">
</service>
```

### 5.2 Modifier android/app/build.gradle

Vérifiez que `minSdkVersion` est au moins **23** :
```gradle
android {
    defaultConfig {
        minSdkVersion 23
        targetSdkVersion 34
    }
}
```

### 5.3 Modifier android/build.gradle (racine)

Ajoutez dans `buildscript > dependencies` :
```gradle
classpath 'com.google.gms:google-services:4.4.0'
```

Et en bas de `android/app/build.gradle`, ajoutez :
```gradle
apply plugin: 'com.google.gms.google-services'
```

---

## 🚀 Étape 6 — Lancer l'application

### Sur un émulateur Android :
```bash
# Démarrer un émulateur (depuis Android Studio ou AVD Manager)
# Puis :
flutter run
```

### Sur un vrai téléphone Android :
1. Activez les **options développeur** sur votre téléphone
2. Activez **Débogage USB**
3. Connectez le téléphone par USB
4. ```bash
   flutter run
   ```

### Build APK pour installer :
```bash
flutter build apk --release
# L'APK se trouve dans : build/outputs/flutter-apk/app-release.apk
```

---

## 🔐 Fonctionnalités implémentées

| Fonctionnalité | Statut |
|---|---|
| Authentification biométrique (empreinte) | ✅ |
| Son de succès après biométrie | ✅ |
| Redirection paramètres si pas d'empreinte | ✅ |
| Inscription avec nom, prénom, date de naissance | ✅ |
| Vérification âge ≥ 13 ans | ✅ |
| Connexion / Déconnexion Firebase | ✅ |
| Réinitialisation mot de passe | ✅ |
| Page statistiques avec message de bienvenue | ✅ |
| Histogramme minutes par jour | ✅ |
| Total heures/minutes du mois | ✅ |
| Top morceaux écoutés | ✅ |
| Barre de progression vers objectif | ✅ |
| Objectif configurable (menu déroulant) | ✅ |
| Lecteur audio avec API externe (Quran) | ✅ |
| Lecture en arrière-plan | ✅ |
| Playlist par catégories | ✅ |
| Lecture / Pause / Répétition | ✅ |
| Favoris sauvegardés sur Firebase | ✅ |
| Suppression favoris protégée par empreinte | ✅ |

---

## ❓ Problèmes courants

**"No fingerprints enrolled"** : Allez dans Paramètres du téléphone → Sécurité → Empreinte digitale et ajoutez une empreinte.

**"Firebase not initialized"** : Vérifiez que `google-services.json` est bien dans `android/app/` et que firebase_options.dart est généré.

**Erreur de lecture audio** : Vérifiez votre connexion internet (les MP3 viennent d'une API externe).

**`flutter pub get` échoue** : Vérifiez votre version de Flutter avec `flutter --version` (doit être ≥ 3.0).
