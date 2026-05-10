//
//  MaticooMediationAdapter.m
//  AppLovin MAX Demo App - ObjC
//
//  Created by root on 2023/5/18.
//  Copyright © 2023 AppLovin Corporation. All rights reserved.
//

#import "MaticooMediationAdapter.h"
#import "MaticooMaxAdapterDebugLog.h"
#define ADAPTER_VERSION @"2.1.0"

#define MAT_NSSTRING_NOT_NULL(str)\
([(str) isKindOfClass:[NSString class]] && ![(str) isEqualToString:@""])

static NSString * const kAdapterSource = @"max";
static const NSInteger kAdTypeBanner = 1;
static const NSInteger kAdTypeInterstitial = 2;
static const NSInteger kAdTypeRewardedVideo = 3;

static MAReward *MARewardFromMATRewardInfo(MATRewardInfo *rewardInfo) {
    NSInteger amount = rewardInfo.rewardAmount;
    NSString *label = rewardInfo.rewardName;
    if (label.length == 0) {
        label = MAReward.defaultLabel;
    }
    if (amount <= 0) {
        amount = MAReward.defaultAmount;
    }
    return [MAReward rewardWithAmount:amount label:label];
}

static NSString *MATAdTypeDes(NSString *placementId, NSInteger maticooAdType, NSString * _Nullable errorMsg) {
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    dic[@"placementId"] = placementId ?: @"";
    dic[@"adType"] = @(maticooAdType);
    dic[@"source"] = kAdapterSource;
    if (errorMsg.length) {
        dic[@"error"] = errorMsg;
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:dic options:0 error:nil];
    return data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : @"";
}

@interface ALMaticooMediationAdapterInterstitialAdDelegate : NSObject <MATInterstitialAdDelegate>
@property (nonatomic,   weak) MaticooMediationAdapter *parentAdapter;
@property (nonatomic, strong) id<MAInterstitialAdapterDelegate> delegate;
@property (nonatomic,   copy) NSString *placementId;
- (instancetype)initWithParentAdapter:(MaticooMediationAdapter *)parentAdapter andNotify:(id<MAInterstitialAdapterDelegate>)delegate;
@end

@interface ALMaticooMediationAdapterAdViewDelegate : NSObject <MATBannerAdDelegate>
@property (nonatomic, weak) MaticooMediationAdapter *parentAdapter;
@property (nonatomic, strong) id<MAAdViewAdapterDelegate> delegate;
@property (nonatomic, copy) NSString *placementId;
- (instancetype)initWithParentAdapter:(MaticooMediationAdapter *)parentAdapter andNotify:(id<MAAdViewAdapterDelegate>)delegate;
@end

@interface ALMaticooMediationAdapterRewardedAdDelegate : NSObject <MATRewardedVideoAdDelegate>
@property (nonatomic, weak) MaticooMediationAdapter *parentAdapter;
@property (nonatomic, strong) id<MARewardedAdapterDelegate> delegate;
@property (nonatomic, copy) NSString *placementId;
- (instancetype)initWithParentAdapter:(MaticooMediationAdapter *)parentAdapter andNotify:(id<MARewardedAdapterDelegate>)delegate;
@end

@interface MaticooMediationAdapter ()

@property (nonatomic, strong) MATInterstitialAd *interstitial;
@property (nonatomic, strong) ALMaticooMediationAdapterInterstitialAdDelegate *interstitialAdapterDelegate;
@property (nonatomic, strong) MATRewardedVideoAd *rewardedVideo;
@property (nonatomic, strong) ALMaticooMediationAdapterRewardedAdDelegate *rewardedAdapterDelegate;
@property (nonatomic, strong) MATBannerAd *bannerAdView;
@property (nonatomic, strong) ALMaticooMediationAdapterAdViewDelegate *adViewAdapterDelegate;
@property (nonatomic, copy) NSString *placementId;
/// 最近一次发起加载的广告类型（`BANNER` / `INTERSTITIAL` / `REWARDEDVIDEO`），供 `adapter_destroy` 埋点使用。
@property (nonatomic, assign) NSInteger lastLoadedMaticooAdType;

@end


@implementation MaticooMediationAdapter

/// MAX `doNotSell`, `userConsentSet`
+ (void)applyMaxPrivacyIfPresent {
    if ([ALPrivacySettings isDoNotSellSet]) {
        if ([[MaticooAds shareSDK] respondsToSelector:@selector(setDoNotSell:)]) {
            [[MaticooAds shareSDK] setDoNotSell:[ALPrivacySettings isDoNotSell]];
        }
    }
    if ([ALPrivacySettings isUserConsentSet]) {
        if ([[MaticooAds shareSDK] respondsToSelector:@selector(setConsentStatus:)]) {
            [[MaticooAds shareSDK] setConsentStatus:[ALPrivacySettings hasUserConsent]];
        }
    }
}

#pragma mark - MAAdapter Methods

- (instancetype)init {
    self = [super init];
    if (self) {
        
        _lastLoadedMaticooAdType = -1;
    }
    return self;
}

- (void)initializeWithParameters:(id<MAAdapterInitializationParameters>)parameters completionHandler:(void (^)(MAAdapterInitializationStatus, NSString *_Nullable))completionHandler
{
    NSString *appKey = [parameters.serverParameters al_stringForKey: @"app_id"];
    MaticooMaxAdapterDebugLog(@"Initializing Maticoo SDK with app key: %@...", appKey);
    // Override point for customization after application launch.
    [MaticooMediationAdapter applyMaxPrivacyIfPresent];
    [[MaticooAds shareSDK] setMediationName:@"max"];
    [[MaticooAds shareSDK] initSDK:appKey onSuccess:^() {
        completionHandler(MAAdapterInitializationStatusInitializedSuccess, nil);
    } onError:^(NSError* error) {
        completionHandler(MAAdapterInitializationStatusInitializedFailure, error.description);
    }];
}

- (NSString *)SDKVersion
{
    return [[MaticooAds shareSDK] getSDKVersion];
}

- (NSString *)adapterVersion
{
    return ADAPTER_VERSION;
}

+ (MAAdapterError *)toMaxLoadError:(NSError *)maticooError{
    return [MaticooMediationAdapter toMaxError:maticooError isLoad:YES];
}

+ (MAAdapterError *)toMaxShowError:(NSError *)maticooError{
    return [MaticooMediationAdapter toMaxError:maticooError isLoad:NO];
}

+ (MAAdapterError *)toMaxError:(NSError *)maticooError isLoad:(BOOL)isLoad
{
    NSInteger maticooErrorCode = maticooError.code;
    MAAdapterError *adapterError = MAAdapterError.unspecified;

    switch ( maticooErrorCode )
    {
        // Init
        case 10100: adapterError = MAAdapterError.invalidConfiguration; break;
        case 10101: adapterError = MAAdapterError.internalError;        break;

        // Load
        case 20100: adapterError = MAAdapterError.invalidConfiguration; break;
        case 20101: adapterError = MAAdapterError.notInitialized;       break;
        case 20102: adapterError = MAAdapterError.invalidLoadState;     break;
        case 20103: adapterError = MAAdapterError.badRequest;           break;
        case 20104: adapterError = MAAdapterError.timeout;              break;
        case 20105: adapterError = MAAdapterError.noFill;               break;
        case 20106: adapterError = MAAdapterError.internalError;        break;
        case 20107: adapterError = MAAdapterError.invalidConfiguration; break;
        case 20108: adapterError = MAAdapterError.noConnection;         break;
        case 20109: adapterError = MAAdapterError.adFrequencyCappedError; break;
        case 20110: adapterError = MAAdapterError.unspecified;          break;
        case 20111: adapterError = MAAdapterError.timeout;              break;
        case 20112: adapterError = MAAdapterError.unspecified;          break;
        case 20113: adapterError = MAAdapterError.serverError;          break;

        // Show
        case 30100: adapterError = MAAdapterError.invalidLoadState;     break;
        case 30101: adapterError = MAAdapterError.adNotReady;           break;
        case 30102: adapterError = MAAdapterError.internalError;        break;
        case 30104: adapterError = MAAdapterError.noConnection;         break;
        case 30105: adapterError = MAAdapterError.missingViewController; break;
        case 30106: adapterError = MAAdapterError.adExpiredError;       break;
        case 30107: adapterError = MAAdapterError.adDisplayFailedError; break;
        case 30108: adapterError = MAAdapterError.notInitialized;       break;
        case 30109: adapterError = MAAdapterError.adDisplayFailedError; break;
        case 30110: adapterError = MAAdapterError.adNotReady;           break;

        // WebView
        case 40000: adapterError = MAAdapterError.webViewError;         break;
        case 40001: adapterError = MAAdapterError.webViewError;         break;
        case 40002: adapterError = MAAdapterError.webViewError;         break;
        case 40003: adapterError = MAAdapterError.webViewError;         break;
        case 40004: adapterError = MAAdapterError.webViewError;         break;

        default:    adapterError = MAAdapterError.unspecified;          break;
    }

    return [MAAdapterError errorWithAdapterError: adapterError
                        mediatedNetworkErrorCode: maticooErrorCode
                     mediatedNetworkErrorMessage: maticooError.localizedDescription];
}

- (NSDictionary *)ensureParams:(NSDictionary *)dict{
    NSMutableDictionary * newDict = [NSMutableDictionary dictionary];
    
    @try {
        [dict enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            if ([obj isKindOfClass:[NSString class]]) {
                [newDict setValue:obj forKey:key];
            }
        }];
    }@catch (NSException *exception) {
        
    } @finally {
        
    }
    
    return newDict;
}


#pragma mark - MAInterstitialAdapter Methods

- (void)loadInterstitialAdForParameters:(id<MAAdapterResponseParameters>)parameters andNotify:(id<MAInterstitialAdapterDelegate>)delegate
{
    NSString *placementIdentifier = parameters.thirdPartyAdPlacementIdentifier;
    if(!MAT_NSSTRING_NOT_NULL(placementIdentifier)) {
        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed" des:MATAdTypeDes(placementIdentifier, kAdTypeInterstitial, @"placementIdentifier is empty")];
        NSError *error = [[NSError alloc]initWithDomain:@"The placementIdentifier of the interstitial ad is empty." code:106 userInfo:nil];
        MAAdapterError *adapterError = [MaticooMediationAdapter toMaxLoadError: error];
        [delegate didFailToLoadInterstitialAdWithError: adapterError];
        return;
    }
    self.placementId = placementIdentifier;
    self.lastLoadedMaticooAdType = kAdTypeInterstitial;

    [MaticooMediationAdapter applyMaxPrivacyIfPresent];

    MaticooMaxAdapterDebugLog(@"Loading interstitial ad: %@...", placementIdentifier);
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load" des:MATAdTypeDes(placementIdentifier, kAdTypeInterstitial, nil)];
    
    self.interstitial = [[MATInterstitialAd alloc] initWithPlacementID:placementIdentifier];
    self.interstitialAdapterDelegate = [[ALMaticooMediationAdapterInterstitialAdDelegate alloc] initWithParentAdapter: self andNotify: delegate];
    self.interstitialAdapterDelegate.placementId = placementIdentifier;
    self.interstitial.delegate = self.interstitialAdapterDelegate;
    if(parameters.localExtraParameters){
        [self.interstitial loadAdExtraMap:parameters.localExtraParameters];
    } else {
        [self.interstitial loadAd];
    }
}

- (void)showInterstitialAdForParameters:(id<MAAdapterResponseParameters>)parameters andNotify:(id<MAInterstitialAdapterDelegate>)delegate
{
    [self log: @"Showing interstitial: %@...", parameters.thirdPartyAdPlacementIdentifier];
    // Check if ad is already expired or invalidated, and do not show ad if that is the case. You will not get paid to show an invalidated ad.
    if (self.interstitial.isReady){
        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_show" des:MATAdTypeDes(parameters.thirdPartyAdPlacementIdentifier, kAdTypeInterstitial, nil)];
        UIViewController *presentingViewController;
        if ( ALSdk.versionCode >= 11020199 )
        {
            presentingViewController = parameters.presentingViewController ?: [ALUtils topViewControllerFromKeyWindow];
        }
        else
        {
            presentingViewController = [ALUtils topViewControllerFromKeyWindow];
        }
        [self.interstitial showAdFromViewController:presentingViewController];
    }
    else
    {
        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_show_failed" des:MATAdTypeDes(parameters.thirdPartyAdPlacementIdentifier, kAdTypeInterstitial, @"ad is not valid - expired")];
        [self log: @"Unable to show interstitial ad: ad is not valid - marking as expired"];
        [delegate didFailToDisplayInterstitialAdWithError: MAAdapterError.adExpiredError];
    }
}

#pragma mark - MARewardedAdapter

- (void)loadRewardedAdForParameters:(id<MAAdapterResponseParameters>)parameters andNotify:(id<MARewardedAdapterDelegate>)delegate
{
    NSString *placementIdentifier = parameters.thirdPartyAdPlacementIdentifier;
    if (!MAT_NSSTRING_NOT_NULL(placementIdentifier)) {
        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed" des:MATAdTypeDes(placementIdentifier, kAdTypeRewardedVideo, @"placementIdentifier is empty")];
        NSError *error = [[NSError alloc] initWithDomain:@"The placementIdentifier of the rewarded ad is empty." code:106 userInfo:nil];
        MAAdapterError *adapterError = [MaticooMediationAdapter toMaxLoadError:error];
        [delegate didFailToLoadRewardedAdWithError:adapterError];
        return;
    }
    self.placementId = placementIdentifier;
    self.lastLoadedMaticooAdType = kAdTypeRewardedVideo;

    [MaticooMediationAdapter applyMaxPrivacyIfPresent];

    [self log:@"Loading rewarded ad: %@...", placementIdentifier];
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load" des:MATAdTypeDes(placementIdentifier, kAdTypeRewardedVideo, nil)];

    self.rewardedVideo = [[MATRewardedVideoAd alloc] initWithPlacementID:placementIdentifier];
    if (!self.rewardedVideo) {
        NSError *error = [[NSError alloc] initWithDomain:@"MATRewardedVideoAd init failed (empty placement?)." code:20106 userInfo:nil];
        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed" des:MATAdTypeDes(placementIdentifier, kAdTypeRewardedVideo, error.domain)];
        MAAdapterError *adapterError = [MaticooMediationAdapter toMaxLoadError:error];
        [delegate didFailToLoadRewardedAdWithError:adapterError];
        return;
    }

    self.rewardedAdapterDelegate = [[ALMaticooMediationAdapterRewardedAdDelegate alloc] initWithParentAdapter:self andNotify:delegate];
    self.rewardedAdapterDelegate.placementId = placementIdentifier;
    self.rewardedVideo.delegate = self.rewardedAdapterDelegate;
    if (parameters.localExtraParameters) {
        [self.rewardedVideo loadAdExtraMap:parameters.localExtraParameters];
    } else {
        [self.rewardedVideo loadAd];
    }
}

- (void)showRewardedAdForParameters:(id<MAAdapterResponseParameters>)parameters andNotify:(id<MARewardedAdapterDelegate>)delegate
{
    [self log:@"Showing rewarded: %@...", parameters.thirdPartyAdPlacementIdentifier];
    if (self.rewardedVideo.isReady) {
        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_show" des:MATAdTypeDes(parameters.thirdPartyAdPlacementIdentifier, kAdTypeRewardedVideo, nil)];
        UIViewController *presentingViewController;
        if (ALSdk.versionCode >= 11020199) {
            presentingViewController = parameters.presentingViewController ?: [ALUtils topViewControllerFromKeyWindow];
        } else {
            presentingViewController = [ALUtils topViewControllerFromKeyWindow];
        }
        [self.rewardedVideo showAdFromViewController:presentingViewController];
    } else {
        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_show_failed" des:MATAdTypeDes(parameters.thirdPartyAdPlacementIdentifier, kAdTypeRewardedVideo, @"ad is not ready")];
        [self log:@"Unable to show rewarded ad: not ready"];
        [delegate didFailToDisplayRewardedAdWithError:MAAdapterError.adExpiredError];
    }
}

// 老版 iOS MAX（≈1.1.6）：`is_native` → `MATNativeAd` + `renderTrueNativeAd:` 等；当前 zMaticoo `MATNativeAd` 为桩，`is_native` 仅失败返回以免误走 Banner。
#pragma mark - MAAdViewAdapter (Banner / MREC)

- (void)loadAdViewAdForParameters:(id<MAAdapterResponseParameters>)parameters
                         adFormat:(MAAdFormat *)adFormat
                        andNotify:(id<MAAdViewAdapterDelegate>)delegate
{
    BOOL isNative = [parameters.customParameters al_boolForKey:@"is_native"];
    if (isNative) {
        NSError *error = [[NSError alloc] initWithDomain:@"Maticoo MAX adapter: is_native (legacy MATNativeAd path) unavailable — MATNativeAd not implemented in zMaticoo yet." code:106 userInfo:nil];
        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed" des:MATAdTypeDes(parameters.thirdPartyAdPlacementIdentifier ?: @"", (NSInteger)NATIVE, error.domain)];
        MAAdapterError *adapterError = [MaticooMediationAdapter toMaxLoadError:error];
        [delegate didFailToLoadAdViewAdWithError:adapterError];
        return;
    }

    NSString *placementIdentifier = parameters.thirdPartyAdPlacementIdentifier;
    if (!MAT_NSSTRING_NOT_NULL(placementIdentifier)) {
        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed" des:MATAdTypeDes(@"", kAdTypeBanner, @"placementIdentifier is empty")];
        NSError *error = [[NSError alloc] initWithDomain:@"The placementIdentifier of the banner ad is empty." code:106 userInfo:nil];
        MAAdapterError *adapterError = [MaticooMediationAdapter toMaxLoadError:error];
        [delegate didFailToLoadAdViewAdWithError:adapterError];
        return;
    }

    self.placementId = placementIdentifier;
    self.lastLoadedMaticooAdType = kAdTypeBanner;
    [MaticooMediationAdapter applyMaxPrivacyIfPresent];
    [self log: @"Loading %@ ad: %@...", adFormat.label, placementIdentifier];
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load" des:MATAdTypeDes(placementIdentifier, kAdTypeBanner, nil)];

    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        CGSize adSize = [strongSelf adSizeFromAdFormat:adFormat];
        strongSelf.bannerAdView = [[MATBannerAd alloc] initWithPlacementID:placementIdentifier];
        if (!strongSelf.bannerAdView) {
            NSError *error = [[NSError alloc] initWithDomain:@"MATBannerAd init failed (empty placement?)." code:20106 userInfo:nil];
            [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed" des:MATAdTypeDes(placementIdentifier, kAdTypeBanner, error.domain)];
            MAAdapterError *adapterError = [MaticooMediationAdapter toMaxLoadError:error];
            [delegate didFailToLoadAdViewAdWithError:adapterError];
            return;
        }

        strongSelf.bannerAdView.frame = CGRectMake(0, 0, adSize.width, adSize.height);
        strongSelf.adViewAdapterDelegate = [[ALMaticooMediationAdapterAdViewDelegate alloc] initWithParentAdapter:strongSelf andNotify:delegate];
        strongSelf.adViewAdapterDelegate.placementId = placementIdentifier;
        strongSelf.bannerAdView.delegate = strongSelf.adViewAdapterDelegate;
        NSMutableDictionary *localExtra = [NSMutableDictionary dictionary];
        localExtra[@"source"] = kAdapterSource;
        if (parameters.localExtraParameters.count > 0) {
            [localExtra addEntriesFromDictionary:parameters.localExtraParameters];
        }
        strongSelf.bannerAdView.localExtra = [localExtra copy];
        id canCloseObj = parameters.localExtraParameters[@"can_close_ad"];
        if ([canCloseObj isKindOfClass:[NSNumber class]]) {
            strongSelf.bannerAdView.canCloseAd = [(NSNumber *)canCloseObj boolValue];
        } else if ([canCloseObj isKindOfClass:[NSString class]]) {
            strongSelf.bannerAdView.canCloseAd = [(NSString *)canCloseObj boolValue];
        }
        [strongSelf.bannerAdView loadAd];
    });
}

- (CGSize)adSizeFromAdFormat:(MAAdFormat *)adFormat {
    if (adFormat == MAAdFormat.banner) {
        return CGSizeMake(320, 50);
    }
    if (adFormat == MAAdFormat.mrec) {
        return CGSizeMake(300, 250);
    }
    [NSException raise:NSInvalidArgumentException format:@"Unsupported ad format: %@", adFormat];
    return CGSizeZero;
}

- (void)dealloc {
    NSInteger destroyAdType = self.lastLoadedMaticooAdType;
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_destroy" des:MATAdTypeDes(self.placementId, destroyAdType, nil)];
    MATBannerAd *ad = self.bannerAdView;
    self.bannerAdView.delegate = nil;
    self.bannerAdView = nil;
    if (ad) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [ad destroy];
        });
    }
}

@end

@implementation ALMaticooMediationAdapterInterstitialAdDelegate

- (instancetype)initWithParentAdapter:(MaticooMediationAdapter *)parentAdapter andNotify:(id<MAInterstitialAdapterDelegate>)delegate
{
    self = [super init];
    if ( self )
    {
        self.parentAdapter = parentAdapter;
        self.delegate = delegate;
    }
    return self;
}

- (void)interstitialAdDidLoad:(MATInterstitialAd *)interstitialAd{
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_success" des:MATAdTypeDes(self.placementId, kAdTypeInterstitial, nil)];
    [self.delegate didLoadInterstitialAd];
}

- (void)interstitialAd:(MATInterstitialAd *)interstitialAd didFailWithError:(NSError *)error{
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed" des:MATAdTypeDes(self.placementId, kAdTypeInterstitial, error.localizedDescription)];
    MAAdapterError *adapterError = [MaticooMediationAdapter toMaxLoadError: error];
    [self.delegate didFailToLoadInterstitialAdWithError: adapterError];
}

- (void)interstitialAd:(MATInterstitialAd *)interstitialAd displayFailWithError:(NSError *)error{
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_show_failed" des:MATAdTypeDes(self.placementId, kAdTypeInterstitial, error.localizedDescription)];
    MAAdapterError *adapterError = [MaticooMediationAdapter toMaxShowError: error];
    [self.delegate didFailToDisplayInterstitialAdWithError:adapterError];
}

- (void)interstitialAdWillLogImpression:(MATInterstitialAd *)interstitialAd{
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_imp" des:MATAdTypeDes(self.placementId, kAdTypeInterstitial, nil)];
    [self.delegate didDisplayInterstitialAd];
}

- (void)interstitialAdDidClick:(MATInterstitialAd *)interstitialAd{
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_click" des:MATAdTypeDes(self.placementId, kAdTypeInterstitial, nil)];
    [self.delegate didClickInterstitialAd];
}

- (void)interstitialAdWillClose:(MATInterstitialAd *)interstitialAd{
}

- (void)interstitialAdDidClose:(MATInterstitialAd *)interstitialAd{
    [self.delegate didHideInterstitialAd];
}

- (void)interstitialAdDidSkip:(nonnull MATInterstitialAd *)interstitialAd {
}

- (void)interstitialAdEndCardShow:(nonnull MATInterstitialAd *)interstitialAd {
}

@end

@implementation ALMaticooMediationAdapterRewardedAdDelegate

- (instancetype)initWithParentAdapter:(MaticooMediationAdapter *)parentAdapter andNotify:(id<MARewardedAdapterDelegate>)delegate
{
    self = [super init];
    if (self) {
        self.parentAdapter = parentAdapter;
        self.delegate = delegate;
    }
    return self;
}

- (void)rewardedVideoAdDidLoad:(MATRewardedVideoAd *)rewardedVideoAd
{
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_success" des:MATAdTypeDes(self.placementId, kAdTypeRewardedVideo, nil)];
    [self.delegate didLoadRewardedAd];
}

- (void)rewardedVideoAd:(MATRewardedVideoAd *)rewardedVideoAd didFailWithError:(NSError *)error
{
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed" des:MATAdTypeDes(self.placementId, kAdTypeRewardedVideo, error.localizedDescription)];
    MAAdapterError *adapterError = [MaticooMediationAdapter toMaxLoadError:error];
    [self.delegate didFailToLoadRewardedAdWithError:adapterError];
}

- (void)rewardedVideoAd:(MATRewardedVideoAd *)rewardedVideoAd displayFailWithError:(NSError *)error
{
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_show_failed" des:MATAdTypeDes(self.placementId, kAdTypeRewardedVideo, error.localizedDescription)];
    MAAdapterError *adapterError = [MaticooMediationAdapter toMaxShowError:error];
    [self.delegate didFailToDisplayRewardedAdWithError:adapterError];
}

- (void)rewardedVideoAdStarted:(MATRewardedVideoAd *)rewardedVideoAd
{
}

- (void)rewardedVideoAdCompleted:(MATRewardedVideoAd *)rewardedVideoAd
{
}

- (void)rewardedVideoAdWillLogImpression:(MATRewardedVideoAd *)rewardedVideoAd
{
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_imp" des:MATAdTypeDes(self.placementId, kAdTypeRewardedVideo, nil)];
    [self.delegate didDisplayRewardedAd];
}

- (void)rewardedVideoAdDidClick:(MATRewardedVideoAd *)rewardedVideoAd
{
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_click" des:MATAdTypeDes(self.placementId, kAdTypeRewardedVideo, nil)];
    [self.delegate didClickRewardedAd];
}

- (void)rewardedVideoAdWillClose:(MATRewardedVideoAd *)rewardedVideoAd
{
}

- (void)rewardedVideoAdDidClose:(MATRewardedVideoAd *)rewardedVideoAd
{
    [self.delegate didHideRewardedAd];
}

- (void)rewardedVideoAdReward:(MATRewardedVideoAd *)rewardedVideoAd rewardInfo:(MATRewardInfo *)rewardInfo
{
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_reward" des:MATAdTypeDes(self.placementId, kAdTypeRewardedVideo, nil)];
    MAReward *reward = MARewardFromMATRewardInfo(rewardInfo);
    if (rewardInfo.rewardId.length > 0) {
        [self.delegate didRewardUserWithReward:reward extraInfo:@{ @"rewardId": rewardInfo.rewardId }];
    } else {
        [self.delegate didRewardUserWithReward:reward];
    }
}

- (void)rewardedVideoAdDidSkip:(MATRewardedVideoAd *)rewardedVideoAd
{
}

- (void)rewardedVideoAdEndCardShow:(MATRewardedVideoAd *)rewardedVideoAd
{
}

@end

@implementation ALMaticooMediationAdapterAdViewDelegate

- (instancetype)initWithParentAdapter:(MaticooMediationAdapter *)parentAdapter andNotify:(id<MAAdViewAdapterDelegate>)delegate {
    self = [super init];
    if (self) {
        self.parentAdapter = parentAdapter;
        self.delegate = delegate;
    }
    return self;
}

// load 阶段 MATBannerAd 尚未挂到 MAX 容器；SDK 在 adLoadComplete 时可能尚无 window，可见性门闸依赖 didMoveToWindow / 下一 runloop。此处勿自行 addSubview，由 MAX 在 didLoadAdForAdView: 之后挂载。
- (void)bannerAdDidLoad:(MATBannerAd *)bannerAd {
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_success" des:MATAdTypeDes(self.placementId, kAdTypeBanner, nil)];
    [self.parentAdapter log:@"Banner loaded: %@", bannerAd.placementID];
    [self.delegate didLoadAdForAdView:bannerAd];
}

- (void)bannerAd:(MATBannerAd *)bannerAd didFailWithError:(NSError *)error {
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed" des:MATAdTypeDes(self.placementId, kAdTypeBanner, error.localizedDescription)];
    MAAdapterError *adapterError = [MaticooMediationAdapter toMaxLoadError:error];
    [self.parentAdapter log:@"Banner (%@) failed to load with error: %@", bannerAd.placementID, adapterError];
    [self.delegate didFailToLoadAdViewAdWithError:adapterError];
}

- (void)bannerAdDidClick:(MATBannerAd *)bannerAd {
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_click" des:MATAdTypeDes(self.placementId, kAdTypeBanner, nil)];
    [self.parentAdapter log:@"Banner clicked: %@", bannerAd.placementID];
    [self.delegate didClickAdViewAd];
}

- (void)bannerAdDidImpression:(MATBannerAd *)bannerAd {
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_imp" des:MATAdTypeDes(self.placementId, kAdTypeBanner, nil)];
    [self.parentAdapter log:@"Banner shown: %@", bannerAd.placementID];
    [self.delegate didDisplayAdViewAd];
}

- (void)bannerAd:(MATBannerAd *)bannerAd showFailWithError:(NSError *)error {
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_show_failed" des:MATAdTypeDes(self.placementId, kAdTypeBanner, error.localizedDescription)];
    MAAdapterError *adapterError = [MaticooMediationAdapter toMaxShowError:error];
    [self.parentAdapter log:@"Banner show failed: %@ error:%@", bannerAd.placementID, error.localizedDescription];
    if ([self.delegate respondsToSelector:@selector(didFailToDisplayAdViewAdWithError:)]) {
        [self.delegate didFailToDisplayAdViewAdWithError:adapterError];
    }
}

- (void)bannerAdDismissed:(MATBannerAd *)bannerAd {
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_close" des:MATAdTypeDes(self.placementId, kAdTypeBanner, nil)];
    [self.parentAdapter log:@"Banner dismissed (hidden): %@", bannerAd.placementID];
    if ([self.delegate respondsToSelector:@selector(didHideAdViewAd)]) {
        [self.delegate didHideAdViewAd];
    }
}

@end

