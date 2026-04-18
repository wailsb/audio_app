import 'package:flutter/material.dart';
import '../services/favorites_service.dart';
import '../services/biometric_service.dart';
import '../models/audio_track.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

class FavoritesScreen extends StatefulWidget {
  final String uid;
  const FavoritesScreen({super.key, required this.uid});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final FavoritesService _favService = FavoritesService();
  final BiometricService _bioService = BiometricService();
  final AudioPlayer _player = AudioPlayer();
  AudioTrack? _currentTrack;

  Future<void> _playTrack(AudioTrack track) async {
    setState(() => _currentTrack = track);
    try {
      await _player.setAudioSource(AudioSource.uri(
        Uri.parse(track.audioUrl),
        tag: MediaItem(
          id: track.id,
          title: track.title,
          album: track.category,
        ),
      ));
      await _player.play();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _deleteFavorite(AudioTrack track) async {
    final auth = await _bioService.authenticate(
      reason: 'Confirmez la suppression de "${track.title}" des favoris',
    );
    if (!auth) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Authentification biométrique requise pour supprimer')),
        );
      }
      return;
    }
    await _favService.removeFavorite(widget.uid, track.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Retiré des favoris')),
      );
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Mini lecteur si en cours
        if (_currentTrack != null)
          StreamBuilder<PlayerState>(
            stream: _player.playerStateStream,
            builder: (_, snap) {
              final isPlaying = snap.data?.playing ?? false;
              return Container(
                color: const Color(0xFF1A1A2E),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.music_note,
                        color: Color(0xFF6C63FF), size: 26),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _currentTrack!.title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                          isPlaying ? Icons.pause_circle : Icons.play_circle,
                          color: const Color(0xFF6C63FF),
                          size: 34),
                      onPressed: () =>
                          isPlaying ? _player.pause() : _player.play(),
                    ),
                  ],
                ),
              );
            },
          ),

        // Liste des favoris
        Expanded(
          child: StreamBuilder<List<AudioTrack>>(
            stream: _favService.favoritesStream(widget.uid),
            builder: (_, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF6C63FF)));
              }
              final favs = snap.data ?? [];
              if (favs.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.favorite_border,
                          size: 60, color: Colors.white24),
                      SizedBox(height: 16),
                      Text('Aucun favori pour l\'instant',
                          style: TextStyle(color: Colors.white38)),
                      SizedBox(height: 8),
                      Text('Ajoutez des morceaux depuis le lecteur',
                          style:
                              TextStyle(color: Colors.white24, fontSize: 12)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: favs.length,
                itemBuilder: (_, i) {
                  final track = favs[i];
                  final isPlaying = _currentTrack?.id == track.id;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A2E),
                      borderRadius: BorderRadius.circular(14),
                      border: isPlaying
                          ? Border.all(
                              color: const Color(0xFF6C63FF), width: 1.5)
                          : null,
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            const Color(0xFF6C63FF).withOpacity(0.2),
                        child: Icon(
                          isPlaying
                              ? Icons.graphic_eq
                              : Icons.music_note,
                          color: const Color(0xFF6C63FF),
                        ),
                      ),
                      title: Text(track.title,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                          overflow: TextOverflow.ellipsis),
                      subtitle: Text(track.category,
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 12)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Supprimer (biométrie requise)
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.redAccent, size: 20),
                            onPressed: () => _deleteFavorite(track),
                          ),
                          const Icon(Icons.fingerprint,
                              color: Colors.white24, size: 14),
                        ],
                      ),
                      onTap: () => _playTrack(track),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
