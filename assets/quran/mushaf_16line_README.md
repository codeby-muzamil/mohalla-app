# 16-line Pakistani Mushaf — source, licence, verification

## What this is

`mushaf_16line.json` is the **Taj Company 16-line IndoPak Mushaf layout**:
548 pages × 16 lines per page — the printed Quran Pakistani huffaz use
(the 604-page figure is the 15-line Madani Mushaf, NOT this one).
`IndoPakNastaleeq.ttf` is the matching Nastaleeq font that renders it.

## Source

- Layout + word text: **QUL — TarteelAI Quranic Universal Library**,
  "Indopak 16 lines layout (Taj Company)" + IndoPak word-by-word text
  (https://qul.tarteel.ai/resources/mushaf-layout/11 and
  https://qul.tarteel.ai/resources/quran-script/55), as shipped by the
  open-source **Nimaz** app (arshad-shah/Nimaz, branch `dev`):
  `nimaz-pro-data/json/mushaf/indopak_16_layout.json`,
  `nimaz-pro-data/json/mushaf/indopak_text.json`, and
  `core/ui/src/main/res/font/indopak_nastaleeq.ttf`.
- Converted to the bundled format by `/tmp/mushaf16/convert.py`
  (2026-11-17): pages → 16 lines; each line is ayah segments
  (`['a', [[surah, ayah, 'words...'], ...]]`), a surah header
  (`['h', surah]`), a basmalah (`['b']`), or header+basmalah sharing
  one line (`['hb', surah]`, 81 surahs).

## Verified (2026-11-17, before bundling)

- 548 pages, continuous 1..548; 544 pages have exactly 16 visual lines
  (pp. 1–2 have 7 — the opening spread; p. 548 has 10).
- 8,743 visual lines; 6,236 ayat reconstructed word-for-word from the
  layout segments — **83,668 words, 0 mismatches** vs the source text.
- 114 surah headers, 112 basmalah lines (surahs 1 and 9 have none).
- Page 1 renders Surah Al-Fatiha exactly as printed. Pages often end
  mid-ayah in this layout (unlike the Madani Mushaf) — the reader
  handles that; it never reflows or guesses text.

## Licence — READ BEFORE PUBLISHING

- **Layout data (QUL):** TarteelAI states layouts are free to bundle in
  personal and commercial projects, attribution optional.
- **Font (QuranWBW):** the IndoPak Nastaleeq font is shared under
  Sadaqa-e-Jaria terms — "NOT FOR SALE, NOT FOR MODIFICATION, NOT FOR
  DISTRIBUTION … WITHOUT WRITTEN NOTICE BY QURANWBW.COM". Before this
  app is published anywhere, file the written notice to
  **quranwbw@gmail.com** (the Nimaz project did this for its free app).
  The current APK is for the owner's own testing only.
