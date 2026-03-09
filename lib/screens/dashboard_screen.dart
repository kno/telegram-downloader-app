import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/channels_provider.dart';
import '../providers/downloads_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/formatters.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    // Load channels if empty (from local storage)
    final channelsProv = context.read<ChannelsProvider>();
    if (channelsProv.channels.isEmpty) {
      await channelsProv.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final channels = context.watch<ChannelsProvider>();
    final downloads = context.watch<DownloadsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Telegram Downloader'),
        actions: [
          IconButton(
            icon: Icon(
              context.watch<ThemeProvider>().isDark ? Icons.light_mode : Icons.dark_mode,
            ),
            onPressed: () => context.read<ThemeProvider>().toggle(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Stats cards
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.download,
                    label: 'Activas',
                    value: '${downloads.active.length}',
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.check_circle,
                    label: 'Completadas',
                    value: '${downloads.completed.length}',
                    color: theme.colorScheme.tertiary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.list,
                    label: 'Canales',
                    value: '${channels.channels.length}',
                    color: theme.colorScheme.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Active downloads
            if (downloads.active.isNotEmpty) ...[
              Text(
                'Descargas activas',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...downloads.active.map((dl) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(dl.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: dl.percentDone,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(dl.percentDone * 100).toStringAsFixed(1)}% - ${formatSpeed(dl.rateDownload)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  leading: const CircularProgressIndicator(strokeWidth: 2),
                ),
              )),
            ],

            if (downloads.active.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.cloud_download_outlined, size: 64, color: theme.colorScheme.outline),
                      const SizedBox(height: 16),
                      Text(
                        'No hay descargas activas',
                        style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.outline),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
