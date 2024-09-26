//
//  MaticooMediationAdapter.h
//  AppLovin MAX Demo App - ObjC
//
//  Created by root on 2023/5/18.
//  Copyright © 2023 AppLovin Corporation. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppLovinSDK/AppLovinSDK.h>
#import <MaticooSDK/MaticooAds.h>
#import <MaticooSDK/MATInterstitialAd.h>
#import <MaticooSDK/MATRewardedVideoAd.h>
#import <MaticooSDK/MATNativeAd.h>
#import <MaticooSDK/MATBannerAd.h>

NS_ASSUME_NONNULL_BEGIN

#define BANNER 1
#define INTERSTITIAL 2
#define REWARDEDVIDEO 3
#define NATIVE 4
#define INTERACTIVE 5
#define SPLASH 6

@interface MaticooMediationAdapter : ALMediationAdapter <MATBannerAdDelegate, MATNativeAdDelegate, MATInterstitialAdDelegate, MATRewardedVideoAdDelegate>

@end

NS_ASSUME_NONNULL_END
