import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/download.dart';

class WebSocketService {
  final String baseUrl;
  final String apiKey;
  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  bool _closed = false;

  /// Called whenever the server sends an updated list of downloads.
  Function(List<Download>)? onDownloadsUpdate;

  /// Called when a WebSocket error occurs.
  Function(dynamic)? onError;

  WebSocketService({required this.baseUrl, required this.apiKey});

  /// Converts an HTTP(S) URL to a WS(S) URL and returns the full
  /// WebSocket endpoint for download updates.
  String _buildWsUrl() {
    String wsBase = baseUrl;
    if (wsBase.startsWith('https://')) {
      wsBase = 'wss://${wsBase.substring(8)}';
    } else if (wsBase.startsWith('http://')) {
      wsBase = 'ws://${wsBase.substring(7)}';
    }
    // Remove trailing slash if present
    if (wsBase.endsWith('/')) {
      wsBase = wsBase.substring(0, wsBase.length - 1);
    }
    return '$wsBase/api/v2/ws/downloads?apikey=${Uri.encodeComponent(apiKey)}';
  }

  /// Opens the WebSocket connection and starts listening for messages.
  /// Automatically reconnects every 3 seconds if the connection drops
  /// (unless [disconnect] has been called).
  void connect() {
    _closed = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    try {
      final wsUrl = _buildWsUrl();
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _channel!.stream.listen(
        _onMessage,
        onError: _onStreamError,
        onDone: _onStreamDone,
        cancelOnError: false,
      );
    } catch (e) {
      onError?.call(e);
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String);

      if (data is List) {
        final downloads = data
            .map((json) => Download.fromJson(json as Map<String, dynamic>))
            .toList();
        onDownloadsUpdate?.call(downloads);
      } else if (data is Map<String, dynamic> && data.containsKey('downloads')) {
        final list = data['downloads'] as List<dynamic>;
        final downloads = list
            .map((json) => Download.fromJson(json as Map<String, dynamic>))
            .toList();
        onDownloadsUpdate?.call(downloads);
      }
    } catch (e) {
      onError?.call(e);
    }
  }

  void _onStreamError(dynamic error) {
    onError?.call(error);
    _scheduleReconnect();
  }

  void _onStreamDone() {
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_closed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (!_closed) connect();
    });
  }

  /// Closes the WebSocket connection and stops any reconnect attempts.
  void disconnect() {
    _closed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _channel?.sink.close();
    _channel = null;
  }
}
