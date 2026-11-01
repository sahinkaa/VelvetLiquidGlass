#import "../headers/HeadersTweak.h"
#import "../compat/Runtime.h"
#import "../compat/NotificationStyle.h"
#import <objc/runtime.h>
#import "../compat/IconCompletion.h"
#import "../compat/TestBanner.h"

%group V26ControllerLayout
%hook NCNotificationShortLookViewController
- (void)viewDidLayoutSubviews {
    %orig;
    V26Refresh(self);
}
%end
%end
%group V26ControllerAppearance
%hook NCNotificationShortLookViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    V26Refresh(self);
}
%end
%end
%group V26ContentUpdate
%hook NCNotificationShortLookViewController
- (void)_updateWithProvidedStaticContent {
    %orig;
    V26Refresh(self);
}
%end
%end
%group V26RequestUpdateVoid
%hook NCNotificationShortLookViewController
- (void)_setNotificationRequest:(id)request {
    %orig;
    V26RequestChanged(self);
}
%end
%end
%group V26RequestUpdateBool
%hook NCNotificationShortLookViewController
- (BOOL)_setNotificationRequest:(id)request {
    BOOL result = %orig;
    if (result) V26RequestChanged(self);
    else V26Refresh(self);
    return result;
}
%end
%end
%group V26BackgroundAlpha
%hook NCNotificationShortLookView
- (void)setBackgroundAlpha:(double)alpha {
    %orig;
    V26RefreshForView(self);
}
%end
%end
%group V26RootLayout
%hook NCNotificationShortLookView
- (void)layoutSubviews {
    %orig;
    V26RefreshForView(self);
}
%end
%end
%group V26SeamlessLayout
%hook NCNotificationSeamlessContentView
- (void)layoutSubviews {
    %orig;
    V26RefreshForView(self);
}
%end
%end
%group V26IconLayout
%hook NCBadgedIconView
- (void)layoutSubviews {
    %orig;
    V26RefreshForView(self);
}
%end
%end
%group V26Summary
%hook NCNotificationSummaryPlatterView
- (void)layoutSubviews {
    %orig;
    V26Refresh(self);
}
%end
%end

%group VLGProminentCompletion
%hook NCBadgedIconView
- (void)_prominentIconForCurrentInterfaceStyleWithCompletionOnMain:(void (^)(id))completion {
    __weak UIView *view=(UIView *)self;
    %orig(VLGAfterImageCompletion(completion, ^{VLGIconDidComplete(view);}));
}
%end
%end
%group VLGSubordinateCompletion
%hook NCBadgedIconView
- (void)_subordinateIconForCurrentInterfaceStyleWithCompletionOnMain:(void (^)(id))completion {
    __weak UIView *view=(UIView *)self;
    %orig(VLGAfterImageCompletion(completion, ^{VLGIconDidComplete(view);}));
}
%end
%end
// These callbacks run after native text/trait styling. Original methods and
// their exceptions remain outside Velvet's optional styling guard.
%group VLGNativeTextAttributes
%hook NCNotificationSeamlessContentView
- (void)_updateTextAttributes {
    %orig;
    VLGNativeTextDidUpdate(self);
}
%end
%end
%group VLGNativeTextTraits
%hook NCNotificationSeamlessContentView
- (void)traitCollectionDidChange:(id)previous {
    %orig;
    VLGNativeTextDidUpdate(self);
}
%end
%end
%group VLGNativeTextProviderObject
%hook NCNotificationSeamlessContentView
- (void)_visualStylingProviderDidChange:(id)provider forCategory:(id)category outgoingProvider:(id)outgoing {
    %orig;
    VLGNativeTextDidUpdate(self);
}
%end
%end
%group VLGNativeTextProviderInteger
%hook NCNotificationSeamlessContentView
- (void)_visualStylingProviderDidChange:(id)provider forCategory:(NSInteger)category outgoingProvider:(id)outgoing {
    %orig;
    VLGNativeTextDidUpdate(self);
}
%end
%end
%group VLGNativeTextRegistrationSigned
%hook NCNotificationSeamlessContentView
- (void)_updateVisualStylingOfView:(id)view style:(NSInteger)style visualStylingProvider:(id)provider outgoingProvider:(id)outgoing {
    %orig;
    VLGNativeTextProviderRegistered(self,view,style,provider);
}
%end
%end
%group VLGNativeTextRegistrationUnsigned
%hook NCNotificationSeamlessContentView
- (void)_updateVisualStylingOfView:(id)view style:(NSUInteger)style visualStylingProvider:(id)provider outgoingProvider:(id)outgoing {
    %orig;
    if(style<=NSIntegerMax)VLGNativeTextProviderRegistered(self,view,(NSInteger)style,provider);
}
%end
%end
static BOOL V26HookReady(NSString *className, NSString *selector, unsigned count) {
    Class cls = NSClassFromString(className);
    Method m = class_getInstanceMethod(cls, NSSelectorFromString(selector));
    NSString *key = [NSString stringWithFormat:@"abi.%@.%@", className, selector];
    V26Report(key, m ? [NSString stringWithUTF8String:method_getTypeEncoding(m)] : @"MISSING");
    return V26Method(cls, NSSelectorFromString(selector), "v", count);
}
%ctor {
    @autoreleasepool {
        [Velvet2PrefsManager sharedInstance];
        VLGInstallTestBannerService();
        if (![[[Velvet2PrefsManager sharedInstance] objectForKey:@"enabled"] boolValue]) return;
        if (V26HookReady(@"NCNotificationShortLookViewController", @"viewDidLayoutSubviews", 0)) {
            %init(V26ControllerLayout);
        }
        Method appeared = class_getInstanceMethod(NSClassFromString(@"NCNotificationShortLookViewController"), @selector(viewDidAppear:));
        char result[16] = {0}, argument[16] = {0};
        if (appeared && method_getNumberOfArguments(appeared) == 3) {
            method_getReturnType(appeared, result, sizeof(result));
            method_getArgumentType(appeared, 2, argument, sizeof(argument));
            if (!strcmp(result, "v") && (!strcmp(argument, "B") || !strcmp(argument, "c"))) {
            %init(V26ControllerAppearance);
        }
        }
        if (V26HookReady(@"NCNotificationShortLookViewController", @"_updateWithProvidedStaticContent", 0)) {
            %init(V26ContentUpdate);
        }
        if (V26HookReady(@"NCNotificationShortLookViewController", @"_setNotificationRequest:", 1)) {
            %init(V26RequestUpdateVoid);
        } else if (V26Method(NSClassFromString(@"NCNotificationShortLookViewController"), NSSelectorFromString(@"_setNotificationRequest:"), "B", 1)) {
            %init(V26RequestUpdateBool);
            V26Report(@"hooks.booleanRequestSetter", @YES);
        }
        Class root = NSClassFromString(@"NCNotificationShortLookView");
        Method alpha = class_getInstanceMethod(root, NSSelectorFromString(@"setBackgroundAlpha:"));
        char alphaResult[32] = {0}, alphaArgument[64] = {0};
        if (alpha && method_getNumberOfArguments(alpha) == 3) {
            method_getReturnType(alpha, alphaResult, sizeof(alphaResult));
            method_getArgumentType(alpha, 2, alphaArgument, sizeof(alphaArgument));
            if (!strcmp(alphaResult, "v") && !strcmp(alphaArgument, "d")) {
                %init(V26BackgroundAlpha);
                V26Report(@"hooks.backgroundAlpha", @YES);
            }
        }
        if (V26HookReady(@"NCNotificationShortLookView", @"layoutSubviews", 0)) {
            %init(V26RootLayout);
        }
        if (V26HookReady(@"NCNotificationSeamlessContentView", @"layoutSubviews", 0)) {
            %init(V26SeamlessLayout);
        }
        if (V26HookReady(@"NCBadgedIconView", @"layoutSubviews", 0)) {
            %init(V26IconLayout);
        }
        if (V26HookReady(@"NCNotificationSummaryPlatterView", @"layoutSubviews", 0)) {
            %init(V26Summary);
        }
        if(V26HookReady(@"NCNotificationSeamlessContentView",@"_updateTextAttributes",0)) {
            %init(VLGNativeTextAttributes);
        }
        if(V26HookReady(@"NCNotificationSeamlessContentView",@"traitCollectionDidChange:",1)) {
            %init(VLGNativeTextTraits);
        }
        Class seamless=NSClassFromString(@"NCNotificationSeamlessContentView");
        SEL providerSEL=NSSelectorFromString(@"_visualStylingProviderDidChange:forCategory:outgoingProvider:");
        Method providerMethod=class_getInstanceMethod(seamless,providerSEL);
        V26Report(@"abi.seamless.visualStylingProvider",providerMethod ? @(method_getTypeEncoding(providerMethod)) : @"MISSING");
        if(V26Method(seamless,providerSEL,"v",3)) {
            %init(VLGNativeTextProviderObject);
        }
        else if(providerMethod && method_getNumberOfArguments(providerMethod)==5) {
            char r[16]={0},a[64]={0},b[16]={0},c[64]={0};
            method_getReturnType(providerMethod,r,sizeof(r));method_getArgumentType(providerMethod,2,a,sizeof(a));
            method_getArgumentType(providerMethod,3,b,sizeof(b));method_getArgumentType(providerMethod,4,c,sizeof(c));
            if(!strcmp(r,"v") && a[0]=='@' && a[1]!='?' && !strcmp(b,"q") && c[0]=='@' && c[1]!='?') {
            %init(VLGNativeTextProviderInteger);
        }
        }
        SEL registrationSEL=NSSelectorFromString(@"_updateVisualStylingOfView:style:visualStylingProvider:outgoingProvider:");
        Method registration=class_getInstanceMethod(seamless,registrationSEL);
        V26Report(@"abi.seamless.textRegistration",registration ? @(method_getTypeEncoding(registration)) : @"MISSING");
        if(registration && method_getNumberOfArguments(registration)==6) {
            char result[16]={0},view[64]={0},style[16]={0},provider[64]={0},outgoing[64]={0};
            method_getReturnType(registration,result,sizeof(result));method_getArgumentType(registration,2,view,sizeof(view));
            method_getArgumentType(registration,3,style,sizeof(style));method_getArgumentType(registration,4,provider,sizeof(provider));method_getArgumentType(registration,5,outgoing,sizeof(outgoing));
            if(!strcmp(result,"v") && view[0]=='@' && view[1]!='?' && provider[0]=='@' && provider[1]!='?' && outgoing[0]=='@' && outgoing[1]!='?') {
                if(!strcmp(style,"q")) {
                    %init(VLGNativeTextRegistrationSigned);
                } else if(!strcmp(style,"Q")) {
                    %init(VLGNativeTextRegistrationUnsigned);
                }
            }
        }
        Class badge=NSClassFromString(@"NCBadgedIconView");
        if(VLGImageCompletionMethod(badge,NSSelectorFromString(@"_prominentIconForCurrentInterfaceStyleWithCompletionOnMain:"))) {
            %init(VLGProminentCompletion);V26Report(@"hooks.prominentCompletion",@YES);
        }
        if(VLGImageCompletionMethod(badge,NSSelectorFromString(@"_subordinateIconForCurrentInterfaceStyleWithCompletionOnMain:"))) {
            %init(VLGSubordinateCompletion);V26Report(@"hooks.subordinateCompletion",@YES);
        }
        V26Report(@"hooks.installationCompleted", @YES);
    }
}
