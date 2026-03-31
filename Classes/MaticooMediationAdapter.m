//
//  MaticooMediationAdapter.m
//  AppLovin MAX Demo App - ObjC
//
//  Created by root on 2023/5/18.
//  Copyright © 2023 AppLovin Corporation. All rights reserved.
//

#import "MaticooMediationAdapter.h"
#define ADAPTER_VERSION @"2.0.0"

#define MAT_NSSTRING_NOT_NULL(str)\
([(str) isKindOfClass:[NSString class]] && ![(str) isEqualToString:@""])

static NSString * const kAdapterSource = @"max";
static const NSInteger kAdTypeInterstitial = 2;

static NSString *MATAdTypeDes(NSString *placementId, NSString * _Nullable errorMsg) {
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    dic[@"placementId"] = placementId ?: @"";
    dic[@"adType"] = @(kAdTypeInterstitial);
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

@interface MaticooMediationAdapter ()

@property (nonatomic, strong) MATInterstitialAd *interstitial;
@property (nonatomic, strong) ALMaticooMediationAdapterInterstitialAdDelegate *interstitialAdapterDelegate;
@property (nonatomic, copy) NSString *placementId;

@end


@implementation MaticooMediationAdapter

/// MAX `doNotSell`
+ (void)applyMaxDoNotSellIfPresent {
    if ([ALPrivacySettings isDoNotSellSet]) {
        [[MaticooAds shareSDK] setDoNotTrackStatus:[ALPrivacySettings isDoNotSell]];
    }
}

#pragma mark - MAAdapter Methods

- (instancetype)init {
    self = [super init];
    if (self) {
        
    }
    return self;
}

- (void)initializeWithParameters:(id<MAAdapterInitializationParameters>)parameters completionHandler:(void (^)(MAAdapterInitializationStatus, NSString *_Nullable))completionHandler
{
    NSString *appKey = [parameters.serverParameters al_stringForKey: @"app_id"];
    NSLog(@"Initializing Maticoo SDK with app key: %@...", appKey);
    // Override point for customization after application launch.
    [MaticooMediationAdapter applyMaxDoNotSellIfPresent];
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
        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed" des:MATAdTypeDes(placementIdentifier, @"placementIdentifier is empty")];
        NSError *error = [[NSError alloc]initWithDomain:@"The placementIdentifier of the interstitial ad is empty." code:106 userInfo:nil];
        MAAdapterError *adapterError = [MaticooMediationAdapter toMaxLoadError: error];
        [delegate didFailToLoadInterstitialAdWithError: adapterError];
        return;
    }
    self.placementId = placementIdentifier;

    [MaticooMediationAdapter applyMaxDoNotSellIfPresent];

    NSLog(@"Loading interstitial ad: %@...", placementIdentifier);
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load" des:MATAdTypeDes(placementIdentifier, nil)];
    
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
        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_show" des:MATAdTypeDes(parameters.thirdPartyAdPlacementIdentifier, nil)];
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
        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_show_failed" des:MATAdTypeDes(parameters.thirdPartyAdPlacementIdentifier, @"ad is not valid - expired")];
        [self log: @"Unable to show interstitial ad: ad is not valid - marking as expired"];
        [delegate didFailToDisplayInterstitialAdWithError: MAAdapterError.adExpiredError];
    }
}

- (void)dealloc {
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_destroy" des:MATAdTypeDes(self.placementId, nil)];
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
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_success" des:MATAdTypeDes(self.placementId, nil)];
    [self.delegate didLoadInterstitialAd];
}

- (void)interstitialAd:(MATInterstitialAd *)interstitialAd didFailWithError:(NSError *)error{
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed" des:MATAdTypeDes(self.placementId, error.localizedDescription)];
    MAAdapterError *adapterError = [MaticooMediationAdapter toMaxLoadError: error];
    [self.delegate didFailToLoadInterstitialAdWithError: adapterError];
}

- (void)interstitialAd:(MATInterstitialAd *)interstitialAd displayFailWithError:(NSError *)error{
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_show_failed" des:MATAdTypeDes(self.placementId, error.localizedDescription)];
    MAAdapterError *adapterError = [MaticooMediationAdapter toMaxShowError: error];
    [self.delegate didFailToDisplayInterstitialAdWithError:adapterError];
}

- (void)interstitialAdWillLogImpression:(MATInterstitialAd *)interstitialAd{
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_imp" des:MATAdTypeDes(self.placementId, nil)];
    [self.delegate didDisplayInterstitialAd];
}

- (void)interstitialAdDidClick:(MATInterstitialAd *)interstitialAd{
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_click" des:MATAdTypeDes(self.placementId, nil)];
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

