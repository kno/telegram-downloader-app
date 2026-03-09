class SessionStats {
  final int activeTorrentCount;
  final int pausedTorrentCount;
  final int torrentCount;
  final int downloadSpeed;

  SessionStats({
    required this.activeTorrentCount,
    required this.pausedTorrentCount,
    required this.torrentCount,
    required this.downloadSpeed,
  });

  factory SessionStats.fromJson(Map<String, dynamic> json) => SessionStats(
        activeTorrentCount: json['activeTorrentCount'] ?? 0,
        pausedTorrentCount: json['pausedTorrentCount'] ?? 0,
        torrentCount: json['torrentCount'] ?? 0,
        downloadSpeed: json['downloadSpeed'] ?? 0,
      );
}
