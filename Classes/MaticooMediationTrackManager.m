//
//  MATTrackManager.m
//  MaticooSDK
//
//  Created by root on 2023/5/4.
//

#import "MaticooMediationTrackManager.h"
#import <objc/runtime.h>
#import <objc/message.h>
//#import "MaticooMediationNetwork.h"

@implementation MaticooMediationTrackManager

+ (void)trackMediationInitSuccess{
    Class MATTrackManagerClass = NSClassFromString(@"MATTrackManager");
    SEL trackSelector = NSSelectorFromString(@"trackMediationInitSuccess");
    if ([MATTrackManagerClass respondsToSelector:trackSelector]) {
        ((void (*)(Class, SEL))objc_msgSend)(MATTrackManagerClass, trackSelector);
    }
}

+ (void)trackMediationInitFailed:(NSError*)error{
    Class MATTrackManagerClass = NSClassFromString(@"MATTrackManager");
    SEL trackSelector = NSSelectorFromString(@"trackMediationInitFailed:");
    if ([MATTrackManagerClass respondsToSelector:trackSelector]) {
        ((void (*)(Class, SEL, NSString*))objc_msgSend)(MATTrackManagerClass, trackSelector, error.description);
    }
}

+ (void)trackMediationAdRequest:(NSString*)pid adType:(NSInteger)adtype isAutoRefresh:(BOOL)isAuto{
    Class MATTrackManagerClass = NSClassFromString(@"MATTrackManager");
    SEL trackSelector = NSSelectorFromString(@"trackMediationAdRequest:adType:rid:isAutoRefresh:");
    if ([MATTrackManagerClass respondsToSelector:trackSelector]) {
        NSString *rid = @"";
        ((void (*)(Class, SEL, NSString*, NSInteger, NSString*, NSInteger))objc_msgSend)(MATTrackManagerClass, trackSelector, pid, adtype, rid, isAuto);
    }
}

+ (void)trackMediationAdRequestFilled:(NSString*)pid adType:(NSInteger)adtype{
    Class matTrackManagerClass = NSClassFromString(@"MATTrackManager");
    SEL selector = @selector(trackMediationAdRequestFilled:adType:);
    if ([matTrackManagerClass respondsToSelector:selector]) {
        ((void (*)(Class, SEL, NSString*, NSInteger))objc_msgSend)(matTrackManagerClass, selector, pid, adtype);
    }
}

+ (void)trackMediationAdRequestFailed:(NSString*)pid adType:(NSInteger)adtype msg:(NSString*)msg{
    Class matTrackManagerClass = NSClassFromString(@"MATTrackManager");
    SEL selector = @selector(trackMediationAdRequestFailed:adType:msg:);
    if ([matTrackManagerClass respondsToSelector:selector]) {
        ((void (*)(Class, SEL, NSString*, NSInteger, NSString*))objc_msgSend)(matTrackManagerClass, selector, pid, adtype, msg);
    }
}

+ (void)trackMediationAdShow:(NSString*)pid adType:(NSInteger)adtype{
    Class matTrackManagerClass = NSClassFromString(@"MATTrackManager");
    SEL selector = @selector(trackMediationAdShow:adType:);
    if ([matTrackManagerClass respondsToSelector:selector]) {
        ((void (*)(Class, SEL, NSString*, NSInteger))objc_msgSend)(matTrackManagerClass, selector, pid, adtype);
    }
}

+ (void)trackMediationAdImp:(NSString*)pid adType:(NSInteger)adtype{
    Class matTrackManagerClass = NSClassFromString(@"MATTrackManager");
    SEL selector = @selector(trackMediationAdImp:adType:);
    if ([matTrackManagerClass respondsToSelector:selector]) {
        ((void (*)(Class, SEL, NSString*, NSInteger))objc_msgSend)(matTrackManagerClass, selector, pid, adtype);
    }
}

+ (void)trackMediationAdImpFailed:(NSString*)pid adType:(NSInteger)adtype msg:(NSString*)msg{
    Class matTrackManagerClass = NSClassFromString(@"MATTrackManager");
    SEL selector = @selector(trackMediationAdImpFailed:adType:msg:);
    if ([matTrackManagerClass respondsToSelector:selector]) {
        ((void (*)(Class, SEL, NSString*, NSInteger, NSString*))objc_msgSend)(matTrackManagerClass, selector, pid, adtype, msg);
    }
}

+ (void)trackMediationAdClick:(NSString*)pid adType:(NSInteger)adtype{
    Class matTrackManagerClass = NSClassFromString(@"MATTrackManager");
    SEL selector = @selector(trackMediationAdClick:adType:);
    if ([matTrackManagerClass respondsToSelector:selector]) {
        ((void (*)(Class, SEL, NSString*, NSInteger))objc_msgSend)(matTrackManagerClass, selector, pid, adtype);
    }
}

@end
