#if defined(VLG_TEST_SERVICE_HOST)
#import "../tests/TestBannerUIKit.h"
#else
#import <UIKit/UIKit.h>
#endif
#import "TestBanner.h"
#import "Runtime.h"
#import <CoreFoundation/CoreFoundation.h>
#import <objc/message.h>
#import <objc/runtime.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>

static id VLGRequest;
static __weak id VLGDestination;
static NSString *VLGCurrentSession,*VLGLastNonce;
static NSUInteger VLGGeneration;
static NSDictionary *VLGExceptionFields(NSException *exception,NSString *stage) {
    NSString *reason=exception.reason ?: @"No exception reason was supplied";
    if(reason.length>512)reason=[reason substringToIndex:512];
    return @{@"stage":stage ?: @"unknown",@"name":exception.name ?: @"unknown",@"reason":reason};
}
static void VLGStage(NSString *stage) {
    V26Report([@"testBanner.reached." stringByAppendingString:stage],@YES);
    V26Event(@"testBannerStage",@{@"stage":stage});
}
static id VLGCall(id target,NSString *selector,id argument) {
    if(!VLGTestObjectMethod(target,selector,"@",1))return nil;
    return ((id(*)(id,SEL,id))objc_msgSend)(target,NSSelectorFromString(selector),argument);
}
static BOOL VLGSend(id target,NSString *selector,id argument) {
    if(!VLGTestObjectMethod(target,selector,"v",1))return NO;
    ((void(*)(id,SEL,id))objc_msgSend)(target,NSSelectorFromString(selector),argument);return YES;
}
static BOOL VLGIsOurs(id request) {
    return VLGRequest && [V26Object(request,@"notificationIdentifier") isEqual:V26Object(VLGRequest,@"notificationIdentifier")];
}
static void VLGWithdraw(void) {
    ++VLGGeneration;
    if(VLGRequest) {
        @try {VLGSend(VLGDestination,@"withdrawNotificationRequest:",VLGRequest);}
        @catch(NSException *e){V26Report(@"testBanner.withdrawError",e.name);}
    }
    VLGRequest=nil;VLGDestination=nil;VLGCurrentSession=nil;
}
static NSDictionary *VLGReadCommand(void) {
    // Bound reads and refuse symlinks. A stale command is never replayed on load.
    int fd=open(VLGTestCommandPath().fileSystemRepresentation,O_RDONLY|O_NOFOLLOW|O_CLOEXEC);
    if(fd<0)return nil;
    struct stat status;NSMutableData *data=nil;
    if(!fstat(fd,&status) && S_ISREG(status.st_mode) && status.st_size>0 && status.st_size<=8192) {
        data=[NSMutableData dataWithLength:(NSUInteger)status.st_size];
        if(read(fd,data.mutableBytes,data.length)!=(ssize_t)data.length)data=nil;
    }
    close(fd);if(!data)return nil;
    return VLGValidateTestCommand([NSPropertyListSerialization propertyListWithData:data options:0 format:NULL error:NULL],NSDate.date);
}
static UIImage *VLGThemedIcon(NSString *identifier) {
    // Fetch through the system icon API inside SpringBoard, where the installed
    // icon theme is applied. Never open an app's original on-disk icon asset.
    SEL selector=NSSelectorFromString(@"_applicationIconImageForBundleIdentifier:format:scale:");
    Method method=class_getClassMethod(UIImage.class,selector);
    if(!method || method_getNumberOfArguments(method)!=5)return nil;
    char type[128]={0};method_getReturnType(method,type,sizeof(type));if(strcmp(type,"@"))return nil;
    method_getArgumentType(method,2,type,sizeof(type));if(strcmp(type,"@"))return nil;
    method_getArgumentType(method,3,type,sizeof(type));BOOL wide=!strcmp(type,"q") || !strcmp(type,"Q");
    if(!wide && strcmp(type,"i") && strcmp(type,"I"))return nil;
    method_getArgumentType(method,4,type,sizeof(type));if(strcmp(type,"d"))return nil;
    for(NSNumber *format in @[@2,@5]) {
        @try {
            id image;
            if(wide)image=((id(*)(id,SEL,id,NSInteger,double))objc_msgSend)(UIImage.class,selector,identifier,format.integerValue,UIScreen.mainScreen.scale);
            else image=((id(*)(id,SEL,id,int,double))objc_msgSend)(UIImage.class,selector,identifier,format.intValue,UIScreen.mainScreen.scale);
            if([image isKindOfClass:UIImage.class]) {V26Report(@"testBanner.iconFormat",format);return image;}
        } @catch(NSException *e) {
            V26Report([@"testBanner.iconFailure." stringByAppendingString:format.stringValue],VLGExceptionFields(e,@"icon lookup"));
        }
    }
    V26Report(@"testBanner.genericIconFallback",@YES);
    return [UIImage systemImageNamed:@"app.fill"];
}
static void VLGHandleCommand(void) {
    if(!NSThread.isMainThread){dispatch_async(dispatch_get_main_queue(),^{VLGHandleCommand();});return;}
    NSDictionary *command=VLGReadCommand();if(!command || [VLGLastNonce isEqual:command[@"nonce"]])return;
    VLGLastNonce=command[@"nonce"];
    if([command[@"action"] isEqual:@"cancel"]) {if([VLGCurrentSession isEqual:command[@"session"]])VLGWithdraw();return;}
    NSString *stage=@"foreground check";
    @try {
        VLGStage(stage);
        // A test requested from Settings cannot appear later over another app.
        id front=V26Object(UIApplication.sharedApplication,@"_accessibilityFrontMostApplication");
        NSString *frontID=V26Object(front,@"bundleIdentifier");
        if(![frontID isEqual:@"com.apple.Preferences"]) {V26Event(@"testBannerSkipped",@{@"reason":@"settingsNotForeground"});VLGTestBannerReply(command[@"nonce"],@"Open Velvet in Settings and try Test Banner again.");return;}
        stage=@"banner destination lookup";VLGStage(stage);
        id dispatcher=V26Object(UIApplication.sharedApplication,@"notificationDispatcher");
        id destination=V26Object(dispatcher,@"bannerDestination");
        NSString *destinationID=V26Object(destination,@"identifier");
        if(![destinationID isKindOfClass:NSString.class] || !VLGTestObjectMethod(destination,@"postNotificationRequest:","v",1) || !VLGTestObjectMethod(destination,@"withdrawNotificationRequest:","v",1)) {
            V26Event(@"testBannerUnavailable",@{@"reason":@"destinationABI"});VLGTestBannerReply(command[@"nonce"],@"This device does not expose the expected native banner interface. No notification was posted.");return;
        }
        NSString *identifier=command[@"identifier"];
        stage=@"app title lookup";VLGStage(stage);
        NSString *title=@"Velvet Test Banner";
        @try {
#if defined(VLG_TEST_SERVICE_HOST)
            id workspace=V26Object(NSClassFromString(@"VLGFixtureApplicationWorkspace"),@"defaultWorkspace");
#else
            id workspace=V26Object(NSClassFromString(@"LSApplicationWorkspace"),@"defaultWorkspace");
#endif
            id proxy=VLGCall(workspace,@"applicationForBundleIdentifier:",identifier);
            id name=V26Object(proxy,@"localizedName");if([name isKindOfClass:NSString.class] && [name length])title=name;
        } @catch(NSException *e) {V26Report(@"testBanner.titleFailure",VLGExceptionFields(e,stage));}
        stage=@"app icon loading";VLGStage(stage);
        UIImage *icon=VLGThemedIcon(identifier);
        stage=@"notification creation";VLGStage(stage);
        NSError *error=nil;
        NSString *requestID=[@"com.sahinkaa.velvetliquidglass.test." stringByAppendingString:command[@"nonce"]];
        id request=VLGMakeTestNotification(NSClassFromString(@"NCNotificationRequest"),NSClassFromString(@"NCMutableNotificationOptions"),identifier,requestID,destinationID,title ?: @"Velvet Test Banner",icon,&error);
        if(!request){V26Event(@"testBannerUnavailable",@{@"reason":error.localizedDescription ?: @"assembly"});VLGTestBannerReply(command[@"nonce"],error.localizedDescription ?: @"The native Test Banner could not be created.");return;}
        V26Report(@"testBanner.requestShape",@{@"requestClass":NSStringFromClass([request class]),
            @"contentClass":NSStringFromClass([V26Object(request,@"content") class]) ?: @"nil",
            @"optionsClass":NSStringFromClass([V26Object(request,@"options") class]) ?: @"nil",
            @"hasUUID":@(V26Object(request,@"uuid")!=nil),@"hasIdentifier":@(V26Object(request,@"notificationIdentifier")!=nil)});
        stage=@"previous test cleanup";VLGStage(stage);
        VLGWithdraw();VLGRequest=request;VLGDestination=destination;VLGCurrentSession=command[@"session"];
        stage=@"native banner presentation";VLGStage(stage);
        VLGSend(destination,@"postNotificationRequest:",request);
        V26Event(@"testBannerPosted",@{@"sticky":@YES,@"silent":@YES,@"bannerOnly":@YES});
        NSUInteger generation=VLGGeneration;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(.8*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
            if(generation==VLGGeneration) {
                BOOL presented=VLGIsOurs(V26Object(destination,@"_presentedNotificationRequest"));
                V26Event(@"testBannerPresentation",@{@"presented":@(presented)});
                VLGTestBannerReply(command[@"nonce"],presented ? @"" : @"iOS did not present the Test Banner. Dismiss any current banner and try again.");
            }
        });
        // One bounded safety expiry, not a recurring poll/repost. Normal cleanup
        // happens on leaving Velvet, locking or foregrounding another app.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,15*60*NSEC_PER_SEC),dispatch_get_main_queue(),^{if(generation==VLGGeneration)VLGWithdraw();});
    } @catch(NSException *exception) {
        V26Report(@"testBanner.serviceError",exception.name);
        NSDictionary *failure=VLGExceptionFields(exception,stage);
        // Keep the first reason per stage even when the rolling event history
        // later fills with ordinary notification activity.
        V26Report([@"testBanner.failure." stringByAppendingString:stage],failure);V26Event(@"testBannerFailure",failure);
        VLGWithdraw();
        VLGTestBannerReply(command[@"nonce"],[NSString stringWithFormat:@"iOS could not show the Test Banner during %@. Details were saved to the SpringBoard log.",stage]);
    }
}
static void VLGLocked(CFNotificationCenterRef center,void *observer,CFStringRef name,const void *object,CFDictionaryRef info) {
    dispatch_async(dispatch_get_main_queue(),^{VLGWithdraw();});
}
static void VLGCommandReceived(CFNotificationCenterRef center,void *observer,CFStringRef name,const void *object,CFDictionaryRef info) {
    dispatch_async(dispatch_get_main_queue(),^{VLGHandleCommand();});
}
void VLGInstallTestBannerService(void) {
    static dispatch_once_t once;dispatch_once(&once,^{
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),NULL,VLGCommandReceived,CFSTR("com.sahinkaa.velvetliquidglass/test-banner"),NULL,CFNotificationSuspensionBehaviorCoalesce);
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),NULL,VLGLocked,CFSTR("com.apple.springboard.lockstate"),NULL,CFNotificationSuspensionBehaviorCoalesce);
        V26Report(@"testBanner.serviceInstalled",@YES);
    });
}
