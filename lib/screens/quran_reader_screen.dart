import 'dart:ui';

import 'package:just_audio/just_audio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/quran_audio_cache.dart';
import '../services/quran_service.dart';
import '../services/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Quran reader: Arabic (Uthmani) + Urdu (Jalandhari) + English (Asad),
/// 4 Arabic fonts, font-size control, 5 reader themes, translation
/// display options, bookmarks, last-read resume, per-ayah audio
/// (online, Alafasy — or offline when the surah is downloaded).
class QuranReaderScreen extends StatefulWidget {
  final int surahNumber;
  final int initialAyah;

  const QuranReaderScreen({
    super.key,
    required this.surahNumber,
    this.initialAyah = 1,
  });

  @override
  State<QuranReaderScreen> createState() => _QuranReaderScreenState();
}

class _QuranReaderScreenState extends State<QuranReaderScreen> {
  final AudioPlayer _player = AudioPlayer();
  int? _playingAyah; // ayah index currently playing
  bool _hifzMode = false;
  final Set<int> _revealed = {};
  bool _audioFailed = false;

  // Offline audio for this surah (per-surah download, see
  // QuranAudioCache). _audioDownloaded null = not checked yet.
  bool? _audioDownloaded;
  bool _downloadingAudio = false;
  int _downloadDone = 0;
  int _downloadTotal = 0;
  int _downloadedBytes = 0;
  int _surahAudioBytes = 0;
  String? _downloadError;

  static const Map<String, String> _fonts = {
    'Amiri': 'Amiri',
    'ScheherazadeNew': 'Scheherazade New',
    'Lateef': 'Lateef',
    'Default': 'Default (system)',
  };

  @override
  void initState() {
    super.initState();
    // just_audio reports completion through playerStateStream
    // (there is no onPlayerComplete callback).
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed && mounted) {
        setState(() => _playingAyah = null);
      }
    }, onError: (_) {});
    _refreshAudioState();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _playAyah(int ayahIndex) async {
    final global =
        QuranService.globalAyahNumber(widget.surahNumber, ayahIndex);
    final url = QuranService.audioUrlForGlobalAyah(global);
    setState(() {
      _playingAyah = ayahIndex;
      _audioFailed = false;
    });
    try {
      await _player.stop();
      // Downloaded ayahs play from the phone (offline); anything
      // else streams exactly as before.
      final local = await QuranAudioCache.localFileForAyah(
        widget.surahNumber,
        ayahIndex,
      );
      if (local != null) {
        await _player.setFilePath(local.path);
      } else {
        await _player.setUrl(url);
      }
      await _player.play();
    } catch (_) {
      if (mounted) {
        setState(() {
          _playingAyah = null;
          _audioFailed = true;
        });
      }
    }
  }

  Future<void> _refreshAudioState() async {
    final downloaded =
        await QuranAudioCache.isSurahDownloaded(widget.surahNumber);
    final bytes =
        await QuranAudioCache.cachedBytesForSurah(widget.surahNumber);
    if (mounted) {
      setState(() {
        _audioDownloaded = downloaded;
        _surahAudioBytes = bytes;
      });
    }
  }

  Future<void> _downloadAudio() async {
    final surah = QuranService.surah(widget.surahNumber);
    setState(() {
      _downloadingAudio = true;
      _downloadError = null;
      _downloadDone = 0;
      _downloadTotal = surah.ayahs.length;
      _downloadedBytes = 0;
    });
    try {
      await QuranAudioCache.downloadSurah(
        widget.surahNumber,
        onProgress: (done, total, bytes) {
          if (mounted) {
            setState(() {
              _downloadDone = done;
              _downloadTotal = total;
              _downloadedBytes = bytes;
            });
          }
        },
      );
      await _refreshAudioState();
    } catch (_) {
      if (mounted) {
        setState(() {
          _downloadError =
              'Download failed — check your internet and try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _downloadingAudio = false);
    }
  }

  Future<void> _deleteAudio() async {
    await QuranAudioCache.deleteSurah(widget.surahNumber);
    await _refreshAudioState();
  }

  Widget _buildAudioDownloadCard(ReaderTheme theme) {
    if (_downloadingAudio) {
      final total = _downloadTotal == 0 ? 1 : _downloadTotal;
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          children: [
            LinearProgressIndicator(
              value: _downloadDone / total,
              color: theme.accent,
              backgroundColor: theme.accent.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 6),
            Text(
              'Downloading audio… $_downloadDone/$_downloadTotal verses'
              ' • ${QuranAudioCache.formatBytes(_downloadedBytes)}',
              style: TextStyle(fontSize: 12, color: theme.accent),
            ),
          ],
        ),
      );
    }
    if (_audioDownloaded == true) {
      // Demo token pill: chip surface + card-line border, reader
      // accent kept for the text/icon (it belongs to the reader theme).
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final chipBg = isDark ? AppTheme.chipDark : AppTheme.chipLight;
      final cardLine =
          isDark ? AppTheme.cardLineDark : AppTheme.cardLineLight;
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: chipBg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: cardLine, width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.download_done, size: 16, color: theme.accent),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Audio downloaded • '
                  '${QuranAudioCache.formatBytes(_surahAudioBytes)} — plays offline',
                  style: TextStyle(fontSize: 12, color: theme.accent),
                ),
              ),
              TextButton(
                onPressed: _deleteAudio,
                child: const Text('Delete'),
              ),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          OutlinedButton.icon(
            onPressed: _downloadAudio,
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Download audio for offline listening'),
          ),
          if (_downloadError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _downloadError!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  void _showReaderSettings() {
    final settings = context.read<SettingsProvider>();
    // Demo tokens for the sheet chrome only — the 5 ReaderTheme
    // choices below are unchanged.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? AppTheme.nightCard : AppTheme.cardLight;
    final gold = isDark ? AppTheme.goldDark : AppTheme.gold;
    final ink = isDark ? AppTheme.nightInk : AppTheme.ink;
    final chipBg = isDark ? AppTheme.chipDark : AppTheme.chipLight;
    final cardLine =
        isDark ? AppTheme.cardLineDark : AppTheme.cardLineLight;
    const sectionStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.bold,
      letterSpacing: 1.1,
    );
    Widget chip(String label, bool selected, VoidCallback onTap) {
      return ChoiceChip(
        label: Text(label),
        selected: selected,
        backgroundColor: chipBg,
        selectedColor: gold.withValues(alpha: 0.25),
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: selected ? gold : ink,
        ),
        side: BorderSide(
          color: selected ? gold : cardLine,
          width: 1.5,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        onSelected: (_) => onTap(),
      );
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            Text(
              'Quran Reader Settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: ink,
              ),
            ),
            const SizedBox(height: 16),
            Text('ARABIC FONT', style: sectionStyle.copyWith(color: gold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _fonts.keys.map((f) {
                return chip(_fonts[f]!, settings.quranFont == f, () {
                  settings.setQuranFont(f);
                  Navigator.pop(ctx);
                });
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text(
              'Font size: ${settings.quranFontSize.round()}',
              style: TextStyle(fontWeight: FontWeight.w600, color: ink),
            ),
            Slider(
              min: 18,
              max: 40,
              divisions: 11,
              value: settings.quranFontSize,
              activeColor: gold,
              inactiveColor: cardLine,
              onChanged: (v) => settings.setQuranFontSize(v),
            ),
            const SizedBox(height: 4),
            Text('READER THEME', style: sectionStyle.copyWith(color: gold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ReaderTheme.all.map((t) {
                return chip(t.labelEnglish, settings.quranTheme == t.id, () {
                  settings.setQuranTheme(t.id);
                  Navigator.pop(ctx);
                });
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text('TRANSLATION', style: sectionStyle.copyWith(color: gold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: {
                'urdu': 'Urdu',
                'english': 'English',
                'both': 'Urdu + English',
                'off': 'Off',
              }.entries.map((e) {
                return chip(e.value, settings.quranTranslation == e.key, () {
                  settings.setQuranTranslation(e.key);
                  Navigator.pop(ctx);
                });
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final surah = QuranService.surah(widget.surahNumber);
    final theme = ReaderTheme.byId(settings.quranTheme);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final arabicFont =
        settings.quranFont == 'Default' ? null : settings.quranFont;

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        // Demo-token chrome: emerald bar by day, night bg after dark.
        // The reader themes (page background / text / accent) are
        // untouched — only this surrounding chrome is re-skinned.
        backgroundColor: isDark ? AppTheme.nightBg : AppTheme.emerald,
        foregroundColor: isDark ? AppTheme.nightInk : Colors.white,
        elevation: 0,
        // Title is English only with ellipsis: the old
        // 'English (Arabic)' title overflowed the AppBar and clipped
        // into the action icons on a narrow phone at 1.3x elder text
        // (bidi Arabic inside an LTR title). The Arabic name is shown
        // in the body header below (Basmalah + info line).
        title: Text(
          surah.englishName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Hifz mode (blur + tap to reveal)',
            icon: Icon(
              _hifzMode ? Icons.visibility_off : Icons.visibility,
            ),
            onPressed: () => setState(() {
              _hifzMode = !_hifzMode;
              _revealed.clear();
            }),
          ),
          IconButton(
            tooltip: 'Reader settings',
            icon: const Icon(Icons.text_fields),
            onPressed: _showReaderSettings,
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        itemCount: surah.ayahs.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              children: [
                if (surah.number != 1 && surah.number != 9)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: arabicFont ?? 'Amiri',
                        fontSize: settings.quranFontSize + 2,
                        color: theme.text,
                      ),
                    ),
                  ),
                Text(
                  '${surah.englishName} — ${surah.englishNameTranslation} • '
                  '${surah.ayahs.length} verses • ${surah.revelationType}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.accent, fontSize: 13),
                ),
                if (_audioFailed)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Audio did not load — check your internet.',
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                _buildAudioDownloadCard(theme),
                const SizedBox(height: 8),
              ],
            );
          }
          final ayahIndex = index - 1;
          final ayahNumber = ayahIndex + 1;
          final key = '${surah.number}:$ayahNumber';
          final bookmarked = settings.quranBookmarks.contains(key);
          final juz = QuranService.juzOf(surah.number, ayahNumber);
          final arabic = surah.ayahs[ayahIndex];
          final blurred =
              _hifzMode && !_revealed.contains(ayahIndex);

          return Card(
            color: theme.background,
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: theme.accent.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              onTap: () {
                settings.setLastRead(key);
                if (_hifzMode) {
                  setState(() {
                    if (_revealed.contains(ayahIndex)) {
                      _revealed.remove(ayahIndex);
                    } else {
                      _revealed.add(ayahIndex);
                    }
                  });
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        NumberBadge(
                          text: '$ayahNumber',
                          radius: 14,
                        ),
                        if (juz > 0)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Text(
                              'Juz $juz',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.accent,
                              ),
                            ),
                          ),
                        const Spacer(),
                        // Compact buttons: the default 48px IconButton
                        // + 1.3x elder text squeezed the badge and
                        // "Para X" label on narrow phones.
                        IconButton(
                          tooltip: _audioDownloaded == true
                              ? 'Listen to audio (offline)'
                              : 'Listen to audio (online)',
                          iconSize: 22,
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            _playingAyah == ayahIndex
                                ? Icons.stop_circle
                                : Icons.play_circle,
                            color: theme.accent,
                          ),
                          onPressed: () {
                            if (_playingAyah == ayahIndex) {
                              _player.stop();
                              setState(() => _playingAyah = null);
                            } else {
                              _playAyah(ayahIndex);
                            }
                          },
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: 'Bookmark',
                          iconSize: 22,
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            bookmarked
                                ? Icons.bookmark
                                : Icons.bookmark_border,
                            color: theme.accent,
                          ),
                          onPressed: () =>
                              settings.toggleBookmark(key),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ImageFiltered(
                      imageFilter: blurred
                          ? ImageFilter.blur(sigmaX: 8, sigmaY: 8)
                          : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                      child: Text(
                        arabic,
                        textDirection: TextDirection.rtl,
                        // Centred (was right): a long right-aligned ayah
                        // clips its beginning and shows only its half.
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: arabicFont,
                          fontSize: settings.quranFontSize,
                          color: theme.text,
                          height: 2.0,
                        ),
                      ),
                    ),
                    if (blurred)
                      Text(
                        'Hifz mode — recite from memory, then tap to reveal',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.accent,
                        ),
                      ),
                    if (settings.quranTranslation != 'off') ...[
                      const SizedBox(height: 8),
                      if (settings.quranTranslation == 'urdu' ||
                          settings.quranTranslation == 'both')
                        Text(
                          QuranService.urduAyah(surah.number, ayahIndex),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.text,
                          ),
                        ),
                      if (settings.quranTranslation == 'english' ||
                          settings.quranTranslation == 'both')
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            QuranService.englishAyah(surah.number, ayahIndex),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: theme.text.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
