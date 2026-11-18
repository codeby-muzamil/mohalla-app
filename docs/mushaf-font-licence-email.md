# Mushaf font licence — email draft (send before any PUBLIC release)

**To:** quranwbw@gmail.com
**Subject:** Notice — IndoPak Nastaleeq font (QuranWBW) used in the Mohalla app

**Body:**

> Assalamu Alaikum,
>
> My name is [YOUR NAME], and I am the developer of **Mohalla**, a free Islamic app for Android (package name: `com.mohalla.app`).
>
> I am writing to give the written notice requested for the **IndoPak Nastaleeq** font (QuranWBW, Al Qalam) before any public release of the app.
>
> The font is used in Mohalla only to display the Holy Quran in the traditional 16-line Pakistani Mushaf layout (the "Mushaf — 16 Line" reader in the app). The font file (`IndoPakNastaleeq.ttf`) is bundled with the app; it is not modified, not resold, and not distributed on its own. The app itself is free.
>
> The Quran text layout data used alongside the font is the QUL "Indopak 16 lines" dataset (TarteelAI / Nimaz project), which is free to bundle.
>
> Please let me know if this notice is sufficient, or if you need any further information (for example the exact font version, the app's store listing, or a different form of attribution).
>
> Jazakum Allahu Khairan,
>
> [YOUR NAME]
> [YOUR EMAIL]
> Mohalla — com.mohalla.app

---

## Why this email exists

- The 16-line Mushaf reader (`lib/screens/mushaf_reader_screen.dart`) uses the **IndoPak Nastaleeq** font (`assets/fonts/IndoPakNastaleeq.ttf`, family `IndoPak` in `pubspec.yaml`), from QuranWBW (Al Qalam).
- The QUL layout data is free to bundle, but the **font** asks for written notice before distribution — see `assets/quran/mushaf_16line_README.md`.
- **This email MUST be sent before any public release** (Play Store or any other public distribution). Internal testing builds on the owner's own phone do not count as a public release, but do not publish until the notice is sent.
- Replace the `[YOUR NAME]` / `[YOUR EMAIL]` placeholders before sending. Keep a copy of the sent email.
