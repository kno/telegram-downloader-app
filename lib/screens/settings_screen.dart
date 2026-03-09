import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import 'setup_wizard_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _telegramBlue = Color(0xFF0088CC);

  String? _downloadDirectory;

  @override
  void initState() {
    super.initState();
    _loadDownloadDirectory();
  }

  Future<void> _loadDownloadDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _downloadDirectory = prefs.getString('download_directory');
    });
  }

  Future<void> _pickDownloadDirectory() async {
    final dir = await FilePicker.platform.getDirectoryPath();
    if (dir == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('download_directory', dir);
    if (!mounted) return;
    setState(() => _downloadDirectory = dir);
  }

  Future<void> _clearDownloadDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('download_directory');
    setState(() => _downloadDirectory = null);
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesion'),
        content: const Text(
          '¿Estas seguro de que quieres cerrar la sesion de Telegram?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cerrar sesion'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await context.read<AuthProvider>().logout();
  }

  void _openSetupWizard() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SetupWizardScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = context.watch<ThemeProvider>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Seccion cuenta de Telegram
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _telegramBlue,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Cuenta de Telegram',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (auth.isAuthenticated) ...[
                    _buildAuthenticatedUser(theme, auth),
                  ] else if (auth.loading) ...[
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ] else ...[
                    _buildNotAuthenticated(theme),
                  ],
                  if (auth.error.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      auth.error,
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Apariencia
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Apariencia',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Modo oscuro'),
                    subtitle:
                        Text(themeProvider.isDark ? 'Activado' : 'Desactivado'),
                    value: themeProvider.isDark,
                    onChanged: (_) => themeProvider.toggle(),
                    secondary: Icon(
                      themeProvider.isDark ? Icons.dark_mode : Icons.light_mode,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Descargas
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Descargas',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.folder_outlined, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Carpeta de destino por defecto'),
                            const SizedBox(height: 2),
                            Text(
                              _downloadDirectory ?? 'Sin configurar',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: _downloadDirectory != null
                                    ? theme.colorScheme.onSurface
                                    : theme.colorScheme.outline,
                                fontStyle: _downloadDirectory == null
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickDownloadDirectory,
                        icon: const Icon(Icons.folder_open, size: 18),
                        label: const Text('Cambiar'),
                      ),
                      if (_downloadDirectory != null) ...[
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _clearDownloadDirectory,
                          icon: const Icon(Icons.clear, size: 18),
                          label: const Text('Borrar'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.colorScheme.error,
                            side: BorderSide(
                                color: theme.colorScheme.error
                                    .withValues(alpha: 0.5)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Acerca de
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Acerca de',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('Telegram Downloader v1.0.0'),
                  const SizedBox(height: 4),
                  Text(
                    'Cliente multiplataforma para gestionar descargas de Telegram.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthenticatedUser(ThemeData theme, AuthProvider auth) {
    final user = auth.user;
    final firstName = user?['first_name'] as String? ?? '';
    final lastName = user?['last_name'] as String? ?? '';
    final username = user?['username'] as String? ?? '';
    // Construir el nombre completo a partir de los campos TDLib
    final displayName = [firstName, lastName]
        .where((s) => s.isNotEmpty)
        .join(' ');
    final nameToShow = displayName.isNotEmpty ? displayName : 'Usuario';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFF0088CC).withValues(alpha: 0.15),
              child: Text(
                nameToShow.isNotEmpty ? nameToShow[0].toUpperCase() : 'T',
                style: const TextStyle(
                  color: _telegramBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nameToShow,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (username.isNotEmpty)
                    Text(
                      '@$username',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Conectado',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: auth.loading ? null : _logout,
          icon: const Icon(Icons.logout, size: 18),
          label: const Text('Cerrar sesion'),
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.error,
            side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.5)),
          ),
        ),
      ],
    );
  }

  Widget _buildNotAuthenticated(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: theme.colorScheme.onSurfaceVariant,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'No autenticado',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _openSetupWizard,
          icon: const Icon(Icons.login, size: 18),
          label: const Text('Configurar cuenta'),
          style: FilledButton.styleFrom(backgroundColor: _telegramBlue),
        ),
      ],
    );
  }
}
