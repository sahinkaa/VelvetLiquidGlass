#import "TestBanner.h"
#import "Runtime.h"
#import <CoreFoundation/CoreFoundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#include <math.h>

BOOL VLGValidTestIdentifier(id identifier) {
    if(![identifier isKindOfClass:NSString.class] || [identifier length]<3 || [identifier length]>255 || ![identifier containsString:@"."])return NO;
    static NSCharacterSet *invalid;static dispatch_once_t once;
    dispatch_once(&once,^{invalid=[[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-_"] invertedSet];});
    return [identifier rangeOfCharacterFromSet:invalid].location==NSNotFound;
}
NSDictionary *VLGValidateTestCommand(id command,NSDate *now) {
    if(![command isKindOfClass:NSDictionary.class] || [command count]>8 || ![now isKindOfClass:NSDate.class])return nil;
    if(![command[@"schema"] isEqual:@1] || ![command[@"date"] isKindOfClass:NSDate.class])return nil;
    double age=[now timeIntervalSinceDate:command[@"date"]];if(!isfinite(age) || age < -2 || age>15)return nil;
    for(NSString *key in @[@"session",@"nonce"])if(![command[key] isKindOfClass:NSString.class] || ![[NSUUID alloc] initWithUUIDString:command[key]])return nil;
    if(![@[@"show",@"cancel"] containsObject:command[@"action"]])return nil;
    if([command[@"action"] isEqual:@"show"] && !VLGValidTestIdentifier(command[@"identifier"]))return nil;
    return command;
}
BOOL VLGTestObjectMethod(id receiver,NSString *name,const char *result,unsigned arguments) {
    if(!receiver)return NO;
    Method method=class_getInstanceMethod(object_getClass(receiver),NSSelectorFromString(name));
    if(!method || method_getNumberOfArguments(method)!=arguments+2)return NO;
    char type[128]={0};method_getReturnType(method,type,sizeof(type));
    if(strcmp(type,result))return NO;
    for(unsigned i=2;i<arguments+2;++i) {
        method_getArgumentType(method,i,type,sizeof(type));
        if(strcmp(type,"@") && strncmp(type,"@\"",2))return NO; // Never accept blocks/structs as objects.
    }
    return YES;
}
static BOOL VLGSet(id receiver,NSString *selector,id object) {
    if(!VLGTestObjectMethod(receiver,selector,"v",1))return NO;
    ((void(*)(id,SEL,id))objc_msgSend)(receiver,NSSelectorFromString(selector),object);return YES;
}
static BOOL VLGSetBool(id receiver,NSString *selector,BOOL value) {
    Method method=receiver ? class_getInstanceMethod(object_getClass(receiver),NSSelectorFromString(selector)) : NULL;
    if(!method || method_getNumberOfArguments(method)!=3)return NO;
    char result[16]={0},arg[16]={0};method_getReturnType(method,result,sizeof(result));method_getArgumentType(method,2,arg,sizeof(arg));
    if(strcmp(result,"v") || (strcmp(arg,"B") && strcmp(arg,"c")))return NO;
    ((void(*)(id,SEL,BOOL))objc_msgSend)(receiver,NSSelectorFromString(selector),value);return YES;
}
static id VLGGet(id receiver,NSString *selector) {
    return VLGTestObjectMethod(receiver,selector,"@",0) ? ((id(*)(id,SEL))objc_msgSend)(receiver,NSSelectorFromString(selector)) : nil;
}
static id VLGCopy(id receiver,BOOL mutable) {
    if(!VLGTestObjectMethod(receiver,mutable ? @"mutableCopy" : @"copy","@",0))return nil;
    // Real Objective-C copy-family sends let ARC honor the +1 ownership rule.
    return mutable ? [receiver mutableCopy] : [receiver copy];
}
static NSError *VLGError(NSString *text) {return [NSError errorWithDomain:@"com.sahinkaa.velvetliquidglass.test-banner" code:1 userInfo:@{NSLocalizedDescriptionKey:text}];}
id VLGMakeTestNotification(Class requestClass,Class optionsClass,NSString *identifier,NSString *notificationID,NSString *destination,NSString *title,id icon,NSError **error) {
    NSString *factory=@"notificationRequestWithSectionId:notificationId:threadId:title:message:timestamp:destination:";
    if(!VLGValidTestIdentifier(identifier) || ![notificationID hasPrefix:@"com.sahinkaa.velvetliquidglass.test."] || !destination.length || !icon || !VLGTestObjectMethod(requestClass,factory,"@",7)) {
        if(error)*error=VLGError(@"This iOS version does not provide the required Test Banner interface.");return nil;
    }
    @try {
        id original=((id(*)(id,SEL,id,id,id,id,id,id,id))objc_msgSend)(requestClass,NSSelectorFromString(factory),identifier,notificationID,@"Velvet Test Banner",title ?: @"Velvet Test Banner",@"Velvet Test Banner. Adjust settings to see changes live.",[NSDate date],destination);
        id request=VLGCopy(original,YES);
        id options=VLGCopy(VLGGet(request,@"options"),YES);
        if(!options && [optionsClass isSubclassOfClass:NSObject.class]) options=[optionsClass new];
        id content=VLGCopy(VLGGet(request,@"content"),YES);
        BOOL valid=request && content && options;
        // This is Apple's request-specific sticky banner flag. No dismissal
        // hook, real app preference edit or real notification suppression.
        valid=VLGSetBool(options,@"setDismissAutomatically:",NO) && valid;
        valid=VLGSetBool(options,@"setCanPlaySound:",NO) && valid;
        valid=VLGSetBool(options,@"setPreventsAutomaticLock:",NO) && valid;
        valid=VLGSetBool(options,@"setSuppressesAlertsWhenAppIsActive:",NO) && valid;
        valid=VLGSet(content,@"setIcons:",@[icon]) && valid;
        valid=VLGSet(request,@"setOptions:",VLGCopy(options,NO)) && valid;
        valid=VLGSet(request,@"setContent:",VLGCopy(content,NO)) && valid;
        valid=VLGSet(request,@"setSound:",nil) && valid;
        for(NSString *name in @[@"setDefaultAction:",@"setCancelAction:",@"setClearAction:",@"setCloseAction:",@"setSilenceAction:",@"setInlineAction:"])valid=VLGSet(request,name,nil) && valid;
        // NCNotificationRequest actions are keyed by context. Apple's banner
        // destination indexes this dictionary with objectForKey:, even empty.
        // An NSArray has the same object ABI but aborts native presentation.
        valid=VLGSet(request,@"setSupplementaryActions:",@{}) && valid;
        id inheritedContext=VLGGet(request,@"context");
        NSMutableDictionary *context=[inheritedContext isKindOfClass:NSDictionary.class] ? [inheritedContext mutableCopy] : [NSMutableDictionary new];
        context[@"VelvetTestBanner"]=@YES;valid=VLGSet(request,@"setContext:",context) && valid;
        if(!VLGGet(request,@"uuid") && VLGTestObjectMethod(request,@"setUuid:","v",1))valid=VLGSet(request,@"setUuid:",NSUUID.UUID) && valid;
        if(valid)return VLGCopy(request,NO);
    } @catch(NSException *exception) {
        V26Report(@"testBanner.assemblyError",exception.name);
        V26Report(@"testBanner.assemblyFailure",@{@"name":exception.name ?: @"unknown",@"reason":[exception.reason substringToIndex:MIN((NSUInteger)512,exception.reason.length)] ?: @"unavailable"});
    }
    if(error)*error=VLGError(@"The Test Banner interface differs on this device. No test was posted.");return nil;
}
NSString *VLGTestCommandPath(void) {
#if defined(V26_HOST)
    return [NSProcessInfo.processInfo.environment[@"VLG_TEST_COMMAND_FOLDER"] stringByAppendingPathComponent:@"test-banner-command.plist"];
#else
#if defined(V26_ROOTHIDE)
    NSString *folder=V26RootPath(@"/var/mobile/Library/Caches/com.sahinkaa.velvetliquidglass");
#else
    NSString *folder=@"/var/mobile/Library/Caches/com.sahinkaa.velvetliquidglass";
#endif
    return [folder stringByAppendingPathComponent:@"test-banner-command.plist"];
#endif
}
static NSString *VLGPendingNonce;
static void VLGReplyReceived(CFNotificationCenterRef center,void *observer,CFStringRef name,const void *object,CFDictionaryRef info) {
    dispatch_async(dispatch_get_main_queue(),^{
        NSDictionary *reply=[NSDictionary dictionaryWithContentsOfFile:[VLGTestCommandPath().stringByDeletingLastPathComponent stringByAppendingPathComponent:@"test-banner-result.plist"]];
        if([reply[@"nonce"] isEqual:VLGPendingNonce] && [reply[@"message"] isKindOfClass:NSString.class]) {
            VLGPendingNonce=nil;
            [NSNotificationCenter.defaultCenter postNotificationName:@"VLGTestBannerResult" object:nil userInfo:@{@"message":reply[@"message"]}];
        }
    });
}
void VLGTestBannerReply(NSString *nonce,NSString *message) {
    if(![nonce isKindOfClass:NSString.class] || ![message isKindOfClass:NSString.class])return;
    NSString *path=[VLGTestCommandPath().stringByDeletingLastPathComponent stringByAppendingPathComponent:@"test-banner-result.plist"];
    [@{@"nonce":nonce,@"message":message,@"date":NSDate.date} writeToFile:path atomically:YES];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),CFSTR("com.sahinkaa.velvetliquidglass/test-banner-result"),NULL,NULL,YES);
}
static NSString *VLGSession(void) {static NSString *session;static dispatch_once_t once;dispatch_once(&once,^{session=NSUUID.UUID.UUIDString;});return session;}
static BOOL VLGCommand(NSString *action,NSString *identifier,NSError **error) {
    if([action isEqual:@"show"] && !VLGValidTestIdentifier(identifier)) {if(error)*error=VLGError(@"Select an installed application for the Test Banner.");return NO;}
    NSString *path=VLGTestCommandPath();if(!path.length)return NO;
    NSMutableDictionary *command=[@{@"schema":@1,@"action":action,@"date":NSDate.date,@"session":VLGSession(),@"nonce":NSUUID.UUID.UUIDString} mutableCopy];
    if(identifier)command[@"identifier"]=identifier;
    if([action isEqual:@"show"]) {
        static dispatch_once_t once;dispatch_once(&once,^{CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),NULL,VLGReplyReceived,CFSTR("com.sahinkaa.velvetliquidglass/test-banner-result"),NULL,CFNotificationSuspensionBehaviorCoalesce);});
        VLGPendingNonce=command[@"nonce"];
        NSString *nonce=VLGPendingNonce;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,3*NSEC_PER_SEC),dispatch_get_main_queue(),^{
            if([VLGPendingNonce isEqual:nonce]) {
                VLGPendingNonce=nil;
                [NSNotificationCenter.defaultCenter postNotificationName:@"VLGTestBannerResult" object:nil userInfo:@{@"message":@"The Test Banner service did not respond. Close Settings and respring once after installing this build, then try again."}];
            }
        });
    } else VLGPendingNonce=nil;
    NSFileManager *files=NSFileManager.defaultManager;
    if(![files createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:error])return NO;
    NSData *data=[NSPropertyListSerialization dataWithPropertyList:command format:NSPropertyListBinaryFormat_v1_0 options:0 error:error];
    if(!data || ![data writeToFile:path options:NSDataWritingAtomic error:error])return NO;
    V26Report(@"testBanner.commandPath",path);
    V26Event(@"testBannerCommand",@{@"action":action});
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),CFSTR("com.sahinkaa.velvetliquidglass/test-banner"),NULL,NULL,YES);
    return YES;
}
BOOL VLGRequestTestBanner(NSString *identifier,NSError **error) {return VLGCommand(@"show",identifier,error);}
void VLGCancelTestBanner(void) {VLGCommand(@"cancel",nil,NULL);}
