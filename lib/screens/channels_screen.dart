import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/channels_provider.dart';

class ChannelsScreen extends StatefulWidget {
  const ChannelsScreen({super.key});

  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> {
  final _filterController = TextEditingController();
  String _filter = '';

  Future<void> _reloadChannels() async {
    final channelsProv = context.read<ChannelsProvider>();
    await channelsProv.fetchFromTelegram();
    if (channelsProv.error.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${channelsProv.error}')),
      );
    }
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final channelsProv = context.watch<ChannelsProvider>();
    final allChannels = channelsProv.channels;
    final loading = channelsProv.loading;

    final filtered = _filter.isEmpty
        ? allChannels
        : allChannels.where((c) => c.name.toLowerCase().contains(_filter.toLowerCase())).toList();

    final enabledCount = allChannels.where((c) => c.enabled).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Canales'),
        actions: [
          IconButton(
            icon: loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            onPressed: loading ? null : _reloadChannels,
            tooltip: 'Recargar',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _filterController,
                  decoration: const InputDecoration(
                    hintText: 'Filtrar canales...',
                    prefixIcon: Icon(Icons.filter_list),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _filter = v),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$enabledCount de ${allChannels.length} habilitados',
                      style: theme.textTheme.bodySmall,
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => channelsProv.enableAll(),
                          child: const Text('Todos'),
                        ),
                        TextButton(
                          onPressed: () => channelsProv.disableAll(),
                          child: const Text('Ninguno'),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      allChannels.isEmpty ? 'No hay canales. Pulsa recargar.' : 'Sin coincidencias',
                      style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.outline),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final ch = filtered[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: SwitchListTile(
                          value: ch.enabled,
                          onChanged: (_) => channelsProv.toggle(ch.id),
                          title: Text(
                            ch.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            ch.username != null ? '@${ch.username}' : 'ID: ${ch.chatId}',
                            style: theme.textTheme.bodySmall,
                          ),
                          secondary: CircleAvatar(
                            backgroundColor: ch.enabled
                                ? theme.colorScheme.primaryContainer
                                : theme.colorScheme.surfaceContainerHighest,
                            child: Text(
                              '${ch.id - 999}',
                              style: TextStyle(
                                color: ch.enabled
                                    ? theme.colorScheme.onPrimaryContainer
                                    : theme.colorScheme.outline,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
