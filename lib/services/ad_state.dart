import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';



class AdState {
  Future<InitializationStatus> initialization;

  AdState(this.initialization);


  // Create home top banner ad unit.
  String get homeTopBannerAdUnitId {
    if (Platform.isAndroid) {
      return "ca-app-pub-2404156870680632/4534180720";
    } else if (Platform.isIOS) {
      return "ca-app-pub-2404156870680632/9244695314";
    } else {
      throw UnsupportedError("Unsupported platform");
    }
  }

  // Create home bottom banner ad unit.
  String get homeBottomBannerAdUnitId {
    if (Platform.isAndroid) {
      return "ca-app-pub-2404156870680632/4284551673";
    } else if (Platform.isIOS) {
      return "ca-app-pub-2404156870680632/6497196758";
    } else {
      throw UnsupportedError("Unsupported platform");
    }
  }

  // Create Ego Mode top of comments banner ad unit.
  String get imageScreenTopBannerAdUnitId {
    if (Platform.isAndroid) {
      return "ca-app-pub-2404156870680632/7595458335";
    } else if (Platform.isIOS) {
      return "ca-app-pub-2404156870680632/7931613647";
    } else {
      throw UnsupportedError("Unsupported platform");
    }
  }



  // Create Ego Mode top of comments banner ad unit.
  String get chatScreenTopBannerAdUnitId {
    if (Platform.isAndroid) {
      return "ca-app-pub-2404156870680632/5080975632";
    } else if (Platform.isIOS) {
      return "ca-app-pub-2404156870680632/1194852899";
    } else {
      throw UnsupportedError("Unsupported platform");
    }
  }

  // Create Ego Mode top of comments banner ad unit.
  String get activitiesScreenTopBannerAdUnitId {
    if (Platform.isAndroid) {
      return "ca-app-pub-2404156870680632/7323995596";
    } else if (Platform.isIOS) {
      return "ca-app-pub-2404156870680632/3871033417";
    } else {
      throw UnsupportedError("Unsupported platform");
    }
  }


  // Create Ego Mode top of comments banner ad unit.
  String get loginBottomBannerAdUnitId {
    if (Platform.isAndroid) {
      return "ca-app-pub-2404156870680632/6980380669";
    } else if (Platform.isIOS) {
      return "ca-app-pub-2404156870680632/7618706736";
    } else {
      throw UnsupportedError("Unsupported platform");
    }
  }


  // Create Signup Screen Bottom banner ad unit.
  String get signupBottomBannerAdUnitId {
    if (Platform.isAndroid) {
      return "ca-app-pub-2404156870680632/7033185708";
    } else if (Platform.isIOS) {
      return "ca-app-pub-2404156870680632/7235563358";
    } else {
      throw UnsupportedError("Unsupported platform");
    }
  }


  String get questionDetailsTopBanner {
    if (Platform.isAndroid) {
      return "ca-app-pub-2404156870680632/6010314853";
    } else if (Platform.isIOS) {
      return "ca-app-pub-2404156870680632/9751670195";
    } else {
      throw UnsupportedError("Unsupported platform");
    }
  }

  // Create Mood Sessions top banner ad unit.
  String get questionDetailsBottomBanner {
    if (Platform.isAndroid) {
      return "ca-app-pub-2404156870680632/6195568566";
    } else if (Platform.isIOS) {
      return "ca-app-pub-2404156870680632/3186261846";
    } else {
      throw UnsupportedError("Unsupported platform");
    }
  }

}