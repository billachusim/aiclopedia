import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:ai_clopedia/services/ad_state.dart';

class AdService {
  AdService._();
  static final AdService instance = AdService._();

  RewardedAd? _rewardedAd;
  int _numRewardedLoadAttempts = 0;
  final int maxFailedLoadAttempts = 3;

  bool _isAdUnlockedForSession = false;
  bool get isAdUnlockedForSession => _isAdUnlockedForSession;

  void unlockSession() {
    _isAdUnlockedForSession = true;
  }

  void createRewardedAd(AdState adState) {
    RewardedAd.load(
      adUnitId: adState.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          log('$ad loaded.');
          _rewardedAd = ad;
          _numRewardedLoadAttempts = 0;
        },
        onAdFailedToLoad: (LoadAdError error) {
          log('RewardedAd failed to load: $error');
          _rewardedAd = null;
          _numRewardedLoadAttempts += 1;
          if (_numRewardedLoadAttempts <= maxFailedLoadAttempts) {
            createRewardedAd(adState);
          }
        },
      ),
    );
  }

  void showRewardedAd({
    required BuildContext context,
    required AdState adState,
    required Function(int credits) onRewardEarned,
  }) {
    if (_rewardedAd == null) {
      log('Warning: attempt to show rewarded ad before loaded.');
      createRewardedAd(adState);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ad is still loading, please try again in a moment.')),
      );
      return;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (RewardedAd ad) => log('$ad onAdShowedFullScreenContent.'),
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        log('$ad onAdDismissedFullScreenContent.');
        ad.dispose();
        createRewardedAd(adState);
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        log('$ad onAdFailedToShowFullScreenContent: $error');
        ad.dispose();
        createRewardedAd(adState);
      },
    );

    _rewardedAd!.setImmersiveMode(true);
    _rewardedAd!.show(onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
      log('$ad with reward $RewardItem(${reward.amount}, ${reward.type})');
      // Default to 10 if reward amount is 0/missing in test ads
      final int rewardAmount = reward.amount.toInt() > 0 ? reward.amount.toInt() : 10;
      onRewardEarned(rewardAmount);
      unlockSession();
    });
    _rewardedAd = null;
  }
}
