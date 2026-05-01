import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:audio_session/audio_session.dart';
import '../services/audio_api_service.dart';
import '../services/stats_service.dart';
import '../services/favorites_service.dart';
import '../services/biometric_service.dart';
import '../models/audio_track.dart';

class PlayerScreen extends StatefulWidget {
  final String uid;
  const PlayerScreen({super.key, required this.uid});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final AudioApiService _apiService = AudioApiService();
  final StatsService _statsService = StatsService();
  final FavoritesService _favService = FavoritesService();
  final BiometricService _bioService = BiometricService();
  final AudioPlayer _player = AudioPlayer();

  List<Map<String, dynamic>> _categories = [];
  Map<String, List<AudioTrack>> _tracksByCategory = {};
  AudioTrack? _currentTrack;
  bool _loadingCategories = true;
  bool _loadingTracks = false;
  bool _isRepeat = false;
  Map<String, bool> _favStatus = {};
  DateTime? _playStartTime;
  int? _expandedIndex;

  @override
  void initState() {
    super.initState();
    _initAudioSession();
    _fetchCategories();
    _player.playerStateStream.listen(_onPlayerStateChanged);
  }

  Future<void> _initAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  }

  Future<void> _fetchCategories() async {
    setState(() => _loadingCategories = true);
    final cats = await _apiService.fetchCategories();
    setState(() {
      _categories = cats;
      _loadingCategories = false;
    });
  }

  Future<void> _loadCategoryTracks(Map<String, dynamic> category, int index) async {
    if (_tracksByCategory.containsKey(index.toString())) {
      setState(() => _expandedIndex = _expandedIndex == index ? null : index);
      return;
    }
    setState(() { _loadingTracks = true; _expandedIndex = index; });
    final tracks = await _apiService.fetchTracksForCategory(category);
    setState(() {
      _tracksByCategory[index.toString()] = tracks;
      _loadingTracks = false;
    });
  }

  Future<void> _playTrack(AudioTrack track) async {
    // Sauvegarder les stats de la piste précédente
    if (_currentTrack != null && _playStartTime != null) {
      final seconds = DateTime.now().difference(_playStartTime!).inSeconds;
      await _statsService.recordListening(
        uid: widget.uid,
        track: _currentTrack!,
        secondsListened: seconds,
      );
    }

    setState(() { _currentTrack = track; _playStartTime = DateTime.now(); });

    try {
      final source = AudioSource.uri(
        Uri.parse(track.audioUrl),
        tag: MediaItem(
          id: track.id,
          title: track.title,
          album: track.category,
        ),
      );
      await _player.setAudioSource(source);
      await _player.play();
      // Vérifier favori
      final isFav = await _favService.isFavorite(widget.uid, track.id);
      setState(() => _favStatus[track.id] = isFav);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de lecture: $e')),
        );
      }
    }
  }

  void _onPlayerStateChanged(PlayerState state) {
    if (state.processingState == ProcessingState.completed) {
      if (_isRepeat && _currentTrack != null) {
        _player.seek(Duration.zero);
        _player.play();
      }
    }
  }

  Future<void> _toggleFavorite(AudioTrack track) async {
    final isFav = _favStatus[track.id] ?? false;
    if (isFav) {
      // Supprimer → nécessite biométrie
      final auth = await _bioService.authenticate(
        reason: 'Confirmez la suppression du favori',
      );
      if (!auth.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Authentification biométrique requise')),
          );
        }
        return;
      }
      await _favService.removeFavorite(widget.uid, track.id);
    } else {
      await _favService.addFavorite(widget.uid, track);
    }
    setState(() => _favStatus[track.id] = !isFav);
  }

  @override
  void dispose() {
    // Sauvegarder stats à la fermeture
    if (_currentTrack != null && _playStartTime != null) {
      final seconds = DateTime.now().difference(_playStartTime!).inSeconds;
      _statsService.recordListening(
        uid: widget.uid,
        track: _currentTrack!,
        secondsListened: seconds,
      );
    }
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Mini lecteur
        if (_currentTrack != null) _buildMiniPlayer(),

        // Liste catégories
        Expanded(
          child: _loadingCategories
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _categories.length,
                  itemBuilder: (_, i) => _buildCategoryTile(i),
                ),
        ),
      ],
    );
  }

  Widget _buildCategoryTile(int i) {
    final cat = _categories[i];
    final isExpanded = _expandedIndex == i;
    final tracks = _tracksByCategory[i.toString()] ?? [];
    final dynamicCount = tracks.isNotEmpty
        ? tracks.length
        : (cat['verses_count'] ?? cat['versesCount'] ?? cat['verses']?.length);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF6C63FF).withOpacity(0.2),
              child: const Icon(Icons.album, color: Color(0xFF6C63FF)),
            ),
            title: Text(
              cat['name_simple'] ?? 'Catégorie ${i + 1}',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${dynamicCount ?? '?'} morceaux',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
            trailing: Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              color: Colors.white38,
            ),
            onTap: () => _loadCategoryTracks(cat, i),
          ),
          if (isExpanded) ...[
            if (_loadingTracks && tracks.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
              )
            else
              ...tracks.map((t) => _buildTrackTile(t)),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }

  Widget _buildTrackTile(AudioTrack track) {
    final isPlaying = _currentTrack?.id == track.id;
    final isFav = _favStatus[track.id] ?? false;
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(
        isPlaying ? Icons.graphic_eq : Icons.music_note_outlined,
        color: isPlaying ? const Color(0xFF6C63FF) : Colors.white38,
      ),
      title: Text(
        track.title,
        style: TextStyle(
          color: isPlaying ? const Color(0xFF6C63FF) : Colors.white70,
          fontSize: 13,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        icon: Icon(
          isFav ? Icons.favorite : Icons.favorite_border,
          color: isFav ? Colors.redAccent : Colors.white38,
          size: 20,
        ),
        onPressed: () => _toggleFavorite(track),
      ),
      onTap: () => _playTrack(track),
    );
  }

  Widget _buildMiniPlayer() {
    return StreamBuilder<PlayerState>(
      stream: _player.playerStateStream,
      builder: (_, snap) {
        final isPlaying = snap.data?.playing ?? false;
        //final pos = _player.position;
        //final dur = _player.duration ?? Duration.zero;

        return Container(
          color: const Color(0xFF1A1A2E),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            children: [
              // Titre et contrôles
              Row(
                children: [
                  const Icon(Icons.music_note,
                      color: Color(0xFF6C63FF), size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _currentTrack!.title,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Répétition
                  IconButton(
                    icon: Icon(Icons.repeat,
                        color: _isRepeat
                            ? const Color(0xFF6C63FF)
                            : Colors.white38,
                        size: 20),
                    onPressed: () => setState(() => _isRepeat = !_isRepeat),
                  ),
                  // Favori
                  IconButton(
                    icon: Icon(
                      (_favStatus[_currentTrack!.id] ?? false)
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: (_favStatus[_currentTrack!.id] ?? false)
                          ? Colors.redAccent
                          : Colors.white38,
                      size: 20,
                    ),
                    onPressed: () => _toggleFavorite(_currentTrack!),
                  ),
                  // Play/Pause
                  IconButton(
                    icon: Icon(
                      isPlaying ? Icons.pause_circle : Icons.play_circle,
                      color: const Color(0xFF6C63FF),
                      size: 36,
                    ),
                    onPressed: () =>
                        isPlaying ? _player.pause() : _player.play(),
                  ),
                ],
              ),
              // Barre de progression
              StreamBuilder<Duration>(
                stream: _player.positionStream,
                builder: (_, posSnap) {
                  final position = posSnap.data ?? Duration.zero;
                  final duration = _player.duration ?? Duration.zero;
                  final progress = duration.inMilliseconds > 0
                      ? position.inMilliseconds / duration.inMilliseconds
                      : 0.0;
                  return SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                    ),
                    child: Slider(
                      value: progress.clamp(0.0, 1.0),
                      activeColor: const Color(0xFF6C63FF),
                      inactiveColor: Colors.white12,
                      onChanged: (v) {
                        final newPos = Duration(
                            milliseconds:
                                (v * duration.inMilliseconds).round());
                        _player.seek(newPos);
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
