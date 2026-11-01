#if defined(V26_PREFS_HOST)
#import "../tests/ManagerUIKit.h"
#else
#import "../headers/HeadersTweak.h"
#endif
#include <math.h>
#import "../compat/Runtime.h"
#import "../compat/SettingsStore.h"
#import "../compat/SettingsTransfer.h"
#import "../compat/CardStyle.h"

@interface Velvet2PrefsManager ()
@property(nonatomic, strong) V26SettingsStore *store;
@property(nonatomic, strong) NSMutableDictionary *transient;
@property(nonatomic, copy) NSDictionary *snapshot;
@property(nonatomic, copy) NSArray<NSString *> *legacyPaths;
@property(nonatomic) BOOL migrationReady;
@end

#if !defined(V26_PREFS_HOST)
static void V26PreferenceUpdate(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef info) {
    // Darwin callbacks may arrive off the main thread. UIKit observers run on main.
    dispatch_async(dispatch_get_main_queue(), ^{
        [[Velvet2PrefsManager sharedInstance] reloadFromDisk];
        [NSNotificationCenter.defaultCenter postNotificationName:@"com.sahinkaa.velvetliquidglass/updateStyle" object:nil];
    });
}

#endif
@implementation Velvet2PrefsManager
+ (instancetype)sharedInstance {
    static Velvet2PrefsManager *manager;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ manager = [[self alloc] initWithSuiteName:@"com.sahinkaa.velvetliquidglass"]; });
    return manager;
}
- (instancetype)initWithSuiteName:(NSString *)suite {
    if ((self = [super init])) {
#if defined(V26_PREFS_HOST)
        NSString *path=NSProcessInfo.processInfo.environment[@"VLG_PREFS_TEST_PATH"];NSCAssert(path.length,@"Test path required");
#elif defined(V26_ROOTHIDE)
        NSString *path = V26RootPath(@"/var/mobile/Library/Preferences/com.sahinkaa.velvetliquidglass.plist");
#else
        // Standard rootless uses the normal mobile preferences domain.
        NSString *path = @"/var/mobile/Library/Preferences/com.sahinkaa.velvetliquidglass.plist";
#endif
        self.store = [[V26SettingsStore alloc] initWithPath:path];
#if defined(V26_PREFS_HOST)
        NSString *legacy=NSProcessInfo.processInfo.environment[@"VLG_LEGACY_PREFS_TEST_PATH"];
#elif defined(V26_ROOTHIDE)
        NSString *legacy=V26RootPath(@"/var/mobile/Library/Preferences/com.noisyflake.velvet2.plist");
#else
        NSString *legacy=@"/var/mobile/Library/Preferences/com.noisyflake.velvet2.plist";
#endif
        self.legacyPaths=legacy.length ? @[legacy] : @[];
        V26Report(@"preferences.path", path);
        [self reloadFromDisk];
#if !defined(V26_PREFS_HOST)
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, V26PreferenceUpdate, CFSTR("com.sahinkaa.velvetliquidglass/preferenceUpdate"), NULL, CFNotificationSuspensionBehaviorCoalesce);
#endif
    }
    return self;
}
- (NSData *)exportSettingsData:(NSError **)error {
    if(![self ensureMigration:error])return nil;
    NSDictionary *settings=[self.store read:error];return settings ? VLGEncodeSettings(settings,error) : nil;
}
- (BOOL)importSettingsData:(NSData *)data error:(NSError **)error {
    NSDictionary *settings=VLGDecodeSettings(data,error);if(!settings || ![self ensureMigration:error])return NO;
    if(![self.store replaceSettings:settings error:error])return NO;
    @synchronized(self){[self.transient removeAllObjects];}
    [self reloadFromDisk];return YES;
}
- (BOOL)resetIdentifier:(NSString *)identifier error:(NSError **)error {
    if(![self ensureMigration:error])return NO;
    BOOL success=[self.store resetIdentifier:identifier error:error];
    if (success) {
        @synchronized(self) {
            NSString *suffix=[@"_" stringByAppendingString:identifier];
            for (NSString *key in self.transient.allKeys) if ([key hasSuffix:suffix]) [self.transient removeObjectForKey:key];
        }
        [self reloadFromDisk];
    }
    return success;
}
- (BOOL)reset:(NSError **)error {
    if(![self ensureMigration:error])return NO;
    BOOL success = [self.store reset:error];
    if (success) {@synchronized(self) {[self.transient removeAllObjects];}[self reloadFromDisk];}
    return success;
}
- (BOOL)ensureMigration:(NSError **)error {
    if(self.migrationReady)return YES;
    self.migrationReady=[self.store migrateFromPaths:self.legacyPaths error:error];
    return self.migrationReady;
}
- (void)reloadFromDisk {
    NSError *error = nil;
    NSDictionary *values = [self ensureMigration:&error] ? [self.store read:&error] : nil;
    @synchronized (self) {
        if (values) self.snapshot = values;
        else if (!self.snapshot) self.snapshot = @{};
    }
    V26Report(@"preferences.readable", @(values != nil));
    if (error) V26Report(@"preferences.error", error.localizedDescription);
}
- (id)objectForKey:(NSString *)key {
    if (![key isKindOfClass:NSString.class] || !V26PreferenceSupported(key)) return nil;
    @synchronized (self) {
        id value = self.transient[key] ?: self.snapshot[key];
        if(!value && ([key isEqual:@"cornerRadiusPercent"] || [key hasPrefix:@"cornerRadiusPercent_"])) {
            NSString *legacy=[key stringByReplacingOccurrencesOfString:@"cornerRadiusPercent" withString:@"cornerRadiusCustom"];
            id old=self.transient[legacy] ?: self.snapshot[legacy];
            if(([old isKindOfClass:NSNumber.class] || [old isKindOfClass:NSString.class]) && isfinite([old doubleValue]))value=@(VLGLegacyRadiusPercent([old doubleValue]));
        }
        NSString *base = [[key componentsSeparatedByString:@"_"] firstObject];
        id defaultValue = V26Defaults()[base];
        BOOL valid = YES;
        if ([defaultValue isKindOfClass:NSNumber.class]) {
            valid = ([value isKindOfClass:NSNumber.class] || [value isKindOfClass:NSString.class]) && isfinite([value doubleValue]);
        } else if ([defaultValue isKindOfClass:NSString.class] || [base containsString:@"Color"] || [base containsString:@"Gradient"] || [base isEqual:@"currentIcon"]) {
            valid = [value isKindOfClass:NSString.class];
        }
        if(valid && [base isEqual:@"appearance"] && value && ![@[@"light",@"dark"] containsObject:value])value=@"dark";
        if (valid && [defaultValue isKindOfClass:NSNumber.class]) {
            double number = [value doubleValue];
            if ([base hasSuffix:@"Shade"]) value = @(fmax(-100, fmin(100, number)));
            else if ([base hasSuffix:@"Alpha"]) value = @(fmax(0, fmin(100, number)));
            else if ([base hasSuffix:@"Width"]) value = @(fmax(0, fmin(30, number)));
            else if (([base isEqual:@"cornerRadiusCustom"] || [base isEqual:@"cornerRadiusPercent"])) value = @(fmax(0, fmin(100, number)));
        }
        return (valid ? value : nil) ?: V26Defaults()[key];
    }
}
- (void)setTransientValue:(id)value forKey:(NSString *)key {
    if (!V26PreferenceSupported(key)) return;
    @synchronized(self) {
        if (!self.transient) self.transient=[NSMutableDictionary dictionary];
        if (value) self.transient[key]=value;else [self.transient removeObjectForKey:key];
    }
}
- (void)clearTransientValueForKey:(NSString *)key {
    @synchronized(self) { [self.transient removeObjectForKey:key]; }
}
- (id)settingForKey:(NSString *)key withIdentifier:(NSString *)identifier {
    id value = identifier.length ? [self objectForKey:V26PreferenceKey(key, identifier)] : nil;
    return value ?: [self objectForKey:key];
}
- (BOOL)saveValue:(id)value forKey:(NSString *)key error:(NSError **)error {
    if(![self ensureMigration:error])return NO;
    BOOL success = [self.store save:value forKey:key error:error];
    if (success) [self reloadFromDisk];
    return success;
}
- (void)setObject:(id)value forKey:(NSString *)key {
    NSError *error = nil;
    if (![self saveValue:value forKey:key error:&error]) V26Report(@"preferences.saveError", error.localizedDescription ?: @"Invalid setting");
}
- (void)removeObjectForKey:(NSString *)key { [self setObject:nil forKey:key]; }
- (UIColor *)colorForKey:(NSString *)key withIdentifier:(NSString *)identifier {
    id string = [self settingForKey:key withIdentifier:identifier];
    return [string isKindOfClass:NSString.class] ? [UIColor colorFromP3String:string] : UIColor.clearColor;
}
- (CGFloat)alphaValueForKey:(NSString *)key withIdentifier:(NSString *)identifier {
    id value = [self settingForKey:key withIdentifier:identifier];
    double alpha = [value respondsToSelector:@selector(doubleValue)] ? [value doubleValue] / 100 : 0;
    return isfinite(alpha) ? fmax(0, fmin(1, alpha)) : 0;
}
@end
