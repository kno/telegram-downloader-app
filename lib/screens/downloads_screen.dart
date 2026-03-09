import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/downloads_provider.dart';
import '../widgets/download_row.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _connectWs());
  }

  void _connectWs() {
    context.read<DownloadsProvider>().startListening();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dlProv = context.watch<DownloadsProvider>();

    final active = dlProv.active;
    final paused = dlProv.paused;
    final withErrors = dlProv.withErrors;
    final completed = dlProv.completed;

    return Scaffold(
      appBar: AppBar(title: const Text('Descargas')),
      body: dlProv.downloads.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inbox_outlined, size: 64, color: theme.colorScheme.outline),
                  const SizedBox(height: 16),
                  Text(
                    'No hay descargas',
                    style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.outline),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (active.isNotEmpty) ...[
                  _SectionHeader(title: 'Activas', count: active.length, color: theme.colorScheme.primary),
                  ...active.map((dl) => DownloadRow(download: dl)),
                  const SizedBox(height: 16),
                ],
                if (paused.isNotEmpty) ...[
                  _SectionHeader(title: 'Pausadas', count: paused.length, color: theme.colorScheme.outline),
                  ...paused.map((dl) => DownloadRow(download: dl)),
                  const SizedBox(height: 16),
                ],
                if (withErrors.isNotEmpty) ...[
                  _SectionHeader(title: 'Con errores', count: withErrors.length, color: theme.colorScheme.error),
                  ...withErrors.map((dl) => DownloadRow(download: dl)),
                  const SizedBox(height: 16),
                ],
                if (completed.isNotEmpty) ...[
                  _SectionHeader(title: 'Completadas', count: completed.length, color: Colors.green),
                  ...completed.map((dl) => DownloadRow(download: dl)),
                ],
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final Color color;

  const _SectionHeader({required this.title, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 8),
          Text(
            '$title ($count)',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
