import 'package:AiClopedia/screens/user_activities.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:AiClopedia/screens/chat_screen.dart';
import 'package:AiClopedia/screens/home_screen.dart';
import 'package:AiClopedia/screens/image_screen.dart';
import '../models/userModel.dart';
import '../services/firebaseServices.dart';
import '../services/helper.dart';


class NavbarItem {
  final String lightIcon;
  final String boldIcon;
  final String label;

  NavbarItem({required this.lightIcon, required this.boldIcon, required this.label});

  BottomNavigationBarItem item(bool isbold) {
    return BottomNavigationBarItem(
      icon: ImageLoader.imageAsset(isbold ? boldIcon : lightIcon),
      label: label,
    );
  }

  BottomNavigationBarItem get light => item(false);
  BottomNavigationBarItem get bold => item(true);
}

class BottomNavBar extends StatefulWidget {
  static const route = '/bnav';

  BottomNavBar({super.key});

  @override
  State<BottomNavBar> createState() => _BottomNavbarState();
}

class _BottomNavbarState extends State<BottomNavBar> {
  final FirebaseServices firebaseServices = FirebaseServices();
  var currentUser = FirebaseAuth.instance.currentUser;
  int _select = 1;

  final screens = [
    const Homepage(),
    ChatScreen(),
    ImageScreen(),
    ActivitiesScreen()
  ];

  static Image generateIcon(String path) {
    return Image.asset(
      '${ImageLoader.rootPaht}/buttomnav/$path',
      width: 24,
      height: 24,
    );
  }

  final List<BottomNavigationBarItem> items = [
    const BottomNavigationBarItem(
      icon: Icon(Icons.home_filled),
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
    // const BottomNavigationBarItem(
    //   icon: Icon(Icons.person),
    //   activeIcon: Icon(Icons.person),
    //   label: 'Profile',
    // ),
  ];


  @override
  void initState() {
    super.initState();
  }



  @override
  dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);
    return Scaffold(
      body: screens[_select],
      bottomNavigationBar: BottomNavigationBar(
        items: items,
        onTap: ((value) => setState(() => _select = value)),
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
        selectedItemColor: const Color(0xFF097E18),
        unselectedItemColor: const Color(0xFF9E9E9E),
      ),
    );
  }
}
