import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/telegram_service.dart';
import 'package:libtdjson/libtdjson.dart' show Error;

enum AuthState {
  unknown,       // Inicial / cargando
  needsSetup,    // No hay credenciales guardadas
  connecting,    // TDLib inicializando
  waitPhone,     // TDLib espera numero de telefono
  waitCode,      // TDLib espera codigo de verificacion
  waitPassword,  // TDLib espera contrasena 2FA
  authenticated, // Listo
}

class AuthProvider extends ChangeNotifier {
  AuthState _state = AuthState.unknown;
  String _error = '';
  bool _loading = false;
  Map<String, dynamic>? _user;
  StreamSubscription? _authSub;
  StreamSubscription? _errorSub;

  // Credenciales persistidas
  int? _apiId;
  String? _apiHash;

  AuthState get state => _state;
  String get error => _error;
  bool get loading => _loading;
  Map<String, dynamic>? get user => _user;
  bool get isAuthenticated => _state == AuthState.authenticated;

  static const _prefApiId = 'tg_api_id';
  static const _prefApiHash = 'tg_api_hash';

  void clearError() {
    _error = '';
    notifyListeners();
  }

  /// Comprueba si hay credenciales guardadas e intenta conectar
  Future<void> initialize() async {
    _loading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    _apiId = prefs.getInt(_prefApiId);
    _apiHash = prefs.getString(_prefApiHash);

    if (_apiId == null || _apiHash == null || _apiId == 0) {
      _state = AuthState.needsSetup;
      _loading = false;
      notifyListeners();
      return;
    }

    // Tenemos credenciales, intentar inicializar TDLib
    await _connectTdlib();
  }

  /// Guarda credenciales e inicia la conexion TDLib
  Future<void> setup({required int apiId, required String apiHash}) async {
    _loading = true;
    _error = '';
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefApiId, apiId);
    await prefs.setString(_prefApiHash, apiHash);
    _apiId = apiId;
    _apiHash = apiHash;

    await _connectTdlib();
  }

  Future<void> _connectTdlib() async {
    _state = AuthState.connecting;
    notifyListeners();

    try {
      final tg = TelegramService.instance;

      // Escuchar cambios de estado de autenticacion
      _authSub?.cancel();
      _authSub = tg.authStateStream.listen(_onTdAuthState);

      _errorSub?.cancel();
      _errorSub = tg.errorStream.listen((errorMsg) {
        _error = errorMsg;
        _loading = false;
        notifyListeners();
      });

      await tg.initialize(apiId: _apiId!, apiHash: _apiHash!);
    } catch (e) {
      _error = 'Error al conectar con Telegram: ${e.toString()}';
      _state = AuthState.needsSetup;
      _loading = false;
      notifyListeners();
    }
  }

  void _onTdAuthState(TdAuthState tdState) {
    switch (tdState) {
      case TdAuthState.waitPhoneNumber:
        _state = AuthState.waitPhone;
        _loading = false;
        break;
      case TdAuthState.waitCode:
        _state = AuthState.waitCode;
        _loading = false;
        break;
      case TdAuthState.waitPassword:
        _state = AuthState.waitPassword;
        _loading = false;
        break;
      case TdAuthState.ready:
        _state = AuthState.authenticated;
        _user = TelegramService.instance.currentUser;
        _loading = false;
        break;
      case TdAuthState.closed:
        _state = AuthState.needsSetup;
        _loading = false;
        break;
      default:
        return;
    }
    notifyListeners();
  }

  Future<void> sendPhone(String phone) async {
    _loading = true;
    _error = '';
    notifyListeners();
    try {
      await TelegramService.instance.setPhoneNumber(phone);
    } catch (e) {
      _error = _parseError(e);
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> verifyCode(String code) async {
    _loading = true;
    _error = '';
    notifyListeners();
    try {
      await TelegramService.instance.checkCode(code);
    } catch (e) {
      _error = _parseError(e);
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> verifyPassword(String password) async {
    _loading = true;
    _error = '';
    notifyListeners();
    try {
      await TelegramService.instance.checkPassword(password);
    } catch (e) {
      _error = _parseError(e);
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _loading = true;
    _error = '';
    notifyListeners();
    try {
      await TelegramService.instance.logOut();
      _user = null;
    } catch (e) {
      _error = _parseError(e);
    }
    _loading = false;
    notifyListeners();
  }

  String _parseError(Object e) {
    if (e is Error) return e.message;
    final msg = e.toString();
    if (msg.contains('PHONE_NUMBER_INVALID')) return 'Numero de telefono invalido';
    if (msg.contains('PHONE_CODE_INVALID')) return 'Codigo incorrecto';
    if (msg.contains('PASSWORD_HASH_INVALID')) return 'Contrasena incorrecta';
    if (msg.contains('PHONE_CODE_EXPIRED')) return 'El codigo ha expirado';
    return msg;
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _errorSub?.cancel();
    super.dispose();
  }
}
