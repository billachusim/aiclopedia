import 'package:AiClopedia/screens/user_activities.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:AiClopedia/screens/chat_screen.dart';
import 'package:AiClopedia/screens/home_screen.dart';
import 'package:AiClopedia/screens/image_screen.dart';
import 'package:flutter/services.dart';
import '../app_theme.dart';
import '../constants/scrollable_page.dart';
import '../services/firebaseServices.dart';
import '../services/helper.dart';


class BottomNavBar extends StatefulWidget {
  static const route = '/bnav';

  const BottomNavBar({super.key});

  @override
  State<BottomNavBar> createState() => _BottomNavbarState();
}

class _BottomNavbarState extends State<BottomNavBar> {
  final FirebaseServices firebaseServices = FirebaseServices();
  var currentUser = FirebaseAuth.instance.currentUser;
  int _select = 0;
  late final PageController _pageController;

  // --- FINAL: Create GlobalKeys for ALL scrollable pages ---
  final GlobalKey<ScrollablePageState<Homepage>> _homepageKey = GlobalKey();
  final GlobalKey<ScrollablePageState<ChatScreen>> _chatScreenKey = GlobalKey();
  final GlobalKey<ScrollablePageState<ImageScreen>> _imageScreenKey = GlobalKey();
  final GlobalKey<ScrollablePageState<ActivitiesScreen>> _activitiesKey = GlobalKey();

  // --- FINAL: Store all keys in the map for easy access ---
  late final Map<int, GlobalKey> _pageKeys;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _select);
    // --- FINAL: Initialize the keys map with all keys ---
    _pageKeys = {
      0: _homepageKey,
      1: _chatScreenKey,
      2: _imageScreenKey,
      3: _activitiesKey,
    };
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void setTabIndex(int index) async {
    // Check if the user is already on the tab they are tapping
    if (_select == index) {
      // --- Scroll-to-top logic ---
      final key = _pageKeys[index];
      if (key != null && key.currentState is ScrollablePageState) {
        // We have a key for this index, and it's a ScrollablePage.
        // Call its scrollToTop method.
        (key.currentState as ScrollablePageState).scrollToTop();
      }
    } else {
      // If it's a different tab, just navigate to it
      if (await firebaseServices.isUserSignIn(context)) {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  // --- FINAL: Pass the GlobalKeys to each respective page widget ---
  late final List<Widget> screens = [
    Homepage(key: _homepageKey),
    ChatScreen(key: _chatScreenKey),
    ImageScreen(key: _imageScreenKey),
    ActivitiesScreen(key: _activitiesKey),
  ];

  final List<BottomNavigationBarItem> items = [
    const BottomNavigationBarItem(
      icon: Icon(Icons.home_outlined),
      activeIcon: Icon(Icons.home_filled),
      label: 'Home',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.question_answer_outlined),
      activeIcon: Icon(Icons.question_answer_rounded),
      label: 'Ask AI',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.image_outlined),
      activeIcon: Icon(Icons.image_rounded),
      label: 'Generate Image',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.calendar_month_outlined),
      activeIcon: Icon(Icons.calendar_month_rounded),
      label: 'Activities',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    SizeConfig().init(context);

    return WillPopScope(
      onWillPop: () async {
        if (_select != 0) {
          // If not on the home tab, switch to it instead of popping.
          setTabIndex(0);
          return false; // Prevent app from closing
        }
        // If on the home tab, let the system handle the back button.
        return true;
      },
      child: Scaffold(
        body: PageView(
          // Disabling direct swiping to ensure navbar control
          physics: const NeverScrollableScrollPhysics(),
          controller: _pageController,
          onPageChanged: (index) {
            setState(() {
              _select = index;
            });
          },
          children: screens,
        ),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          // --- Theme-aware colors ---
          backgroundColor: isDarkMode ? AppTheme.darkBackground : AppTheme.primaryGreen,
          items: items,
          onTap: setTabIndex, // Simplified onTap
          currentIndex: _select,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
          showUnselectedLabels: true,
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.normal,
            fontSize: 10,
          ),
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white.withAlpha((255 * 0.6).round()),
        ),
      ),
    );
  }
}
