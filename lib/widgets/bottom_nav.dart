import 'package:AiClopedia/screens/user_activities.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:AiClopedia/screens/chat_screen.dart';
import 'package:AiClopedia/screens/home_screen.dart';
import 'package:AiClopedia/screens/image_screen.dart';
import 'package:flutter/services.dart';
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
  int _select = 0;
  PageController _pageController = PageController(initialPage: 0);


  void setTabIndex(index) async {
    if (await firebaseServices.isUserSignIn(context))
      _pageController.animateToPage(
          index, duration: Duration(milliseconds: 500),
          curve: Curves.easeInToLinear);
    switch(index) {
      case 0: {}
      break;
      case 1: {}
      break;
      case 2: {}
      break;
      case 3: {}
      break;

    }
  }

  final screens = [
    const Homepage(),
    ChatScreen(),
    ImageScreen(),
    ActivitiesScreen()
  ];


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
    return WillPopScope(
      onWillPop: () {
        if (_select != 0) {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => BottomNavBar()),
          );
        } else {
          SystemNavigator.pop();
        }
        return Future.value(false);
      },
      child: Scaffold(
        body: PageView(
            physics: AlwaysScrollableScrollPhysics(),
            controller: _pageController,
            onPageChanged: (index){
              setState(() {
                _select  = index;
              });
            },
            children: screens,
        ),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.green,
          items: items,
          onTap: (int index) => setTabIndex(index),
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
          unselectedItemColor: Colors.white60,
        ),
      ),
    );
  }
}
