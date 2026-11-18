import 'dart:ui';

import 'package:just_audio/just_audio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/quran_audio_cache.dart';
import '../services/quran_reciters.dart';
import '../services/quran_service.dart';
import '../services/settings_provider.dart';
import '../services/translation_audio_cache.dart';
import '../services/translation_text_service.dart';
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
  // Estimated download size for this surah with the current reciter
  // (null = not fetched yet). _lastReciterId tracks which reciter the
  // audio state above was fetched for.
  int? _surahAudioEstimate;
  String? _lastReciterId;

  // Translation-audio (spoken Urdu/English) download state for this
  // surah. _transAudioDownloaded null = no voice chosen / not checked.
  bool? _transAudioDownloaded;
  bool _downloadingTransAudio = false;
  int _transDownloadDone = 0;
  int _transDownloadTotal = 0;
  int _transDownloadedBytes = 0;
  int _transAudioBytes = 0;

  // Extra translation (a third language, from
  // TranslationTextService). _extraAyahs holds one entry per ayah
  // after the surah is downloaded; null = none chosen / not loaded.
  List<String>? _extraAyahs;
  bool _extraDownloading = false;
  String? _lastExtraTranslationId;

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
    final settings = context.read<SettingsProvider>();
    _lastReciterId = settings.reciterId;
    _lastExtraTranslationId = settings.extraTranslationId;
    _refreshAudioState();
    _ensureExtraTranslation();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  /// Audio sources for one ayah, from the current audio mode:
  /// 'arabic' → [arabic]; 'interleaved' → [arabic, translation];
  /// 'translation' → [translation]. A mode that needs a translation
  /// voice falls back to Arabic only when no voice is chosen.
  /// Each source prefers the downloaded file, else streams the URL.
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

  Future<void> _playAyah(int ayahIndex) async {
    setState(() {
      _playingAyah = ayahIndex;
      _audioFailed = false;
    });
    try {
      await _player.stop();
      final sources =
          await _ayahSources(widget.surahNumber, ayahIndex);
      if (sources.isEmpty) throw StateError('No audio source');
      await _player.setAudioSource(
        ConcatenatingAudioSource(children: sources),
      );
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
    final settings = context.read<SettingsProvider>();
    final reciterId = settings.reciterId;
    final downloaded = await QuranAudioCache.isSurahDownloaded(
      widget.surahNumber,
      reciterId: reciterId,
    );
    final bytes = await QuranAudioCache.cachedBytesForSurah(
      widget.surahNumber,
      reciterId: reciterId,
    );
    final estimate = await QuranAudioCache.estimateSurahBytes(
      reciterId,
      widget.surahNumber,
    );
    if (mounted && settings.reciterId == reciterId) {
      setState(() {
        _audioDownloaded = downloaded;
        _surahAudioBytes = bytes;
        _surahAudioEstimate = estimate;
      });
    }
    await _refreshTranslationAudioState();
  }

  Future<void> _refreshTranslationAudioState() async {
    final voice = context.read<SettingsProvider>().translationVoice;
    if (voice == null) {
      if (mounted) {
        setState(() {
          _transAudioDownloaded = null;
          _transAudioBytes = 0;
        });
      }
      return;
    }
    final downloaded = await TranslationAudioCache.isSurahDownloaded(
      voice.id,
      widget.surahNumber,
    );
    final bytes = await TranslationAudioCache.cachedBytesForSurah(
      voice.id,
      widget.surahNumber,
    );
    if (mounted) {
      setState(() {
        _transAudioDownloaded = downloaded;
        _transAudioBytes = bytes;
      });
    }
  }

  Future<void> _downloadTranslationAudio() async {
    final voice = context.read<SettingsProvider>().translationVoice;
    if (voice == null) return;
    final surah = QuranService.surah(widget.surahNumber);
    setState(() {
      _downloadingTransAudio = true;
      _downloadError = null;
      _transDownloadDone = 0;
      _transDownloadTotal = surah.ayahs.length;
      _transDownloadedBytes = 0;
    });
    try {
      await TranslationAudioCache.downloadSurah(
        voice.id,
        widget.surahNumber,
        onProgress: (done, total, bytes) {
          if (mounted) {
            setState(() {
              _transDownloadDone = done;
              _transDownloadTotal = total;
              _transDownloadedBytes = bytes;
            });
          }
        },
      );
      await _refreshTranslationAudioState();
    } catch (_) {
      if (mounted) {
        setState(() {
          _downloadError =
              'Translation download failed — check your internet and try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _downloadingTransAudio = false);
    }
  }

  Future<void> _deleteTranslationAudio() async {
    final voice = context.read<SettingsProvider>().translationVoice;
    if (voice == null) return;
    await TranslationAudioCache.deleteSurah(voice.id, widget.surahNumber);
    await _refreshTranslationAudioState();
  }

  /// Downloads this surah's extra translation (if one is chosen)
  /// and caches its ayah texts for the cards below. Silent on
  /// failure — the Urdu/English lines still show.
  Future<void> _ensureExtraTranslation() async {
    final editionId = context.read<SettingsProvider>().extraTranslationId;
    if (editionId.isEmpty) {
      if (mounted) {
        setState(() {
          _extraAyahs = null;
          _extraDownloading = false;
        });
      }
      return;
    }
    if (mounted) setState(() => _extraDownloading = true);
    try {
      await TranslationTextService.ensureSurah(
        editionId,
        widget.surahNumber,
      );
      final count = QuranService.surah(widget.surahNumber).ayahs.length;
      final list = <String>[];
      for (var i = 0; i < count; i++) {
        list.add(
          await TranslationTextService.ayah(
            editionId,
            widget.surahNumber,
            i,
          ),
        );
      }
      if (mounted &&
          context.read<SettingsProvider>().extraTranslationId ==
              editionId) {
        setState(() {
          _extraAyahs = list;
          _extraDownloading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _extraDownloading = false);
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
        reciterId: context.read<SettingsProvider>().reciterId,
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
    await QuranAudioCache.deleteSurah(
      widget.surahNumber,
      reciterId: context.read<SettingsProvider>().reciterId,
    );
    await _refreshAudioState();
  }

  Widget _buildAudioDownloadCard(ReaderTheme theme) {
    final settings = context.read<SettingsProvider>();
    final reciter = settings.reciter;
    final estimate = _surahAudioEstimate;
    final estimateText = estimate != null
        ? ' (≈ ${QuranAudioCache.formatBytes(estimate)})'
        : '';
    // Demo token pill: chip surface + card-line border, reader
    // accent kept for the text/icon (it belongs to the reader theme).
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chipBg = isDark ? AppTheme.chipDark : AppTheme.chipLight;
    final cardLine =
        isDark ? AppTheme.cardLineDark : AppTheme.cardLineLight;

    Widget arabicPart;
    if (_downloadingAudio) {
      final total = _downloadTotal == 0 ? 1 : _downloadTotal;
      arabicPart = Column(
        children: [
          LinearProgressIndicator(
            value: _downloadDone / total,
            color: theme.accent,
            backgroundColor: theme.accent.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 6),
          Text(
            'Downloading ${reciter.label} audio… '
            '$_downloadDone/$_downloadTotal verses'
            ' • ${QuranAudioCache.formatBytes(_downloadedBytes)}',
            style: TextStyle(fontSize: 12, color: theme.accent),
          ),
        ],
      );
    } else if (_audioDownloaded == true) {
      arabicPart = Container(
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
                '${reciter.label} audio downloaded • '
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
      );
    } else {
      arabicPart = Column(
        children: [
          OutlinedButton.icon(
            onPressed: _downloadAudio,
            icon: const Icon(Icons.download, size: 18),
            label: Text(
              'Download ${reciter.label} audio$estimateText '
              'for offline listening',
            ),
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
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          arabicPart,
          if (settings.translationVoice != null) ...[
            const SizedBox(height: 8),
            _buildTranslationAudioRow(theme),
          ],
        ],
      ),
    );
  }

  /// Second row in the audio card: download state for the chosen
  /// translation voice, for this surah only.
  Widget _buildTranslationAudioRow(ReaderTheme theme) {
    final voice = context.read<SettingsProvider>().translationVoice;
    if (voice == null) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chipBg = isDark ? AppTheme.chipDark : AppTheme.chipLight;
    final cardLine =
        isDark ? AppTheme.cardLineDark : AppTheme.cardLineLight;
    if (_downloadingTransAudio) {
      final total = _transDownloadTotal == 0 ? 1 : _transDownloadTotal;
      return Column(
        children: [
          LinearProgressIndicator(
            value: _transDownloadDone / total,
            color: theme.accent,
            backgroundColor: theme.accent.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 6),
          Text(
            'Downloading ${voice.label} audio… '
            '$_transDownloadDone/$_transDownloadTotal verses'
            ' • ${QuranAudioCache.formatBytes(_transDownloadedBytes)}',
            style: TextStyle(fontSize: 12, color: theme.accent),
          ),
        ],
      );
    }
    if (_transAudioDownloaded == true) {
      return Container(
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
                '${voice.label} audio downloaded • '
                '${QuranAudioCache.formatBytes(_transAudioBytes)} — plays offline',
                style: TextStyle(fontSize: 12, color: theme.accent),
              ),
            ),
            TextButton(
              onPressed: _deleteTranslationAudio,
              child: const Text('Delete'),
            ),
          ],
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: _downloadTranslationAudio,
      icon: const Icon(Icons.download, size: 18),
      label: Text(
        'Download ${voice.label} audio for offline listening',
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
      builder: (ctx) => SingleChildScrollView(
        child: Padding(
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
            Text('RECITER', style: sectionStyle.copyWith(color: gold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: QuranReciter.all.map((r) {
                return chip(r.label, settings.reciterId == r.edition, () {
                  settings.setReciterId(r.edition);
                  Navigator.pop(ctx);
                });
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text('AUDIO MODE', style: sectionStyle.copyWith(color: gold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: {
                'arabic': 'Arabic only',
                'interleaved': 'Arabic + translation',
                'translation': 'Translation only',
              }.entries.map((e) {
                return chip(e.value, settings.quranAudioMode == e.key, () {
                  settings.setQuranAudioMode(e.key);
                  Navigator.pop(ctx);
                });
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text(
              'TRANSLATION VOICE',
              style: sectionStyle.copyWith(color: gold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                chip('Off', settings.translationVoiceId.isEmpty, () {
                  settings.setTranslationVoiceId('');
                  Navigator.pop(ctx);
                }),
                ...TranslationVoice.all.map((v) {
                  return chip(
                    v.label,
                    settings.translationVoiceId == v.id,
                    () {
                      settings.setTranslationVoiceId(v.id);
                      Navigator.pop(ctx);
                    },
                  );
                }),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'EXTRA TRANSLATION',
              style: sectionStyle.copyWith(color: gold),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _showExtraTranslationDialog(context);
              },
              icon: const Icon(Icons.translate, size: 18),
              label: Text(
                settings.extraTranslation == null
                    ? 'Choose language… (None)'
                    : 'Choose language… '
                        '(${settings.extraTranslation!.languageName})',
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
        ),
      ),
    );
  }

  /// Language picker for the extra (third) translation, shared with
  /// the Settings screen's own copy. 'None' keeps Urdu + English.
  void _showExtraTranslationDialog(BuildContext context) {
    final settings = context.read<SettingsProvider>();
    final current = settings.extraTranslation;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Extra translation language'),
        content: SizedBox(
          width: double.maxFinite,
          height: 420,
          child: ListView.builder(
            itemCount: TranslationTextService.all.length + 1,
            itemBuilder: (c, i) {
              if (i == 0) {
                return ListTile(
                  title: const Text('None'),
                  subtitle: const Text('Urdu + English only'),
                  trailing: current == null
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () {
                    settings.setExtraTranslationId('');
                    Navigator.pop(ctx);
                  },
                );
              }
              final e = TranslationTextService.all[i - 1];
              return ListTile(
                title: Text(e.languageName),
                subtitle: Text(e.translator),
                trailing: current?.id == e.id
                    ? const Icon(Icons.check)
                    : null,
                onTap: () {
                  settings.setExtraTranslationId(e.id);
                  Navigator.pop(ctx);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    // Reciter / extra-translation changes need a refresh of the
    // audio state / translation texts. Scheduled after this frame
    // so the refresh's setState never runs mid-build.
    if (settings.reciterId != _lastReciterId) {
      _lastReciterId = settings.reciterId;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _refreshAudioState(),
      );
    }
    if (settings.extraTranslationId != _lastExtraTranslationId) {
      _lastExtraTranslationId = settings.extraTranslationId;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _ensureExtraTranslation(),
      );
    }
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
                if (_extraDownloading)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Downloading translation…',
                      style: TextStyle(fontSize: 12, color: theme.accent),
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
                    if (_extraAyahs != null &&
                        ayahIndex < _extraAyahs!.length &&
                        _extraAyahs![ayahIndex].isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _extraAyahs![ayahIndex],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: theme.text.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
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
