import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:AiClopedia/screens/home_screen.dart';
import 'package:AiClopedia/widgets/bottom_nav.dart';

import 'login/login.dart';

class SplashPage extends StatefulWidget {
  _SplashPageState createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  var currentUser = FirebaseAuth.instance.currentUser;


  @override
  void initState() {
    super.initState();
    _controller =
    AnimationController(vsync: this, duration: Duration(seconds: 1))
      ..forward()
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          if (currentUser == null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => LoginPage()),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => BottomNavBar()),
            );
          }
        }
      });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black12,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Expanded(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (_, child) {
                    return Transform.rotate(
                      angle: _controller.value * 1 * math.pi,
                      child: child,
                    );
                  },
                  child: Image.asset(
                    "assets/images/aiclopedia.png",
                    height: 120,
                    width: 120,
                  ),
                ),
              ),
              Text("By Tech Faculty", style: TextStyle(color: Colors.white),)
            ],
          ),
        ),
      ),
    );
  }
}
