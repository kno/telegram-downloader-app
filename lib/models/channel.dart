class Channel {
  final int id;
  final String chatId;
  final String name;
  final String? username;
  bool enabled;

  Channel({
    required this.id,
    required this.chatId,
    required this.name,
    this.username,
    this.enabled = true,
  });

  factory Channel.fromJson(Map<String, dynamic> json) => Channel(
        id: json['id'] ?? 0,
        chatId: json['chatId'] ?? '',
        name: json['name'] ?? '',
        username: json['username'],
        enabled: json['enabled'] ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'chatId': chatId,
        'name': name,
        'username': username,
        'enabled': enabled,
      };
}
