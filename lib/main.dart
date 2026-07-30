import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:AiClopedia/screens/splash_screen.dart';
import 'package:AiClopedia/services/ad_state.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'app_theme.dart';
import 'providers/chats_provider.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  final initFuture = MobileAds.instance.initialize();
  MobileAds.instance.updateRequestConfiguration(
    RequestConfiguration(testDeviceIds: ['51F4CA28BB7EDD1F5E61C5F0F8EFFF00']),
  );
  final adState = AdState(initFuture);
  await Firebase.initializeApp();
  
  if (kDebugMode) {
    print("🛠️ APP CHECK: Activating in DEBUG mode...");
  }

  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttestWithDeviceCheckFallback,
    );
  } catch (e) {
    if (kDebugMode) {
      print("❌ APP CHECK ERROR: $e");
    }
  }

  runApp(
    Provider.value(
      value: adState,
      child: const MyApp(),
    ),
  );
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
