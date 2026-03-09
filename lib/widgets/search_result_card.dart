import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/search_result.dart';
import '../providers/downloads_provider.dart';
import '../utils/formatters.dart';

class SearchResultCard extends StatefulWidget {
  final SearchResult result;

  const SearchResultCard({super.key, required this.result});

  @override
  State<SearchResultCard> createState() => _SearchResultCardState();
}

class _SearchResultCardState extends State<SearchResultCard> {
  String _buttonState = 'idle'; // idle, sending, sent, error
  String? _errorMsg;

  Future<void> _download() async {
    setState(() {
      _buttonState = 'sending';
      _errorMsg = null;
    });

    try {
      await context.read<DownloadsProvider>().addDownload(
        chatId: widget.result.chatId,
        msgId: widget.result.msgId,
        name: widget.result.title,
      );
      setState(() => _buttonState = 'sent');
    } catch (e) {
      setState(() {
        _buttonState = 'error';
        _errorMsg = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = widget.result;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title + size
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    r.title,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    formatSize(r.size),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),

            // Description
            if (r.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                r.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
              ),
            ],

            // Channel name as clickable link
            if (r.channelName.isNotEmpty) ...[
              const SizedBox(height: 4),
              GestureDetector(
                onTap: r.link.isNotEmpty ? () => Process.run('open', [r.link]) : null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.telegram, size: 14, color: theme.colorScheme.primary),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        r.channelName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          decoration: r.link.isNotEmpty ? TextDecoration.underline : null,
                          decorationColor: theme.colorScheme.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 8),

            // Footer: date + download button
            Row(
              children: [
                if (r.pubDate != null) ...[
                  Icon(Icons.calendar_today, size: 14, color: theme.colorScheme.outline),
                  const SizedBox(width: 4),
                  Text(
                    formatDate(r.pubDate),
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                  ),
                ],
                const Spacer(),
                _buildDownloadButton(theme),
              ],
            ),

            if (_errorMsg != null) ...[
              const SizedBox(height: 4),
              Text(
                _errorMsg!,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadButton(ThemeData theme) {
    switch (_buttonState) {
      case 'sending':
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case 'sent':
        return FilledButton.tonal(
          onPressed: null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check, size: 16, color: Colors.green),
              const SizedBox(width: 4),
              const Text('Enviado'),
            ],
          ),
        );
      case 'error':
        return FilledButton.tonal(
          onPressed: _download,
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.errorContainer,
          ),
          child: const Text('Reintentar'),
        );
      default:
        return FilledButton.tonal(
          onPressed: _download,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.download, size: 16),
              SizedBox(width: 4),
              Text('Descargar'),
            ],
          ),
        );
    }
  }
}
