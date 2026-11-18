import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/pattern.dart';

/// Islamic News: announcements and guides from Mohalla, from a
/// local JSON file (assets/data/news.json). Static-first on purpose:
/// there is NO live feed yet — the screen says so honestly at the
/// top, and live news arrives in a later update. No network is used.
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
  List<NewsItem> _items = [];
  bool _loading = true;
  String? _error;
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final raw =
          await rootBundle.loadString('assets/data/news.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final list = (json['items'] as List).cast<Map<String, dynamic>>();
      final items = list.map(NewsItem.fromJson).toList();
      // Newest first.
      items.sort((a, b) => b.date.compareTo(a.date));
      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'News could not be loaded.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    final categories = [
      'All',
      ...{for (final i in _items) i.category},
    ];
    final shown = _filter == 'All'
        ? _items
        : _items.where((i) => i.category == _filter).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppTheme.mutedDark : AppTheme.mutedLight;
    final pillBg = isDark ? AppTheme.goldDark : AppTheme.emerald;
    final pillText =
        isDark ? const Color(0xFF1A2E28) : Colors.white;
    return Column(
      children: [
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
            child: const Text(
              'Announcements and guides from Mohalla. Live news from '
              'the Muslim world will be added in a later update.',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ),
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
