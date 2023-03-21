import 'package:flutter/cupertino.dart';

/// get device height
double getDeviceHeight(BuildContext context) =>
    MediaQuery.of(context).size.height;

/// get device width
double getDeviceWidth(BuildContext context) =>
    MediaQuery.of(context).size.width;

class ImageLoader {
  static const String rootPaht = 'assets/icons/';

  static Image imageAsset(String icon) => Image.asset(rootPaht + icon);

  static Image imageNet(String url) => Image.network(url);

}

/// validate users email
bool isValidEmail(String email) {
  String pattern =
      r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$';
  RegExp regex = RegExp(pattern);
  return regex.hasMatch(email);
}

class SizeConfig {
  static late MediaQueryData _mediaQueryData;
  static late double screenWidth;
  static late double screenHeight;
  static double? defaultSize;
  static Orientation? orientation;

  void init(BuildContext context) {
    _mediaQueryData = MediaQuery.of(context);
    screenWidth = _mediaQueryData.size.width;
    screenHeight = _mediaQueryData.size.height;
    orientation = _mediaQueryData.orientation;
  }
}
