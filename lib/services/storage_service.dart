import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/channel.dart';

class StorageService {
  static const _apiKeyKey = 'apiKey';
  static const _backendUrlKey = 'backendUrl';
  static const _channelsKey = 'channels';
  static const _themeKey = 'theme';

  // ---------------------------------------------------------------------------
  // Settings
  // ---------------------------------------------------------------------------

  /// Returns the stored API key, or an empty string if none is saved.
  Future<String> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiKeyKey) ?? '';
  }

  /// Persists the API key.
  Future<void> setApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyKey, key);
  }

  /// Returns the stored backend URL, or an empty string if none is saved.
  Future<String> getBackendUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_backendUrlKey) ?? '';
  }

  /// Persists the backend URL.
  Future<void> setBackendUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_backendUrlKey, url);
  }

  // ---------------------------------------------------------------------------
  // Channels (local enabled state)
  // ---------------------------------------------------------------------------

  /// Loads the list of channels from local storage.
  /// Returns an empty list if nothing has been saved yet.
  Future<List<Channel>> getChannels() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_channelsKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((json) => Channel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Saves the full channel list (including each channel's enabled state)
  /// to local storage.
  Future<void> saveChannels(List<Channel> channels) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(channels.map((c) => c.toJson()).toList());
    await prefs.setString(_channelsKey, encoded);
  }

  // ---------------------------------------------------------------------------
  // Theme
  // ---------------------------------------------------------------------------

  /// Returns `true` if the user has chosen dark mode.
  /// Defaults to `false` (light mode) when no preference is stored.
  Future<bool> isDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_themeKey) ?? false;
  }

  /// Persists the dark-mode preference.
  Future<void> setDarkMode(bool dark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, dark);
  }
}
