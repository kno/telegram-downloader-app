import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/download.dart';
import '../services/telegram_service.dart';

class DownloadsProvider extends ChangeNotifier {
  static const String _storageKey = 'downloads_v1';

  final Map<int, Download> _downloads = {}; // keyed by fileId
  StreamSubscription? _fileUpdateSub;

  // Speed calculation state
  final Map<int, int> _lastDownloadedSize = {};
  final Map<int, DateTime> _lastUpdateTime = {};

  // Throttle: save at most once per 2 seconds
  Timer? _saveThrottle;
  bool _pendingSave = false;

  List<Download> get downloads => _downloads.values.toList();
  List<Download> get active => downloads.where((d) => d.isActive).toList();
  List<Download> get paused => downloads.where((d) => d.isPaused).toList();
  List<Download> get withErrors => downloads.where((d) => d.hasError).toList();
  List<Download> get completed => downloads.where((d) => d.isCompleted).toList();

  void _saveToStorage() {
    if (_saveThrottle?.isActive ?? false) {
      _pendingSave = true;
      return;
    }
    _doSave();
    _saveThrottle = Timer(const Duration(seconds: 2), () {
      if (_pendingSave) {
        _pendingSave = false;
        _doSave();
      }
    });
  }

  Future<void> _doSave() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _downloads.values.map((d) => d.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(list));
  }

  Future<void> loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      for (final item in list) {
        final dl = Download.fromJson(item as Map<String, dynamic>);
        // Active downloads become paused after restart (TDLib is not running)
        final restored = dl.isActive
            ? Download(
                id: dl.id,
                name: dl.name,
                status: Download.stopped,
                percentDone: dl.percentDone,
                totalSize: dl.totalSize,
                downloadedEver: dl.downloadedEver,
                rateDownload: 0,
                eta: -1,
                error: dl.error,
                errorString: dl.errorString,
                isFinished: false,
                doneDate: 0,
                chatId: dl.chatId,
                msgId: dl.msgId,
                localPath: dl.localPath,
              )
            : dl;
        _downloads[restored.id] = restored;
      }
      notifyListeners();
    } catch (_) {
      // Corrupt data — start fresh
    }
  }

  void startListening() {
    _fileUpdateSub?.cancel();
    _fileUpdateSub = TelegramService.instance.fileUpdateStream.listen(_onFileUpdate);
  }

  void _onFileUpdate(Map<String, dynamic> file) {
    final fileId = file['id'] as int;
    if (!_downloads.containsKey(fileId)) return;

    final local = file['local'] as Map<String, dynamic>?;
    if (local == null) return;

    final isDownloading = local['is_downloading_active'] as bool? ?? false;
    final isComplete = local['is_downloading_completed'] as bool? ?? false;
    final downloadedSize = local['downloaded_prefix_size'] as int? ?? local['downloaded_size'] as int? ?? 0;
    final totalSize = file['size'] as int? ?? file['expected_size'] as int? ?? 0;

    final dl = _downloads[fileId]!;
    final percent = totalSize > 0 ? downloadedSize / totalSize : 0.0;

    // Calculate download speed (bytes/sec)
    final now = DateTime.now();
    int rateDownload = dl.rateDownload;
    int eta = dl.eta;

    if (isDownloading && _lastDownloadedSize.containsKey(fileId)) {
      final prevSize = _lastDownloadedSize[fileId]!;
      final prevTime = _lastUpdateTime[fileId]!;
      final elapsedUs = now.difference(prevTime).inMicroseconds;
      final elapsedSeconds = elapsedUs / 1000000.0;

      // Only recalculate if enough time has passed (>= 300ms) to avoid jitter
      if (elapsedSeconds >= 0.3 && downloadedSize > prevSize) {
        final instantSpeed = (downloadedSize - prevSize) / elapsedSeconds;
        // Weighted average: 70% previous + 30% instant for smooth display
        final prevSpeed = dl.rateDownload.toDouble();
        rateDownload = prevSpeed > 0
            ? (0.7 * prevSpeed + 0.3 * instantSpeed).round()
            : instantSpeed.round();

        // Update tracking only when we actually recalculate
        _lastDownloadedSize[fileId] = downloadedSize;
        _lastUpdateTime[fileId] = now;

        if (rateDownload > 0 && totalSize > downloadedSize) {
          eta = ((totalSize - downloadedSize) / rateDownload).round();
        } else {
          eta = -1;
        }
      }
    } else if (isDownloading) {
      // First update: initialize tracking, keep speed at 0
      _lastDownloadedSize[fileId] = downloadedSize;
      _lastUpdateTime[fileId] = now;
      rateDownload = 0;
      eta = -1;
    }

    if (!isDownloading) {
      rateDownload = 0;
      eta = -1;
    }

    final localPath = isComplete
        ? (local['path'] as String? ?? dl.localPath)
        : dl.localPath;

    _downloads[fileId] = Download(
      id: dl.id,
      name: dl.name,
      status: isComplete ? Download.seeding : (isDownloading ? Download.downloading : Download.stopped),
      percentDone: percent,
      totalSize: totalSize,
      downloadedEver: downloadedSize,
      rateDownload: rateDownload,
      eta: eta,
      error: 0,
      errorString: '',
      isFinished: isComplete,
      doneDate: isComplete ? DateTime.now().millisecondsSinceEpoch ~/ 1000 : 0,
      chatId: dl.chatId,
      msgId: dl.msgId,
      localPath: localPath,
    );
    _saveToStorage();
    notifyListeners();

    // Auto-copy to default download directory when completed
    if (isComplete && localPath != null && localPath.isNotEmpty) {
      _autoCopyToDefaultDirectory(dl.name, localPath);
    }
  }

  Future<void> _autoCopyToDefaultDirectory(String name, String sourcePath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final defaultDir = prefs.getString('download_directory');
      if (defaultDir == null || defaultDir.isEmpty) return;

      final dest = '$defaultDir${Platform.pathSeparator}$name';
      debugPrint('[Downloads] Auto-copying "$name" to $dest');
      await File(sourcePath).copy(dest);
      debugPrint('[Downloads] Auto-copy complete: $dest');
    } catch (e) {
      debugPrint('[Downloads] Auto-copy failed: $e');
    }
  }

  /// Add a download and start it via TDLib.
  Future<void> addDownload({
    required String chatId,
    required int msgId,
    required String name,
  }) async {
    final fileId = await TelegramService.instance.startDownload(
      chatId: int.parse(chatId),
      msgId: msgId,
    );

    _downloads[fileId] = Download(
      id: fileId,
      name: name,
      status: Download.downloading,
      percentDone: 0.0,
      totalSize: 0,
      downloadedEver: 0,
      rateDownload: 0,
      eta: -1,
      error: 0,
      errorString: '',
      isFinished: false,
      doneDate: 0,
      chatId: chatId,
      msgId: msgId,
    );
    _saveToStorage();
    notifyListeners();
  }

  /// Pause (cancel) a download but keep it in the list as paused.
  Future<void> pauseDownload(int fileId) async {
    try {
      await TelegramService.instance.cancelDownload(fileId);
    } catch (_) {}
    _lastDownloadedSize.remove(fileId);
    _lastUpdateTime.remove(fileId);
    final dl = _downloads[fileId];
    if (dl != null) {
      _downloads[fileId] = Download(
        id: dl.id,
        name: dl.name,
        status: Download.stopped,
        percentDone: dl.percentDone,
        totalSize: dl.totalSize,
        downloadedEver: dl.downloadedEver,
        rateDownload: 0,
        eta: -1,
        error: 0,
        errorString: '',
        isFinished: false,
        doneDate: 0,
        chatId: dl.chatId,
        msgId: dl.msgId,
        localPath: dl.localPath,
      );
      _saveToStorage();
      notifyListeners();
    }
  }

  /// Resume a paused download. TDLib continues from where it stopped.
  /// If the file ID is no longer valid (e.g. after app restart), re-fetches
  /// the message to get a fresh file ID.
  Future<void> resumeDownload(int fileId) async {
    final dl = _downloads[fileId];
    if (dl == null) return;
    _lastDownloadedSize.remove(fileId);
    _lastUpdateTime.remove(fileId);

    int activeFileId = fileId;
    try {
      // Try resuming with the existing file ID first
      await TelegramService.instance.resumeFileDownload(fileId);
    } catch (e) {
      debugPrint('[Downloads] resumeFileDownload($fileId) failed: $e');
      // File ID no longer valid — re-fetch from chatId+msgId
      if (dl.chatId != null && dl.msgId != null) {
        try {
          final newFileId = await TelegramService.instance.startDownload(
            chatId: int.parse(dl.chatId!),
            msgId: dl.msgId!,
          );
          debugPrint('[Downloads] Re-fetched file: old=$fileId new=$newFileId');
          activeFileId = newFileId;
          // Remove old entry if fileId changed
          if (newFileId != fileId) {
            _downloads.remove(fileId);
          }
        } catch (e2) {
          debugPrint('[Downloads] startDownload fallback failed: $e2');
          // Mark as error so user sees it failed
          _downloads[fileId] = Download(
            id: dl.id,
            name: dl.name,
            status: Download.stopped,
            percentDone: dl.percentDone,
            totalSize: dl.totalSize,
            downloadedEver: dl.downloadedEver,
            rateDownload: 0,
            eta: -1,
            error: 1,
            errorString: 'No se pudo reanudar: $e2',
            isFinished: false,
            doneDate: 0,
            chatId: dl.chatId,
            msgId: dl.msgId,
            localPath: dl.localPath,
          );
          _saveToStorage();
          notifyListeners();
          return;
        }
      } else {
        // No chatId/msgId to fall back on
        _downloads[fileId] = Download(
          id: dl.id,
          name: dl.name,
          status: Download.stopped,
          percentDone: dl.percentDone,
          totalSize: dl.totalSize,
          downloadedEver: dl.downloadedEver,
          rateDownload: 0,
          eta: -1,
          error: 1,
          errorString: 'No se puede reanudar sin datos del mensaje',
          isFinished: false,
          doneDate: 0,
          chatId: dl.chatId,
          msgId: dl.msgId,
          localPath: dl.localPath,
        );
        _saveToStorage();
        notifyListeners();
        return;
      }
    }

    _downloads[activeFileId] = Download(
      id: activeFileId,
      name: dl.name,
      status: Download.downloading,
      percentDone: dl.percentDone,
      totalSize: dl.totalSize,
      downloadedEver: dl.downloadedEver,
      rateDownload: 0,
      eta: -1,
      error: 0,
      errorString: '',
      isFinished: false,
      doneDate: 0,
      chatId: dl.chatId,
      msgId: dl.msgId,
      localPath: dl.localPath,
    );
    _saveToStorage();
    notifyListeners();
  }

  /// Remove a download entirely from the list.
  Future<void> removeDownload(int fileId, {bool deleteFile = false}) async {
    try {
      await TelegramService.instance.cancelDownload(fileId);
      if (deleteFile) {
        await TelegramService.instance.deleteFile(fileId);
      }
    } catch (_) {}
    _downloads.remove(fileId);
    _lastDownloadedSize.remove(fileId);
    _lastUpdateTime.remove(fileId);
    _saveToStorage();
    notifyListeners();
  }

  @override
  void dispose() {
    _fileUpdateSub?.cancel();
    _saveThrottle?.cancel();
    super.dispose();
  }
}
