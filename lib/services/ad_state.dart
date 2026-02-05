import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';



class AdState {
  Future<InitializationStatus> initialization;

  AdState(this.initialization);


  // Create home top banner ad unit.
  String get homeTopBannerAdUnitId {
    if (Platform.isAndroid) {
      return "ca-app-pub-2404156870680632/4589337767";
    } else if (Platform.isIOS) {
      return "ca-app-pub-2404156870680632/4685442628";
    } else {
      throw UnsupportedError("Unsupported platform");
    }
  }

  // Create home bottom banner ad unit.
  String get homeBottomBannerAdUnitId {
    if (Platform.isAndroid) {
      return "ca-app-pub-2404156870680632/8844179480";
    } else if (Platform.isIOS) {
      return "ca-app-pub-2404156870680632/9718277454";
    } else {
      throw UnsupportedError("Unsupported platform");
    }
  }

  // Create Ego Mode top of comments banner ad unit.
  String get imageScreenTopBannerAdUnitId {
    if (Platform.isAndroid) {
      return "ca-app-pub-2404156870680632/7862270308";
    } else if (Platform.isIOS) {
      return "ca-app-pub-2404156870680632/7338799773";
    } else {
      throw UnsupportedError("Unsupported platform");
    }
  }



  // Create Ego Mode top of comments banner ad unit.
  String get chatScreenTopBannerAdUnitId {
    if (Platform.isAndroid) {
      return "ca-app-pub-2404156870680632/9650092750";
    } else if (Platform.isIOS) {
      return "ca-app-pub-2404156870680632/2709289620";
    } else {
      throw UnsupportedError("Unsupported platform");
    }
  }

  // Create Ego Mode top of comments banner ad unit.
  String get activitiesScreenTopBannerAdUnitId {
    if (Platform.isAndroid) {
      return "ca-app-pub-2404156870680632/6114074363";
    } else if (Platform.isIOS) {
      return "ca-app-pub-2404156870680632/6257642658";
    } else {
      throw UnsupportedError("Unsupported platform");
    }
  }


  // Create Ego Mode top of comments banner ad unit.
  String get loginBottomBannerAdUnitId {
    if (Platform.isAndroid) {
      return "ca-app-pub-2404156870680632/8652607790";
    } else if (Platform.isIOS) {
      return "ca-app-pub-2404156870680632/4022371296";
    } else {
      throw UnsupportedError("Unsupported platform");
    }
  }


  // Create Signup Screen Bottom banner ad unit.
  String get signupBottomBannerAdUnitId {
    if (Platform.isAndroid) {
      return "ca-app-pub-2404156870680632/8277203271";
    } else if (Platform.isIOS) {
      return "ca-app-pub-2404156870680632/1416379512";
    } else {
      throw UnsupportedError("Unsupported platform");
    }
  }


  String get questionDetailsTopBanner {
    if (Platform.isAndroid) {
      return "ca-app-pub-2404156870680632/2174829356";
    } else if (Platform.isIOS) {
      return "ca-app-pub-2404156870680632/2222930812";
    } else {
      throw UnsupportedError("Unsupported platform");
    }
  }

  // Create Mood Sessions top banner ad unit.
  String get questionDetailsBottomBanner {
    if (Platform.isAndroid) {
      return "ca-app-pub-2404156870680632/6927736238";
    } else if (Platform.isIOS) {
      return "ca-app-pub-2404156870680632/6668706194";
    } else {
      throw UnsupportedError("Unsupported platform");
    }
  }

}