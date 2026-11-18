# Mohalla — Flutter Project

**Mohalla** — Global Muslim app (Islamic app, Flutter).
Home with live prayer countdown, **full Quran offline** (114 Surah,
6,236 Ayat), 16-line Pakistani Mushaf reader (548 pages), Seekhein (Wudu/Namaz), Allah ke 99 Naam,
Dua aur Azkar, Hadith Library, Hijri Calendar, Qibla Compass 3D,
Timezones (duniya bhar ki timings), Namaz Tracker, Tasbih,
Zakat Calculator, Sunnat o Shariah, AI Dost (Gemini) — emerald/sand/gold
theme + dark mode + elder (large-font) mode.

- **App name:** Mohalla
- **Package id:** `com.mohalla.app`
- **Flutter:** 3.x (latest Stable — download from https://flutter.dev)
- **Dart:** 3.x (comes with Flutter)
- **Version:** 0.1.0+1 (prototype)

> **APK yahan nahi bani.** Is machine par Flutter/Android SDK install
> karna mana tha, is liye sirf code likha gaya hai — APK **aap apne
> computer par** neeche diye gaye steps se banayenge.

## 1. Apne Windows computer par tayyari

1. **Flutter SDK (Stable)** — https://flutter.dev se download karein,
   extract karein, aur `flutter\bin` ko Windows PATH mein add karein.
2. **Android Studio** — https://developer.android.com/studio — setup ke
   dauraan **Android SDK**, **Android SDK Platform-Tools** aur
   **Android Emulator** install karein (ya apna phone USB debugging
   ke saath istemal karein).
3. Android licences accept karein (terminal mein):

```bat
flutter doctor --android-licenses
```

4. Sab kuch theek hai ya nahi, check karein:

```bat
flutter doctor
```

Har line par green ✓ hona chahiye (kam se kam: Flutter, Android
toolchain, Android Studio). Agar kuch missing ho to `flutter doctor`
khud bata dega.

> Flutter ka **latest Stable** istemal karein. Agar `flutter pub get`
> version ki shikayat kare to pehle `flutter upgrade` chalayein.

## 2. Project chalana

Is zip ko extract karein (ya project folder kholein), phir terminal mein:

```bat
cd mohalla-app
flutter pub get
```

### Phone / emulator par test karein

```bat
flutter run
```

Device list se apna phone (USB debugging ON) ya emulator chunein.
App debug mode mein khul jayegi — hot reload ke liye terminal mein
`r` dabayein.

### APK banana (install karne ke liye)

Debug APK (tez, testing ke liye):

```bat
flutter build apk --debug
```

Release APK (chhoti, share/publish karne ke liye):

```bat
flutter build apk --release
```

APK yahan banegi:

```
build\app\outputs\flutter-apk\app-debug.apk        (debug)
build\app\outputs\flutter-apk\app-release.apk      (release)
```

### Gemini (AI Dost) ke saath chalana

API key **kabhi code mein nahi likhni** — koi bhi APK se key nikaal
sakta hai. Key sirf build/run command mein dein:

```bat
flutter run --dart-define=GEMINI_API_KEY=YOUR_KEY_HERE
flutter build apk --release --dart-define=GEMINI_API_KEY=YOUR_KEY_HERE
```

Key ke baghair bhi app chalegi — AI Dost tab offline jawab dega
(Zakat, Namaz, Roza, Wazu) aur saaf bata dega ke Gemini connected nahi.

## 3. APK phone par install karna

1. `.apk` file phone par copy karein (USB cable, WhatsApp, Google Drive).
2. Phone par APK file par tap karein. Agar Android pooche to
   **"Install unknown apps"** allow karein.
3. **Install** dabayein. Icon gold **M** (minarets) on green hai.
4. Pehli dafa: language chunein → naam/Gmail likhein ya **Skip** →
   location allow karein (namaz timings aur Qibla ke liye) →
   notification ki ijazat dein (Azan ke liye).

## 4. Kya save hota hai, kya nahi (session vs persisted)

**Phone par save hota hai (SharedPreferences):**

- Settings: dark mode, elder mode, sheher/timezone, Azan toggles,
  reminder, moazzin voice, Quran font/size/theme/translation
- Apni masjid: naam, photo ka path, Jamaat timings, board ki photo
- Quran bookmarks + last-read (aakhri parhi hui jagah)
- Namaz tracker (rozana), profile (naam/Gmail)

**Session-only (app band hote hi khatam):**

- Asma-ul-Husna "Yaad kar liya" progress (x/99)
- Dua repeat counters, Tasbih-e-Fatima counters, Tasbih count
- AI Dost chat history

**Server par kuch nahi jata** — koi backend nahi hai (Firebase
lagne tak). Masjid timings aap khud set kar sakte hain (Settings).

## 5. Verified data (is project mein bundled)

| Cheez | Count | Source |
|---|---|---|
| Quran — Arabic (Uthmani) | 114 Surah, 6,236 Ayat | AlQuran Cloud `quran-uthmani` |
| Quran — Urdu tarjuma | 114 Surah, 6,236 Ayat | AlQuran Cloud `ur.jalandhry` (Fateh Muhammad Jalandhari) |
| Quran — English tarjuma | 114 Surah, 6,236 Ayat | AlQuran Cloud `en.asad` (Muhammad Asad) |
| Juz (Para) boundaries | 30 | AlQuran Cloud `/v1/juz/1..30` |
| Allah ke 99 Naam | 99 | AlAdhan API `asmaAlHusna` |
| Duas | 19 (9 categories) | Hadith API dataset + Quran (Ayat-ul-Kursi, Teen Qul) |
| Hadiths | 20 (Bukhari 16, Muslim 4) | Hadith API dataset (fawazahmed0/hadith-api) |
| Salah recitations | 8 | Hadith API dataset |
| Azan voices | 4 MP3 | Internet Archive (dekhein `assets/azan/README.md`) |

**Omitted (accuracy rule — verify na ho saka to shaamil nahi kiya):**

- Hadith: Bukhari 5641, Muslim 54, 55, 2699 — dataset mein inke
  liye text khaali tha ya Arabic/English pair poora verify nahi ho
  saka, is liye 24 ki bajaye 20 hadiths hain. Count UI mein dynamic
  hai — jab verify ho jayein to `assets/data/hadiths.json` mein
  add kar dein.
- Asma-ul-Husna ke Urdu meanings shaamil nahi (koi verified source
  nahi mila) — app sirf English meaning dikhata hai.
- Duas ki Urdu translation bhi sirf wahan hai jahan verified source
  mila; baaqi mein Arabic + English hai.
- Wazu ke dauraan har uzv ki alag dua mustanad tor par sabit nahi —
  is liye Learn screen mein sirf Wazu se pehle/baad ki verified
  duain hain, aur ye baat screen par saaf likhi hai.

**Prayer times:** `adhan` package, Karachi method, Hanafi Asr —
on-device hisab, koi internet nahi chahiye. Timezone ka purana bug
(web prototype mein UTC dikhata tha) Flutter mein nahi hai: har waqt
muntakhib sheher ki IANA timezone mein banta hai.

**Qibla:** great-circle formula se bearing (Hyderabad: 267°,
Makkah tak ~2,940 km). Compass `sensors_plus` (accelerometer +
magnetometer) se heading nikalta hai; emulator par sensor nahi hota
— wahan manual slider hai.

## 6. Abhi bhi aapke input ki zaroorat hai

1. **Gemini API key** — sirf `--dart-define` se (Section 2 dekhein).
   Proper tareeqa: key ko Firebase Function / apne server par rakhna
   (BUILD_NOTES.md dekhein).
2. **Launcher icon (Icon 2)** — gold M (two minarets) wali asal icon
   file. Abhi `android/app/src/main/res/mipmap-*/ic_launcher.png`
   mein ek simple placeholder (gold M on emerald) hai. Asal file se
   replace karein — ya `flutter_launcher_icons` package se generate
   karein. Icon 2 ki file project mein shaamil nahi ki gayi.
3. **Firebase** — jab login sync chahiye ho
   (BUILD_NOTES.md dekhein). Iske baghair app poori tarah chalti hai.
4. **Release signing key** — Play Store par publish karne se pehle
   (https://docs.flutter.dev/deployment/android#signing-the-app).
   Abhi release build debug key se sign hoti hai.
5. **Jamia Masjid Khizra ki Jamaat timings** — listing mein
   "Awaiting Verification" hai; asal Jamaat timings masjid ke board
   se tasdeeq karke Home par edit karein.

## 7. Known limits (imandari se)

- **Azan notifications:** phone band/restart hone ke baad dobara
  schedule karne ke liye app ek dafa kholni parti hai (app start
  par reschedule hota hai). Android 12+ par "exact alarms" aur
  Android 13+ par notifications ki ijazat deni parti hai.
- **Quran audio:** per-ayah audio online hai (Alafasy, islamic.network
  CDN) — offline nahi bajegi. Quran ka TEXT poora offline hai.
- **Camera OCR:** timings-board ki photo le kar waqt khud parh kar
  likhna parta hai — auto-OCR (ML Kit) abhi nahi laga.
- **iOS:** project Android-first hai — `ios/` folder nahi hai.
  iOS chahiye ho to `flutter create . --platforms=ios` se generate karein.
- **sensors_plus 7.1.1:** Qibla screen accelerometer +
  magnetometer se heading nikalti hai (rotation-matrix maths).
  (flutter_qiblah hata diya gaya 2026-11-16: uska compass
  dependency AGP 9 ke saath nahi chalta.)
- **No compile check on this machine:** is machine par Flutter/Dart
  nahi hai, is liye `flutter analyze` / `flutter build` yahan nahi
  chalaya gaya. YAML aur JSON validate kiye gaye; Dart files ka
  brace-balance check kiya gaya. Pehli dafa `flutter pub get` /
  `flutter run` par agar koi version ya API error aaye to batayein —
  fix kar dunga.
