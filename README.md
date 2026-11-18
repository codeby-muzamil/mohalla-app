# Mohalla icons 5A / 5B — PNG delivery (2026-11-18)

**READ THIS FIRST — these PNGs are NOT in the GitHub repo yet.**
Muse's GitHub connection can only push text files, never binary PNGs,
so the launcher and in-app icon PNGs below must be copied by hand.
The text/config changes (icon background colour, splash wiring) ARE
already in the repo and will come down with `git pull`. **Do not build
the APK until you have copied these PNGs** — without them the launcher
would still show the old Icon 2 and the splash would fall back to a
plain mosque glyph.

## What goes where

Copy this whole folder's contents over `D:\softwares\mohalla-app`,
keeping the folder structure exactly as it is. Every file below
overwrites the file at the same path (the old Icon 2 PNGs).

| File in this folder | Destination in D:\softwares\mohalla-app | Size |
|---|---|---|
| android/app/src/main/res/mipmap-mdpi/ic_launcher.png | android/app/src/main/res/mipmap-mdpi/ic_launcher.png | 48x48 |
| android/app/src/main/res/mipmap-mdpi/ic_launcher_round.png | android/app/src/main/res/mipmap-mdpi/ic_launcher_round.png | 48x48 |
| android/app/src/main/res/mipmap-mdpi/ic_launcher_foreground.png | android/app/src/main/res/mipmap-mdpi/ic_launcher_foreground.png | 108x108 |
| android/app/src/main/res/mipmap-hdpi/ic_launcher.png | android/app/src/main/res/mipmap-hdpi/ic_launcher.png | 72x72 |
| android/app/src/main/res/mipmap-hdpi/ic_launcher_round.png | android/app/src/main/res/mipmap-hdpi/ic_launcher_round.png | 72x72 |
| android/app/src/main/res/mipmap-hdpi/ic_launcher_foreground.png | android/app/src/main/res/mipmap-hdpi/ic_launcher_foreground.png | 162x162 |
| android/app/src/main/res/mipmap-xhdpi/ic_launcher.png | android/app/src/main/res/mipmap-xhdpi/ic_launcher.png | 96x96 |
| android/app/src/main/res/mipmap-xhdpi/ic_launcher_round.png | android/app/src/main/res/mipmap-xhdpi/ic_launcher_round.png | 96x96 |
| android/app/src/main/res/mipmap-xhdpi/ic_launcher_foreground.png | android/app/src/main/res/mipmap-xhdpi/ic_launcher_foreground.png | 216x216 |
| android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png | android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png | 144x144 |
| android/app/src/main/res/mipmap-xxhdpi/ic_launcher_round.png | android/app/src/main/res/mipmap-xxhdpi/ic_launcher_round.png | 144x144 |
| android/app/src/main/res/mipmap-xxhdpi/ic_launcher_foreground.png | android/app/src/main/res/mipmap-xxhdpi/ic_launcher_foreground.png | 324x324 |
| android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png | android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png | 192x192 |
| android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_round.png | android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_round.png | 192x192 |
| android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_foreground.png | android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_foreground.png | 432x432 |
| assets/images/mohalla_icon.png | assets/images/mohalla_icon.png | 512x512 |
| assets/images/mohalla_splash_icon.png | assets/images/mohalla_splash_icon.png | 512x512 |

- **5B (refined flat, gold mosque on emerald)** = launcher icon
  (`ic_launcher*`) + in-app mark (`assets/images/mohalla_icon.png`,
  used in the header, login and permissions screens).
- **5A (3D premium, glowing crescent + stars)** = splash screen only
  (`assets/images/mohalla_splash_icon.png`).
- `ic_launcher_round.png` is identical to `ic_launcher.png` at every
  density (same as the old Icon 2 setup).
- The adaptive foreground has transparent corners and the gold mosque
  centred (~63dp wide, same as the old Icon 2 foreground). The matching
  background colour `#004136` is already set in the repo
  (`android/app/src/main/res/values/colors.xml`), so there is no visible
  seam between foreground and background.

## Steps (on your Windows machine)

```powershell
cd D:\softwares\mohalla-app
git pull
```

Copy the `android` and `assets` folders from this delivery folder into
`D:\softwares\mohalla-app`, overwriting the 17 PNGs. Then:

```powershell
git add -A
git commit -m "Install icons 5A/5B"
git push
flutter pub get
flutter clean
flutter build apk --release
```

Install `build\app\outputs\flutter-apk\app-arm64-v8a-release.apk`
on your Tecno phone (uninstall the old app first, as before).

## Check on the phone

1. **Home screen launcher icon** — the new 5B gold mosque. Check it is
   NOT cut off at the edges (minarets/crescent fully visible).
2. **Splash screen** — the 5A 3D mosque with glowing crescent and stars,
   inside the gold ring with the orbiting Arabic words (unchanged).
3. **Header / login** — the 5B flat mosque mark (same as the launcher).

If the launcher icon looks cut off, tell Muse — the foreground artwork
can be shrunk a little more inside its safe zone.
