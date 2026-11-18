import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../services/mushaf_service.dart';
import '../services/quran_audio_cache.dart';
import '../services/quran_reciters.dart';
import '../services/quran_service.dart';
import '../services/settings_provider.dart';
import '../services/translation_audio_cache.dart';
import '../services/translation_text_service.dart';
import '../services/translation_tts_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/pattern.dart';

/// 16-line Pakistani Mushaf reader (Taj Company, 548 pages x 16 lines).
/// Swipe left/right to turn pages. The page looks like the printed
/// mushaf: paper background, gold double border, 16 lines in the
/// IndoPak Nastaleeq font. A line can span several ayat (pages often
/// end mid-ayah in this layout). Translations of the page's ayat are
/// available from the Tarjuma button (Urdu Jalandhari + English Asad,
/// from the same verified data as the Surah reader).
class MushafReaderScreen extends StatefulWidget {
  const MushafReaderScreen({super.key});

  @override
  State<MushafReaderScreen> createState() => _MushafReaderScreenState();
}

class _MushafReaderScreenState extends State<MushafReaderScreen> {
  late final PageController _controller;
  int _page = 1;
  bool _loading = true;

  // Page audio: plays the current page's ayat in order through the
  // same reciter / audio-mode / translation-voice settings as the
  // Surah reader. Stops when the page turns or the button is tapped.
  final AudioPlayer _pagePlayer = AudioPlayer();
  bool _playingPage = false;

  // Phone voice (device TTS): reads the Tarjuma sheet's visible
  // translations aloud, page by page.
  final TranslationTtsService _tts = TranslationTtsService();

  @override
  void initState() {
    super.initState();
    _page = context.read<SettingsProvider>().mushafPage;
    _controller = PageController(initialPage: _page - 1);
    _pagePlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed && mounted) {
        setState(() => _playingPage = false);
      }
    }, onError: (_) {});
    Future.wait([MushafService.load(), QuranService.load()]).then((_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  void dispose() {
    _tts.stop();
    _pagePlayer.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Audio sources for one ayah — same logic as the Surah reader
  /// (duplicated here on purpose; no shared service in this pass):
  /// Arabic source first (unless mode is 'translation'), then the
  /// translation source when a voice is chosen and the mode asks
  /// for it. Each source prefers the downloaded file, else streams.
  Future<List<AudioSource>> _ayahSources(int surah, int ayahIndex) async {
    final settings = context.read<SettingsProvider>();
    final global = QuranService.globalAyahNumber(surah, ayahIndex);
    final ayahNumber = ayahIndex + 1;
    final voice = settings.translationVoice;
    final mode = settings.quranAudioMode;
    final wantTranslation = mode != 'arabic' && voice != null;
    final sources = <AudioSource>[];
    if (mode != 'translation' || !wantTranslation) {
      final local = await QuranAudioCache.localFileForAyah(
        surah,
        ayahIndex,
        reciterId: settings.reciterId,
      );
      if (local != null) {
        sources.add(AudioSource.file(local.path));
      } else {
        sources.add(
          AudioSource.uri(Uri.parse(settings.reciter.ayahUrl(global))),
        );
      }
    }
    if (wantTranslation) {
      final tLocal = await TranslationAudioCache.localFileForAyah(
        voice!.id,
        surah,
        ayahNumber,
      );
      if (tLocal != null) {
        sources.add(AudioSource.file(tLocal.path));
      } else {
        sources.add(
          AudioSource.uri(
            Uri.parse(voice.urlFor(surah, ayahNumber, global)),
          ),
        );
      }
    }
    return sources;
  }

  Future<void> _playPage() async {
    // Phone voice and reciter audio never overlap.
    await _tts.stop();
    final ayahs = MushafService.pageAyahs(_page);
    final sources = <AudioSource>[];
    for (final (s, a) in ayahs) {
      sources.addAll(await _ayahSources(s, a - 1));
    }
    if (sources.isEmpty) return;
    setState(() => _playingPage = true);
    try {
      await _pagePlayer.stop();
      await _pagePlayer.setAudioSource(
        ConcatenatingAudioSource(children: sources),
      );
      await _pagePlayer.play();
    } catch (_) {
      if (mounted) setState(() => _playingPage = false);
    }
  }

  void _stopPage() {
    _tts.stop();
    _pagePlayer.stop();
    setState(() => _playingPage = false);
  }

  void _goToPage(int page) {
    final p = page.clamp(1, MushafService.totalPages);
    _controller.animateToPage(
      p - 1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _showJumpToPage() {
    final ctrl = TextEditingController(text: '$_page');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Go to page'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Page number (1–548)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final p = int.tryParse(ctrl.text.trim()) ?? _page;
              Navigator.pop(ctx);
              _goToPage(p);
            },
            child: const Text('Go'),
          ),
        ],
      ),
    );
  }

  void _showJumpToSurah() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppTheme.mutedDark : AppTheme.mutedLight;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Go to Surah'),
        content: SizedBox(
          width: double.maxFinite,
          height: 420,
          child: ListView.builder(
            itemCount: QuranService.surahs.length,
            itemBuilder: (c, i) {
              final s = QuranService.surahs[i];
              return ListTile(
                leading: NumberBadge(
                  text: '${s.number}',
                  radius: 18,
                ),
                title: Text(
                  s.name,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(fontFamily: 'Amiri', fontSize: 20),
                ),
                subtitle: Text(
                  '${s.englishName} • Page ${MushafService.firstPageOfSurah(s.number)}',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _goToPage(MushafService.firstPageOfSurah(s.number));
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showTranslations() {
    final settings = context.read<SettingsProvider>();
    final ayahs = MushafService.pageAyahs(_page);
    // Demo tokens for the sheet chrome only — the mushaf page
    // rendering below is untouched.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? AppTheme.nightCard : AppTheme.cardLight;
    final ink = isDark ? AppTheme.nightInk : AppTheme.ink;
    final muted = isDark ? AppTheme.mutedDark : AppTheme.mutedLight;
    final accent = isDark ? AppTheme.goldDark : AppTheme.emerald;
    final cardLine =
        isDark ? AppTheme.cardLineDark : AppTheme.cardLineLight;
    // Extra translation for this page's ayat (a third language).
    // Downloaded on demand, one surah at a time; the sheet opens
    // immediately and fills the extra lines in when they arrive.
    final extraId = settings.extraTranslationId;
    final distinctSurahs = <int>{for (final (s, _) in ayahs) s}.toList();
    var extraLoading = extraId.isNotEmpty;
    var extraLoadStarted = false;
    Map<String, String>? extraTexts;
    // Phone voice state for the sheet (method scope — the
    // StatefulBuilder rebuilds, so a builder-local flag would reset).
    var ttsPlaying = false;

    Future<Map<String, String>> loadExtra() async {
      final map = <String, String>{};
      try {
        for (final s in distinctSurahs) {
          await TranslationTextService.ensureSurah(extraId, s);
        }
        for (final (s, a) in ayahs) {
          map['$s:$a'] =
              await TranslationTextService.ayah(extraId, s, a - 1);
        }
      } catch (_) {
        // Silent — the Urdu/English lines still show.
      }
      return map;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (c, setSheetState) {
          if (extraLoading && !extraLoadStarted) {
            extraLoadStarted = true;
            loadExtra().then((map) {
              extraTexts = map;
              setSheetState(() => extraLoading = false);
            });
          }
          // Phone voice: reads this page's visible translations
          // aloud, ayah by ayah. Tap again to stop.
          Future<void> toggleTts() async {
            if (ttsPlaying) {
              await _tts.stop();
              setSheetState(() => ttsPlaying = false);
              return;
            }
            _stopPage();
            final parts = <TtsPart>[];
            for (final (s, a) in ayahs) {
              if (settings.quranTranslation != 'english') {
                final t = QuranService.urduAyah(s, a - 1).trim();
                if (t.isNotEmpty) parts.add(TtsPart(t, 'ur'));
              }
              if (settings.quranTranslation == 'both' ||
                  settings.quranTranslation == 'english') {
                final t = QuranService.englishAyah(s, a - 1).trim();
                if (t.isNotEmpty) parts.add(TtsPart(t, 'en'));
              }
              final extra = extraTexts?['$s:$a']?.trim() ?? '';
              if (extra.isNotEmpty) {
                parts.add(
                  TtsPart(
                    extra,
                    settings.extraTranslation?.languageCode ?? 'en',
                  ),
                );
              }
            }
            if (parts.isEmpty) return;
            setSheetState(() => ttsPlaying = true);
            final ok = await _tts.speakParts(parts);
            final stopped = !ttsPlaying;
            setSheetState(() => ttsPlaying = false);
            if (!ok && !stopped) {
              ScaffoldMessenger.of(c).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Phone voice is not available for this language on this phone.',
                  ),
                ),
              );
            }
          }
          return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (c, scrollCtrl) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cardLine,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Translation — Page $_page',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: ink,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: ttsPlaying
                        ? 'Stop phone voice'
                        : 'Listen to translation (phone voice)',
                    icon: Icon(
                      ttsPlaying
                          ? Icons.stop_circle
                          : Icons.record_voice_over,
                      color: accent,
                    ),
                    onPressed: toggleTts,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Urdu (Jalandhari) + English (Asad) — the same verified translation as the Surah reader.',
                style: TextStyle(fontSize: 12, color: muted),
              ),
              if (extraLoading)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Downloading translation…',
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  itemCount: ayahs.length,
                  itemBuilder: (c, i) {
                    final (s, a) = ayahs[i];
                    final surah = QuranService.surah(s);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${surah.englishName} $s:$a',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: accent,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (settings.quranTranslation != 'english')
                              Text(QuranService.urduAyah(s, a - 1)),
                            if (settings.quranTranslation == 'both' ||
                                settings.quranTranslation == 'english')
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  QuranService.englishAyah(s, a - 1),
                                  style: const TextStyle(
                                    fontStyle: FontStyle.italic,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            if (extraTexts != null &&
                                (extraTexts!['$s:$a'] ?? '').isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  extraTexts!['$s:$a']!,
                                  style: const TextStyle(
                                    fontStyle: FontStyle.italic,
                                    fontSize: 13,
                                  ),
                                ),
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
        ),
      );
        },
      ),
    ).whenComplete(() => _tts.stop());
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paper = isDark ? AppTheme.nightCard : const Color(0xFFFFFDF5);
    final ink = isDark ? AppTheme.nightInk : const Color(0xFF2B2118);

    return Scaffold(
      appBar: AppBar(
        // Demo-token chrome: emerald bar by day, night bg after dark.
        // The mushaf page rendering below is untouched.
        backgroundColor: isDark ? AppTheme.nightBg : AppTheme.emerald,
        foregroundColor: isDark ? AppTheme.nightInk : Colors.white,
        elevation: 0,
        title: const Text(
          'Mushaf — 16 Line',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: _playingPage ? 'Stop page audio' : 'Play this page',
            icon: Icon(_playingPage ? Icons.stop : Icons.play_arrow),
            onPressed: _loading
                ? null
                : () {
                    if (_playingPage) {
                      _stopPage();
                    } else {
                      _playPage();
                    }
                  },
          ),
          IconButton(
            tooltip: 'Go to Surah',
            icon: const Icon(Icons.menu_book),
            onPressed: _loading ? null : _showJumpToSurah,
          ),
          IconButton(
            tooltip: 'Page number',
            icon: const Icon(Icons.find_in_page),
            onPressed: _loading ? null : _showJumpToPage,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Page $_page / ${MushafService.totalPages} • '
                          'Pakistani Mushaf (16 line)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: ink,
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.translate, size: 18),
                        label: const Text('Translation'),
                        onPressed: _showTranslations,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: MushafService.totalPages,
                    onPageChanged: (i) {
                      if (_playingPage) {
                        _pagePlayer.stop();
                        _playingPage = false;
                      }
                      setState(() => _page = i + 1);
                      settings.setMushafPage(i + 1);
                    },
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                        child: _MushafPage(
                          page: index + 1,
                          paper: paper,
                          ink: ink,
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Previous page'),
                          onPressed: _page > 1
                              ? () => _goToPage(_page - 1)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('Next page'),
                          onPressed:
                              _page < MushafService.totalPages
                                  ? () => _goToPage(_page + 1)
                                  : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

/// One printed mushaf page: gold double border, faint pattern, 16 lines.
class _MushafPage extends StatelessWidget {
  final int page;
  final Color paper;
  final Color ink;

  const _MushafPage({
    required this.page,
    required this.paper,
    required this.ink,
  });

  @override
  Widget build(BuildContext context) {
    final lines = MushafService.pageLines(page);
    final surahs = MushafService.pageSurahs(page);
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          colors: [AppTheme.goldLight, AppTheme.gold, AppTheme.emerald],
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: paper,
          borderRadius: BorderRadius.circular(8),
        ),
        child: PatternBackground(
          base: paper,
          patternColor: AppTheme.gold,
          patternOpacity: 0.07,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              children: [
                // Page header: surah name(s) on this page. One line,
                // ellipsised — a wrapping header used to push the 16
                // lines down and crowd the first line.
                if (surahs.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      surahs
                          .map((s) => QuranService.surah(s).englishName)
                          .join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: ink.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                Expanded(
                  child: Column(
                    children: [
                      for (final line in lines)
                        Expanded(child: _MushafLine(line: line, ink: ink)),
                      // Short pages (opening spread, last page) keep
                      // their lines at the top; the rest stays empty,
                      // exactly like the printed mushaf.
                      for (var i = lines.length; i < 16; i++)
                        const Expanded(child: SizedBox.shrink()),
                    ],
                  ),
                ),
                Text(
                  'Page $page',
                  style: TextStyle(
                    fontSize: 11,
                    color: ink.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One printed line. Lines never wrap or overflow: the text is scaled
/// down to fit the page width (FittedBox), like the printed mushaf.
class _MushafLine extends StatelessWidget {
  final List<dynamic> line;
  final Color ink;

  const _MushafLine({required this.line, required this.ink});

  @override
  Widget build(BuildContext context) {
    if (line.isEmpty) return const SizedBox.shrink();
    final type = line[0] as String;
    if (type == 'h' || type == 'hb') {
      final surah = QuranService.surah(line[1] as int);
      // OVERLAP FIX (Run 7): a header line holds TWO stacked texts
      // (surah-name pill + basmalah) inside ONE 1/16-height slot
      // (~37px on a phone). Unwrapped, the two texts together are
      // taller than the slot, so the basmalah printed ON TOP of the
      // next line — the "pixels overlap" on the Mushaf. The whole
      // header is now wrapped in a scale-down FittedBox, so it shrinks
      // to fit the slot (both axes) instead of overflowing it.
      return FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.gold, width: 1.5),
                borderRadius: BorderRadius.circular(20),
                color: AppTheme.gold.withValues(alpha: 0.12),
              ),
              child: Text(
                surah.name,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: 'IndoPak',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ink,
                ),
              ),
            ),
            if (type == 'hb')
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(
                  MushafService.basmalah,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: 'IndoPak',
                    fontSize: 15,
                    color: ink,
                  ),
                ),
              ),
          ],
        ),
      );
    }
    if (type == 'b') {
      return Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            MushafService.basmalah,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'IndoPak',
              fontSize: 20,
              color: ink,
            ),
          ),
        ),
      );
    }
    // Ayah line: join all segments on this visual line. Centred (was
    // right-aligned): a long right-aligned line clips its beginning and
    // shows only its second half; centred text stays whole.
    final segs = line[1] as List;
    final text = segs.map((s) => s[2].toString()).join(' ');
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'IndoPak',
            fontSize: 21,
            color: ink,
            height: 1.6,
          ),
        ),
      ),
    );
  }
}
