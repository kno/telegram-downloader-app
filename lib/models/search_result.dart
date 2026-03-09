class SearchResult {
  final String title;
  final String guid;
  final String link;
  final String? pubDate;
  final int size;
  final String description;
  final int categoryId;
  final String channelName;

  SearchResult({
    required this.title,
    required this.guid,
    required this.link,
    this.pubDate,
    required this.size,
    required this.description,
    required this.categoryId,
    this.channelName = '',
  });

  String get chatId => guid.split(':').first;
  int get msgId => int.parse(guid.split(':').last);

  factory SearchResult.fromJson(Map<String, dynamic> json) => SearchResult(
        title: json['title'] ?? '',
        guid: json['guid'] ?? '',
        link: json['link'] ?? '',
        pubDate: json['pubDate'],
        size: json['size'] ?? 0,
        description: json['description'] ?? '',
        categoryId: json['categoryId'] ?? 0,
        channelName: json['channelName'] ?? '',
      );
}

class SearchResponse {
  final int total;
  final int offset;
  final List<SearchResult> items;

  SearchResponse({
    required this.total,
    required this.offset,
    required this.items,
  });

  factory SearchResponse.fromJson(Map<String, dynamic> json) => SearchResponse(
        total: json['total'] ?? 0,
        offset: json['offset'] ?? 0,
        items: (json['items'] as List<dynamic>?)
                ?.map((e) => SearchResult.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}
