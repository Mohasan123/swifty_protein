import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'utils/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const SwiftyProteinApp());
}

class SwiftyProteinApp extends StatefulWidget {
  const SwiftyProteinApp({super.key});
  @override
  State<SwiftyProteinApp> createState() => _SwiftyProteinAppState();
}

class _SwiftyProteinAppState extends State<SwiftyProteinApp> with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();

  // Tracks whether the app has genuinely been backgrounded (paused) since
  // it was last resumed. Flutter's lifecycle goes resumed -> inactive ->
  // resumed for things that only briefly cover the app without truly
  // backgrounding it (pulling down the notification shade, a system
  // dialog like the biometric prompt, certain WebView focus shifts). It
  // only reaches `paused` when the app is genuinely no longer in the
  // foreground (Home button, app switcher, screen lock). Forcing re-login
  // only when we've actually seen `paused` avoids false-positive re-locks
  // from those harmless inactive blips, while still meeting the security
  // requirement for every real backgrounding event.
  bool _wasPaused = false;

  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); }

  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _wasPaused = true;
      return;
    }

    if (state == AppLifecycleState.resumed) {
      if (_wasPaused) {
        _wasPaused = false;
        _navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (_) => false,
        );
      }
      // If we never saw `paused` (e.g. just `inactive` -> `resumed`, from a
      // notification shade peek, biometric prompt, or WebView focus blip),
      // do nothing — the user never actually left the app.
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Swifty Protein',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const SplashScreen(),
    );
  }
}