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

- Karachi method, Hanafi Asr — `adhan` package. Agar kisi sheher ke
  liye doosra method chahiye ho to `lib/services/prayer_service.dart`
  mein `CalculationMethod` badlein (MWL, ISNA, Egypt, Makkah, etc.).

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
