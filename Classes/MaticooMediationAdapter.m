//
//  MaticooMediationAdapter.m
//  AppLovin MAX Demo App - ObjC
//
//  Created by root on 2023/5/18.
//  Copyright © 2023 AppLovin Corporation. All rights reserved.
//

#import "MaticooMediationAdapter.h"
#import "MaticooMediationTrackManager.h"
#define ADAPTER_VERSION @"1.1.6"



#define MAT_NSSTRING_NOT_NULL(str)\
([(str) isKindOfClass:[NSString class]] && ![(str) isEqualToString:@""])

@interface ALMaticooMediationAdapterInterstitialAdDelegate : NSObject <MATInterstitialAdDelegate>
@property (nonatomic,   weak) MaticooMediationAdapter *parentAdapter;
@property (nonatomic, strong) id<MAInterstitialAdapterDelegate> delegate;
- (instancetype)initWithParentAdapter:(MaticooMediationAdapter *)parentAdapter andNotify:(id<MAInterstitialAdapterDelegate>)delegate;
@end

@interface ALMaticooMediationAdapterRewardedVideoAdDelegate : NSObject <MATRewardedVideoAdDelegate>
@property (nonatomic,   weak) MaticooMediationAdapter *parentAdapter;
@property (nonatomic, strong) id<MARewardedAdapterDelegate> delegate;
- (instancetype)initWithParentAdapter:(MaticooMediationAdapter *)parentAdapter andNotify:(id<MARewardedAdapterDelegate>)delegate;
@end

@interface ALMaticooMediationAdapterAdViewDelegate : NSObject <MATBannerAdDelegate>
@property (nonatomic,   weak) MaticooMediationAdapter *parentAdapter;
@property (nonatomic, strong) id<MAAdViewAdapterDelegate> delegate;
- (instancetype)initWithParentAdapter:(MaticooMediationAdapter *)parentAdapter andNotify:(id<MAAdViewAdapterDelegate>)delegate;
@end

@interface ALMaticooMediationAdapterNativeAdViewAdDelegate : NSObject <MATNativeAdDelegate>
@property (nonatomic,   weak) MaticooMediationAdapter *parentAdapter;
@property (nonatomic, strong) id<MAAdViewAdapterDelegate> delegate;
- (instancetype)initWithParentAdapter:(MaticooMediationAdapter *)parentAdapter andNotify:(id<MAAdViewAdapterDelegate>)delegate;
@end

@interface ALMaticooMediationAdapterNativeAdDelegate : NSObject <MATNativeAdDelegate>
@property (nonatomic,   weak) MaticooMediationAdapter *parentAdapter;
@property (nonatomic, strong) id<MANativeAdAdapterDelegate> delegate;
- (instancetype)initWithParentAdapter:(MaticooMediationAdapter *)parentAdapter andNotify:(id<MANativeAdAdapterDelegate>)delegate;
@end

@interface MAMaticooNativeAd : MANativeAd
@property (nonatomic, weak) MaticooMediationAdapter *parentAdapter;
- (instancetype)initWithParentAdapter:(MaticooMediationAdapter *)parentAdapter builderBlock:(NS_NOESCAPE MANativeAdBuilderBlock)builderBlock;
- (instancetype):(MAAdFormat *)format builderBlock:(NS_NOESCAPE MANativeAdBuilderBlock)builderBlock NS_UNAVAILABLE;
@end

@interface MaticooMediationAdapter ()
@property (nonatomic, strong) MATBannerAd *bannerAdView;
@property (nonatomic, strong) MATInterstitialAd *interstitial;
@property (nonatomic, strong) MATNativeAd *nativeAd;
@property (nonatomic, strong) MATRewardedVideoAd *rewardedVideoAd;

@property (nonatomic, strong) ALMaticooMediationAdapterInterstitialAdDelegate *interstitialAdapterDelegate;
@property (nonatomic, strong) ALMaticooMediationAdapterRewardedVideoAdDelegate *rewardedAdapterDelegate;
@property (nonatomic, strong) ALMaticooMediationAdapterAdViewDelegate *adViewAdapterDelegate;
@property (nonatomic, strong) ALMaticooMediationAdapterNativeAdViewAdDelegate *nativeAdViewAdAdapterDelegate;
@property (nonatomic, strong) ALMaticooMediationAdapterNativeAdDelegate *nativeAdAdapterDelegate;


@end


@implementation MaticooMediationAdapter 

#pragma mark - MAAdapter Methods

- (void)initializeWithParameters:(id<MAAdapterInitializationParameters>)parameters completionHandler:(void (^)(MAAdapterInitializationStatus, NSString *_Nullable))completionHandler
{
    NSString *appKey = [parameters.serverParameters al_stringForKey: @"app_id"];
    NSLog(@"Initializing Maticoo SDK with app key: %@...", appKey);
    // Override point for customization after application launch.
    completionHandler(MAAdapterInitializationStatusDoesNotApply, nil);
    [[MaticooAds shareSDK] setMediationName:@"max"];
    [[MaticooAds shareSDK] initSDK:appKey onSuccess:^() {
        completionHandler(MAAdapterInitializationStatusInitializedSuccess, nil);
        [MaticooMediationTrackManager trackMediationInitSuccess];
    } onError:^(NSError* error) {
        completionHandler(MAAdapterInitializationStatusInitializedFailure, error.description);
        [MaticooMediationTrackManager trackMediationInitFailed:error];
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
    if(isLoad){
        adapterError = MAAdapterError.noFill;
    }else{
        adapterError = MAAdapterError.adDisplayFailedError;
    }
    
    switch ( maticooErrorCode )
    {
        case 1000: // Network Error
            adapterError = MAAdapterError.noConnection;
            break;
        case 1001: // No Fill
        case 106:
            adapterError = MAAdapterError.noFill;
            break;
//        case 106:
//            adapterError = MAAdapterError.invalidLoadState;
//            break;
        case 104:
            adapterError = MAAdapterError.invalidConfiguration;
            break;
        case 107:
            adapterError = MAAdapterError.adDisplayFailedError;
            break;
    }
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [MAAdapterError errorWithCode: adapterError.errorCode
                             errorString: adapterError.errorMessage
                  thirdPartySdkErrorCode: maticooErrorCode
               thirdPartySdkErrorMessage: maticooError.localizedDescription];
#pragma clang diagnostic pop
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
        NSError *error = [[NSError alloc]initWithDomain:@"The placementIdentifier of the interstitial ad is empty." code:106 userInfo:nil];
        [MaticooMediationTrackManager trackMediationAdRequestFailed:placementIdentifier adType:INTERSTITIAL msg:error.description];
        MAAdapterError *adapterError = [MaticooMediationAdapter toMaxLoadError: error];
        [delegate didFailToLoadInterstitialAdWithError: adapterError];
        return;
    }
    
    NSLog(@"Loading interstitial ad: %@...", placementIdentifier);
    [MaticooMediationTrackManager trackMediationAdRequest:placementIdentifier adType:INTERSTITIAL isAutoRefresh:NO];
    
    self.interstitial = [[MATInterstitialAd alloc] initWithPlacementID:placementIdentifier];
    self.interstitialAdapterDelegate = [[ALMaticooMediationAdapterInterstitialAdDelegate alloc] initWithParentAdapter: self andNotify: delegate];
    if(parameters.localExtraParameters){
        self.interstitial.localExtra = [self ensureParams:parameters.localExtraParameters];
    }
    self.interstitial.delegate = self.interstitialAdapterDelegate;
    [self.interstitial loadAd];    
}

- (void)showInterstitialAdForParameters:(id<MAAdapterResponseParameters>)parameters andNotify:(id<MAInterstitialAdapterDelegate>)delegate
{
    [self log: @"Showing interstitial: %@...", parameters.thirdPartyAdPlacementIdentifier];
    [MaticooMediationTrackManager trackMediationAdShow:parameters.thirdPartyAdPlacementIdentifier adType:INTERSTITIAL];
    // Check if ad is already expired or invalidated, and do not show ad if that is the case. You will not get paid to show an invalidated ad.
    if (self.interstitial.isReady){
        
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
        [self log: @"Unable to show interstitial ad: ad is not valid - marking as expired"];
        [delegate didFailToDisplayInterstitialAdWithError: MAAdapterError.adExpiredError];
    }
}

#pragma mark - MARewardedAdapter Methods

- (void)loadRewardedAdForParameters:(id<MAAdapterResponseParameters>)parameters andNotify:(id<MARewardedAdapterDelegate>)delegate
{
    NSString *placementIdentifier = parameters.thirdPartyAdPlacementIdentifier;
    if(!MAT_NSSTRING_NOT_NULL(placementIdentifier)) {
        NSError *error = [[NSError alloc]initWithDomain:@"The placementIdentifier of the RewardedVideo ad is empty." code:106 userInfo:nil];
        [MaticooMediationTrackManager trackMediationAdRequestFailed:placementIdentifier adType:REWARDEDVIDEO msg:error.description];
        MAAdapterError *adapterError = [MaticooMediationAdapter toMaxLoadError: error];
        [delegate didFailToLoadRewardedAdWithError: adapterError];
        return;
    }
    [self log: @"Loading rewarded ad: %@...", placementIdentifier];
    [MaticooMediationTrackManager trackMediationAdRequest:placementIdentifier adType:REWARDEDVIDEO isAutoRefresh:NO];
    
    self.rewardedVideoAd = [[MATRewardedVideoAd alloc] initWithPlacementID: placementIdentifier];
    self.rewardedAdapterDelegate = [[ALMaticooMediationAdapterRewardedVideoAdDelegate alloc] initWithParentAdapter: self andNotify: delegate];
    self.rewardedVideoAd.delegate = self.rewardedAdapterDelegate;
    
    if ( [self.rewardedVideoAd isReady] )
    {
        [self log: @"A rewarded ad has been loaded already"];
        [delegate didLoadRewardedAd];
    }
    else
    {
        if(parameters.localExtraParameters){
            self.rewardedVideoAd.localExtra = [self ensureParams:parameters.localExtraParameters];
        }
        [self log: @"Loading bidding rewarded ad..."];
        [self.rewardedVideoAd loadAd];
    }
}

- (void)showRewardedAdForParameters:(id<MAAdapterResponseParameters>)parameters andNotify:(id<MARewardedAdapterDelegate>)delegate
{
    [self log: @"Showing rewarded ad: %@...", parameters.thirdPartyAdPlacementIdentifier];
    [MaticooMediationTrackManager trackMediationAdShow:parameters.thirdPartyAdPlacementIdentifier adType:REWARDEDVIDEO];
    // Check if ad is already expired or invalidated, and do not show ad if that is the case. You will not get paid to show an invalidated ad.
    if ( [self.rewardedVideoAd isReady] )
    {
        UIViewController *presentingViewController;
        if ( ALSdk.versionCode >= 11020199 )
        {
            presentingViewController = parameters.presentingViewController ?: [ALUtils topViewControllerFromKeyWindow];
        }
        else
        {
            presentingViewController = [ALUtils topViewControllerFromKeyWindow];
        }
        
        [self.rewardedVideoAd showAdFromViewController:presentingViewController];
    }
    else
    {
        [self log: @"Unable to show rewarded ad: ad is not valid - marking as expired"];
        [delegate didFailToDisplayRewardedAdWithError: MAAdapterError.adExpiredError];
    }
}

- (void)loadAdViewAdForParameters:(id<MAAdapterResponseParameters>)parameters
                         adFormat:(MAAdFormat *)adFormat
                        andNotify:(id<MAAdViewAdapterDelegate>)delegate
{
    BOOL isNative = [parameters.customParameters al_boolForKey: @"is_native"];
    NSString *domain = nil;
    NSInteger adType = 0;
    if(isNative){
        domain = @"The placementIdentifier of the native ad is empty.";
        adType = NATIVE;
    }else {
        domain = @"The placementIdentifier of the banner ad is empty.";
        adType = BANNER;
    }
    
    NSString *placementIdentifier = parameters.thirdPartyAdPlacementIdentifier;
    if(!MAT_NSSTRING_NOT_NULL(placementIdentifier)) {
        NSError *error = [[NSError alloc]initWithDomain:domain code:106 userInfo:nil];
        [MaticooMediationTrackManager trackMediationAdRequestFailed:placementIdentifier adType:adType msg:error.description];
        MAAdapterError *adapterError = [MaticooMediationAdapter toMaxLoadError: error];
        [delegate didFailToLoadAdViewAdWithError: adapterError];
        return;
    }
    
    [self log: @"Loading%@%@ ad: %@...", isNative ? @" native " : @" ", adFormat.label, placementIdentifier];
    
    if ( isNative )
    {
        [MaticooMediationTrackManager trackMediationAdRequest:placementIdentifier adType:NATIVE isAutoRefresh:NO];
        self.nativeAd = [[MATNativeAd alloc] initWithPlacementID: placementIdentifier];
        self.nativeAdViewAdAdapterDelegate = [[ALMaticooMediationAdapterNativeAdViewAdDelegate alloc] initWithParentAdapter: self andNotify: delegate];
        self.nativeAd.delegate = self.nativeAdViewAdAdapterDelegate;
        [self log: @"Loading bidding native %@ ad...", adFormat.label];
        if(parameters.localExtraParameters){
            self.nativeAd.localExtra = [self ensureParams:parameters.localExtraParameters];
        }
        [self.nativeAd loadAd];
    }
    else
    {
        [MaticooMediationTrackManager trackMediationAdRequest:placementIdentifier adType:BANNER isAutoRefresh:NO];
        CGSize adSize = [self adSizeFromAdFormat: adFormat];
        self.bannerAdView = [[MATBannerAd alloc] initWithPlacementID:placementIdentifier];
        self.bannerAdView.frame = CGRectMake(0, 0, adSize.width, adSize.height);
        self.adViewAdapterDelegate = [[ALMaticooMediationAdapterAdViewDelegate alloc] initWithParentAdapter: self andNotify: delegate];
        self.bannerAdView.delegate = self.adViewAdapterDelegate;
        if(parameters.localExtraParameters){
            self.bannerAdView.localExtra = [self ensureParams:parameters.localExtraParameters];
        }
        [self.bannerAdView loadAd];
    }
}

#pragma mark - MANativeAdAdapter Methods

- (void)loadNativeAdForParameters:(id<MAAdapterResponseParameters>)parameters andNotify:(id<MANativeAdAdapterDelegate>)delegate
{
    NSDictionary<NSString *, id> *serverParameters = parameters.serverParameters;
    BOOL isNativeBanner = [serverParameters al_boolForKey: @"is_native_banner"];
    NSString *placementIdentifier = parameters.thirdPartyAdPlacementIdentifier;
    if(!MAT_NSSTRING_NOT_NULL(placementIdentifier)) {
        NSError *error = [[NSError alloc]initWithDomain:@"The placementIdentifier of the native ad is empty." code:106 userInfo:nil];
        [MaticooMediationTrackManager trackMediationAdRequestFailed:placementIdentifier adType:NATIVE msg:error.description];
        MAAdapterError *adapterError = [MaticooMediationAdapter toMaxLoadError: error];
        [delegate didFailToLoadNativeAdWithError: adapterError];
        return;
    }
    [self log: @"Loading native %@ad: %@...", isNativeBanner ? @"banner " : @"" , placementIdentifier];
    [MaticooMediationTrackManager trackMediationAdRequest:placementIdentifier adType:NATIVE isAutoRefresh:NO];
    dispatchOnMainQueue(^{
        self.nativeAd = [[MATNativeAd alloc] initWithPlacementID: placementIdentifier];
        self.nativeAdAdapterDelegate = [[ALMaticooMediationAdapterNativeAdDelegate alloc] initWithParentAdapter: self andNotify: delegate];
        self.nativeAd.delegate = self.nativeAdAdapterDelegate;
        
        if(parameters.localExtraParameters){
            self.nativeAd.localExtra = [self ensureParams:parameters.localExtraParameters];
        }
        [self.nativeAd loadAd];
    });
}

- (void)renderTrueNativeAd:(MATNativeAd *)nativeAd
                 andNotify:(id<MANativeAdAdapterDelegate>)delegate
{
    if ( !nativeAd )
    {
        [self log: @"Native ad failed to load: no fill"];
        [delegate didFailToLoadNativeAdWithError: MAAdapterError.noFill];
        
        return;
    }
    
    dispatchOnMainQueue(^{
        
        MANativeAd *maxNativeAd = [[MAMaticooNativeAd alloc] initWithParentAdapter: self builderBlock:^(MANativeAdBuilder *builder) {
            builder.title = nativeAd.nativeElements.title;
            builder.body = nativeAd.nativeElements.describe;
            builder.callToAction = nativeAd.nativeElements.ctatext;
            builder.icon = [[MANativeAdImage alloc] initWithURL: [NSURL URLWithString:nativeAd.nativeElements.iconUrl]];
            builder.mediaView = nativeAd.nativeElements.mediaView;
            CGFloat mediaContentAspectRatio = 1.64;//nativeAd.nativeElements.aspectRatio;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
            // Introduced in 11.4.0
            if ( [builder respondsToSelector: @selector(setMediaContentAspectRatio:)] )
            {
                [builder performSelector: @selector(setMediaContentAspectRatio:) withObject: @(mediaContentAspectRatio)];
            }
#pragma clang diagnostic pop
        }];
        
        [delegate didLoadAdForNativeAd: maxNativeAd withExtraInfo: nil];
    });
}

-(CGSize) adSizeFromAdFormat:(MAAdFormat*) adFormat{
    if ( adFormat == MAAdFormat.banner )
        {
            return CGSizeMake(320, 50);
        }
        else if ( adFormat == MAAdFormat.mrec )
        {
            return CGSizeMake(300, 250); 
        }
        else
        {
            [NSException raise: NSInvalidArgumentException format: @"Unsupported ad format: %@", adFormat];
            return CGSizeMake(0, 0);
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
    NSLog(@"interstitialAd interstitialAdDidLoad");
    [MaticooMediationTrackManager trackMediationAdRequestFilled:interstitialAd.placementID adType:INTERSTITIAL];
    [self.delegate didLoadInterstitialAd];
    return;
}

- (void)interstitialAd:(MATInterstitialAd *)interstitialAd didFailWithError:(NSError *)error{
    NSLog(@"interstitialAd didFailWithError, %@, %@", interstitialAd.placementID, error.description);
    [MaticooMediationTrackManager trackMediationAdRequestFailed:interstitialAd.placementID adType:INTERSTITIAL msg:error.description];
    MAAdapterError *adapterError = [MaticooMediationAdapter toMaxLoadError: error];
    [self.delegate didFailToLoadInterstitialAdWithError: adapterError];
}

- (void)interstitialAd:(MATInterstitialAd *)interstitialAd displayFailWithError:(NSError *)error{
    NSLog(@"interstitialAd displayFailWithError, %@", error.description);
    [MaticooMediationTrackManager trackMediationAdImpFailed:interstitialAd.placementID adType:INTERSTITIAL msg:error.description];
    MAAdapterError *adapterError = [MaticooMediationAdapter toMaxShowError: error];
    [self.delegate didFailToDisplayInterstitialAdWithError:adapterError];
}

- (void)interstitialAdWillLogImpression:(MATInterstitialAd *)interstitialAd{
    NSLog(@"interstitialAdWillLogImpression");
    [MaticooMediationTrackManager trackMediationAdImp:interstitialAd.placementID adType:INTERSTITIAL];
    [self.delegate didDisplayInterstitialAd];
}

- (void)interstitialAdDidClick:(MATInterstitialAd *)interstitialAd{
    NSLog(@"interstitialAdDidClick");
    [MaticooMediationTrackManager trackMediationAdClick:interstitialAd.placementID adType:INTERSTITIAL];
    [self.delegate didClickInterstitialAd];
}

- (void)interstitialAdWillClose:(MATInterstitialAd *)interstitialAd{
    NSLog(@"interstitialAdWillClose");
}

- (void)interstitialAdDidClose:(MATInterstitialAd *)interstitialAd{
    NSLog(@"interstitialAdDidClose");
    [self.delegate didHideInterstitialAd];
}

@end


@implementation ALMaticooMediationAdapterRewardedVideoAdDelegate

- (instancetype)initWithParentAdapter:(MaticooMediationAdapter *)parentAdapter andNotify:(id<MARewardedAdapterDelegate>)delegate
{
    self = [super init];
    if ( self )
    {
        self.parentAdapter = parentAdapter;
        self.delegate = delegate;
    }
    return self;
}

//rewarded video delegate
- (void)rewardedVideoAdDidLoad:(MATRewardedVideoAd *)rewardedVideoAd{
    [MaticooMediationTrackManager trackMediationAdRequestFilled:rewardedVideoAd.placementID adType:REWARDEDVIDEO];
    [self.parentAdapter log: @"Rewarded ad loaded: %@", rewardedVideoAd.placementID];
    [self.delegate didLoadRewardedAd];
}

- (void)rewardedVideoAd:(MATRewardedVideoAd *)rewardedVideoAd didFailWithError:(NSError *)error{
    MAAdapterError *adapterError = [MaticooMediationAdapter toMaxLoadError: error];
    [self.parentAdapter log: @"Rewarded ad (%@) failed to load with error: %@", rewardedVideoAd.placementID, adapterError];
    [self.delegate didFailToLoadRewardedAdWithError: adapterError];
    [MaticooMediationTrackManager trackMediationAdRequestFailed:rewardedVideoAd.placementID adType:REWARDEDVIDEO msg:error.description];
}

- (void)rewardedVideoAd:(MATRewardedVideoAd *)rewardedVideoAd displayFailWithError:(NSError *)error{
    [self.parentAdapter log: @"Rewarded video displayFailWithError: %@", rewardedVideoAd.placementID];
    MAAdapterError *adapterError = [MaticooMediationAdapter toMaxShowError: error];
    [self.delegate didFailToDisplayRewardedAdWithError: adapterError];
    [MaticooMediationTrackManager trackMediationAdImpFailed:rewardedVideoAd.placementID adType:REWARDEDVIDEO msg:error.description];
}

- (void)rewardedVideoAdStarted:(MATRewardedVideoAd *)rewardedVideoAd{
    [self.parentAdapter log: @"Rewarded video started: %@", rewardedVideoAd.placementID];
}

- (void)rewardedVideoAdCompleted:(MATRewardedVideoAd *)rewardedVideoAd{
    [self.parentAdapter log: @"Rewarded video completed: %@", rewardedVideoAd.placementID];
}

- (void)rewardedVideoAdWillLogImpression:(MATRewardedVideoAd *)rewardedVideoAd{
    [MaticooMediationTrackManager trackMediationAdImp:rewardedVideoAd.placementID adType:REWARDEDVIDEO];
    [self.parentAdapter log: @"Rewarded video impression: %@", rewardedVideoAd.placementID];
    [self.delegate didDisplayRewardedAd];
    
}

- (void)rewardedVideoAdDidClick:(MATRewardedVideoAd *)rewardedVideoAd{
    [MaticooMediationTrackManager trackMediationAdClick:rewardedVideoAd.placementID adType:REWARDEDVIDEO];
    [self.parentAdapter log: @"Rewarded ad clicked: %@", rewardedVideoAd.placementID];
    [self.delegate didClickRewardedAd];
}

- (void)rewardedVideoAdDidClose:(MATRewardedVideoAd *)rewardedVideoAd{
    [self.parentAdapter log: @"Rewarded ad hidden: %@", rewardedVideoAd.placementID];
    [self.delegate didHideRewardedAd];
}

- (void)rewardedVideoAdReward:(MATRewardedVideoAd *)rewardedVideoAd{
    MAReward *reward = [self.parentAdapter reward];
    [self.parentAdapter log: @"Rewarded user with reward: %@", reward];
    [self.delegate didRewardUserWithReward: reward];
}

- (void)rewardedVideoAdWillClose:(nonnull MATRewardedVideoAd *)rewardedVideoAd {
    
}

@end

@implementation ALMaticooMediationAdapterAdViewDelegate

- (instancetype)initWithParentAdapter:(MaticooMediationAdapter *)parentAdapter andNotify:(id<MAAdViewAdapterDelegate>)delegate
{
    self = [super init];
    if ( self )
    {
        self.parentAdapter = parentAdapter;
        self.delegate = delegate;
    }
    return self;
}

- (void)bannerAdDidLoad:(nonnull MATBannerAd *)bannerAd {
    [MaticooMediationTrackManager trackMediationAdRequestFilled:bannerAd.placementID adType:BANNER];
    [self.parentAdapter log: @"Banner loaded: %@", bannerAd.placementID];
    [self.delegate didLoadAdForAdView: bannerAd];
}

- (void)bannerAd:(nonnull MATBannerAd *)bannerAd didFailWithError:(nonnull NSError *)error {
    [MaticooMediationTrackManager trackMediationAdRequestFailed:bannerAd.placementID adType:BANNER msg:error.description];
    MAAdapterError *adapterError = [MaticooMediationAdapter toMaxLoadError: error];
    [self.parentAdapter log: @"Banner (%@) failed to load with error: %@", bannerAd.placementID, adapterError];
    [self.delegate didFailToLoadAdViewAdWithError: adapterError];
}

- (void)bannerAdDidClick:(nonnull MATBannerAd *)bannerAd {
    [MaticooMediationTrackManager trackMediationAdClick:bannerAd.placementID adType:BANNER];
    [self.parentAdapter log: @"Banner clicked: %@", bannerAd.placementID];
    [self.delegate didClickAdViewAd];
}

- (void)bannerAdDidImpression:(nonnull MATBannerAd *)bannerAd {
    [MaticooMediationTrackManager trackMediationAdImp:bannerAd.placementID adType:BANNER];
    [self.parentAdapter log: @"Banner shown: %@", bannerAd.placementID];
    [self.delegate didDisplayAdViewAd];
}

- (void)bannerAd:(MATBannerAd *)bannerAd showFailWithError:(NSError *)error{
    [MaticooMediationTrackManager trackMediationAdImpFailed:bannerAd.placementID adType:BANNER msg:error.description];
    MAAdapterError *adapterError = [MaticooMediationAdapter toMaxShowError: error];
    [self.parentAdapter log: @"Banner show failed: %@ and error:%@", bannerAd.placementID, error.description];
    if ([self.delegate respondsToSelector:@selector(didFailToDisplayAdViewAdWithError:)]) {
        [self.delegate didFailToDisplayAdViewAdWithError:adapterError];
    }
}
@end

@implementation ALMaticooMediationAdapterNativeAdViewAdDelegate

- (instancetype)initWithParentAdapter:(MaticooMediationAdapter *)parentAdapter andNotify:(id<MAAdViewAdapterDelegate>)delegate{
    self = [super init];
    if ( self )
    {
        self.parentAdapter = parentAdapter;
        self.delegate = delegate;
    }
    return self;
}

- (void)nativeAdClicked:(nonnull MATNativeAd *)nativeAd {
    [MaticooMediationTrackManager trackMediationAdClick:nativeAd.placementID adType:NATIVE];
    [self.parentAdapter log: @"Native clicked: %@", nativeAd.placementID];
    [self.delegate didClickAdViewAd];
}

- (void)nativeAdClosed:(nonnull MATNativeAd *)nativeAd {
    
}

- (void)nativeAdDisplayFailed:(nonnull MATNativeAd *)nativeAd {
    [MaticooMediationTrackManager trackMediationAdImpFailed:nativeAd.placementID adType:NATIVE msg:@""];
}

- (void)nativeAdDisplayed:(nonnull MATNativeAd *)nativeAd {
    [MaticooMediationTrackManager trackMediationAdImp:nativeAd.placementID adType:NATIVE];
    [self.parentAdapter log: @"Native shown: %@", nativeAd.placementID];
    [self.delegate didDisplayAdViewAd];
}

- (void)nativeAdFailed:(nonnull MATNativeAd *)nativeAd withError:(nonnull NSError *)error {
    [MaticooMediationTrackManager trackMediationAdRequestFailed:nativeAd.placementID adType:NATIVE msg:@""];
    [self.parentAdapter log: @"Native (%@) failed to load with error: %@", nativeAd.placementID, error];
    MAAdapterError *adapterError = [MaticooMediationAdapter toMaxLoadError: error];
    [self.delegate didFailToLoadAdViewAdWithError: adapterError];
}

- (void)nativeAdLoadSuccess:(nonnull MATNativeAd *)nativeAd {
    [MaticooMediationTrackManager trackMediationAdRequestFilled:nativeAd.placementID adType:NATIVE];
    [self.parentAdapter log: @"Native ad loaded: %@", nativeAd.placementID];
    [self.parentAdapter renderTrueNativeAd: nativeAd
                                 andNotify: self.delegate];
}

@end

@implementation ALMaticooMediationAdapterNativeAdDelegate

- (instancetype)initWithParentAdapter:(MaticooMediationAdapter *)parentAdapter andNotify:(id<MANativeAdAdapterDelegate>)delegate{
    self = [super init];
    if ( self )
    {
        self.parentAdapter = parentAdapter;
        self.delegate = delegate;
    }
    return self;
}
- (void)nativeAdClicked:(nonnull MATNativeAd *)nativeAd {
    [MaticooMediationTrackManager trackMediationAdClick:nativeAd.placementID adType:NATIVE];
    [self.parentAdapter log: @"Native ad clicked: %@", nativeAd.placementID];
    [self.delegate didClickNativeAd];
}

- (void)nativeAdClosed:(nonnull MATNativeAd *)nativeAd {
    
}

- (void)nativeAdDisplayFailed:(nonnull MATNativeAd *)nativeAd {
    [MaticooMediationTrackManager trackMediationAdImpFailed:nativeAd.placementID adType:NATIVE msg:@""];
}

- (void)nativeAdDisplayed:(nonnull MATNativeAd *)nativeAd {
    [MaticooMediationTrackManager trackMediationAdImp:nativeAd.placementID adType:NATIVE];
    [self.parentAdapter log: @"Native ad shown: %@", nativeAd.placementID];
    [self.delegate didDisplayNativeAdWithExtraInfo: nil];
}

- (void)nativeAdFailed:(nonnull MATNativeAd *)nativeAd withError:(nonnull NSError *)error {
    [MaticooMediationTrackManager trackMediationAdRequestFailed:nativeAd.placementID adType:NATIVE msg:error.description];
    MAAdapterError *adapterError = nil;
     [self.parentAdapter log: @"Native (%@) failed to load with error: %@",  nativeAd.placementID, adapterError];
     [self.delegate didFailToLoadNativeAdWithError: adapterError];
}

- (void)nativeAdLoadSuccess:(nonnull MATNativeAd *)nativeAd {
    [MaticooMediationTrackManager trackMediationAdRequestFilled:nativeAd.placementID adType:NATIVE];
    [self.parentAdapter log: @"Native ad loaded: %@", nativeAd.placementID];
    [self.parentAdapter renderTrueNativeAd: nativeAd
                                 andNotify: self.delegate];
}

@end

@implementation MAMaticooNativeAd

- (instancetype)initWithParentAdapter:(MaticooMediationAdapter *)parentAdapter builderBlock:(NS_NOESCAPE MANativeAdBuilderBlock)builderBlock
{
    self = [super initWithFormat: MAAdFormat.native builderBlock: builderBlock];
    if ( self )
    {
        self.parentAdapter = parentAdapter;
    }
    return self;
}

- (void)prepareViewForInteraction:(MANativeAdView *)maxNativeAdView
{
    MATNativeAd *nativeAd = self.parentAdapter.nativeAd;
    [nativeAd registerViewForInteraction:maxNativeAdView iConView:maxNativeAdView.iconImageView CTAView:maxNativeAdView.callToActionButton];
    
}

@end
