import 'package:firebase_core/firebase_core.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:AiClopedia/providers/models_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:AiClopedia/screens/splash_screen.dart';
import 'package:AiClopedia/services/ad_state.dart';

import 'constants/constants.dart';
import 'providers/chats_provider.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  final initFuture = MobileAds.instance.initialize();
  final adState = AdState(initFuture);
  await Firebase.initializeApp();
  runApp(Provider.value(
    value: adState,
    builder: (context, child) => MyApp(),
  ),);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ModelsProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => ChatProvider(),
        ),
      ],
      child: MaterialApp(
        title: 'AiClopedia',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
            scaffoldBackgroundColor: scaffoldBackgroundColor,
            appBarTheme: AppBarTheme(
              color: Colors.green,
            )),
        home: SplashPage(),
      ),
    );
  }
}
