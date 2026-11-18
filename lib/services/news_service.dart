import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart';

/// One worldwide Islamic news story, from a free public RSS feed.
class NewsArticle {
  final String title;
  final String summary;
  final String source; // e.g. 'IQNA', 'Al Jazeera'
  final String url;
  final DateTime publishedAt;
  final String imageUrl; // may be ''

  const NewsArticle({
    required this.title,
    required this.summary,
    required this.source,
    required this.url,
    required this.publishedAt,
    required this.imageUrl,
  });

  /// 'Just now', '2h ago', '3d ago'.
  String get timeAgo {
    final diff = DateTime.now().difference(publishedAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'summary': summary,
        'source': source,
        'url': url,
        'publishedAt': publishedAt.toIso8601String(),
        'imageUrl': imageUrl,
      };

  factory NewsArticle.fromJson(Map<String, dynamic> json) => NewsArticle(
        title: json['title'] as String? ?? '',
        summary: json['summary'] as String? ?? '',
        source: json['source'] as String? ?? '',
        url: json['url'] as String? ?? '',
        publishedAt:
            DateTime.tryParse(json['publishedAt'] as String? ?? '') ??
                DateTime.now(),
        imageUrl: json['imageUrl'] as String? ?? '',
      );
}

class _Feed {
  final String name;
  final String url;

  /// False = the feed is general news: keep only items about
  /// Islamic topics (keyword filter). True = the whole feed is
  /// Islamic news already.
  final bool islamicOnly;

  const _Feed(this.name, this.url, this.islamicOnly);
}

/// Free public RSS feeds — no key, no account, no billing. IQNA is
/// a dedicated Islamic news agency (verified live 2026-11-19);
/// Al Jazeera's general feed is filtered to Islamic topics
/// (verified live 2026-11-19); Google News is searched for "Islam".
/// A feed that fails (blocked, down, bad XML) simply contributes
/// nothing — it never blocks the others.
const _feeds = [
  _Feed('IQNA', 'https://iqna.ir/en/rss', true),
  _Feed('Al Jazeera', 'https://www.aljazeera.com/xml/rss/all.xml', false),
  _Feed(
    'Google News',
    'https://news.google.com/rss/search?q=Islam&hl=en&gl=US&ceid=US:en',
    true,
  ),
];

const _islamicKeywords = [
  'islam',
  'muslim',
  'mosque',
  'masjid',
  'quran',
  "qur'an",
  'ramadan',
  'hajj',
  'umrah',
  'eid',
  'palestine',
  'gaza',
  'halal',
  'imam',
  'madrasa',
  'sharia',
  'islamic',
  'hijab',
  'fatwa',
  'azan',
  'adhan',
];

bool _isIslamic(String text) {
  final t = text.toLowerCase();
  return _islamicKeywords.any(t.contains);
}

/// Fetches fresh worldwide Islamic news from all feeds at once.
/// One dead feed never blocks the others. Newest first, max 30.
Future<List<NewsArticle>> fetchWorldNews() async {
  final results = await Future.wait(
    _feeds.map((f) => _fetchFeed(f).catchError((_) => <NewsArticle>[])),
  );
  final all = results.expand((list) => list).toList();
  final seen = <String>{};
  all.retainWhere((a) => a.url.isNotEmpty && seen.add(a.url));
  all.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
  return all.take(30).toList();
}

Future<List<NewsArticle>> _fetchFeed(_Feed feed) async {
  final res = await http
      .get(
        Uri.parse(feed.url),
        headers: {'User-Agent': 'Mohalla/1.0 (mohalla app)'},
      )
      .timeout(const Duration(seconds: 12));
  if (res.statusCode != 200) return [];
  final doc = XmlDocument.parse(res.body);
  final out = <NewsArticle>[];
  for (final item in doc.findAllElements('item').take(15)) {
    final title = _decodeEntities(_text(item, 'title'));
    final link = _text(item, 'link').trim();
    if (title.isEmpty || link.isEmpty) continue;
    if (!feed.islamicOnly && !_isIslamic(title)) continue;
    final summary = _cleanHtml(_text(item, 'description'));
    final publishedAt = _parseDate(_text(item, 'pubDate'));
    // Article image, when the feed provides one.
    String imageUrl = '';
    final enclosure = item.getElement('enclosure');
    final encUrl = enclosure?.getAttribute('url') ?? '';
    final encType = enclosure?.getAttribute('type') ?? '';
    if (encUrl.isNotEmpty && encType.contains('image')) {
      imageUrl = encUrl;
    } else {
      for (final e in item.descendantElements) {
        if (e.localName == 'thumbnail' || e.localName == 'content') {
          final u = e.getAttribute('url') ?? '';
          if (u.isNotEmpty &&
              (u.endsWith('.jpg') ||
                  u.endsWith('.jpeg') ||
                  u.endsWith('.png') ||
                  u.contains('image'))) {
            imageUrl = u;
            break;
          }
        }
      }
    }
    out.add(
      NewsArticle(
        title: title,
        summary: summary,
        source: feed.name,
        url: link,
        publishedAt: publishedAt,
        imageUrl: imageUrl,
      ),
    );
  }
  return out;
}

String _text(XmlElement item, String tag) =>
    item.getElement(tag)?.innerText.trim() ?? '';

String _cleanHtml(String html) {
  var text = html.replaceAll(RegExp(r'<[^>]*>'), ' ');
  text = _decodeEntities(text);
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.length > 220) text = '${text.substring(0, 220).trim()}…';
  return text;
}

String _decodeEntities(String s) => s
    .replaceAll('&amp;', '&')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&apos;', "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>');

DateTime _parseDate(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return DateTime.now();
  try {
    return HttpDate.parse(s);
  } catch (_) {
    return DateTime.now();
  }
}

// ---- Daily refresh cache ----

const _kCache = 'cached_world_news_json';
const _kCacheAt = 'cached_world_news_at';

/// News is refreshed at most once a day: if the saved list is less
/// than 24 hours old it is returned immediately (fast, works
/// offline); otherwise fresh news is fetched and saved. A failed
/// fetch returns the last saved list (possibly empty). Pass
/// [forceRefresh] for pull-to-refresh / the refresh button.
const _kCacheMaxAge = Duration(hours: 24);

Future<List<NewsArticle>> loadWorldNews({bool forceRefresh = false}) async {
  final prefs = await SharedPreferences.getInstance();
  final cached = _readCache(prefs);
  final cachedAt = prefs.getInt(_kCacheAt) ?? 0;
  final age = DateTime.now().difference(
    DateTime.fromMillisecondsSinceEpoch(cachedAt),
  );
  if (!forceRefresh && cached.isNotEmpty && age < _kCacheMaxAge) {
    return cached;
  }
  try {
    final fresh = await fetchWorldNews();
    if (fresh.isNotEmpty) {
      await prefs.setString(
        _kCache,
        jsonEncode(fresh.map((a) => a.toJson()).toList()),
      );
      await prefs.setInt(
        _kCacheAt,
        DateTime.now().millisecondsSinceEpoch,
      );
      return fresh;
    }
  } catch (_) {}
  return cached;
}

List<NewsArticle> _readCache(SharedPreferences prefs) {
  final raw = prefs.getString(_kCache);
  if (raw == null) return [];
  try {
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => NewsArticle.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
}

/// When the saved news was last fetched (null = never).
Future<DateTime?> lastNewsUpdate() async {
  final prefs = await SharedPreferences.getInstance();
  final at = prefs.getInt(_kCacheAt);
  if (at == null || at == 0) return null;
  return DateTime.fromMillisecondsSinceEpoch(at);
}
