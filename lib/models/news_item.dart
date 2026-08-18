enum NewsType { live, tutorial, news }

class NewsItemModel {
  final String id;
  final String title;
  final String description;
  final String category;
  final NewsType type;
  final String imageUrl;
  final String? videoUrl;
  final DateTime publishedAt;
  final bool isLive;

  NewsItemModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.type,
    required this.imageUrl,
    this.videoUrl,
    required this.publishedAt,
    this.isLive = false,
  });

  factory NewsItemModel.fromMap(Map<String, dynamic> map, String id) {
    NewsType type = NewsType.news;
    if (map['type'] == 'live') type = NewsType.live;
    if (map['type'] == 'tutorial') type = NewsType.tutorial;

    return NewsItemModel(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? 'Beach Tennis',
      type: type,
      imageUrl: map['imageUrl'] ?? 'https://images.unsplash.com/photo-1595435934249-5df7ed86e1c0',
      videoUrl: map['videoUrl'],
      publishedAt: map['publishedAt'] != null ? (map['publishedAt'] as dynamic).toDate() : DateTime.now(),
      isLive: map['isLive'] ?? false,
    );
  }
}
