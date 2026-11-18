# Azan audio — verified Internet Archive recordings

The 4 MP3 files in this folder are real Azan recordings from
Internet Archive (archive.org), verified live on 2026-11-16
(HTTP 200, audio/mpeg, correct MP3 data):

| File | Recording | Source |
|---|---|---|
| `afasy.mp3` (4,028 KB) | Azan by Mishary Rashid Al-Afasy | archive.org item `VeryBeautifulAdhaanByMisharyAlAfasy` |
| `qatami.mp3` (3,110 KB) | Azan by Nasser Al-Qatami | archive.org item `AthanQatami` |
| `makkah.mp3` (3,908 KB) | Makkah Fajr Adhan by Sheikh Yunus Khoja (5-9-13) | archive.org item `MakkahAdhanAl-fajr5-9-13SheikhYunusKhoja` |
| `madinah.mp3` (2,460 KB) | Madinah Asr Adhan by Sheikh Surayhi (2-9-13) | archive.org item `MadinahAsrAdhan2913SheikhSurayhi` |

## Honest labels

- `makkah.mp3` is a **Fajr** Adhan — it includes
  "as-salatu khayrun min an-nawm". The app labels it as a Fajr Adhan.
- `madinah.mp3` is an **Asr** Adhan (standard wording).
- The app labels each voice exactly as above; no voice is presented
  as a recording it is not.

## How they are wired

- In-app playback (Settings "sunn kar dekhein" + the in-app Azan
  banner): `assets/azan/<file>.mp3` via the `just_audio` package.
- Scheduled notification sound: the same files are ALSO copied to
  `android/app/src/main/res/raw/` (afasy.mp3, qatami.mp3, makkah.mp3,
  madinah.mp3) and referenced as
  `RawResourceAndroidNotificationSound('<name>')` in
  `lib/services/notification_service.dart`.

## Replacing a voice

To use a different recording, replace the MP3 file here AND in
`android/app/src/main/res/raw/` with the same filename, keeping the
name lowercase with no spaces or dashes (Android raw-resource rule).
