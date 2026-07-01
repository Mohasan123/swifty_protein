# Why the biometric button isn't showing — Android checklist

> **Confirmed cause for this project**: tapping "Use Biometrics" showed the
> error *"local_auth plugin requires activity to be a FragmentActivity"* —
> this is cause #3 below. If you see that exact message, skip straight to
> section 3, fix it, and you're done; sections 1 and 2 were not the issue
> here.

`auth.isBiometricAvailable` (in `auth_service.dart`) calls two `local_auth`
methods under the hood:

```dart
final canCheck = await _localAuth.canCheckBiometrics;
final isSupported = await _localAuth.isDeviceSupported();
return canCheck && isSupported;
```

Both must return `true`, or the button stays hidden. On a real Android
phone with fingerprint already enrolled, if it's still `false`, it's almost
always one of these three — check in this order:

## 1. Missing permissions in AndroidManifest.xml

Open `android/app/src/main/AndroidManifest.xml`. Inside the `<manifest>`
tag (as a sibling of `<application>`, not nested inside it), you need:

```xml
<uses-permission android:name="android.permission.USE_BIOMETRIC"/>
```

If your `minSdkVersion` is below 28, also add the older permission for
backward compatibility:

```xml
<uses-permission android:name="android.permission.USE_FINGERPRINT"/>
```

Without `USE_BIOMETRIC`, `canCheckBiometrics` silently returns `false` —
it does not throw an error or log anything obvious, which is why this is
easy to miss.

## 2. minSdkVersion too low

Open `android/app/build.gradle` (or `android/app/build.gradle.kts` if
you're on a newer Flutter template). Find:

```gradle
defaultConfig {
    minSdkVersion 21   // <-- if it's below 23, that's the problem
}
```

`local_auth` requires API 23 (Android 6.0) minimum for biometric prompts.
Change it to:

```gradle
minSdkVersion 23
```

## 3. MainActivity must extend FlutterFragmentActivity, not FlutterActivity

This is the one people miss most often, because `flutter create` generates
the wrong base class by default, and the app still builds and runs fine —
it just makes biometrics silently unavailable.

Find your file:
- Kotlin: `android/app/src/main/kotlin/.../MainActivity.kt`
- Java: `android/app/src/main/java/.../MainActivity.java`

It currently probably looks like this:

```kotlin
import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity()
```

Change it to:

```kotlin
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity: FlutterFragmentActivity()
```

(Java equivalent: change `extends FlutterActivity` to
`extends FlutterFragmentActivity`, and update the import.)

**Why this matters**: `local_auth` on Android shows the biometric prompt
using a `FragmentManager`, which only exists on `FlutterFragmentActivity`.
On a plain `FlutterActivity`, the biometric check methods don't crash —
they just quietly report "not available," which looks exactly like what
you're seeing.

## After fixing any of the above

```bash
flutter clean
flutter pub get
flutter run
```

A full rebuild is required — hot reload won't pick up changes to
`AndroidManifest.xml`, `build.gradle`, or `MainActivity`.

## How to confirm which one it was

Add a temporary debug print in `login_screen.dart`'s `_checkBiometrics()`
to see the raw values before they get combined:

```dart
Future<void> _checkBiometrics() async {
  final canCheck = await auth_instance_var.canCheckBiometrics; // expose temporarily
  print('canCheckBiometrics: $canCheck');
  final available = await auth.isBiometricAvailable;
  print('isBiometricAvailable: $available');
  final types = await auth.availableBiometrics;
  print('availableBiometrics: $types');
  if (mounted) setState(() { _biometricAvailable = available; _biometrics = types; });
}
```

Run the app, watch the terminal/Logcat output when the login screen loads.
If `canCheckBiometrics` prints `false`, it's #3 (MainActivity). If it
throws a `PlatformException`, it's #1 (permissions). Remove the print
statements once it's confirmed working.
