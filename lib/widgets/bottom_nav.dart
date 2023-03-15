import 'package:flutter/material.dart';
import 'package:school_expo/screens/home_screen.dart';
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
  int _select = 0;

  final screens = [
    const Homepage(),
    //CartScreen(),
    //OrderScreen(title: 'Orders'),
    //WalletScreen(transactions: [],),
    //const ProfileScreen(),
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
      label: 'Market',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.shopping_cart),
      activeIcon: Icon(Icons.shopping_cart),
      label: 'Cart',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.notifications_none),
      activeIcon: Icon(Icons.notifications_none),
      label: 'Orders',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.notifications_none),
      activeIcon: Icon(Icons.notifications_none),
      label: 'Wallet',
    ),
    // const BottomNavigationBarItem(
    //   icon: Icon(Icons.person),
    //   activeIcon: Icon(Icons.person),
    //   label: 'Profile',
    // ),
  ];

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
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
        selectedItemColor: const Color(0xFFFFC402),
        unselectedItemColor: const Color(0xFF9E9E9E),
      ),
    );
  }
}
