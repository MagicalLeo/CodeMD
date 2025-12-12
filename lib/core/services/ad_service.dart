import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Service for managing rewarded ads
class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  // Real Ad Unit ID for production
  static const String _rewardedAdUnitId = 'ca-app-pub-5388263355129714/2579601225';

  // Test Ad Unit ID for development (use this during testing)
  static const String _testRewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917';

  RewardedAd? _rewardedAd;
  bool _isAdLoaded = false;
  bool _isInitialized = false;

  bool get isAdLoaded => _isAdLoaded;
  bool get isInitialized => _isInitialized;

  /// Initialize Mobile Ads SDK
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;
      debugPrint('[AdService] MobileAds initialized');
      // Pre-load an ad
      loadRewardedAd();
    } catch (e) {
      debugPrint('[AdService] Failed to initialize: $e');
    }
  }

  /// Get the appropriate ad unit ID based on debug mode
  String get _adUnitId {
    // Use test ad in debug mode to avoid policy violations
    if (kDebugMode) {
      return _testRewardedAdUnitId;
    }
    return _rewardedAdUnitId;
  }

  /// Load a rewarded ad
  void loadRewardedAd() {
    if (!_isInitialized) {
      debugPrint('[AdService] Cannot load ad - not initialized');
      return;
    }

    RewardedAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isAdLoaded = true;
          debugPrint('[AdService] Rewarded ad loaded');

          // Set callbacks
          _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              debugPrint('[AdService] Ad dismissed');
              ad.dispose();
              _rewardedAd = null;
              _isAdLoaded = false;
              // Preload next ad
              loadRewardedAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('[AdService] Ad failed to show: $error');
              ad.dispose();
              _rewardedAd = null;
              _isAdLoaded = false;
              loadRewardedAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('[AdService] Failed to load rewarded ad: $error');
          _isAdLoaded = false;
        },
      ),
    );
  }

  /// Show rewarded ad and call onRewarded when user earns reward
  Future<bool> showRewardedAd({
    required Function(int amount, String type) onRewarded,
    Function()? onAdNotReady,
  }) async {
    if (!_isAdLoaded || _rewardedAd == null) {
      debugPrint('[AdService] Ad not ready');
      onAdNotReady?.call();
      // Try to load for next time
      loadRewardedAd();
      return false;
    }

    try {
      await _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) {
          debugPrint('[AdService] User earned reward: ${reward.amount} ${reward.type}');
          onRewarded(reward.amount.toInt(), reward.type);
        },
      );
      return true;
    } catch (e) {
      debugPrint('[AdService] Error showing ad: $e');
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _isAdLoaded = false;
  }
}
