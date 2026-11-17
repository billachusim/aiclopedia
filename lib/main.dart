import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ai_clopedia/screens/splash_screen.dart';
import 'package:ai_clopedia/services/ad_state.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'app_theme.dart';
import 'providers/chats_provider.dart';


Future<void> main() async {
  runZonedGuarded(_start, (error, stack) {
    _recordError(error, stack, fatal: true);
  });
}

bool _firebaseReady = false;

void _recordError(Object error, StackTrace? stack, {bool fatal = false}) {
  if (kDebugMode) {
    print("Unhandled error: $error");
  }
  if (_firebaseReady) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: fatal);
  }
}

Future<void> _start() async {
  WidgetsFlutterBinding.ensureInitialized();

  // A missing or broken .env must never stop the app from opening.
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    if (kDebugMode) print("dotenv load failed: $e");
    dotenv.loadFromString(envString: '', isOptional: true);
  }

  // Firebase is needed by the splash screen (FirebaseAuth), so it starts
  // before runApp, but it is guarded so a failure can't crash the launch.
  try {
    await Firebase.initializeApp().timeout(const Duration(seconds: 10));
    _firebaseReady = true;
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  } catch (e) {
    if (kDebugMode) print("Firebase init failed: $e");
  }

  // Ads start after the first frame; banners wait on this future.
  final adsReady = Completer<InitializationStatus>();
  final adState = AdState(adsReady.future);

  runApp(
    Provider.value(
      value: adState,
      child: const MyApp(),
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    _startBackgroundServices(adsReady);
  });
}

Future<void> _startBackgroundServices(
    Completer<InitializationStatus> adsReady) async {
  if (_firebaseReady) {
    try {
      await FirebaseAppCheck.instance
          .activate(
            providerAndroid: kDebugMode
                ? const AndroidDebugProvider()
                : const AndroidPlayIntegrityProvider(),
            providerApple: kDebugMode
                ? const AppleDebugProvider()
                : const AppleAppAttestWithDeviceCheckFallbackProvider(),
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      if (kDebugMode) print("App Check activate failed: $e");
    }
  }

  try {
    final status = await MobileAds.instance
        .initialize()
        .timeout(const Duration(seconds: 15));
    await MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(testDeviceIds: ['51F4CA28BB7EDD1F5E61C5F0F8EFFF00']),
    );
    if (!adsReady.isCompleted) adsReady.complete(status);
  } catch (e) {
    if (kDebugMode) print("MobileAds init failed: $e");
    // Leave adsReady pending: banners simply never load.
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ChatProvider(),
        ),
      ],
      child: GetMaterialApp(
        title: 'AiClopedia',
        debugShowCheckedModeBanner: false,
        // Set the light and dark themes
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        // This will automatically switch between light and dark based on system settings
        themeMode: ThemeMode.system,
        home: const SplashPage(),
      ),
    );
  }
}
