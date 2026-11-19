# BUILD_NOTES.md — things the owner must fill in himself

Honest gaps in this project. Nothing below is secretly done — each item
says exactly what is missing and how to fill it.

## 1. Launcher icon (Icon 2 — gold M minarets)

- `android/app/src/main/res/mipmap-*/ic_launcher.png` mein abhi ek
  SIMPLE placeholder hai (gold "M" on emerald, PIL se banaya gaya).
- Asal Icon 2 (gold letter M shaped as two minarets with a small dome)
  ki file se replace karein — ya `flutter_launcher_icons` package se
  generate karein:
  1. Icon ki PNG file (1024x1024) project mein rakhein, masalan
     `assets/icon/icon-2.png`.
  2. `flutter_launcher_icons: ^0.14.0` dev dependency add karein.
  3. `flutter pub run flutter_launcher_icons` chalayein.
- Jab tak replace na karein, app placeholder icon ke saath chalegi.

## 2. Gemini AI bot (AI Dost) — key kabhi APK mein nahi

- Abhi: key `--dart-define=GEMINI_API_KEY=...` se build/run waqt di
  jati hai (README Section 2). Key ke baghair bot offline jawab deta hai.
- **New (2026-11-18):** key ab app ke andar bhi di ja sakti hai —
  **Settings → AI Friend (Gemini)** mein apni key paste karein. Key
  sirf phone par save hoti hai (SharedPreferences), kahin upload nahi
  hoti, aur poori key kabhi wapas dikhayi nahi jati (sirf aakhri 4
  characters). In-app key `--dart-define` wali key se pehle istemal
  hoti hai. Key ke baghair bot offline jawab deta rehta hai.
- Proper tareeqa (publishing se pehle): key ko Firebase Function ya
  apne chhote server par rakhein, aur `lib/services/gemini_service.dart`
  mein server ka URL lagayein. App sawaal server ko bhejegi, server
  Gemini ko call karega aur jawab wapas dega. Key APK mein daalna
  matlab key chori hona hai.

## 3. Firebase (optional — login sync)

- `firebase_core` / `firebase_auth` abhi `pubspec.yaml` mein **nahi**
  hain (comment bhi nahi — bilkul shaamil nahi). App inke baghair
  poori tarah chalti hai.
- Enable karne ke liye: Firebase project banayein, Android app add
  karein (package `com.mohalla.app`), `google-services.json` ko
  `android/app/` mein rakhein, dependencies add karein, `flutter pub get`
  chalayein, aur `lib/main.dart` mein Firebase initialize karein.
- Tab tak: profile local hai (naam/Gmail phone par save hota hai,
  kahin upload nahi hota).

## 4. Nearby mosques — map nahi, links hain

- Is project mein `google_maps_flutter` **nahi** hai — map ke liye
  Google Maps API key chahiye hoti, is liye mosques screen mein
  Google Maps ke links hain (browser mein khulte hain).
- Agar in-app map chahiye ho to: `google_maps_flutter` add karein,
  https://console.cloud.google.com/google/maps-apis se key lein
  (Maps SDK for Android enable karein) aur key ko
  `android/app/src/main/AndroidManifest.xml` mein
  `com.google.android.geo.API_KEY` par lagayein.

## 5. Quran audio (online)

- Per-ayah audio online hai (Alafasy, `cdn.islamic.network`) — text
  poora offline hai. Audio offline chahiye ho to ayah MP3s download
  karke `assets/` mein rakhne ka tareeqa badalna parega (6,236 files,
  bara size) — is liye abhi online hi rakha gaya hai.

## 6. Azan notifications — phone restart ke baad

- App start par aaj ki Azan schedule hoti hai. Phone restart hone ke
  baad alarms khatam ho jate hain — app ek dafa kholne par dobara
  schedule ho jati hain. (Background reschedule ke liye
  `RECEIVE_BOOT_COMPLETED` + receiver add karna hoga — future step.)
- Android 12+ par "Alarms & reminders" (exact alarm) aur Android 13+
  par notification permission deni parti hai — app pehli dafa
  maangti hai (Settings se bhi).

## 7. Camera OCR (timings board)

- Home par "Clock/board ki photo lein" se photo li ja sakti hai aur
  timings khud likhi ja sakti hain. Photo se waqt **khud-ba-khud**
  parhna (OCR) abhi nahi hai — iske liye `google_mlkit_text_recognition`
  jaisi library add karni paregi. Manual entry hi honest tareeqa hai.

## 8. Prayer-time method

- Calculation method + Asr madhab are picked in **Settings → Prayer
  calculation** (Karachi / ISNA / Muslim World League / Egyptian /
  Makkah, Hanafi / Shafi'i Asr). Default: Karachi method, Hanafi Asr.
  Stored in SharedPreferences (`calculation_method`, `asr_madhab`).
  Changing either reschedules Azan immediately.

## 9. Known compile risks

- `sensors_plus` ko asal device compass chahiye; emulator par
  compass slider se kaam chalayein (sensor not available message
  nahi — slider fallback hai).
- `flutter pub get` agar kisi version par fail ho to `flutter pub outdated`
  chalayein; versions 2026-11-16 ko pub.dev se verify karke pin ki
  gayi hain (Flutter latest Stable ke saath).
- Is machine par Flutter nahi hai — `flutter analyze` yahan nahi
  chalaya gaya. Pehle `flutter run` par jo bhi error aaye, uski
  screenshot bhej dein.

## Redesign — 2026-11-17 (user feedback ke baad)

1. **Community section hata diya gaya** — user ke faislay se. 5 tabs
   reh gaye: Home, Quran, Seekhein, AI Dost, Zyada.
2. **Text overflow fix** — NumberBadge (FittedBox scale-down) har jagah
   jahan number circle mein tha (Quran list, Asma-ul-Husna, ayah chips);
   headings/labels ko maxLines + ellipsis; countdown FittedBox mein.
3. **Compass lag fix** — sensor events 100ms + 1° threshold par throttle;
   needle 160ms AnimationController/Tween se glide karta hai (har sensor
   event par rebuild nahi); sirf dial rebuild hota hai
   (ValueListenableBuilder). Manual slider bhi animate karta hai.
4. **3D header/footer** — header: emerald pattern + gold glow + gold M
   medallion + city subtitle; footer: active tab gold gradient pill
   (glow + uthaya hua), press par scale 0.9.
5. **Apni masjid ki timings** — Settings mein "Apni masjid ki namaz
   timings" (per-prayer HH:mm, Jumu'ah alag, reset button). Home
   countdown + Azan notifications inhi timings se chalte hain jab set
   hon. shared_preferences mein save hoti hain (`masjid_timings`).
6. **Quran 16-line Mushaf** — asli verified dataset (TarteelAI QUL
   "Indopak 16 lines", Nimaz repo se liya gaya): 548 pages, 16 lines
   per page, IndoPak Nastaleeq font. Quran list mein "Mushaf — 16 Line"
   card se khulta hai; page navigation, surah jump, Tarjuma bottom
   sheet, last page save hota hai. Detail:
   `assets/quran/mushaf_16line_README.md` (licence note: font ke liye
   public release se pehle quranwbw@gmail.com ko written notice zaroori).
7. **Nusuk-style onboarding (first launch)** — Splash (pattern + gold M),
   Permissions (Azan notifications + preset-city location, koi GPS
   nahi), Login (icon top-right, Arabic words — الله، محمد، بسم الله —
   slow orbit mein ghoomte hue, Gmail login + Skip). Sirf pehli baar
   dikhta hai (`onboarded` flag).
8. **Cards + effects** — PressableCard (hover lift, press scale 0.97,
   InkWell splash, gradient border), PatternBackground (8-point star
   lattice), gradient blobs/glow, animated counters (Home countdown).
9. **Baaki sab waisa hi** — prayer countdown, Hijri date, Quran audio
   (just_audio), Azan + 4 muezzin voices, tasbih, zakat, duas, hadiths,
   99 Naam, Wudu/Namaz learning, dark mode, elder mode, 18 cities.

## GPS migration — 2026-11-18 (manual location setup removed)

- **Manual location is gone.** No city picker, no preset cities, no
  timezone list. Everything location-dependent — prayer times, nearby
  mosques, Qibla bearing/distance, Azan, countdown, header place name
  — comes from the phone's GPS location (`lib/services/location_service.dart`,
  geolocator + geocoding). The last good location is cached on the
  phone (`last_location_json`) so timings still show when GPS is
  briefly unavailable; a cached location is always labelled
  "last known location".
- **First build after this change MUST run `flutter pub get`** (new
  dependencies: `geolocator 14.1.2`, `geocoding 5.0.1`). Then the
  usual `flutter clean` + `flutter build apk --release`. Do NOT
  hand-edit `pubspec.lock` — `flutter pub get` regenerates it.
- **First launch asks for location permission.** If the user denies
  it, Home / Qibla / Mosques show a visible "location needed" card
  with an Enable button instead of blank screens; Azan is not
  scheduled until a location exists. Denied-forever opens the app's
  Settings page from the My Location screen.
- **Method + Asr are now a Settings choice** (see section 8 above).
  `lib/services/prayer_service.dart` takes GPS coordinates +
  method/madhab; all times are the phone's local time (no city
  time-zone conversion any more). The `timezone` package stays ONLY
  for Azan scheduling (`tz.local` in notification_service.dart).
- **Files changed:** new `lib/services/location_service.dart` +
  `lib/screens/location_screen.dart` (replaces `timezones_screen.dart`,
  deleted); deleted `lib/models/city.dart` and the dead
  `lib/screens/community_screen.dart` (nothing imported it);
  rewritten `prayer_service.dart`, `mosques_screen.dart`;
  updated `settings_provider.dart` (city/autoTimezone removed,
  method/madhab added), `notification_service.dart`,
  `main.dart` (MultiProvider: Settings + Location),
  `home_screen.dart`, `qibla_screen.dart`, `settings_screen.dart`,
  `timings_editor.dart`, `zyada_screen.dart`, `pubspec.yaml`,
  onboarding copy (`onboarding_flow.dart`: the Permissions tile now
  says GPS instead of "preset city / no live GPS").
- **Not verified here:** this machine has no Flutter toolchain, so
  `flutter analyze` / `flutter pub get` / build were NOT run. The
  owner's build is the proof — send a screenshot of any error.

## BOOT_COMPLETED receiver — 2026-11-18 (Azan after a phone restart)

- **Problem fixed:** before this, Azan notifications were only scheduled
  when the app was opened — after a phone restart they were dead until
  the next launch. Now `android/app/src/main/kotlin/com/mohalla/app/BootReceiver.kt`
  listens for `BOOT_COMPLETED` (permission `RECEIVE_BOOT_COMPLETED` added
  to `AndroidManifest.xml`) and runs the `bootReschedule` Dart entrypoint
  (`lib/boot_reschedule.dart`, `@pragma('vm:entry-point')`) in a headless
  FlutterEngine — no app UI opens. It reads the cached GPS location
  (`last_location_json`, key exposed as `LocationService.cacheKey`) +
  the saved method/madhab/toggles/voice/masjid times via
  `SettingsProvider.init()` and calls `NotificationService.rescheduleAll`.
  The engine is shut down after ~20 seconds. If no location is cached
  yet, it does nothing (the next app launch reschedules as usual).
  Nothing in the launch flow was touched; `launch_background.xml`
  is still a solid colour only (no `<bitmap>` — see the 2026-11-17
  launch-crash rule).
- **How to prove it on the phone:** 1) Open the app once (so a location
  is cached and Azan is scheduled). 2) Restart the phone. 3) Do NOT
  open Mohalla. 4) At the next prayer time the Azan notification must
  fire with sound. If it does not fire: check that notifications +
  exact alarms are allowed for Mohalla (Settings → Apps → Mohalla),
  and that the app was not force-stopped (a force-stopped app gets no
  BOOT_COMPLETED until it is opened once). Note: this is the ONE part
  of this batch that cannot be proven without a real restart — it was
  not verified here (no toolchain on this machine).
- **Fix 2026-11-18 (build failed):** the first version used Dart-style
  `catch (_)` in this Kotlin file — Kotlin does not accept that
  ("An explicit type is required on a value parameter"). All four
  sites are now `catch (e: Exception)`. Rule: in `.kt` files always
  write the exception type (`catch (e: Exception)`), never bare `_`.
- **Not verified here:** no Flutter toolchain on this machine, so
  `flutter analyze` / build were NOT run. The owner's build is the proof.


## Offline per-surah Quran audio — 2026-11-18

- **Problem fixed:** Quran recitation was online-only. Now each surah
  can be downloaded for offline listening (`lib/services/quran_audio_cache.dart`).
  Files are the same Alafasy 128kbps MP3s the reader streams today
  (`cdn.islamic.network/quran/audio/128/ar.alafasy/{global ayah}.mp3`),
  saved per ayah as `quran_audio/<surah>/<global ayah>.mp3` in the app
  documents directory. The FULL Quran (~1 GB+) is never bundled and
  there is no "download all" button — one surah at a time, on purpose.
- **How it works:** the reader header has a "Download audio for offline
  listening" button (progress bar + verses/MB while downloading), then
  shows "Audio downloaded • X MB — plays offline" with a Delete button.
  Played ayahs use the local file (`setFilePath`) when downloaded and
  stream (`setUrl`) exactly as before otherwise — streaming behaviour
  for non-downloaded surahs is unchanged. A failed ayah never leaves a
  half-written file (bytes go to a `.tmp` file, renamed only on success),
  and a failed download resumes where it stopped (already-downloaded
  ayahs are skipped). No-network shows "Download failed — check your
  internet and try again." The Quran list screen shows the total
  downloaded size ("Downloaded audio: X MB") when anything is cached.
- **New dependency:** `path_provider 2.1.5` (app documents directory).
  `http 1.6.0` was already there. First build after this change MUST
  run `flutter pub get`. Do NOT hand-edit `pubspec.lock`.
- **Known minor limitation:** the total on the Quran list screen is
  loaded once when the tab opens — after downloading a surah, the
  reader shows the live per-surah size, and the list total refreshes
  the next time the Quran tab is reopened (e.g. after an app restart).
- **Not verified here:** no Flutter toolchain on this machine, so
  `flutter analyze` / build were NOT run. The owner's build is the proof.

## Islamic News screen — 2026-11-18

- **Problem fixed:** the app had no News screen at all. New
  `lib/screens/news_screen.dart` + `assets/data/news.json` (9 items),
  opened from More → Islamic News (route + title added in
  `lib/main.dart`, tile added in `lib/screens/zyada_screen.dart`).
  List view (category chips: Announcement / Guide / Reflection, newest
  first) + detail view with the full article.
- **Static-first, honestly labelled:** the items are local announcements
  (the GPS migration, offline Quran audio, Azan after restart — all
  true, dated 2026-11-18) plus evergreen guides (calculation methods,
  Ramadan preparation, Zakat, the 99 Names, Jumu'ah, Hajj/Umrah).
  No real-world events are invented. The top of the list says plainly:
  "Announcements and guides from Mohalla. Live news from the Muslim
  world will be added in a later update." No network dependency was
  added; `assets/data/` was already a bundled asset directory, so
  `pubspec.yaml` needed no change for the JSON file.
- **Not verified here:** no Flutter toolchain on this machine, so
  `flutter analyze` / build were NOT run. The owner's build is the proof.

## Permission prompt + APK split — 2026-11-18

- **Problem fixed:** when notification permission was denied, Azan
  was silently off — the app said nothing. Now the Home screen shows
  an amber banner whenever notification permission is denied AND any
  Azan toggle is on: "Azan notifications are off — notification
  permission is denied, so Azan cannot sound when the app is closed.
  In-app Azan still works while the app is open." Buttons: "Allow
  notifications" (asks the system again), "Open Settings" (the app's
  Settings page), and an X to dismiss. Once dismissed it does not
  nag again until the permission state changes (checked at startup
  and every time the app comes back to the foreground).
  `NotificationService.areNotificationsEnabled()` (flutter_local_notifications
  `areNotificationsEnabled()`) does the check; unknown = no banner.
  Location-denied is already covered by the visible "location
  needed" cards — the Home card now also shows an "Open Settings"
  button when location permission is denied forever (asking again
  shows nothing in that state).
- **Per-ABI APK split:** do NOT put a `splits { abi { ... } }` block
  in `android/app/build.gradle.kts` — it was tried 2026-11-18 and the
  build FAILED ("ndk abiFilters cannot be present when splits abi
  filters are set": the Flutter Gradle plugin already sets ndk
  abiFilters for the fat APK). The block was removed again the same
  night. Per-ABI APKs come from the build command instead:
  `flutter build apk --release --split-per-abi` produces THREE APKs
  of ~25 MB each instead of one ~70 MB fat APK:
  `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk`,
  `app-arm64-v8a-release.apk`, `app-x86_64-release.apk`.
  Install **app-arm64-v8a-release.apk** on the Tecno SPARK 30 Pro.
  For another phone: Settings → About phone → processor — arm64
  (most modern phones), armeabi-v7a (older 32-bit phones), x86_64
  (rare, mostly emulators). Installing the wrong ABI simply fails
  to install — it cannot break the phone.
- **Not verified here:** no Flutter toolchain on this machine, so
  `flutter analyze` / build were NOT run. The owner's build is the proof.

## Smaller fixes — 2026-11-18

- **Hijri date ±1 day:** the Hijri date comes from the phone's Islamic
  calendar, but moon sighting can shift a date by a day. Settings →
  Hijri date adjustment now offers One day earlier / No adjustment /
  One day later (stored in SharedPreferences as `hijri_adjustment`,
  default 0). It applies everywhere the Hijri date is shown — the
  Home header and the Hijri calendar grid + upcoming events (the
  shift is applied to the Gregorian date before conversion).
- **Compass fallback:** when the compass sensor does not report
  (the existing ~5s watchdog / no-sensor card), the Qibla screen now
  also shows a static North-up direction: a mini-dial with the arrow
  fixed at the Qibla bearing, "Face 264° — West" in words, and a
  note explaining how to use it (line the N up with real North, then
  face the arrow). The sensor/compass logic itself was NOT touched —
  on a phone with no compass sensor the screen is still useful.
- **In-app Gemini key field:** see section 2 above (Settings → AI
  Friend (Gemini)). The key is stored on the phone only, masked
  (last 4 characters) when shown back, never logged, and used in
  preference to the --dart-define key.
- **Mushaf font licence email — MUST be sent before any PUBLIC
  release:** the ready-to-send draft is at
  `docs/mushaf-font-licence-email.md` (to quranwbw@gmail.com — written
  notice for the IndoPak Nastaleeq font). Replace the [YOUR NAME] /
  [YOUR EMAIL] placeholders and send it before publishing anywhere.
  Internal testing on the owner's own phone is not a public release.
- **Not verified here:** no Flutter toolchain on this machine, so
  `flutter analyze` / build were NOT run. The owner's build is the proof.

## UI design pass (demo v13) — 2026-11-18

- **Source:** the final approved splash/login demo v13
  (`mohalla-splash-login-demo-v13.html`, 19 screens, full English,
  dark mode proven working). Tokens + patterns written down at
  `~/workspace/ui-design-pass/TOKENS.md`; balance checker at
  `~/workspace/ui-design-pass/balance_check.py`.
- **Tokens now in `lib/theme/app_theme.dart`:** light — bg #F3EDDC,
  card #FBF7EA, ink #17352A, muted #4C6156, gold #A97F14 / #C9A227,
  emerald #0B3D2E, chip #EFE7CF, card line #DDD0AB; dark — bg #081713,
  surface #0F2A22, ink #F5EFE3, muted #B9CDBF, gold #D9A441 / #E6C860,
  emerald #005A45, chip #123528, card line #234636. Arabic gold
  #D4AF37 (dark) / emerald #005A45 (light) for Asma / Dua / Tasbih
  Arabic. Cards radius 20, buttons radius 14, chips radius 999.
- **Restyled (visual only, no behaviour/logic/nav changes):**
  `app_theme.dart`, `main.dart` (header/footer, notification-denied
  banner in demo toast colours), `widgets/common.dart`
  (PressableCard/SectionTitle/ToolCard/GoldButton/SampleBanner/
  SampleNote), and all 21 screens: onboarding (Splash orbit words,
  Permissions, Login), Home, Quran list + reader + Mushaf, Learn,
  AI Dost, Zyada, Qibla, Mosques, Tracker, Names, Duas, Hadith,
  Calendar, Zakat, Sunnah, Settings, Profile Edit, News, Location.
- **Preserved:** Home shows ONLY "Assalamu Alaikum," (no time
  greeting on Home — Login-only); prayer maths stays outside
  `build()` in Home; GPS migration, method selector, BOOT_COMPLETED
  receiver, offline Quran audio, News screen, permission banner,
  Hijri ±1, compass fallback, Gemini key field — all intact
  (verified by grep: 0 references to CityPreset / presetCities /
  autoTimezone / setCity / timezones_screen; all preserved files
  exist and are referenced; no `<bitmap>` in launch_background.xml).
  ReaderThemes (paper/sepia/emerald/night/rose) untouched; Qibla
  dial geometry untouched (chip stays clear of 'W'); icon/GoldMark
  untouched (5A/5B install is a separate step).
- **Known deltas from the demo (deliberate):** Login day/night
  toggle not ported (behaviour change, out of scope); Login time
  greeting not added (needs time logic); Zyada tool cells keep a
  small subtitle line under the label; Qibla aligned state stays
  green (functional meaning); hadith Arabic stays ink (tokens
  assign gold only to Asma/Dua/Tasbih Arabic); reader ayah cards
  stay radius 12 (reading surface, not chrome); orbit-word golds
  are literals #F0D488 / #8A6D1B (no named constant).
- **Not verified here:** no Flutter toolchain on this machine, so
  `flutter analyze` / `pub get` / build were NOT run. All 24
  changed files pass the brace/paren/bracket balance check. The
  owner's phone build is the proof — especially: Zyada grid at
  1.3x elder text, Settings rows (taller with 11px padding),
  Names grid at 1.3x elder text, Qibla chip at all headings,
  dark-mode rendering of every screen.
- **Build (owner, Windows):** `cd D:\softwares\mohalla-app`,
  `git pull`, `flutter pub get`, `flutter clean`,
  `flutter build apk --release`, install
  `build\app\outputs\flutter-apk\app-arm64-v8a-release.apk`.

## Icons 5A/5B install — 2026-11-18
- **Plan (user-approved):** 5B refined-flat mosque = launcher icon +
  in-app mark (header/login/permissions); 5A 3D premium mosque =
  splash screen only. Replaces Icon 2 (gold M).
- **Sources (WEBP, 1600x1600, opaque, white corner triangles):**
  `icon-work/media-generation-mohalla-icon-5-improved-refine-*.webp` (5B),
  `icon-work/media-generation-mohalla-icon-5-improved-3d-*.webp` (5A).
  Both are rounded-square artwork on white corners; the white was
  flood-filled to transparent, the baked-in light arc fringe defringed,
  and the corners filled with the artwork's own field colour
  (5B #004136, 5A #032C27).
- **PNGs (17, in delivery folder `mohalla-app-icon-pngs/`, NOT in the
  repo — the GitHub connector cannot push binaries; the owner copies
  them into D:\softwares\mohalla-app, then git add/commit/push):**
  5 x mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher.png
  (48/72/96/144/192) + byte-identical ic_launcher_round.png;
  5 x ic_launcher_foreground.png (108/162/216/324/432, RGBA, gold
  ~63dp wide centred, corners transparent);
  assets/images/mohalla_icon.png (5B, 512);
  assets/images/mohalla_splash_icon.png (5A, 512).
- **Config changes (in the repo, pushed as text):**
  `android/app/src/main/res/values/colors.xml` —
  `ic_launcher_background` #005A45 -> #004136 (exactly the 5B field
  colour, so the adaptive foreground/background seam is invisible).
  `lib/screens/onboarding_flow.dart` — GoldMark takes an `asset`
  parameter (default 5B `mohalla_icon.png`); the Splash passes the 5A
  asset. Orbit words, gold ring, flow order and splash timer untouched.
  `ic_launcher.xml` / `ic_launcher_round.xml` needed NO change (already
  reference @color/ic_launcher_background + @mipmap/ic_launcher_foreground).
  `launch_background.xml` untouched — solid colour only, never a <bitmap>
  (standing rule: the 2026-11-17 launch crash).
  `pubspec.yaml` needed NO change — `assets/images/` is already a
  directory asset, so `mohalla_splash_icon.png` is covered.
- **Verification done here:** all 17 PNGs checked (sizes, modes, corner
  colours, foreground corners transparent, gold bbox 63dp wide centred,
  round == launcher at every density, zero near-white pixels left);
  foreground preview composited over #004136 inspected visually (clean,
  no seam). Dart/XML brace-paren balance passes on the changed files.
  Regression guard: GPS files, BootReceiver, audio cache, News screen,
  permission banner, UI-pass theme tokens all intact; grep sanity pass
  0 references to CityPreset / presetCities / autoTimezone / setCity /
  timezones_screen.
- **Not verified here:** no Flutter toolchain on this machine, so
  `flutter analyze` / `pub get` / build were NOT run. The owner's phone
  build is the proof — especially: launcher icon on the home screen
  (adaptive icon not cut off on his Tecno's launcher mask), splash
  shows the 5A artwork, header/login show the 5B mark.
- **Build (owner, Windows):** `cd D:\softwares\mohalla-app`, `git pull`,
  copy the 17 PNGs from the delivery folder over the same paths,
  `git add -A`, `git commit -m "Install icons 5A/5B"`, `git push`,
  `flutter pub get`, `flutter clean`, `flutter build apk --release`,
  install `build\app\outputs\flutter-apk\app-arm64-v8a-release.apk`.

## Manual map location (2026-11-19 ~00:05 PKT)
- **Why:** GPS test with a VPN on "did not work" — a VPN cannot move GPS
  (GPS comes from satellites, not the network), and a cold indoor fix can
  also miss the old 10s timeout. The map pin is now the manual way to set
  any location on purpose.
- `pubspec.yaml`: + `flutter_map 8.3.2` (OpenStreetMap tiles, free, no API
  key — verified on pub.dev: sdk >=3.6.0, flutter >=3.27.0; needs
  latlong2 >=0.9.1 <0.11.0, http ^1.5.0 — app has Dart 3.14 /
  Flutter 3.50 / http 1.6.0) + `latlong2 0.10.1` (sdk >=3.0.0,
  intl >=0.15.0 <1.0.0 — app intl is 0.20.3). No Google Maps key, no
  manifest change (INTERNET permission already present).
- `lib/services/location_service.dart`: manual pin (`manualLocation`,
  persisted as 'manual_location_json'). `current` is now a getter —
  manual pin ?? GPS fix — so ALL readers (Home, Qibla, mosques, Azan
  scheduling, header) switch to the pin at once with no other file
  changed. `setManualLocation(lat, lng)` (reverse-geocodes the pin),
  `clearManualLocation()` (back to GPS + refresh). GPS `timeLimit`
  raised 10s -> 30s (cold indoor fix). Header shows '(manual)'.
- `lib/screens/location_screen.dart`: full map (340px, OSM tiles) +
  place search (Nominatim, free, no key) + tap-to-pin + "Use GPS
  location" + re-centre button. Prayer-times and Qibla cards below
  the map now follow the pin (they read `location.current`).
- **Build (owner):** `git pull`, `flutter pub get`, `flutter build apk
  --release --split-per-abi`, install arm64 APK (uninstall old first).
  Phone test: open My Location, tap the map in another city, check
  prayer times change; press "Use GPS location", check they return.
- **Not verified here:** no Flutter toolchain — `flutter analyze` /
  build NOT run. Phone build is the proof.

## In-app mosques + directions (2026-11-19 ~00:10 PKT)
- **Why:** "Find mosques near me" opened Google Maps. Now the list AND
  the directions both live in the app.
- `lib/services/mosque_service.dart` (NEW): `fetchNearbyMosques` via the
  free OpenStreetMap Overpass API (no key, no billing — Google Places
  would need a key + billing); keeps Muslim places of worship, dedupes
  node+way doubles, sorts by distance. `fetchRoute` via the free OSRM
  router (no key): walking profile first, driving fallback; returns
  the path + distance + walking time + turn-by-turn steps.
- `lib/screens/mosques_screen.dart`: map (OSM) with mosque pins +
  route polyline, radius chips (2/5/10 km), in-app list (name,
  distance, compass direction), tap a mosque (list or pin) for
  in-app walking directions (route drawn on the map + steps with
  distances). No Google Maps in the find flow any more. The list
  re-fetches when GPS arrives or the manual map pin moves.
  Own-mosque card kept as-is.
- **Limits:** the list is only what OpenStreetMap has mapped — small
  unnamed mosques may be missing; no Iqama times exist anywhere to
  show. Routes + map tiles need internet.
- **Build (owner):** `git pull`, `flutter pub get`, `flutter build apk
  --release --split-per-abi`, install arm64 APK (uninstall old first).
  Phone test: open Nearby Mosques, tap a mosque, check the route
  draws on the map and the steps make sense.
- **Not verified here:** no Flutter toolchain — `flutter analyze` /
  build NOT run. Phone build is the proof.

## Live worldwide Islamic news + daily refresh (2026-11-19 ~00:15 PKT)
- **Why:** the News screen only showed Mohalla announcements/guides.
  Now it shows real worldwide Islamic news, refreshed daily.
- `pubspec.yaml`: + `xml 7.1.0` (RSS parsing; needs sdk ^3.13.0 —
  app Dart is 3.14; verified on pub.dev 2026-11-19).
- `lib/services/news_service.dart` (NEW): free public RSS feeds, no
  key — IQNA (dedicated Islamic news agency, verified live
  2026-11-19), Al Jazeera (general feed, filtered to Islamic
  topics, verified live 2026-11-19), Google News search for "Islam".
  One dead feed never blocks the others. Daily refresh: the list is
  cached on the phone and re-fetched only when older than 24 hours;
  pull-to-refresh / the refresh button forces a fresh fetch. Offline
  = last saved list (or the bundled stories, with an honest note).
- `lib/screens/news_screen.dart`: live list (source pill + time ago
  + thumbnail, tap opens the article in the browser), source filter
  chips, "Updated …" status bar. The bundled news.json stories are
  now only the offline fallback; NewsDetailScreen kept for them.
- **Build (owner):** `git pull`, `flutter pub get`, `flutter build apk
  --release --split-per-abi`, install arm64 APK (uninstall old first).
  Phone test: open Islamic News — worldwide stories should appear
  with today's dates; pull down to refresh.
- **Not verified here:** no Flutter toolchain — `flutter analyze` /
  build NOT run. Phone build is the proof.

## Hijri calendar auto-update (2026-11-19 ~00:15 PKT)
- The Hijri date was computed once in Home's initState: if the app
  stayed open past midnight, the header kept yesterday's Hijri date.
- `lib/screens/home_screen.dart`: the 1-second tick now detects a
  day change and re-runs `_updateHijri()` (Hijri + Gregorian header
  dates roll over by themselves).
- `lib/screens/calendar_screen.dart`: a 1-minute timer rebuilds the
  screen when the day rolls over, so the "today" highlight and the
  upcoming-events list move on their own. Opening the screen always
  shows the current month (state is rebuilt on open).
- The Hijri date itself comes from the `hijri` package (device
  Islamic calendar) ± the Settings adjustment (-1/0/+1 day).

## Complete Quran — reciters, translation audio, 51 translation languages (2026-11-19 ~00:40 PKT)
- **Why:** full Quran listening — Arabic in several voices, translation
  read aloud, translation text in 50+ languages — all offline after
  download, all on the 16-line single-page Mushaf.
- **NO new pubspec dependency.** Everything uses http / path_provider /
  shared_preferences, already in the app. No audio is bundled in the
  APK — every reciter, voice and language is download-on-demand.
- **Reciter picker (6 voices, all verified HTTP 200 on 2026-11-19):**
  Mishary Alafasy (128kbps), Abdul Basit (192kbps), Abdurrahmaan
  As-Sudais (192kbps), Mahmoud Khalil Al-Husary (128), Mohamed Siddiq
  Al-Minshawi (128), Maher Al Muaiqly (128). BITRATE IS PER RECITER:
  Abdul Basit + Sudais 403 at 128kbps — their 192kbps URLs work.
  DROPPED (403): ar.abdullahbasfar, ar.saoodshuraym. Per-ayah MP3s
  from cdn.islamic.network/quran/audio/{bitrate}/{edition}/{globalAyah}.mp3.
  Per-surah single files exist ONLY for Alafasy (Baqarah 116 MB) and
  Abdul Basit (100 MB) — the app never plays them; they are used only
  for the download-size estimate.
- `lib/services/quran_reciters.dart` (NEW): QuranReciter (id, edition,
  bitrate, label, note; ayahUrl/surahUrl, byEdition) + TranslationVoice.
- `lib/services/quran_audio_cache.dart`: all methods take optional
  `{String reciterId = 'ar.alafasy'}`; Alafasy keeps the EXISTING
  cache dir `quran_audio/<surah>/` (old downloads still work); other
  reciters use `quran_audio/<reciterId>/<surah>/`. New
  `estimateSurahBytes` (HEAD on the per-surah file when it exists,
  else ayah-count × ~180 KB @128k / ~270 KB @192k). `_downloading`
  is now keyed `reciterId:surah` (was a plain surah set).
- `lib/services/quran_service.dart`: `audioUrlForGlobalAyah(global,
  [edition, bitrate])` — old single-arg calls still work.
- `lib/services/settings_provider.dart`: new persisted settings —
  `reciterId` (default 'ar.alafasy'), `translationVoiceId` (default
  '' = off), `extraTranslationId` (default '' = none),
  `quranAudioMode` (default 'arabic'; 'arabic' | 'interleaved' |
  'translation'), with getters + validating setters.
- **Translation audio (human voice, only 2 languages exist anywhere
  as per-ayah audio):** Urdu — Shamshad Ali Khan, everyayah.com
  `.../translations/urdu_shamshad_ali_khan_46kbps/{SSS}{AAA}.mp3`
  (folder name is LOWERCASE — the mixed-case name 404s; verified
  001001/002001/114006 = 200). English — Ibrahim Walk, Islamic
  Network CDN `.../audio/192/en.walk/{globalAyah}.mp3` (verified 200;
  there is NO English folder on everyayah, and the 128kbps URL 403s).
  `lib/services/translation_audio_cache.dart` (NEW): per-ayah download
  cache `translation_audio/<voiceId>/<surah>/<SSSAAA>.mp3`, same
  .tmp+rename/resume model as the Arabic cache.
- **Playback modes (surah reader):** Arabic only / Arabic then
  translation (interleaved) / Translation only — built with
  just_audio `ConcatenatingAudioSource`; downloaded files play
  offline, otherwise streams. Mushaf reader: AppBar Play button
  plays the whole page's ayat in order (same modes), stops on page
  change or tap.
- **Translation TEXT, 51 languages** (one edition per language):
  47 from alquran.cloud (all confirmed format 'text'; 'ar' entries
  are audio, so 47 not 48) + 4 from QuranEnc — Gujarati
  (gujarati_omari, Rabella Al-Omari), Vietnamese (vietnamese_rwwad,
  Rowwad), Yoruba (yoruba_mikail, Abu Rahimah Mikael), Oromo
  (oromo_rwwad, Rowwad). Tanzil adds ZERO new languages (verified —
  all its languages are already on alquran.cloud) and is not used.
  `lib/services/translation_text_service.dart` (NEW): per-surah
  download + disk cache `translations/<editionId>/<surah>.json`,
  in-memory cache capped at 30 surahs. alquran.cloud:
  GET /v1/surah/{n}/{edition}; QuranEnc: GET
  /api/v1/translation/sura/{key}/{sura} → {"result": [{"aya",
  "translation", ...}]} (verified live; footnote markers like "[1]"
  are passed through as-is). The reader shows the chosen language
  under each ayah (in addition to bundled Urdu/English); the Mushaf
  Tarjuma sheet shows it for the page's ayat. Settings has an
  'Extra translation language' picker (51 languages, language +
  translator). Arabic + Urdu (Jalandhari) + English (Asad) stay
  bundled as before; default translation display stays Urdu.
- **Settings screen:** new 'Quran audio & translation' section
  (reciter, translation voice, audio mode, extra language).
- **Mushaf stays 16-line, one page at a time** — page layout
  (_MushafPage/_MushafLine) untouched; audio + translation attach
  to it only.
- **flutter_tts NOT added (skipped, on purpose):** flutter_tts 4.2.5
  resolves fine (sdk >=3.4.0 <4.0.0, zero third-party deps, no
  pubspec conflict — verified on pub.dev 2026-11-19), BUT its README
  requires an AndroidManifest `<queries>` block so the app can
  discover TTS engines on Android 11+ — that file was outside the
  allowed scope for this pass. The 'Phone voice' (device TTS) button
  is therefore NOT in this build. To add it later (2 minutes):
  add `flutter_tts: 4.2.5` to pubspec, add this inside
  `android/app/src/main/AndroidManifest.xml` under `<manifest>`:
  `<queries><intent><action android:name="android.intent.action.TTS_SERVICE" /></intent></queries>`
  then wire a small TtsService (speak/stop/setLanguage) + a
  'Phone voice' button under the shown translation.
- **Build (owner):** `git pull`, `flutter pub get`, `flutter clean`,
  `flutter build apk --release --split-per-abi`, install arm64 APK
  (uninstall old first).
- **Phone tests:** (1) Settings → Quran audio & translation → pick
  Husary, open a surah, play an ayah (streams), download the surah
  (shows ≈ size, progress, offline play after). (2) Pick Sudais
  (192kbps) and repeat — the 192kbps path is the one that 403'd at
  128. (3) Translation voice Urdu → mode 'Arabic, then translation'
  → ayah plays Arabic then Urdu; download the surah's Urdu audio,
  turn on airplane mode, play again. (4) English voice → same.
  (5) Extra translation → pick Yoruba (QuranEnc) or Gujarati →
  open a surah → translation appears under each ayah (first open
  downloads it — needs internet once). (6) Mushaf → Play button
  plays the page; Tarjuma shows the extra language. (7) Restart the
  app — reciter/voice/mode/language choices must stick.
- **Not verified here:** no Flutter toolchain — `flutter analyze` /
  build NOT run; in-app playback/download of the new reciters,
  voices and QuranEnc languages is unproven until the phone build.
  Balance checks (raw braces/parens/brackets) on all 9 changed
  files are 0/0/0.

## Phone voice (device TTS) for translations (2026-11-19 ~00:40 PKT)
- **What:** a "Phone voice" button reads the shown translation aloud
  with the phone's built-in text-to-speech engine. It is the device
  voice, NOT a reciter — and it only works for languages the phone
  has a voice for (Urdu/English work on most phones; a missing
  voice shows an honest message instead of failing silently).
- `pubspec.yaml`: + `flutter_tts 4.2.5` (sdk >=3.4.0 <4.0.0, zero
  third-party deps — verified on pub.dev 2026-11-19).
- `android/app/src/main/AndroidManifest.xml`: `<queries>` block with
  `android.intent.action.TTS_SERVICE` (Android 11+ engine discovery).
- `lib/services/translation_tts_service.dart` (NEW): speaks a list of
  (text, language) parts in order, one language at a time (locale
  map for the 51 translation languages + Urdu/English); a generation
  counter guarantees only one reading runs at a time; any failure
  returns false, never throws.
- `lib/screens/quran_reader_screen.dart`: speaker button on every
  ayah card (next to Play, only when a translation is shown) — reads
  that ayah's visible translations (Urdu, English, extra language)
  in order; tap again to stop. Reciter audio and phone voice never
  overlap; TTS stops when the screen closes.
- `lib/screens/mushaf_reader_screen.dart`: speaker button in the
  Tarjuma sheet header — reads the whole page's visible
  translations, ayah by ayah; stops when the sheet closes or the
  page audio starts. 16-line page layout untouched.
- **Build (owner):** `git pull`, `flutter pub get`, `flutter build apk
  --release --split-per-abi`, install arm64 APK (uninstall old first).
  Phone test: open a surah, tap the speaker on an ayah (Urdu
  translation) — the phone reads it; try an extra language (e.g.
  French) — if the phone has no French voice, the honest message
  shows. Mushaf → Tarjuma → speaker reads the page.
- **Not verified here:** no Flutter toolchain — `flutter analyze` /
  build NOT run; TTS behaviour (engine discovery, per-language
  voices) is unproven until the phone build.

## flutter_tts build fix — plugin VENDORED (2026-11-19 ~01:00 PKT)
- **Build error (owner's machine):** `flutter build apk` failed
  configuring project ':flutter_tts': (1) could not download
  kotlin-gradle-plugin 2.2.20 from dl.google.com (network/VPN), and
  (2) "Failed to apply plugin 'kotlin-android' — this and base files
  have different roots" + "does not specify compileSdk". Root cause:
  hosted flutter_tts 4.2.5 (the latest — verified on pub.dev
  2026-11-19, no newer version) pins AGP 8.13.0 + Kotlin 2.2.20 +
  Java 11 via a legacy buildscript, while the app uses AGP 9.3.1 /
  Gradle 9.5.0 / Kotlin 2.4.20 / Java 17. Same failure, same fix as
  heading_sensor (see its build.gradle header for the full reasoning).
- **Fix:** flutter_tts 4.2.5 vendored at `plugins/flutter_tts/`
  (published sources verbatim — verified byte-identical to the
  pub.dev tarball, sha256 ce5eb209…; only `android/build.gradle`
  replaced with the modern shape: `com.android.library` only, no
  kotlin-android, `compileSdk = flutter.compileSdkVersion`,
  Java/Kotlin 17). App pubspec now uses `path: plugins/flutter_tts`.
  No Kotlin 2.2.20 download is needed any more, so the dl.google.com
  failure goes away too.
- **Build (owner):** `git pull`, `flutter clean`, `flutter pub get`,
  `flutter build apk --release --split-per-abi`, install arm64 APK
  (uninstall old first). `flutter clean` matters this time — the
  dependency changed from hosted to a local path.
- **Not verified here:** no Flutter toolchain — `flutter analyze` /
  build NOT run; the vendored build is unproven until the phone build.

## Mushaf TTS semicolon fix (2026-11-19 ~01:14 PKT)
- **Build error:** `mushaf_reader_screen.dart:441` — "Expected ';' after
  this". Cause: `return DraggableScrollableSheet(...)` in
  `_showTranslations` ended with `),` instead of `);` — one missing
  semicolon. Fix: line 441 `),` -> `);`. Nothing else changed.
- **Build (owner):** `git pull`, `flutter build apk --release
  --split-per-abi` (`flutter pub get`/`clean` not needed this time).

## Today's Dua / Hadith buttons fixed (2026-11-19 ~01:42 PKT)
- **Bug (owner's phone):** Home "Today's Deen" — "Today's Verse"
  worked, but "Today's Dua" and "Today's Hadith" did nothing.
  Cause: both cards had an empty `onTap: () {}` — never wired.
- **Fix (home_screen.dart only):** `_DailyCards` now also takes
  `onOpenTool` (already wired on HomeScreen to main's `_openTool`).
  Dua card -> `onOpenTool('duas')`, Hadith card ->
  `onOpenTool('hadith')` — same route the Zyada tools use.
- **Build (owner):** `git pull`, `flutter build apk --release
  --split-per-abi`. Tap each card: Dua opens Duas & Azkar,
  Hadith opens Hadith Library.

## 5A in-app everywhere + splash on every launch (2026-11-19 ~01:50 PKT)
- **Icon rule changed (owner):** 5B is LAUNCHER icon only (mipmap).
  In-app mark is now 5A everywhere: GoldMark default asset changed
  from assets/images/mohalla_icon.png (5B) to
  assets/images/mohalla_splash_icon.png (5A) — covers splash, login,
  header, permissions. The 5B asset file stays in the repo, unused
  in-app.
- **Splash on every launch (owner):** the splash used to show only on
  first run (home was RootScreen once onboarded). Now MohallaApp is
  stateful with an in-memory `_splashShown` gate: every cold start
  shows OnboardingFlow splash-only (2.6s, tap to skip), then Home if
  onboarded, else the full onboarding starting at Permissions
  (initialStep 1 — no double splash). Background/resume does NOT
  re-show it; only a fresh start does.
- **Build (owner):** `git pull`, `flutter build apk --release
  --split-per-abi`. Check: close the app fully, reopen — splash
  (5A) shows, then Home. Header/login also show 5A now.

## Phone voice: male + heavy everywhere (2026-11-19 ~02:00 PKT)
- **Complaint (owner):** some Quran translations read aloud in a
  female phone voice; he wants male voice only, heavy/deep like
  Qari Abdul Basit's. (The recorded translation audio — Shamshad
  Ali Khan Urdu, Ibrahim Walk English — was already male; the
  female voice was the phone's default TTS voice.)
- **Fix (translation_tts_service.dart only — it is the app's ONLY
  phone voice, so this covers the whole app):** per language, the
  service now picks a male-named installed voice
  ("...#male_1-local", female checked first because 'female'
  contains 'male'; falls back to any non-female voice) via
  setVoice after setLanguage, and the pitch is lowered 1.0 -> 0.75
  for a deeper, heavier voice.
- **Honest limit:** if the phone has NO male voice installed for a
  language, the engine default is used — the app cannot invent a
  voice. Male voices can be added in the phone's TTS settings
  (Google TTS -> Install voice data).
- **Build (owner):** `git pull`, `flutter build apk --release
  --split-per-abi`. Test the speaker button on an ayah + the
  Mushaf Tarjuma sheet: Urdu + English should both sound male
  and deep now.

## Logo corners rounded (2026-11-19 ~02:05 PKT)
- **Complaint (owner):** wherever the logo shows, its corners were
  visible (sharp). Cause: the GoldMark frame was already rounded,
  but the artwork itself is a solid square — its sharp 90-degree
  corners showed inside the rounded frame.
- **Fix (onboarding_flow.dart, GoldMark only — every in-app logo
  goes through it: splash, login, header, permissions):** the
  Image is now wrapped in an inner ClipRRect, radius 12% — slight
  rounding on all 4 sides. Outer frame stays 24%.
- **Build (owner):** `git pull`, `flutter build apk --release
  --split-per-abi`. Check the splash, login and header logos —
  no sharp corners anywhere now.

## 5B system preloader removed, 5A splash kept (2026-11-19 ~02:07 PKT)
- **Complaint (owner):** before the Flutter splash (5A, every
  launch), a 5B preloader also appeared. That was the Android 12+
  system splash screen: with no override it shows the launcher
  icon (5B) while the app starts. The 5A Flutter splash must stay.
- **Fix (Android only, Flutter splash untouched):** NEW
  drawable/splash_icon_transparent.xml + LaunchTheme (values AND
  values-night) now sets android:windowSplashScreenAnimatedIcon to
  it and windowSplashScreenBackground to the emerald
  launch_background. Launch is now: solid emerald -> Flutter 5A
  splash -> Home. No icon is shown by the system any more.
- **Build (owner):** `git pull`, `flutter build apk --release
  --split-per-abi`. Fully close + reopen the app: the 5B icon must
  NOT appear any more; only the 5A splash, then Home.

## Splash 3D logo bigger + header/footer pattern visible (2026-11-19 ~22:41 PKT)
- **Complaints (owner, phone test):** (1) splash should show the
  3D logo; (2) do NOT change the translator fonts; (3) header and
  footer pattern merges into the background; (4) Quran AI voice is
  female, make it male.
- **Verified first:** the repo's mohalla_splash_icon.png IS the 3D
  5A artwork (checked the actual file: 3D gold mosque, glowing
  crescent) and the splash code already shows it — the owner was
  almost certainly testing a stale build (last confirmed build
  01:22 PKT, before the 5A-everywhere change 1324f9e and the male
  voice fix 68dcd5b). So the splash mark is now BIGGER instead:
  GoldMark 132 -> 160, ring radius 44 -> 50, so the 3D mosque
  reads clearly inside the ring. Translator fonts: NOT touched
  anywhere in this pass (no font change in the diff at all).
- **Header pattern (real bug):** white pattern at 0.24 under the
  0.5 scrim wash was ~0.12 effective — the girih lines merged
  into the emerald. Now GOLD pattern (like the splash) at 0.32
  with scrim 0.30.
- **Footer pattern (real bug):** pattern Opacity was 0.12 dark /
  0.18 light over the gradient — invisible. Now 0.30 / 0.35.
- **Quran female voice:** NO code change — the male/heavy fix
  (68dcd5b: male-named voice per language + pitch 0.75) is already
  in the repo, and the speaker-button code passes the right
  language codes ('ur'/'en'/extra). It reaches the phone only
  with a fresh build after `git pull`. If it STILL sounds female
  after rebuilding, the phone has no male Urdu voice installed —
  then download one in phone Settings -> Language -> Text-to-speech
  -> Google TTS -> Install voice data (Urdu, male voice).
- **Build (owner):** `git pull`, `flutter build apk --release
  --split-per-abi`, uninstall old app, install arm64 APK. Check:
  splash shows the big 3D mosque; header/footer girih pattern
  clearly visible; Quran speaker button reads Urdu/English in a
  male voice; translator fonts unchanged.
