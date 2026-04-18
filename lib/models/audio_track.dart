class AudioTrack {
  final String id;
  final String title;
  final String category;
  final String audioUrl;
  final String? imageUrl;
  int playCount;
  int totalSecondsListened;

  AudioTrack({
    required this.id,
    required this.title,
    required this.category,
    required this.audioUrl,
    this.imageUrl,
    this.playCount = 0,
    this.totalSecondsListened = 0,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'category': category,
        'audioUrl': audioUrl,
        'imageUrl': imageUrl,
        'playCount': playCount,
        'totalSecondsListened': totalSecondsListened,
      };

  factory AudioTrack.fromMap(Map<String, dynamic> map) => AudioTrack(
        id: map['id'] ?? '',
        title: map['title'] ?? '',
        category: map['category'] ?? '',
        audioUrl: map['audioUrl'] ?? '',
        imageUrl: map['imageUrl'],
        playCount: map['playCount'] ?? 0,
        totalSecondsListened: map['totalSecondsListened'] ?? 0,
      );
}
