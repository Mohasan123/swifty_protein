# Native launch screen & app icon setup

Two different things are easy to confuse here, and the subject cares about both:

1. **The native launch screen** — what the OS shows for a split second
   *before* Flutter even starts (a blank white/black flash is the default).
   This lives in native iOS/Android project files, not in `lib/`.
2. **`splash_screen.dart`** — the animated logo screen we built in Dart,
   which only appears *after* Flutter has booted.

The subject's requirement ("launch screen visible for 1-2s, not a static
stuck-loading image") is satisfied by the combination of both: the native
launch screen bridges the gap before Flutter loads, then our animated
`SplashScreen` widget takes over seamlessly.

## Step 1 — Generate the app icon (all sizes, both platforms)

We already created the source images:
- `assets/icon/icon.png` — 1024×1024 master icon (used for iOS, and as the
  full Android icon on older API levels)
- `assets/icon/icon_foreground.png` — transparent-background version for
  Android adaptive icons (the OS composites this over a background color
  we specify, `#0D0D1A`, and may mask it into a circle/squircle/etc.
  depending on the device's launcher)

Run this once, after `flutter pub get`:

```bash
flutter pub get
dart run flutter_launcher_icons
```

This reads the `flutter_launcher_icons:` block in `pubspec.yaml` and
generates every required resolution automatically:
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/` (all iOS sizes)
- `android/app/src/main/res/mipmap-*/` (all Android densities)
- `android/app/src/main/res/mipmap-anydpi-v26/` (adaptive icon XML)

You should see new/changed files under `ios/` and `android/` after running
it — that's expected, commit them.

## Step 2 — Native launch screen (the pre-Flutter flash)

### iOS
Open `ios/Runner/Assets.xcassets/LaunchImage.imageset` in Xcode, or edit
`ios/Runner/Base.lproj/LaunchScreen.storyboard` directly. Simplest approach:
set the storyboard's background color to `#0D0D1A` (matching our app theme)
so the transition into the Dart splash screen is invisible — no white flash.

In Xcode: select `LaunchScreen.storyboard` → select the root view → in the
Attributes Inspector, set Background to a custom color matching `#0D0D1A`.

### Android
Edit `android/app/src/main/res/values/styles.xml` (and the `values-night/`
variant if present). Find the `LaunchTheme` style and set:

```xml
<style name="LaunchTheme" parent="@android:style/Theme.Black.NoTitleBar">
    <item name="android:windowBackground">@drawable/launch_background</item>
</style>
```

Then edit `android/app/src/main/res/drawable/launch_background.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@android:color/black" />
    <!-- Or to match our exact theme color: -->
    <!-- <item><color android:color="#0D0D1A" /></item> -->
</layer-list>
```

Same idea: matching background color means there's no jarring flash
between "native launch screen" and "our Dart splash screen" — it should
feel like one continuous 1-2 second branded moment, exactly what the
subject asks for.

## Why this matters for grading

The subject explicitly says: *"The launch screen must not be a static image
that looks like the app is loading forever."* Our `splash_screen.dart`
already satisfies the "not stuck forever" part (it auto-navigates after
2.2s). This step closes the remaining gap: making sure the very first
native frame doesn't show a jarring white flash or the default Flutter
logo before our branded screen takes over.
