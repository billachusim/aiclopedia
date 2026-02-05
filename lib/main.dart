import 'package:firebase_core/firebase_core.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:AiClopedia/screens/splash_screen.dart';
import 'package:AiClopedia/services/ad_state.dart';
import 'app_theme.dart';
import 'providers/chats_provider.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // It's better to await the initialization here
  final initFuture = MobileAds.instance.initialize();
  final adState = AdState(initFuture);
  await Firebase.initializeApp();

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
      child: MaterialApp(
        title: 'AiClopedia',
        debugShowCheckedModeBanner: false,
        // Set the light and dark themes
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        // This will automatically switch between light and dark based on system settings
        themeMode: ThemeMode.system,
        home: SplashPage(),
      ),
    );
  }
}
