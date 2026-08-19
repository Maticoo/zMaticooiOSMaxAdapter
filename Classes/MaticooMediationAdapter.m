//
//  MaticooMediationAdapter.m
//  AppLovin MAX Demo App - ObjC
//
//  Created by root on 2023/5/18.
//  Copyright © 2023 AppLovin Corporation. All rights reserved.
//

#import "MaticooMediationAdapter.h"
#import "MaticooMaxAdapterDebugLog.h"
#import <MaticooSDK/MATAdChoicesView.h>
#import <MaticooSDK/MATAdImage.h>
#import <MaticooSDK/MATMediaContent.h>
#import <MaticooSDK/MATMediaView.h>
#import <MaticooSDK/MATNativeAdOptions.h>
#import <MaticooSDK/MATVideoOptions.h>
#define ADAPTER_VERSION @"2.2.0"

#define MAT_NSSTRING_NOT_NULL(str)\
([(str) isKindOfClass:[NSString class]] && ![(str) isEqualToString:@""])

static NSString * const kAdapterSource = @"max";

// 取代之前 header 里无前缀的 `#define BANNER/INTERSTITIAL/NATIVE/...`，避免预处理符号污染整个工程命名空间。
typedef NS_ENUM(NSInteger, MATMaxAdapterAdType) {
    MATMaxAdapterAdTypeBanner        = 1,
    MATMaxAdapterAdTypeInterstitial  = 2,
    MATMaxAdapterAdTypeRewardedVideo = 3,
    MATMaxAdapterAdTypeNative        = 4,
    MATMaxAdapterAdTypeInteractive   = 5,
    MATMaxAdapterAdTypeSplash        = 6,
};

static const NSInteger kAdTypeBanner = MATMaxAdapterAdTypeBanner;
static const NSInteger kAdTypeInterstitial = MATMaxAdapterAdTypeInterstitial;
static const NSInteger kAdTypeRewardedVideo = MATMaxAdapterAdTypeRewardedVideo;
static const NSInteger kAdTypeNative = MATMaxAdapterAdTypeNative;

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

/// `parameters.localExtraParameters` 原样交给 `-loadAdExtraMap:`，这里不挑 key、不改写值。
static NSDictionary<NSString *, id> *MATLoadExtraMapFromLocalExtraParameters(NSDictionary *localExtraParameters) {
    return [localExtraParameters isKindOfClass:[NSDictionary class]] ? localExtraParameters : nil;
}

/// 读取字典里的 `is_muted`；`NSNumber` 或 `"true"`/`"false"`，非法或缺省返回 nil。
static NSNumber * _Nullable MATMutedFromExtraDictionary(NSDictionary *extra) {
    if (![extra isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    id value = extra[@"is_muted"];
    if ([value isKindOfClass:[NSNumber class]]) {
        return value;
    }
    if ([value isKindOfClass:[NSString class]]) {
        NSString *text = [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([text caseInsensitiveCompare:@"true"] == NSOrderedSame) {
            return @YES;
        }
        if ([text caseInsensitiveCompare:@"false"] == NSOrderedSame) {
            return @NO;
        }
    }
    return nil;
}

/// 读取 `localExtraParameters[@"is_muted"]`。
static NSNumber * _Nullable MATMutedFromLocalExtraParameters(NSDictionary *localExtraParameters) {
    return MATMutedFromExtraDictionary(localExtraParameters);
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

static NSString * const kUseImageSelfRenderKey = @"use_image_self_render";

@interface ALMaticooMediationAdapterNativeAdDelegate : NSObject <MATNativeAdDelegate>
@property (nonatomic, weak) MaticooMediationAdapter *parentAdapter;
@property (nonatomic, strong) id<MANativeAdAdapterDelegate> delegate;
@property (nonatomic, copy) NSString *placementId;
/// 与 AdMob/TopOn 对齐：图片素材时不注入 MATMediaView，走主图自渲染。
@property (nonatomic, assign) BOOL useImageSelfRender;
- (instancetype)initWithParentAdapter:(MaticooMediationAdapter *)parentAdapter andNotify:(id<MANativeAdAdapterDelegate>)delegate;
@end

/// MAX 要求子类覆盖 prepareForInteraction，才能把渲染后的 container / clickableViews 交给下游 SDK 注册。
@interface ALMaticooMANativeAd : MANativeAd
@property (nonatomic, strong) MATNativeAd *maticooNativeAd;
@property (nonatomic, strong, nullable) MATMediaView *maticooMediaView;
@property (nonatomic, copy) NSString *placementId;
@end

@implementation ALMaticooMANativeAd

// MAX 可能在非主线程调 prepareForInteraction，而 load 回调线程写这两个 strong 指针。
// ARC 并发读写 nonatomic strong 会读到哨兵 0x400000000000bad0，读写必须同锁。
@synthesize maticooNativeAd = _maticooNativeAd;
@synthesize maticooMediaView = _maticooMediaView;
@synthesize placementId = _placementId;

- (MATNativeAd *)maticooNativeAd {
    @synchronized (self) {
        return _maticooNativeAd;
    }
}

- (void)setMaticooNativeAd:(MATNativeAd *)maticooNativeAd {
    @synchronized (self) {
        _maticooNativeAd = maticooNativeAd;
    }
}

- (MATMediaView *)maticooMediaView {
    @synchronized (self) {
        return _maticooMediaView;
    }
}

- (void)setMaticooMediaView:(MATMediaView *)maticooMediaView {
    @synchronized (self) {
        _maticooMediaView = maticooMediaView;
    }
}

- (NSString *)placementId {
    @synchronized (self) {
        return _placementId;
    }
}

- (void)setPlacementId:(NSString *)placementId {
    @synchronized (self) {
        _placementId = [placementId copy];
    }
}

- (BOOL)prepareForInteractionClickableViews:(NSArray<UIView *> *)clickableViews withContainer:(UIView *)container {
    MATNativeAd *nativeAd = self.maticooNativeAd;
    MATMediaView *mediaView = self.maticooMediaView;
    if (!nativeAd || !container) {
        return NO;
    }
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_show"
                                                       des:MATAdTypeDes(self.placementId, kAdTypeNative, nil)];
    [nativeAd registerViewForInteraction:container
                               mediaView:mediaView
                          clickableViews:clickableViews];
    return YES;
}

@end

@interface MaticooMediationAdapter ()

@property (nonatomic, strong) MATInterstitialAd *interstitial;
@property (nonatomic, strong) ALMaticooMediationAdapterInterstitialAdDelegate *interstitialAdapterDelegate;
@property (nonatomic, strong) MATRewardedVideoAd *rewardedVideo;
@property (nonatomic, strong) ALMaticooMediationAdapterRewardedAdDelegate *rewardedAdapterDelegate;
@property (nonatomic, strong) MATBannerAd *bannerAdView;
@property (nonatomic, strong) ALMaticooMediationAdapterAdViewDelegate *adViewAdapterDelegate;
@property (nonatomic, strong) MATNativeAd *nativeAdInstance;
@property (nonatomic, strong) ALMaticooMediationAdapterNativeAdDelegate *nativeAdapterDelegate;
@property (nonatomic, copy) NSString *placementId;
/// 最近一次发起加载的广告类型（`MATMaxAdapterAdTypeBanner` / `Interstitial` / `RewardedVideo` / `Native`），供 `adapter_destroy` 埋点使用。
@property (nonatomic, assign) NSInteger lastLoadedMaticooAdType;

@end


@implementation MaticooMediationAdapter

// 广告对象与 nested delegate 在 load 线程写，MAX 可能在其它线程读 show / isReady / prepareForInteraction。
// ARC 并发读写 nonatomic strong 会读到哨兵指针 0x400000000000bad0，读写必须同锁。
// 持锁只保护指针交换；拿到局部变量后再调 SDK，不要在 @synchronized(self) 内调外部方法。
@synthesize interstitial = _interstitial;
@synthesize interstitialAdapterDelegate = _interstitialAdapterDelegate;
@synthesize rewardedVideo = _rewardedVideo;
@synthesize rewardedAdapterDelegate = _rewardedAdapterDelegate;
@synthesize bannerAdView = _bannerAdView;
@synthesize adViewAdapterDelegate = _adViewAdapterDelegate;
@synthesize nativeAdInstance = _nativeAdInstance;
@synthesize nativeAdapterDelegate = _nativeAdapterDelegate;
@synthesize placementId = _placementId;

- (MATInterstitialAd *)interstitial {
    @synchronized (self) {
        return _interstitial;
    }
}

- (void)setInterstitial:(MATInterstitialAd *)interstitial {
    @synchronized (self) {
        _interstitial = interstitial;
    }
}

- (ALMaticooMediationAdapterInterstitialAdDelegate *)interstitialAdapterDelegate {
    @synchronized (self) {
        return _interstitialAdapterDelegate;
    }
}

- (void)setInterstitialAdapterDelegate:(ALMaticooMediationAdapterInterstitialAdDelegate *)interstitialAdapterDelegate {
    @synchronized (self) {
        _interstitialAdapterDelegate = interstitialAdapterDelegate;
    }
}

- (MATRewardedVideoAd *)rewardedVideo {
    @synchronized (self) {
        return _rewardedVideo;
    }
}

- (void)setRewardedVideo:(MATRewardedVideoAd *)rewardedVideo {
    @synchronized (self) {
        _rewardedVideo = rewardedVideo;
    }
}

- (ALMaticooMediationAdapterRewardedAdDelegate *)rewardedAdapterDelegate {
    @synchronized (self) {
        return _rewardedAdapterDelegate;
    }
}

- (void)setRewardedAdapterDelegate:(ALMaticooMediationAdapterRewardedAdDelegate *)rewardedAdapterDelegate {
    @synchronized (self) {
        _rewardedAdapterDelegate = rewardedAdapterDelegate;
    }
}

- (MATBannerAd *)bannerAdView {
    @synchronized (self) {
        return _bannerAdView;
    }
}

- (void)setBannerAdView:(MATBannerAd *)bannerAdView {
    @synchronized (self) {
        _bannerAdView = bannerAdView;
    }
}

- (ALMaticooMediationAdapterAdViewDelegate *)adViewAdapterDelegate {
    @synchronized (self) {
        return _adViewAdapterDelegate;
    }
}

- (void)setAdViewAdapterDelegate:(ALMaticooMediationAdapterAdViewDelegate *)adViewAdapterDelegate {
    @synchronized (self) {
        _adViewAdapterDelegate = adViewAdapterDelegate;
    }
}

- (MATNativeAd *)nativeAdInstance {
    @synchronized (self) {
        return _nativeAdInstance;
    }
}

- (void)setNativeAdInstance:(MATNativeAd *)nativeAdInstance {
    @synchronized (self) {
        _nativeAdInstance = nativeAdInstance;
    }
}

- (ALMaticooMediationAdapterNativeAdDelegate *)nativeAdapterDelegate {
    @synchronized (self) {
        return _nativeAdapterDelegate;
    }
}

- (void)setNativeAdapterDelegate:(ALMaticooMediationAdapterNativeAdDelegate *)nativeAdapterDelegate {
    @synchronized (self) {
        _nativeAdapterDelegate = nativeAdapterDelegate;
    }
}

- (NSString *)placementId {
    @synchronized (self) {
        return _placementId;
    }
}

- (void)setPlacementId:(NSString *)placementId {
    @synchronized (self) {
        _placementId = [placementId copy];
    }
}

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

/// MAX 全局静音：优先 `serverParameters[@"is_muted"]`，否则 `ALSdk.settings.muted` → `MaticooAds.videoMute`（仅全屏，不影响 Native）
+ (void)applyMaxGlobalVideoMuteWithServerParameters:(NSDictionary *)serverParameters {
    NSNumber *serverMuted = MATMutedFromExtraDictionary(serverParameters);
    MaticooAds *sdk = [MaticooAds shareSDK];
    if (serverMuted != nil) {
        sdk.videoMute = serverMuted.boolValue;
        MaticooMaxAdapterDebugLog(@"MAX server is_muted=%d -> MaticooAds.videoMute", serverMuted.boolValue);
        return;
    }
    BOOL muted = [ALSdk shared].settings.muted;
    sdk.videoMute = muted;
    MaticooMaxAdapterDebugLog(@"MAX settings.muted=%d -> MaticooAds.videoMute", muted);
}

+ (void)applyMaxGlobalVideoMute {
    [self applyMaxGlobalVideoMuteWithServerParameters:nil];
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
    [MaticooMediationAdapter applyMaxGlobalVideoMuteWithServerParameters:parameters.serverParameters];
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
    
    MATInterstitialAd *interstitial = [[MATInterstitialAd alloc] initWithPlacementID:placementIdentifier];
    ALMaticooMediationAdapterInterstitialAdDelegate *adapterDelegate =
        [[ALMaticooMediationAdapterInterstitialAdDelegate alloc] initWithParentAdapter:self andNotify:delegate];
    adapterDelegate.placementId = placementIdentifier;
    self.interstitial = interstitial;
    self.interstitialAdapterDelegate = adapterDelegate;
    interstitial.delegate = adapterDelegate;
    NSNumber *isMuted = MATMutedFromLocalExtraParameters(parameters.localExtraParameters);
    if (isMuted != nil) {
        interstitial.videoMute = isMuted.boolValue;
    }
    [interstitial loadAdExtraMap:MATLoadExtraMapFromLocalExtraParameters(parameters.localExtraParameters)];
}

- (void)showInterstitialAdForParameters:(id<MAAdapterResponseParameters>)parameters andNotify:(id<MAInterstitialAdapterDelegate>)delegate
{
    [self log: @"Showing interstitial: %@...", parameters.thirdPartyAdPlacementIdentifier];
    MATInterstitialAd *interstitial = self.interstitial;
    // Check if ad is already expired or invalidated, and do not show ad if that is the case. You will not get paid to show an invalidated ad.
    if (interstitial.isReady){
        [MaticooMediationAdapter applyMaxPrivacyIfPresent];
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
        [interstitial showAdFromViewController:presentingViewController];
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

    MATRewardedVideoAd *rewardedVideo = [[MATRewardedVideoAd alloc] initWithPlacementID:placementIdentifier];
    if (!rewardedVideo) {
        NSError *error = [[NSError alloc] initWithDomain:@"MATRewardedVideoAd init failed (empty placement?)." code:20106 userInfo:nil];
        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed" des:MATAdTypeDes(placementIdentifier, kAdTypeRewardedVideo, error.domain)];
        MAAdapterError *adapterError = [MaticooMediationAdapter toMaxLoadError:error];
        [delegate didFailToLoadRewardedAdWithError:adapterError];
        return;
    }
    self.rewardedVideo = rewardedVideo;

    ALMaticooMediationAdapterRewardedAdDelegate *adapterDelegate =
        [[ALMaticooMediationAdapterRewardedAdDelegate alloc] initWithParentAdapter:self andNotify:delegate];
    adapterDelegate.placementId = placementIdentifier;
    self.rewardedAdapterDelegate = adapterDelegate;
    rewardedVideo.delegate = adapterDelegate;
    NSNumber *isMuted = MATMutedFromLocalExtraParameters(parameters.localExtraParameters);
    if (isMuted != nil) {
        rewardedVideo.videoMute = isMuted.boolValue;
    }
    [rewardedVideo loadAdExtraMap:MATLoadExtraMapFromLocalExtraParameters(parameters.localExtraParameters)];
}

- (void)showRewardedAdForParameters:(id<MAAdapterResponseParameters>)parameters andNotify:(id<MARewardedAdapterDelegate>)delegate
{
    [self log:@"Showing rewarded: %@...", parameters.thirdPartyAdPlacementIdentifier];
    MATRewardedVideoAd *rewardedVideo = self.rewardedVideo;
    if (rewardedVideo.isReady) {
        [MaticooMediationAdapter applyMaxPrivacyIfPresent];
        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_show" des:MATAdTypeDes(parameters.thirdPartyAdPlacementIdentifier, kAdTypeRewardedVideo, nil)];
        UIViewController *presentingViewController;
        if (ALSdk.versionCode >= 11020199) {
            presentingViewController = parameters.presentingViewController ?: [ALUtils topViewControllerFromKeyWindow];
        } else {
            presentingViewController = [ALUtils topViewControllerFromKeyWindow];
        }
        [rewardedVideo showAdFromViewController:presentingViewController];
    } else {
        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_show_failed" des:MATAdTypeDes(parameters.thirdPartyAdPlacementIdentifier, kAdTypeRewardedVideo, @"ad is not ready")];
        [self log:@"Unable to show rewarded ad: not ready"];
        [delegate didFailToDisplayRewardedAdWithError:MAAdapterError.adExpiredError];
    }
}

// v2.2.0：移除老版 is_native 早失败分支；Native 由 loadNativeAdForParameters:andNotify: 处理（MAAdViewAdapter 仅负责 Banner/MREC）。
#pragma mark - MAAdViewAdapter (Banner / MREC)

- (void)loadAdViewAdForParameters:(id<MAAdapterResponseParameters>)parameters
                         adFormat:(MAAdFormat *)adFormat
                        andNotify:(id<MAAdViewAdapterDelegate>)delegate
{
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
        if (CGSizeEqualToSize(adSize, CGSizeZero)) {
            NSError *error = [[NSError alloc] initWithDomain:[NSString stringWithFormat:@"Unsupported MAAdFormat: %@", adFormat.label] code:106 userInfo:nil];
            [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed" des:MATAdTypeDes(placementIdentifier, kAdTypeBanner, error.domain)];
            MAAdapterError *adapterError = [MaticooMediationAdapter toMaxLoadError:error];
            [delegate didFailToLoadAdViewAdWithError:adapterError];
            return;
        }

        MATBannerAd *bannerAdView = [[MATBannerAd alloc] initWithPlacementID:placementIdentifier];
        if (!bannerAdView) {
            NSError *error = [[NSError alloc] initWithDomain:@"MATBannerAd init failed (empty placement?)." code:20106 userInfo:nil];
            [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed" des:MATAdTypeDes(placementIdentifier, kAdTypeBanner, error.domain)];
            MAAdapterError *adapterError = [MaticooMediationAdapter toMaxLoadError:error];
            [delegate didFailToLoadAdViewAdWithError:adapterError];
            return;
        }
        strongSelf.bannerAdView = bannerAdView;

        bannerAdView.frame = CGRectMake(0, 0, adSize.width, adSize.height);
        ALMaticooMediationAdapterAdViewDelegate *adapterDelegate =
            [[ALMaticooMediationAdapterAdViewDelegate alloc] initWithParentAdapter:strongSelf andNotify:delegate];
        adapterDelegate.placementId = placementIdentifier;
        strongSelf.adViewAdapterDelegate = adapterDelegate;
        bannerAdView.delegate = adapterDelegate;
        // can_close_ad 仍从 localExtraParameters 单独读取（已 isKindOfClass 校验类型），不进入 localExtra 字典。
        id canCloseObj = parameters.localExtraParameters[@"can_close_ad"];
        if ([canCloseObj isKindOfClass:[NSNumber class]]) {
            bannerAdView.canCloseAd = [(NSNumber *)canCloseObj boolValue];
        } else if ([canCloseObj isKindOfClass:[NSString class]]) {
            bannerAdView.canCloseAd = [(NSString *)canCloseObj boolValue];
        }
        [bannerAdView loadAdExtraMap:MATLoadExtraMapFromLocalExtraParameters(parameters.localExtraParameters)];
    });
}

#pragma mark - MANativeAdAdapter

- (void)loadNativeAdForParameters:(id<MAAdapterResponseParameters>)parameters andNotify:(id<MANativeAdAdapterDelegate>)delegate {
    NSString *placementIdentifier = parameters.thirdPartyAdPlacementIdentifier;
    if (!MAT_NSSTRING_NOT_NULL(placementIdentifier)) {
        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed"
                                                           des:MATAdTypeDes(placementIdentifier, kAdTypeNative, @"placementIdentifier is empty")];
        NSError *error = [[NSError alloc] initWithDomain:@"The placementIdentifier of the native ad is empty." code:106 userInfo:nil];
        MAAdapterError *adapterError = [MaticooMediationAdapter toMaxLoadError:error];
        [delegate didFailToLoadNativeAdWithError:adapterError];
        return;
    }
    self.placementId = placementIdentifier;
    self.lastLoadedMaticooAdType = kAdTypeNative;
    [MaticooMediationAdapter applyMaxPrivacyIfPresent];

    [self log:@"Loading native ad: %@...", placementIdentifier];
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load"
                                                       des:MATAdTypeDes(placementIdentifier, kAdTypeNative, nil)];

    BOOL useImageSelfRender = NO;
    id useImageSelfRenderObj = parameters.localExtraParameters[kUseImageSelfRenderKey];
    if ([useImageSelfRenderObj isKindOfClass:[NSNumber class]]) {
        useImageSelfRender = [(NSNumber *)useImageSelfRenderObj boolValue];
    } else if ([useImageSelfRenderObj isKindOfClass:[NSString class]]) {
        useImageSelfRender = [(NSString *)useImageSelfRenderObj boolValue];
    }

    NSDictionary *extraMap = MATLoadExtraMapFromLocalExtraParameters(parameters.localExtraParameters);
    NSNumber *isMuted = MATMutedFromLocalExtraParameters(parameters.localExtraParameters);

    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        MATNativeAd *nativeAdInstance = [[MATNativeAd alloc] initWithPlacementID:placementIdentifier];
        if (!nativeAdInstance) {
            NSError *error = [[NSError alloc] initWithDomain:@"MATNativeAd init failed (empty placement?)." code:20106 userInfo:nil];
            [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed"
                                                               des:MATAdTypeDes(placementIdentifier, kAdTypeNative, error.domain)];
            MAAdapterError *adapterError = [MaticooMediationAdapter toMaxLoadError:error];
            [delegate didFailToLoadNativeAdWithError:adapterError];
            return;
        }
        strongSelf.nativeAdInstance = nativeAdInstance;
        ALMaticooMediationAdapterNativeAdDelegate *adapterDelegate =
            [[ALMaticooMediationAdapterNativeAdDelegate alloc] initWithParentAdapter:strongSelf andNotify:delegate];
        adapterDelegate.placementId = placementIdentifier;
        adapterDelegate.useImageSelfRender = useImageSelfRender;
        strongSelf.nativeAdapterDelegate = adapterDelegate;
        nativeAdInstance.delegate = adapterDelegate;
        if (isMuted != nil) {
            MATVideoOptions *videoOpts = [[MATVideoOptions alloc] init];
            videoOpts.startMuted = isMuted.boolValue;
            MATNativeAdOptions *nativeOpts = [[MATNativeAdOptions alloc] init];
            nativeOpts.videoOptions = videoOpts;
            [nativeAdInstance setNativeAdOptions:nativeOpts];
        }
        [nativeAdInstance loadAdExtraMap:extraMap];
    });
}

// 不支持的格式返回 CGSizeZero，由调用方走失败回调，避免抛 NSException 导致 MAX 主线程崩溃。
- (CGSize)adSizeFromAdFormat:(MAAdFormat *)adFormat {
    if (adFormat == MAAdFormat.banner) {
        return CGSizeMake(320, 50);
    }
    if (adFormat == MAAdFormat.mrec) {
        return CGSizeMake(300, 250);
    }
    if (adFormat == MAAdFormat.leader) {
        return CGSizeMake(728, 90);
    }
    return CGSizeZero;
}

- (void)dealloc {
    MATInterstitialAd *interstitial = nil;
    MATRewardedVideoAd *rewardedVideo = nil;
    MATBannerAd *ad = nil;
    MATNativeAd *nativeAd = nil;
    NSString *placementId = nil;
    NSInteger destroyAdType = 0;
    @synchronized (self) {
        destroyAdType = _lastLoadedMaticooAdType;
        placementId = _placementId;
        interstitial = _interstitial;
        _interstitial = nil;
        _interstitialAdapterDelegate = nil;
        rewardedVideo = _rewardedVideo;
        _rewardedVideo = nil;
        _rewardedAdapterDelegate = nil;
        ad = _bannerAdView;
        _bannerAdView = nil;
        _adViewAdapterDelegate = nil;
        nativeAd = _nativeAdInstance;
        _nativeAdInstance = nil;
        _nativeAdapterDelegate = nil;
        _placementId = nil;
    }
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_destroy" des:MATAdTypeDes(placementId, destroyAdType, nil)];

    interstitial.delegate = nil;
    rewardedVideo.delegate = nil;
    ad.delegate = nil;
    nativeAd.delegate = nil;
    if (ad) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [ad destroy];
        });
    }
    if (nativeAd) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [nativeAd destroy];
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

@implementation ALMaticooMediationAdapterNativeAdDelegate

- (instancetype)initWithParentAdapter:(MaticooMediationAdapter *)parentAdapter andNotify:(id<MANativeAdAdapterDelegate>)delegate {
    self = [super init];
    if (self) {
        self.parentAdapter = parentAdapter;
        self.delegate = delegate;
    }
    return self;
}

- (void)nativeAdLoadSuccess:(MATNativeAd *)nativeAd {
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_success"
                                                       des:MATAdTypeDes(self.placementId, kAdTypeNative, nil)];
    MATNativeAdElements *e = nativeAd.nativeElements;
    __block MATMediaView *mediaView = nil;
    ALMaticooMANativeAd *maNativeAd = [[ALMaticooMANativeAd alloc] initWithFormat:MAAdFormat.native builderBlock:^(MANativeAdBuilder * _Nonnull builder) {
        builder.title = e.headline;
        builder.advertiser = e.advertiser;
        builder.body = e.body;
        builder.callToAction = e.callToAction;
        if (e.icon.image) {
            builder.icon = [[MANativeAdImage alloc] initWithImage:e.icon.image];
        } else if (e.icon.imageURL) {
            builder.icon = [[MANativeAdImage alloc] initWithURL:e.icon.imageURL];
        }
        MATAdImage *mainImg = e.images.firstObject;
        if (mainImg.image) {
            builder.mainImage = [[MANativeAdImage alloc] initWithImage:mainImg.image];
        } else if (mainImg.imageURL) {
            builder.mainImage = [[MANativeAdImage alloc] initWithURL:mainImg.imageURL];
        }
        if (e.mediaContent.aspectRatio > 0) {
            builder.mediaContentAspectRatio = e.mediaContent.aspectRatio;
        }
        // 与 AdMob/TopOn 一致：有视频始终给 MATMediaView；图片 + use_image_self_render 时不建 mediaView，走 mainImage。
        if (e.mediaContent.hasVideoContent) {
            mediaView = [[MATMediaView alloc] init];
            mediaView.clipsToBounds = YES;
            builder.mediaView = mediaView;
        } else if (self.useImageSelfRender) {
            mediaView = nil;
            builder.mediaView = nil;
        } else {
            mediaView = [[MATMediaView alloc] init];
            mediaView.clipsToBounds = YES;
            builder.mediaView = mediaView;
        }

        MATAdChoicesView *adChoicesView = [[MATAdChoicesView alloc] init];
        [adChoicesView setNativeAd:nativeAd];
        builder.optionsView = adChoicesView;
    }];
    maNativeAd.maticooNativeAd = nativeAd;
    maNativeAd.maticooMediaView = mediaView;
    maNativeAd.placementId = self.placementId;
    [self.delegate didLoadAdForNativeAd:maNativeAd withExtraInfo:nil];
}

- (void)nativeAdFailed:(MATNativeAd *)nativeAd withError:(NSError *)error {
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed"
                                                       des:MATAdTypeDes(self.placementId, kAdTypeNative, error.localizedDescription)];
    [self.delegate didFailToLoadNativeAdWithError:[MaticooMediationAdapter toMaxLoadError:error]];
}

- (void)nativeAdDisplayed:(MATNativeAd *)nativeAd {
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_imp"
                                                       des:MATAdTypeDes(self.placementId, kAdTypeNative, nil)];
    [self.delegate didDisplayNativeAdWithExtraInfo:nil];
}

- (void)nativeAd:(MATNativeAd *)nativeAd displayFailWithError:(NSError *)error {
    (void)nativeAd;
    // MAX Native adapter delegate 无 didFailToDisplay*，只能上报 adapter 埋点。
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_show_failed"
                                                       des:MATAdTypeDes(self.placementId, kAdTypeNative, error.localizedDescription)];
}

- (void)nativeAdClicked:(MATNativeAd *)nativeAd {
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_click"
                                                       des:MATAdTypeDes(self.placementId, kAdTypeNative, nil)];
    if ([self.delegate respondsToSelector:@selector(didClickNativeAd)]) {
        [self.delegate didClickNativeAd];
    }
}

@end

