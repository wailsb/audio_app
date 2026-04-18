import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../services/biometric_service.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'home_screen.dart';

class BiometricScreen extends StatefulWidget {
  const BiometricScreen({super.key});

  @override
  State<BiometricScreen> createState() => _BiometricScreenState();
}

class _BiometricScreenState extends State<BiometricScreen>
    with SingleTickerProviderStateMixin {
  final BiometricService _biometricService = BiometricService();
  final AuthService _authService = AuthService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  late AnimationController _animController;
  late Animation<double> _pulseAnim;

  bool _isAuthenticating = false;
  String _statusMessage = 'Bienvenue sur AudioSecure';
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim =
        Tween<double>(begin: 0.9, end: 1.1).animate(_animController);

    // Lancer automatiquement après chargement
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAuth());
  }

  Future<void> _startAuth() async {
    setState(() {
      _isAuthenticating = true;
      _isError = false;
      _statusMessage = 'Vérification de l\'empreinte digitale...';
    });

    // Vérifier si des empreintes sont enregistrées
    final hasEnrolled = await _biometricService.hasEnrolledBiometrics();
    if (!hasEnrolled) {
      setState(() {
        _statusMessage =
            'Aucune empreinte enregistrée.\nRedirection vers les paramètres...';
        _isError = true;
        _isAuthenticating = false;
      });
      await Future.delayed(const Duration(seconds: 2));
      // Ouvrir les paramètres système (Android)
      // AppSettings.openBiometricSettings() nécessite le package app_settings
      // Pour l'instant, afficher un dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Empreinte requise'),
            content: const Text(
                'Veuillez aller dans Paramètres > Sécurité > Empreinte digitale pour enregistrer une empreinte.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _startAuth();
                },
                child: const Text('Réessayer'),
              ),
            ],
          ),
        );
      }
      return;
    }

    // Authentifier
    final success = await _biometricService.authenticate(
      reason: 'Placez votre doigt pour accéder à AudioSecure',
    );

    if (success) {
      // Émettre son de succès
      await _playSuccessSound();

      setState(() {
        _statusMessage = 'Authentification réussie ✓';
        _isError = false;
        _isAuthenticating = false;
      });

      await Future.delayed(const Duration(milliseconds: 800));

      // Vérifier si déjà connecté sur Firebase
      if (mounted) {
        final currentUser = _authService.currentUser;
        if (currentUser != null) {
          final userData = await _authService.getUserData(currentUser.uid);
          if (userData != null && mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => HomeScreen(user: userData),
              ),
            );
            return;
          }
        }
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } else {
      setState(() {
        _statusMessage = 'Échec de l\'authentification.\nRéessayez.';
        _isError = true;
        _isAuthenticating = false;
      });
    }
  }

  Future<void> _playSuccessSound() async {
    try {
      // Utilise un asset local
      await _audioPlayer.setAsset('assets/sounds/success.mp3');
      await _audioPlayer.play();
      await Future.delayed(const Duration(milliseconds: 1500));
    } catch (_) {
      // Son optionnel, pas critique
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo / Titre
                const Icon(
                  Icons.music_note_rounded,
                  size: 60,
                  color: Color(0xFF6C63FF),
                ),
                const SizedBox(height: 12),
                const Text(
                  'AudioSecure',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 60),

                // Animation empreinte
                ScaleTransition(
                  scale: _pulseAnim,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isError
                          ? Colors.red.withOpacity(0.15)
                          : const Color(0xFF6C63FF).withOpacity(0.15),
                      border: Border.all(
                        color: _isError
                            ? Colors.red
                            : const Color(0xFF6C63FF),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.fingerprint_rounded,
                      size: 70,
                      color: _isError ? Colors.red : const Color(0xFF6C63FF),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Message de statut
                Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: _isError ? Colors.red[300] : Colors.white70,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 40),

                // Bouton réessayer si erreur
                if (_isError && !_isAuthenticating)
                  ElevatedButton.icon(
                    onPressed: _startAuth,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Réessayer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                  ),

                if (_isAuthenticating)
                  const CircularProgressIndicator(
                    color: Color(0xFF6C63FF),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
