import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/audio_track.dart';

class AudioApiService {
  static const String _baseUrl = 'https://quran.yousefheiba.com';

  // Récupérer les sourates (catégories)
  Future<List<Map<String, dynamic>>> fetchCategories() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/en'));
      if (response.statusCode == 200) {
        // L'API retourne du JSON avec les sourates
        final data = json.decode(response.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
        if (data is Map && data.containsKey('chapters')) {
          return List<Map<String, dynamic>>.from(data['chapters']);
        }
      }
    } catch (_) {}
    // Données de secours si l'API ne répond pas
    return _fallbackCategories();
  }

  // Récupérer les morceaux d'une catégorie
  Future<List<AudioTrack>> fetchTracksForCategory(
      Map<String, dynamic> category) async {
    final List<AudioTrack> tracks = [];
    try {
      final chapterId = category['id'] ?? category['chapter_number'] ?? 1;
      final response =
          await http.get(Uri.parse('$_baseUrl/en/$chapterId'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List verses = [];
        if (data is List) {
          verses = data;
        } else if (data is Map && data.containsKey('verses')) {
          verses = data['verses'];
        }
        for (final verse in verses) {
          final audioUrl = verse['audio']?['url'] ??
              verse['audio_url'] ??
              'https://cdn.islamic.network/quran/audio/128/ar.alafasy/${verse['verse_number'] ?? 1}.mp3';
          tracks.add(AudioTrack(
            id: '${chapterId}_${verse['verse_number'] ?? verse['id']}',
            title:
                '${category['name_simple'] ?? 'Chapitre'} - Verset ${verse['verse_number'] ?? verse['id']}',
            category: category['name_simple'] ?? 'Chapitre $chapterId',
            audioUrl: audioUrl,
          ));
        }
      }
    } catch (_) {}

    // Si rien récupéré, retourner des morceaux de secours
    if (tracks.isEmpty) {
      return _fallbackTracks(category);
    }
    return tracks;
  }

  // Données de secours : sourates du Coran (Islamic Network CDN)
  List<Map<String, dynamic>> _fallbackCategories() {
    return [
      {'id': 1, 'name_simple': 'Al-Fatiha', 'verses_count': 7},
      {'id': 2, 'name_simple': 'Al-Baqarah', 'verses_count': 286},
      {'id': 3, 'name_simple': 'Al-Imran', 'verses_count': 200},
      {'id': 36, 'name_simple': 'Ya-Sin', 'verses_count': 83},
      {'id': 67, 'name_simple': 'Al-Mulk', 'verses_count': 30},
      {'id': 112, 'name_simple': 'Al-Ikhlas', 'verses_count': 4},
      {'id': 113, 'name_simple': 'Al-Falaq', 'verses_count': 5},
      {'id': 114, 'name_simple': 'An-Nas', 'verses_count': 6},
    ];
  }

  List<AudioTrack> _fallbackTracks(Map<String, dynamic> category) {
    final chapterId = category['id'] ?? 1;
    final count = (category['verses_count'] as int? ?? 5).clamp(1, 10);
    return List.generate(count, (i) {
      final verseNum = i + 1;
      return AudioTrack(
        id: '${chapterId}_$verseNum',
        title: '${category['name_simple']} - Verset $verseNum',
        category: category['name_simple'] ?? 'Chapitre',
        audioUrl:
            'https://cdn.islamic.network/quran/audio/128/ar.alafasy/${_getAbsoluteVerseNumber(chapterId, verseNum)}.mp3',
      );
    });
  }

  // Numéro de verset absolu (simplifié)
  int _getAbsoluteVerseNumber(int chapter, int verse) {
    const chapterOffsets = {
      1: 0, 2: 7, 3: 293, 36: 2855, 67: 5673, 112: 6219, 113: 6223, 114: 6228
    };
    return (chapterOffsets[chapter] ?? 0) + verse;
  }
}
