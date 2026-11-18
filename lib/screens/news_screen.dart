import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/news_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/pattern.dart';

/// Islamic News: worldwide Islamic news from free public RSS feeds
/// (IQNA, Al Jazeera, Google News) — no key, no account. News is
/// refreshed at most once a day (24-hour cache in
/// `news_service.dart`); pull down or tap refresh for the latest.
/// Offline (or when every feed is down) the screen falls back to
/// the saved stories in assets/data/news.json and says so honestly.
/// Tapping a live story opens the article in the browser.
class NewsItem {
  final String id;
  final String title;
  final String category;
  final String date; // ISO 'yyyy-MM-dd'
  final String summary;
  final String body;

  const NewsItem({
    required this.id,
    required this.title,
    required this.category,
    required this.date,
    required this.summary,
    required this.body,
  });

  factory NewsItem.fromJson(Map<String, dynamic> json) => NewsItem(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        category: json['category'] as String? ?? '',
        date: json['date'] as String? ?? '',
        summary: json['summary'] as String? ?? '',
        body: json['body'] as String? ?? '',
      );

  /// '2026-11-18' -> '18 Nov 2026'. Falls back to the raw string.
  String get dateLabel {
    final parts = date.split('-');
    if (parts.length != 3) return date;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final m = int.tryParse(parts[1]) ?? 0;
    if (m < 1 || m > 12) return date;
    final day = int.tryParse(parts[2]) ?? 0;
    return '$day ${months[m - 1]} ${parts[0]}';
  }
}

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  List<NewsArticle> _articles = [];
  List<NewsItem> _saved = []; // bundled fallback (offline)
  bool _loading = true;
  bool _offline = false;
  DateTime? _updatedAt;
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    if (!forceRefresh) setState(() => _loading = true);
    final articles = await loadWorldNews(forceRefresh: forceRefresh);
    final updatedAt = await lastNewsUpdate();
    var saved = <NewsItem>[];
    var offline = false;
    if (articles.isEmpty) {
      // No live news (offline / all feeds down): saved stories.
      try {
        final raw =
            await rootBundle.loadString('assets/data/news.json');
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final list = (json['items'] as List).cast<Map<String, dynamic>>();
        saved = list.map(NewsItem.fromJson).toList();
        saved.sort((a, b) => b.date.compareTo(a.date));
      } catch (_) {}
      offline = true;
    }
    if (!mounted) return;
    setState(() {
      _articles = articles;
      _saved = saved;
      _offline = offline;
      _updatedAt = updatedAt;
      _filter = 'All';
      _loading = false;
    });
  }

  Future<void> _openArticle(NewsArticle article) async {
    final uri = Uri.parse(article.url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _updatedLabel() {
    final at = _updatedAt;
    if (at == null) return 'Not updated yet';
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return 'Updated just now';
    if (diff.inMinutes < 60) return 'Updated ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Updated ${diff.inHours}h ago';
    return 'Updated ${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppTheme.mutedDark : AppTheme.mutedLight;
    final pillBg = isDark ? AppTheme.goldDark : AppTheme.emerald;
    final pillText =
        isDark ? const Color(0xFF1A2E28) : Colors.white;

    if (_articles.isEmpty && _saved.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'News could not be loaded. Check your internet and try again.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              GoldButton(
                label: 'Try again',
                icon: Icons.refresh,
                onPressed: () => _load(forceRefresh: true),
              ),
            ],
          ),
        ),
      );
    }

    final live = _articles.isNotEmpty;
    return Column(
      children: [
        // ---- Status bar ----
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.gold.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _offline
                        ? 'You\'re offline — showing saved stories from Mohalla.'
                        : 'Worldwide Islamic news — ${_updatedLabel()}. Pull down to refresh.',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                if (live)
                  IconButton(
                    tooltip: 'Refresh',
                    icon: const Icon(Icons.refresh),
                    onPressed: () => _load(forceRefresh: true),
                  ),
              ],
            ),
          ),
        ),
        if (live)
          _buildLiveList(pillBg, pillText, muted)
        else
          _buildSavedList(pillBg, pillText, muted),
      ],
    );
  }

  /// Live worldwide news, filterable by source, pull-to-refresh.
  Widget _buildLiveList(Color pillBg, Color pillText, Color muted) {
    final sources = ['All', ...{for (final a in _articles) a.source}];
    final shown = _filter == 'All'
        ? _articles
        : _articles.where((a) => a.source == _filter).toList();
    return Expanded(
      child: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              children: [
                for (final s in sources)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(s),
                      selected: _filter == s,
                      onSelected: (_) => setState(() => _filter = s),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _load(forceRefresh: true),
              child: shown.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                            child: Text('No news from this source yet.'),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 92),
                      itemCount: shown.length,
                      itemBuilder: (context, i) {
                        final a = shown[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: PressableCard(
                            onTap: () => _openArticle(a),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: pillBg,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              a.source,
                                              style: TextStyle(
                                                color: pillText,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            a.timeAgo,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: muted,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        a.title,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (a.summary.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          a.summary,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (a.imageUrl.isNotEmpty) ...[
                                  const SizedBox(width: 12),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      a.imageUrl,
                                      width: 72,
                                      height: 72,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const SizedBox(
                                        width: 72,
                                        height: 72,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// Saved Mohalla stories (offline fallback), filterable by category.
  Widget _buildSavedList(Color pillBg, Color pillText, Color muted) {
    final categories = [
      'All',
      ...{for (final i in _saved) i.category},
    ];
    final shown = _filter == 'All'
        ? _saved
        : _saved.where((i) => i.category == _filter).toList();
    return Expanded(
      child: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              children: [
                for (final c in categories)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(c),
                      selected: _filter == c,
                      onSelected: (_) => setState(() => _filter = c),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: shown.isEmpty
                ? const Center(child: Text('No news in this category yet.'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 92),
                    itemCount: shown.length,
                    itemBuilder: (context, i) {
                      final item = shown[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: PressableCard(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  NewsDetailScreen(item: item),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: pillBg,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      item.category,
                                      style: TextStyle(
                                        color: pillText,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    item.dateLabel,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: muted,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                item.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.summary,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
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

/// Full article view. Pushed directly (own Scaffold + AppBar) like
/// the Edit Profile screen, because the list itself is opened through
/// the More tab's tool wrapper.
class NewsDetailScreen extends StatelessWidget {
  final NewsItem item;

  const NewsDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('Islamic News')),
      body: PatternBackground(
        base: isDark ? AppTheme.nightBg : AppTheme.sand,
        patternColor: isDark ? Colors.white : AppTheme.emerald,
        patternOpacity: isDark ? 0.10 : 0.20,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 92),
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.goldDark : AppTheme.emerald,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item.category,
                    style: TextStyle(
                      color: isDark
                          ? const Color(0xFF1A2E28)
                          : Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  item.dateLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              item.title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              height: 3,
              width: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? const [
                          AppTheme.goldDarkLight,
                          AppTheme.goldDark,
                        ]
                      : const [AppTheme.goldLight, AppTheme.gold],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              item.body,
              style: const TextStyle(fontSize: 15, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}
