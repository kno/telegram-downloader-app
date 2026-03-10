import 'dart:async';
import 'dart:io' show Directory, Platform;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:libtdjson/libtdjson.dart' show Service, Error;

enum TdAuthState {
  initial,
  waitPhoneNumber,
  waitCode,
  waitPassword,
  ready,
  loggingOut,
  closed,
}

class TelegramService {
  static TelegramService? _instance;
  static TelegramService get instance => _instance ??= TelegramService._();

  Service? _service;
  bool _initialized = false;

  final _authStateController = StreamController<TdAuthState>.broadcast();
  Stream<TdAuthState> get authStateStream => _authStateController.stream;
  TdAuthState _authState = TdAuthState.initial;
  TdAuthState get authState => _authState;

  // Error stream for UI to display
  final _errorController = StreamController<String>.broadcast();
  Stream<String> get errorStream => _errorController.stream;

  Map<String, dynamic>? currentUser;

  TelegramService._();

  Future<void> initialize({required int apiId, required String apiHash}) async {
    if (_initialized && _service != null && _service!.isRunning) return;

    // Stop any existing service first
    if (_service != null) {
      try {
        await _service!.stop();
      } catch (_) {}
      _service = null;
      _initialized = false;
    }

    final appDir = await getApplicationDocumentsDirectory();
    final tdDir = Directory('${appDir.path}/tdlib');
    if (!tdDir.existsSync()) tdDir.createSync(recursive: true);

    try {
      _service = Service(
        start: false,
        newVerbosityLevel: 1,
        tdlibParameters: {
          'api_id': apiId,
          'api_hash': apiHash,
          'device_model': 'Desktop',
          'system_language_code': Platform.localeName,
          'application_version': '1.0.0',
          'database_directory': '${tdDir.path}/db',
          'files_directory': '${tdDir.path}/files',
          'use_file_database': true,
          'use_chat_info_database': true,
          'use_message_database': true,
          'enable_storage_optimizer': true,
        },
        afterReceive: _handleUpdate,
        onReceiveError: _handleReceiveError,
      );

      await _service!.start();
      _initialized = true;
    } catch (e) {
      final errorMsg = e.toString();
      debugPrint('TDLib init error: $errorMsg');

      // If database is locked, clean it up and retry once
      if (errorMsg.contains("Can't lock file") || errorMsg.contains('lock')) {
        debugPrint('Database locked, cleaning up and retrying...');
        await _cleanDatabase(tdDir);
        _service = null;
        // Retry once
        try {
          _service = Service(
            start: false,
            newVerbosityLevel: 1,
            tdlibParameters: {
              'api_id': apiId,
              'api_hash': apiHash,
              'device_model': 'Desktop',
              'system_language_code': Platform.localeName,
              'application_version': '1.0.0',
              'database_directory': '${tdDir.path}/db',
              'files_directory': '${tdDir.path}/files',
              'use_file_database': true,
              'use_chat_info_database': true,
              'use_message_database': true,
              'enable_storage_optimizer': true,
            },
            afterReceive: _handleUpdate,
            onReceiveError: _handleReceiveError,
          );
          await _service!.start();
          _initialized = true;
        } catch (retryError) {
          _errorController.add('Error al iniciar Telegram: $retryError');
          rethrow;
        }
      } else {
        _errorController.add('Error al iniciar Telegram: $errorMsg');
        rethrow;
      }
    }
  }

  Future<void> _cleanDatabase(Directory tdDir) async {
    final dbDir = Directory('${tdDir.path}/db');
    if (dbDir.existsSync()) {
      try {
        dbDir.deleteSync(recursive: true);
        debugPrint('Cleaned TDLib database directory');
      } catch (e) {
        debugPrint('Failed to clean database: $e');
      }
    }
  }

  void _handleReceiveError(dynamic error) {
    debugPrint('TDLib receive error: $error');
    if (error is Error) {
      final msg = error.message;
      if (msg.contains("Can't lock file") || msg.contains('lock')) {
        _errorController.add('La base de datos de Telegram está bloqueada. Reinicia la aplicación.');
      } else {
        _errorController.add(msg);
      }
    } else {
      _errorController.add(error.toString());
    }
  }

  // File progress stream
  final _fileUpdateController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get fileUpdateStream => _fileUpdateController.stream;

  void _handleUpdate(Map<String, dynamic> event) {
    if (event['@type'] == 'updateAuthorizationState') {
      _handleAuthState(event['authorization_state']);
    } else if (event['@type'] == 'updateFile') {
      _fileUpdateController.add(event['file'] as Map<String, dynamic>);
    }
  }

  void _handleAuthState(Map<String, dynamic> state) {
    switch (state['@type']) {
      case 'authorizationStateWaitPhoneNumber':
        _authState = TdAuthState.waitPhoneNumber;
        break;
      case 'authorizationStateWaitCode':
        _authState = TdAuthState.waitCode;
        break;
      case 'authorizationStateWaitPassword':
        _authState = TdAuthState.waitPassword;
        break;
      case 'authorizationStateReady':
        _authState = TdAuthState.ready;
        _fetchCurrentUser();
        break;
      case 'authorizationStateLoggingOut':
        _authState = TdAuthState.loggingOut;
        break;
      case 'authorizationStateClosed':
        _authState = TdAuthState.closed;
        _initialized = false;
        break;
      default:
        return;
    }
    _authStateController.add(_authState);
  }

  Future<void> _fetchCurrentUser() async {
    try {
      final result = await _service!.sendSync({'@type': 'getMe'});
      currentUser = result;
    } catch (_) {}
  }

  Future<void> setPhoneNumber(String phone) async {
    await _service!.send({
      '@type': 'setAuthenticationPhoneNumber',
      'phone_number': phone,
    });
  }

  Future<void> checkCode(String code) async {
    await _service!.send({
      '@type': 'checkAuthenticationCode',
      'code': code,
    });
  }

  Future<void> checkPassword(String password) async {
    await _service!.send({
      '@type': 'checkAuthenticationPassword',
      'password': password,
    });
  }

  Future<void> logOut() async {
    await _service!.send({'@type': 'logOut'});
  }

  Future<void> destroy() async {
    await _service?.stop();
    _service = null;
    _initialized = false;
  }

  bool get isRunning => _service?.isRunning ?? false;

  Future<Map<String, dynamic>> sendRequest(Map<String, dynamic> request) async {
    if (_service == null) throw StateError('TelegramService not initialized');
    return _service!.sendSync(request);
  }

  /// Search for documents, videos, and audio across specified channels.
  /// Returns a list of search result maps compatible with SearchResult model.
  Future<List<Map<String, dynamic>>> searchMessages({
    required String query,
    required List<Map<String, dynamic>> channels,
    int limit = 50,
  }) async {
    if (_service == null) throw StateError('TelegramService not initialized');

    final allItems = <Map<String, dynamic>>[];
    final perChannel = (limit / channels.length).ceil().clamp(5, 100);

    debugPrint('[Search] query="$query", channels=${channels.length}, perChannel=$perChannel');

    const filters = [
      'searchMessagesFilterDocument',
      'searchMessagesFilterVideo',
      'searchMessagesFilterAudio',
    ];

    for (final ch in channels) {
      try {
        final chatId = int.parse(ch['chat_id'] as String);
        final channelName = ch['name'] ?? ch['chat_id'];
        debugPrint('[Search] Searching channel "$channelName" (chatId=$chatId)...');

        final seenMsgIds = <int>{};

        for (final filterType in filters) {
          final request = {
            '@type': 'searchChatMessages',
            'chat_id': chatId,
            'query': query,
            'from_message_id': 0,
            'offset': 0,
            'limit': perChannel,
            'filter': {'@type': filterType},
          };
          debugPrint('[Search] Request (filter=$filterType): $request');

          final result = await _service!.sendSync(request);

          final totalCount = result['total_count'] ?? 0;
          final messages = (result['messages'] as List<dynamic>?) ?? [];
          debugPrint('[Search] Channel "$channelName" filter=$filterType: total_count=$totalCount, messages returned=${messages.length}');

          if (messages.isEmpty && totalCount == 0) {
            debugPrint('[Search] Channel "$channelName": No results for "$query" with filter=$filterType');
          }

          for (final msg in messages) {
            final msgMap = msg as Map<String, dynamic>;
            final msgId = msgMap['id'] as int;

            if (seenMsgIds.contains(msgId)) {
              debugPrint('[Search] Channel "$channelName": msg $msgId already seen, skipping duplicate');
              continue;
            }

            final content = msgMap['content'] as Map<String, dynamic>?;
            if (content == null) {
              debugPrint('[Search] Channel "$channelName": msg $msgId has null content');
              continue;
            }

            final contentType = content['@type'] as String?;
            String fileName;
            int fileSize;

            if (contentType == 'messageDocument') {
              final document = content['document'] as Map<String, dynamic>?;
              if (document == null) {
                debugPrint('[Search] Channel "$channelName": msg $msgId has null document');
                continue;
              }
              final file = document['document'] as Map<String, dynamic>?;
              fileName = document['file_name'] as String? ?? 'Unknown';
              fileSize = file?['size'] as int? ?? file?['expected_size'] as int? ?? 0;
            } else if (contentType == 'messageVideo') {
              final video = content['video'] as Map<String, dynamic>?;
              if (video == null) {
                debugPrint('[Search] Channel "$channelName": msg $msgId has null video');
                continue;
              }
              final file = video['video'] as Map<String, dynamic>?;
              final caption = (content['caption'] as Map<String, dynamic>?)?['text'] as String? ?? '';
              fileName = video['file_name'] as String? ?? (caption.isNotEmpty ? caption : 'Video');
              fileSize = file?['size'] as int? ?? file?['expected_size'] as int? ?? 0;
            } else if (contentType == 'messageAudio') {
              final audio = content['audio'] as Map<String, dynamic>?;
              if (audio == null) {
                debugPrint('[Search] Channel "$channelName": msg $msgId has null audio');
                continue;
              }
              final file = audio['audio'] as Map<String, dynamic>?;
              fileName = audio['file_name'] as String? ?? audio['title'] as String? ?? 'Audio';
              fileSize = file?['size'] as int? ?? file?['expected_size'] as int? ?? 0;
            } else {
              debugPrint('[Search] Channel "$channelName": msg $msgId type=$contentType (skipped, not document/video/audio)');
              continue;
            }

            final date = msgMap['date'] as int? ?? 0;
            final caption = (content['caption'] as Map<String, dynamic>?)?['text'] as String? ?? '';
            final threadId = msgMap['message_thread_id'] as int? ?? 0;

            debugPrint('[Search] Channel "$channelName": Found "$fileName" (${fileSize}B) msgId=$msgId threadId=$threadId type=$contentType');

            String link;
            if (ch['username'] != null) {
              link = threadId != 0
                  ? 'https://t.me/${ch['username']}/$threadId/$msgId'
                  : 'https://t.me/${ch['username']}/$msgId';
            } else {
              link = threadId != 0
                  ? 'https://t.me/c/${chatId.abs()}/$threadId/$msgId'
                  : 'https://t.me/c/${chatId.abs()}/$msgId';
            }

            seenMsgIds.add(msgId);
            allItems.add({
              'title': fileName,
              'guid': '${ch['chat_id']}:$msgId',
              'link': link,
              'pubDate': DateTime.fromMillisecondsSinceEpoch(date * 1000).toIso8601String(),
              'size': fileSize,
              'description': caption,
              'categoryId': ch['category_id'] ?? 0,
              'chatId': ch['chat_id'],
              'msgId': msgId,
              'channelName': ch['name'] ?? '',
            });
          }
        }
      } catch (e, stackTrace) {
        debugPrint('[Search] ERROR in channel ${ch['name'] ?? ch['chat_id']}: $e');
        debugPrint('[Search] Stack: $stackTrace');
      }
    }

    debugPrint('[Search] Total results: ${allItems.length}');
    // Sort by date descending
    allItems.sort((a, b) => (b['pubDate'] as String).compareTo(a['pubDate'] as String));
    return allItems;
  }

  /// Download a file from a Telegram message.
  /// Returns the file_id for tracking progress.
  Future<int> startDownload({required int chatId, required int msgId}) async {
    if (_service == null) throw StateError('TelegramService not initialized');

    // Get the message to find the file
    final message = await _service!.sendSync({
      '@type': 'getMessage',
      'chat_id': chatId,
      'message_id': msgId,
    });

    final content = message['content'] as Map<String, dynamic>;
    final Map<String, dynamic> file;

    switch (content['@type']) {
      case 'messageDocument':
        file = (content['document'] as Map<String, dynamic>)['document'] as Map<String, dynamic>;
        break;
      case 'messageVideo':
        file = (content['video'] as Map<String, dynamic>)['video'] as Map<String, dynamic>;
        break;
      case 'messageAudio':
        file = (content['audio'] as Map<String, dynamic>)['audio'] as Map<String, dynamic>;
        break;
      default:
        throw StateError('Message does not contain a downloadable file');
    }

    final fileId = file['id'] as int;

    // Start download with high priority
    await _service!.sendSync({
      '@type': 'downloadFile',
      'file_id': fileId,
      'priority': 32,
      'synchronous': false,
    });

    return fileId;
  }

  /// Resume downloading a file by its file_id. TDLib continues from where it stopped.
  Future<void> resumeFileDownload(int fileId) async {
    if (_service == null) throw StateError('TelegramService not initialized');
    await _service!.sendSync({
      '@type': 'downloadFile',
      'file_id': fileId,
      'priority': 32,
      'synchronous': false,
    });
  }

  /// Cancel a file download.
  Future<void> cancelDownload(int fileId) async {
    if (_service == null) return;
    await _service!.sendSync({
      '@type': 'cancelDownloadFile',
      'file_id': fileId,
      'only_if_pending': false,
    });
  }

  /// Delete a downloaded file from local storage.
  Future<void> deleteFile(int fileId) async {
    if (_service == null) return;
    await _service!.sendSync({
      '@type': 'deleteFile',
      'file_id': fileId,
    });
  }

  /// Fetch all channels and supergroups the user is subscribed to,
  /// including archived chats.
  Future<List<Map<String, dynamic>>> fetchChannels() async {
    if (_service == null) throw StateError('TelegramService not initialized');

    // Fetch from both main and archive chat lists
    final chatIds = <int>[];
    for (final listType in ['chatListMain', 'chatListArchive']) {
      try {
        final result = await _service!.sendSync({
          '@type': 'getChats',
          'chat_list': {'@type': listType},
          'limit': 500,
        });
        final ids = (result['chat_ids'] as List<dynamic>?)?.cast<int>() ?? [];
        chatIds.addAll(ids);
      } catch (e) {
        debugPrint('Error fetching $listType: $e');
      }
    }

    final channels = <Map<String, dynamic>>[];
    int categoryId = 1000;

    // Step 2: Get details for each chat
    for (final chatId in chatIds) {
      try {
        final chat = await _service!.sendSync({
          '@type': 'getChat',
          'chat_id': chatId,
        });

        final chatType = chat['type'] as Map<String, dynamic>?;
        if (chatType == null) continue;

        // Only include supergroups and channels
        if (chatType['@type'] != 'chatTypeSupergroup') continue;

        String? username;
        try {
          final supergroupId = chatType['supergroup_id'] as int;
          final supergroup = await _service!.sendSync({
            '@type': 'getSupergroup',
            'supergroup_id': supergroupId,
          });
          // TDLib v1.8+ uses usernames object
          final usernames = supergroup['usernames'] as Map<String, dynamic>?;
          if (usernames != null) {
            final active = usernames['active_usernames'] as List<dynamic>?;
            if (active != null && active.isNotEmpty) {
              username = active[0] as String;
            }
          }
          // Fallback for older TDLib
          username ??= supergroup['username'] as String?;
        } catch (_) {}

        channels.add({
          'chat_id': chatId.toString(),
          'category_id': categoryId,
          'name': chat['title'] ?? 'Unknown',
          'username': username,
        });
        categoryId++;
      } catch (e) {
        debugPrint('Error fetching chat $chatId: $e');
      }
    }

    return channels;
  }
}
