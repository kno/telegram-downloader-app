import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/search_result.dart';
import '../providers/channels_provider.dart';
import '../services/telegram_service.dart';
import '../widgets/search_result_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _queryController = TextEditingController();
  final _seasonController = TextEditingController();
  final _episodeController = TextEditingController();

  SearchResponse? _results;
  bool _loading = false;
  String? _error;
  int _offset = 0;
  static const _limit = 50;

  // Cache of all raw results for local pagination/filtering
  List<Map<String, dynamic>> _allRawResults = [];

  Future<void> _search({int offset = 0}) async {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      _offset = offset;
    });

    try {
      final channelsProv = context.read<ChannelsProvider>();
      final enabledChannels = channelsProv.channels
          .where((c) => c.enabled)
          .map((c) => {
                'chat_id': c.chatId,
                'category_id': c.id,
                'name': c.name,
                'username': c.username,
              })
          .toList();

      debugPrint('[SearchScreen] query="$query", enabledChannels=${enabledChannels.length}');
      for (final ch in enabledChannels) {
        debugPrint('[SearchScreen]   - ${ch['name']} (chatId=${ch['chat_id']})');
      }

      if (enabledChannels.isEmpty) {
        setState(() {
          _error = 'No hay canales habilitados';
          _loading = false;
        });
        return;
      }

      // Only fetch from TDLib if offset is 0 (new search)
      if (offset == 0) {
        debugPrint('[SearchScreen] Fetching from TDLib...');
        _allRawResults = await TelegramService.instance.searchMessages(
          query: query,
          channels: enabledChannels,
          limit: 200,
        );
        debugPrint('[SearchScreen] Got ${_allRawResults.length} raw results');
      }

      // Apply season/episode filter locally if provided
      var filtered = _allRawResults;
      final season = _seasonController.text.trim();
      final episode = _episodeController.text.trim();
      if (season.isNotEmpty || episode.isNotEmpty) {
        debugPrint('[SearchScreen] Filtering by season="$season" episode="$episode"');
        filtered = _filterBySeasonEp(filtered, season, episode);
        debugPrint('[SearchScreen] After filter: ${filtered.length} results');
      }

      final total = filtered.length;
      final paginated = filtered.skip(offset).take(_limit).toList();

      final items = paginated.map((json) => SearchResult.fromJson(json)).toList();
      debugPrint('[SearchScreen] Showing ${items.length} of $total total (offset=$offset)');

      setState(() => _results = SearchResponse(
        total: total,
        offset: offset,
        items: items,
      ));
    } catch (e, stackTrace) {
      debugPrint('[SearchScreen] ERROR: $e');
      debugPrint('[SearchScreen] Stack: $stackTrace');
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _filterBySeasonEp(
      List<Map<String, dynamic>> items, String season, String episode) {
    final sNum = int.tryParse(season);
    final eNum = int.tryParse(episode);
    if (sNum == null && eNum == null) return items;

    return items.where((item) {
      final title = item['title'] as String? ?? '';
      if (sNum != null && eNum != null) {
        if (RegExp('S0*${sNum}E0*$eNum\\b', caseSensitive: false).hasMatch(title)) return true;
        if (RegExp('\\b0*${sNum}x0*$eNum\\b', caseSensitive: false).hasMatch(title)) return true;
        return false;
      } else if (sNum != null) {
        if (RegExp('S0*$sNum(?:E\\d|[\\s._-])', caseSensitive: false).hasMatch(title)) return true;
        if (RegExp('\\b0*${sNum}x\\d', caseSensitive: false).hasMatch(title)) return true;
        return false;
      }
      return true;
    }).toList();
  }

  @override
  void dispose() {
    _queryController.dispose();
    _seasonController.dispose();
    _episodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabledCount = context.watch<ChannelsProvider>().channels.where((c) => c.enabled).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Buscar')),
      body: Column(
        children: [
          // Search form
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _queryController,
                  decoration: InputDecoration(
                    hintText: 'Buscar en Telegram...',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _queryController.clear();
                        setState(() {
                          _results = null;
                          _allRawResults = [];
                        });
                      },
                    ),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _seasonController,
                        decoration: const InputDecoration(
                          hintText: 'Temporada',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _episodeController,
                        decoration: const InputDecoration(
                          hintText: 'Episodio',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _loading ? null : () => _search(),
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Buscar'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$enabledCount canales habilitados',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                ),
              ],
            ),
          ),

          // Results
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_error!, style: TextStyle(color: theme.colorScheme.onErrorContainer)),
                ),
              ),
            ),

          if (_results != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '${_results!.total} resultados',
                style: theme.textTheme.bodySmall,
              ),
            ),

          Expanded(
            child: _results == null
                ? Center(
                    child: Text(
                      'Introduce un termino de busqueda',
                      style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.outline),
                    ),
                  )
                : _results!.items.isEmpty
                    ? Center(
                        child: Text(
                          'Sin resultados',
                          style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.outline),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _results!.items.length,
                        itemBuilder: (context, index) {
                          return SearchResultCard(result: _results!.items[index]);
                        },
                      ),
          ),

          // Pagination
          if (_results != null && _results!.total > _limit)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: _offset > 0 ? () => _search(offset: _offset - _limit) : null,
                    child: const Text('Anterior'),
                  ),
                  const SizedBox(width: 16),
                  Text('${(_offset ~/ _limit) + 1} / ${((_results!.total - 1) ~/ _limit) + 1}'),
                  const SizedBox(width: 16),
                  TextButton(
                    onPressed: _offset + _limit < _results!.total
                        ? () => _search(offset: _offset + _limit)
                        : null,
                    child: const Text('Siguiente'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
