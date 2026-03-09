import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

/// Asistente multi-paso de autenticacion mostrado cuando la app no esta autenticada.
class SetupWizardScreen extends StatefulWidget {
  const SetupWizardScreen({super.key});

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen> {
  // Paso 0: Credenciales + telefono, Paso 1: Codigo, Paso 2: 2FA
  int _currentStep = 0;

  // Paso 0
  final _apiIdController = TextEditingController();
  final _apiHashController = TextEditingController();
  final _phoneController = TextEditingController();

  // Paso 1
  final _codeController = TextEditingController();

  // Paso 2
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  final _step0FormKey = GlobalKey<FormState>();
  final _step1FormKey = GlobalKey<FormState>();
  final _step2FormKey = GlobalKey<FormState>();

  // Indica si ya se envio el telefono tras la conexion TDLib
  bool _phoneSent = false;

  static const _telegramBlue = Color(0xFF0088CC);

  @override
  void dispose() {
    _apiIdController.dispose();
    _apiHashController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Reacciona a cambios de estado de auth para auto-avanzar pasos.
  void _reactToAuthState(AuthProvider auth) {
    // Auto-avanzar de paso 0 a paso 1 cuando TDLib pide el codigo
    if (auth.state == AuthState.waitCode && _currentStep == 0) {
      setState(() => _currentStep = 1);
    }
    // Auto-avanzar de paso 1 a paso 2 cuando TDLib pide 2FA
    if (auth.state == AuthState.waitPassword && _currentStep <= 1) {
      setState(() => _currentStep = 2);
    }
  }

  Future<void> _onStep0Continue() async {
    if (!_step0FormKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    auth.clearError();

    final apiId = int.tryParse(_apiIdController.text.trim());
    if (apiId == null) return;

    // Guardar credenciales e iniciar TDLib
    await auth.setup(
      apiId: apiId,
      apiHash: _apiHashController.text.trim(),
    );
    if (!mounted) return;
    if (auth.error.isNotEmpty) return;

    // Esperar a que TDLib pida el telefono
    if (auth.state == AuthState.waitPhone) {
      await _sendPhone(auth);
    } else if (auth.state == AuthState.connecting) {
      // TDLib aun esta arrancando; marcar que hay que enviar el telefono
      // cuando el estado cambie a waitPhone
      _phoneSent = false;
    }
  }

  Future<void> _sendPhone(AuthProvider auth) async {
    if (_phoneSent) return;
    _phoneSent = true;
    await auth.sendPhone(_phoneController.text.trim());
  }

  Future<void> _onStep1Continue() async {
    if (!_step1FormKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    auth.clearError();
    await auth.verifyCode(_codeController.text.trim());
  }

  Future<void> _onStep2Continue() async {
    if (!_step2FormKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    auth.clearError();
    await auth.verifyPassword(_passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();

    // Reaccionar a cambios de estado para auto-avance
    _reactToAuthState(auth);

    // Si el estado cambio a waitPhone y aun no enviamos el telefono
    if (auth.state == AuthState.waitPhone && !_phoneSent && _phoneController.text.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _sendPhone(context.read<AuthProvider>());
      });
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(theme),
              const SizedBox(height: 32),
              _buildStepIndicator(theme),
              const SizedBox(height: 32),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildCurrentStep(theme, auth),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: _telegramBlue,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(Icons.send_rounded, color: Colors.white, size: 38),
        ),
        const SizedBox(height: 16),
        Text(
          'Telegram Downloader',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          'Configura tu cuenta de Telegram para comenzar',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildStepIndicator(ThemeData theme) {
    final steps = ['Credenciales', 'Codigo', if (_currentStep >= 2) '2FA'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          final stepIndex = i ~/ 2;
          return Expanded(
            child: Container(
              height: 2,
              color: stepIndex < _currentStep
                  ? _telegramBlue
                  : theme.colorScheme.outlineVariant,
            ),
          );
        }
        final stepIndex = i ~/ 2;
        final isActive = stepIndex == _currentStep;
        final isDone = stepIndex < _currentStep;
        return Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isDone || isActive ? _telegramBlue : Colors.transparent,
                border: Border.all(
                  color: isDone || isActive
                      ? _telegramBlue
                      : theme.colorScheme.outlineVariant,
                  width: 2,
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isDone
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : Text(
                        '${stepIndex + 1}',
                        style: TextStyle(
                          color: isActive
                              ? Colors.white
                              : theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              steps[stepIndex],
              style: theme.textTheme.labelSmall?.copyWith(
                color: isActive
                    ? _telegramBlue
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildCurrentStep(ThemeData theme, AuthProvider auth) {
    switch (_currentStep) {
      case 0:
        return _buildStep0(theme, auth);
      case 1:
        return _buildStep1(theme, auth);
      case 2:
        return _buildStep2(theme, auth);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStep0(ThemeData theme, AuthProvider auth) {
    return Card(
      key: const ValueKey('step0'),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _step0FormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Configuracion de Telegram',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Necesitas tu API ID y API Hash para conectar la aplicacion con Telegram.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              InkWell(
                onTap: () {},
                child: Text(
                  'Obten tus credenciales en my.telegram.org',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _telegramBlue,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _apiIdController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'API ID',
                  hintText: 'Ej: 12345678',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.tag),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Campo obligatorio';
                  if (int.tryParse(v.trim()) == null) return 'Debe ser un numero';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _apiHashController,
                decoration: const InputDecoration(
                  labelText: 'API Hash',
                  hintText: 'Ej: a1b2c3d4e5f6...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.vpn_key_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Campo obligatorio';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Numero de telefono',
                  hintText: '+34 600 000 000',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Campo obligatorio';
                  if (!v.trim().startsWith('+')) {
                    return 'Incluye el codigo de pais (ej: +34)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              if (auth.error.isNotEmpty) ...[
                _buildError(theme, auth.error),
                const SizedBox(height: 16),
              ],
              FilledButton(
                onPressed: auth.loading ? null : _onStep0Continue,
                style: FilledButton.styleFrom(
                  backgroundColor: _telegramBlue,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: auth.loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Continuar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep1(ThemeData theme, AuthProvider auth) {
    return Card(
      key: const ValueKey('step1'),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _step1FormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.sms_outlined, size: 48, color: _telegramBlue),
              const SizedBox(height: 16),
              Text(
                'Codigo de verificacion',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Hemos enviado un codigo a tu telefono.\nIntroducelo a continuacion.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.center,
                maxLength: 6,
                style: theme.textTheme.headlineMedium?.copyWith(
                  letterSpacing: 8,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  hintText: '000000',
                  hintStyle: theme.textTheme.headlineMedium?.copyWith(
                    letterSpacing: 8,
                    color: theme.colorScheme.outlineVariant,
                  ),
                  border: const OutlineInputBorder(),
                  counterText: '',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Introduce el codigo';
                  if (v.trim().length < 5) return 'El codigo debe tener al menos 5 digitos';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              if (auth.error.isNotEmpty) ...[
                _buildError(theme, auth.error),
                const SizedBox(height: 16),
              ],
              FilledButton(
                onPressed: auth.loading ? null : _onStep1Continue,
                style: FilledButton.styleFrom(
                  backgroundColor: _telegramBlue,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: auth.loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Verificar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep2(ThemeData theme, AuthProvider auth) {
    return Card(
      key: const ValueKey('step2'),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _step2FormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.lock_outlined, size: 48, color: _telegramBlue),
              const SizedBox(height: 16),
              Text(
                'Verificacion en dos pasos',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Tu cuenta tiene verificacion en dos pasos activa.\nIntroduce tu contrasena de Telegram.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Contrasena de verificacion',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Campo obligatorio';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              if (auth.error.isNotEmpty) ...[
                _buildError(theme, auth.error),
                const SizedBox(height: 16),
              ],
              FilledButton(
                onPressed: auth.loading ? null : _onStep2Continue,
                style: FilledButton.styleFrom(
                  backgroundColor: _telegramBlue,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: auth.loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Verificar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError(ThemeData theme, String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline,
              size: 18, color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
