import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/channel.dart';
import '../models/download.dart';
import '../models/search_result.dart';
import '../models/session_stats.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiService {
  final String baseUrl;
  final String apiKey;
  final http.Client _client;

  ApiService({
    required this.baseUrl,
    required this.apiKey,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Uri _buildUri(String path, [Map<String, String>? queryParams]) {
    final uri = Uri.parse('$baseUrl$path');
    final params = {'apikey': apiKey, ...?queryParams};
    return uri.replace(queryParameters: params);
  }

  Future<dynamic> _get(String path, [Map<String, String>? queryParams]) async {
    final uri = _buildUri(path, queryParams);
    final response = await _client.get(uri);
    _checkResponse(response);
    return jsonDecode(response.body);
  }

  Future<dynamic> _post(String path, [Map<String, String>? queryParams]) async {
    final uri = _buildUri(path, queryParams);
    final response = await _client.post(uri);
    _checkResponse(response);
    if (response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }

  Future<void> _delete(String path, [Map<String, String>? queryParams]) async {
    final uri = _buildUri(path, queryParams);
    final response = await _client.delete(uri);
    _checkResponse(response);
  }

  void _checkResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;

    String message;
    try {
      final body = jsonDecode(response.body);
      message = body['detail'] ?? body['error'] ?? response.reasonPhrase ?? 'Unknown error';
    } catch (_) {
      message = response.reasonPhrase ?? 'HTTP ${response.statusCode}';
    }
    throw ApiException(response.statusCode, message);
  }

  /// Tests connectivity to the backend.
  /// GET /api/v2/health
  Future<bool> testConnection() async {
    try {
      final uri = Uri.parse('$baseUrl/api/v2/health');
      final response = await _client.get(uri);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Fetches all configured Telegram channels.
  /// GET /api/v2/channels?apikey=...
  Future<List<Channel>> fetchChannels() async {
    final data = await _get('/api/v2/channels');
    final list = data as List<dynamic>;
    return list.map((json) => Channel.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Searches for content across Telegram channels.
  /// GET /api/v2/search?apikey=...&q=...&channels=...&season=...&ep=...&offset=...&limit=...
  Future<SearchResponse> search({
    required String query,
    String? channels,
    String? season,
    String? ep,
    int offset = 0,
    int limit = 50,
  }) async {
    final params = <String, String>{
      'q': query,
      'offset': offset.toString(),
      'limit': limit.toString(),
    };
    if (channels != null && channels.isNotEmpty) params['channels'] = channels;
    if (season != null && season.isNotEmpty) params['season'] = season;
    if (ep != null && ep.isNotEmpty) params['ep'] = ep;

    final data = await _get('/api/v2/search', params);
    return SearchResponse.fromJson(data as Map<String, dynamic>);
  }

  /// Fetches all current downloads.
  /// GET /api/v2/downloads?apikey=...
  Future<List<Download>> fetchDownloads() async {
    final data = await _get('/api/v2/downloads');
    final list = data as List<dynamic>;
    return list.map((json) => Download.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Fetches session statistics (active downloads, total size, etc.).
  /// GET /api/v2/stats?apikey=...
  Future<SessionStats> fetchStats() async {
    final data = await _get('/api/v2/stats');
    return SessionStats.fromJson(data as Map<String, dynamic>);
  }

  /// Starts a new download from a Telegram message.
  /// POST /api/v2/downloads?apikey=...&chat_id=...&msg_id=...
  Future<Map<String, dynamic>> addDownload({
    required String chatId,
    required int msgId,
  }) async {
    final data = await _post('/api/v2/downloads', {
      'chat_id': chatId,
      'msg_id': msgId.toString(),
    });
    return data as Map<String, dynamic>;
  }

  /// Removes a download by ID.
  /// DELETE /api/v2/downloads/{id}?apikey=...&delete_file=...
  Future<void> removeDownload(int id, {bool deleteFile = false}) async {
    await _delete('/api/v2/downloads/$id', {
      'delete_file': deleteFile.toString(),
    });
  }

  /// Pauses an active download.
  /// POST /api/v2/downloads/{id}/pause?apikey=...
  Future<void> pauseDownload(int id) async {
    await _post('/api/v2/downloads/$id/pause');
  }

  /// Resumes a paused download.
  /// POST /api/v2/downloads/{id}/resume?apikey=...
  Future<void> resumeDownload(int id) async {
    await _post('/api/v2/downloads/$id/resume');
  }

  /// Returns the direct file download URL for a completed download.
  String getFileUrl(int downloadId) =>
      '$baseUrl/api/v2/downloads/$downloadId/file?apikey=${Uri.encodeComponent(apiKey)}';

  /// Disposes the underlying HTTP client.
  void dispose() {
    _client.close();
  }
}
