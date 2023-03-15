import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';



class AdState {
  Future<InitializationStatus> initialization;

  AdState(this.initialization);


  // Create Tictactoe top banner ad unit.
  String get homeTopBannerAdUnitId {
    if (Platform.isAndroid) {
      return "ca-app-pub-3940256099942544/6300978111";
    } else if (Platform.isIOS) {
      return "ca-app-pub-2404156870680632/3116018582";
    } else {
      throw UnsupportedError("Unsupported platform");
    }
  }

  // Create Mood Sessions top banner ad unit.
  String get homeBottomBannerAdUnitId {
    if (Platform.isAndroid) {
      return "ca-app-pub-3940256099942544/6300978111";
    } else if (Platform.isIOS) {
      return "ca-app-pub-2404156870680632/7874957062";
    } else {
      throw UnsupportedError("Unsupported platform");
    }
  }

  // Create Ego Mode top of comments banner ad unit.
  String get imageScreenTopBannerAdUnitId {
    if (Platform.isAndroid) {
      return "ca-app-pub-3940256099942544/6300978111";
    } else if (Platform.isIOS) {
      return "ca-app-pub-2404156870680632/5702526856";
    } else {
      throw UnsupportedError("Unsupported platform");
    }
  }



  // Create Ego Mode top of comments banner ad unit.
  String get chatScreenTopBannerAdUnitId {
    if (Platform.isAndroid) {
      return "ca-app-pub-3940256099942544/6300978111";
    } else if (Platform.isIOS) {
      return "ca-app-pub-2404156870680632/5702526856";
    } else {
      throw UnsupportedError("Unsupported platform");
    }
  }

}