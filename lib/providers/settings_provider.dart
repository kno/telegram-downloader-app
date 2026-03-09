import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';

class SettingsProvider extends ChangeNotifier {
  static const defaultBackendUrl = 'http://localhost:9117';

  final StorageService _storage = StorageService();
  String _backendUrl = defaultBackendUrl;

  String get backendUrl => _backendUrl;

  /// Siempre configurado: la autenticacion se gestiona via TDLib directamente.
  bool get configured => true;

  /// Servicio API para comunicacion con backend remoto (busqueda, descargas).
  /// Retorna null por ahora; se reemplazara con busqueda via TDLib.
  ApiService? get apiService => null;

  Future<void> load() async {
    final storedUrl = await _storage.getBackendUrl();
    _backendUrl = storedUrl.isNotEmpty ? storedUrl : defaultBackendUrl;
    notifyListeners();
  }

  Future<void> saveBackendUrl(String backendUrl) async {
    _backendUrl = backendUrl.isNotEmpty ? backendUrl : defaultBackendUrl;
    await _storage.setBackendUrl(_backendUrl);
    notifyListeners();
  }
}
