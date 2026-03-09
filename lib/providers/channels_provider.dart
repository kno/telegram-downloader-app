import 'package:flutter/material.dart';
import '../models/channel.dart';
import '../services/storage_service.dart';
import '../services/telegram_service.dart';

class ChannelsProvider extends ChangeNotifier {
  final StorageService _storage = StorageService();
  List<Channel> _channels = [];
  bool _loading = false;
  String _error = '';

  List<Channel> get channels => _channels;
  bool get loading => _loading;
  String get error => _error;
  List<int> get enabledIds =>
      _channels.where((c) => c.enabled).map((c) => c.id).toList();

  Future<void> load() async {
    _channels = await _storage.getChannels();
    notifyListeners();
  }

  /// Fetch channels from Telegram via TDLib and merge with local state.
  Future<void> fetchFromTelegram() async {
    _loading = true;
    _error = '';
    notifyListeners();

    try {
      final tg = TelegramService.instance;
      if (!tg.isRunning) {
        _error = 'Telegram no está conectado';
        _loading = false;
        notifyListeners();
        return;
      }

      final rawChannels = await tg.fetchChannels();
      final newChannels = rawChannels.map((json) => Channel(
        id: json['category_id'] as int,
        chatId: json['chat_id'] as String,
        name: json['name'] as String,
        username: json['username'] as String?,
      )).toList();

      await setChannels(newChannels);
    } catch (e) {
      _error = e.toString();
    }

    _loading = false;
    notifyListeners();
  }

  Future<void> setChannels(List<Channel> newChannels) async {
    final existing = {for (var c in _channels) c.id: c.enabled};
    for (var ch in newChannels) {
      ch.enabled = existing[ch.id] ?? true;
    }
    _channels = newChannels;
    await _storage.saveChannels(_channels);
    notifyListeners();
  }

  Future<void> toggle(int id) async {
    final index = _channels.indexWhere((c) => c.id == id);
    if (index != -1) {
      _channels[index].enabled = !_channels[index].enabled;
      await _storage.saveChannels(_channels);
      notifyListeners();
    }
  }

  Future<void> enableAll() async {
    for (var ch in _channels) {
      ch.enabled = true;
    }
    await _storage.saveChannels(_channels);
    notifyListeners();
  }

  Future<void> disableAll() async {
    for (var ch in _channels) {
      ch.enabled = false;
    }
    await _storage.saveChannels(_channels);
    notifyListeners();
  }
}
