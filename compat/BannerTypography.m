#import "BannerTypography.h"
#import "Runtime.h"
#import <CoreFoundation/CoreFoundation.h>
#include <math.h>
NSDictionary *VLGInitialBannerTypography(void) {return @{@"title":@15,@"message":@15,@"date":@13};}
static NSDictionary *VLGFontCache;
static BOOL VLGFontsRead;
static NSString *VLGFontPath(void) {
#if defined(VLG_TYPOGRAPHY_HOST)
    return NSProcessInfo.processInfo.environment[@"VLG_FONT_TEST_PATH"];
#elif defined(V26_ROOTHIDE)
    return V26RootPath(@"/var/mobile/Library/Caches/com.sahinkaa.velvetliquidglass/banner-fonts.plist");
#else
    return @"/var/mobile/Library/Caches/com.sahinkaa.velvetliquidglass/banner-fonts.plist";
#endif
}
static NSDictionary *VLGValidFontSizes(id object) {
    if(![object isKindOfClass:NSDictionary.class])return nil;
    NSMutableDictionary *result=[NSMutableDictionary new];
    for(NSString *key in @[@"title",@"message",@"date"]) {
        id value=object[key];if(![value isKindOfClass:NSNumber.class])return nil;
        double size=[value doubleValue];if(!isfinite(size) || size<8 || size>64)return nil;
        result[key]=@(size);
    }
    return result;
}
#if !defined(VLG_TYPOGRAPHY_HOST)
static void VLGFontsChanged(CFNotificationCenterRef c,void *o,CFStringRef n,const void *p,CFDictionaryRef info) {
    dispatch_async(dispatch_get_main_queue(),^{VLGFontsRead=NO;VLGFontCache=nil;[NSNotificationCenter.defaultCenter postNotificationName:@"VLGPreviewTypographyChanged" object:nil];});
}
#endif
NSDictionary *VLGReadBannerTypography(void) {
    if(!NSThread.isMainThread)return nil;
#if !defined(VLG_TYPOGRAPHY_HOST)
    static dispatch_once_t once;dispatch_once(&once,^{CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),NULL,VLGFontsChanged,CFSTR("com.sahinkaa.velvetliquidglass/bannerFonts"),NULL,CFNotificationSuspensionBehaviorCoalesce);});
#endif
    if(VLGFontsRead)return VLGFontCache;VLGFontsRead=YES;
    NSDictionary *saved=[NSDictionary dictionaryWithContentsOfFile:VLGFontPath()];
    if([saved[@"os"] isEqual:NSProcessInfo.processInfo.operatingSystemVersionString] && [saved[@"version"] isEqual:@1])VLGFontCache=VLGValidFontSizes(saved[@"sizes"]);
    return VLGFontCache;
}
BOOL VLGStoreBannerTypography(NSDictionary *sizes) {
    if(!NSThread.isMainThread)return NO;
    NSDictionary *valid=VLGValidFontSizes(sizes);if(!valid)return NO;
    if([valid isEqual:VLGReadBannerTypography()])return YES;
    NSString *path=VLGFontPath();if(!path.length)return NO;
    NSError *error=nil;
    if(![NSFileManager.defaultManager createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:&error])return NO;
    NSDictionary *record=@{@"version":@1,@"os":NSProcessInfo.processInfo.operatingSystemVersionString,@"sizes":valid};
    if(![record writeToFile:path atomically:YES])return NO;
    VLGFontCache=valid;VLGFontsRead=YES;
#if !defined(VLG_TYPOGRAPHY_HOST)
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),CFSTR("com.sahinkaa.velvetliquidglass/bannerFonts"),NULL,NULL,YES);
#endif
    return YES;
}
