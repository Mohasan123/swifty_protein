# Swifty Protein — Flutter 42 Project

A 3D protein ligand visualizer built with Flutter for the 42 school project.

## Architecture

```
lib/
  main.dart                    ← App entry, lifecycle auth guard
  utils/
    app_theme.dart             ← Dark theme, colors, styles
  models/
    ligand.dart                ← Atom, Bond, Ligand models + CIF parser
  services/
    auth_service.dart          ← Biometric + secure storage auth
    ligand_service.dart        ← HTTP fetch + CIF parsing + cache
  screens/
    splash_screen.dart         ← 2s animated splash
    login_screen.dart          ← Login/Register + biometrics
    ligands_list_screen.dart   ← Searchable list of 800+ ligands
    protein_viewer_screen.dart ← WebView 3D viewer
assets/
  ligands.txt                  ← Ligand IDs list
  three_viewer.html            ← Three.js 3D renderer
```

## Setup

### 1. pubspec.yaml dependencies
```
flutter pub get
```

### 2. Android — android/app/src/main/AndroidManifest.xml
Add inside `<manifest>`:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.USE_BIOMETRIC"/>
<uses-permission android:name="android.permission.USE_FINGERPRINT"/>
```

### 3. iOS — ios/Runner/Info.plist
Add:
```xml
<key>NSFaceIDUsageDescription</key>
<string>Authenticate to access your protein library</string>
```

### 4. iOS — ios/Podfile
Ensure minimum iOS version:
```ruby
platform :ios, '13.0'
```

### 5. Android minSdkVersion — android/app/build.gradle
```gradle
minSdkVersion 23
```

## Features

### Mandatory ✅
- Splash screen (1-2s, branded)
- Login/Register with SHA-256 hashed passwords in Keychain/KeyStore
- Biometric auth (Face ID, Touch ID, Fingerprint)
- Login always shown on app launch and resume from background
- Ligand list with real-time search (800+ ligands from RCSB)
- .cif file fetching with loading indicator
- Proper error messages for 404, timeout, parse errors
- 3D ball-and-stick model with CPK coloring
- Rotation (drag), zoom (pinch) gestures
- Tap atom for element info tooltip
- Share screenshot via native share sheet

### How 3D works
Three.js r128 renders inside a WebView. Flutter passes atom/bond JSON 
to JavaScript via `runJavaScript`. Raycasting handles atom tap detection.
No game engine used — pure WebGL inside a standard mobile app.

## CIF Parser

Parses `_chem_comp_atom` and `_chem_comp_bond` loops from RCSB .cif files.
Prefers `pdbx_model_Cartn_x/y/z_ideal` coordinates, falls back to `model_Cartn_x/y/z`.

## CPK Colors

| Element | Color  |
|---------|--------|
| C       | #404040 (dark gray) |
| H       | #FFFFFF (white)     |
| O       | #FF0D0D (red)       |
| N       | #3050F8 (blue)      |
| S       | #FFFF30 (yellow)    |
| P       | #FF8000 (orange)    |
| F/Cl    | #90E050/#1FF01F (green) |
