#import "SettingsStore.h"
#import "SettingsTransfer.h"
#include <sys/file.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>

NSDictionary *V26Defaults(void) { return @{
        @"enabled": @YES,
        @"appearance": @"dark",
        @"backgroundEnabled": @NO,

        @"backgroundType": @"icon",
        @"backgroundColorAlpha": @100,
        @"backgroundColorShade": @0,
        @"backgroundGradientAlpha": @100,
        @"backgroundGradientShade": @0,
        @"backgroundIconShade": @0,
        @"backgroundIconAlpha": @50,
        @"backgroundGradientDirection": @"right",





        @"bannerBorderEnabled": @NO,
        @"bannerBorderWidth": @2,
        @"bannerBorderType": @"icon",
        @"bannerBorderColorAlpha": @100,
        @"bannerBorderColorShade": @0,
        @"bannerBorderGradientAlpha": @100,
        @"bannerBorderGradientShade": @0,
        @"bannerBorderIconShade": @0,
        @"bannerBorderIconAlpha": @100,
        @"bannerBorderGradientDirection": @"right",
        @"shadowEnabled": @NO,
        @"shadowWidth": @5,
        @"shadowType": @"icon",
        @"shadowColorAlpha": @100,
        @"shadowColorShade": @0,
        @"shadowIconShade": @0,
        @"shadowIconAlpha": @100,






        @"titleEnabled": @NO,
        @"titleType": @"icon",
        @"titleColorAlpha": @100,
        @"titleColorShade": @0,
        @"titleGradientAlpha": @100,
        @"titleGradientShade": @0,
        @"titleIconShade": @0,
        @"titleIconAlpha": @100,
        @"titleGradientDirection": @"right",
        @"messageEnabled": @NO,
        @"messageType": @"icon",
        @"messageColorAlpha": @100,
        @"messageColorShade": @0,
        @"messageGradientAlpha": @100,
        @"messageGradientShade": @0,
        @"messageIconShade": @0,
        @"messageIconAlpha": @100,
        @"messageGradientDirection": @"right",
        @"dateEnabled": @NO,
        @"dateType": @"icon",
        @"dateColorAlpha": @100,
        @"dateColorShade": @0,
        @"dateGradientAlpha": @100,
        @"dateGradientShade": @0,
        @"dateIconShade": @0,
        @"dateIconAlpha": @100,
        @"dateGradientDirection": @"right",
        @"cornerRadiusEnabled": @NO,
        @"cornerRadiusCustom": @19,
        @"cornerRadiusPercent": @70,



    }; }

BOOL V26PreferenceSupported(NSString *key) {
    if (![key isKindOfClass:NSString.class]) return NO;
    NSString *base=[[key componentsSeparatedByString:@"_"] firstObject];
    return ![base hasPrefix:@"border"] && ![base hasPrefix:@"line"] &&
        ![@[@"appIconHidden",@"appIconCornerRadiusCircle",@"stackDimmingViewHidden",@"backgroundBlurHidden"] containsObject:base];
}

NSString *V26PreferenceKey(NSString *key, NSString *identifier) {
    if (![key isKindOfClass:NSString.class] || !key.length) return nil;
    return identifier.length ? [NSString stringWithFormat:@"%@_%@", key, identifier] : key;
}

BOOL V26Requirement(NSString *requirement, NSDictionary *effective) {
    if (!requirement.length) return YES;
    for (NSString *part in [requirement componentsSeparatedByString:@"&"]) {
        NSArray *pair = [part componentsSeparatedByString:@"="];
        if (pair.count == 2) {
            if (![effective[pair[0]] isEqual:pair[1]]) return NO;
        } else if (pair.count == 1 && part.length) {
            BOOL inverse = [part hasPrefix:@"!"];
            NSString *key = inverse ? [part substringFromIndex:1] : part;
            id value = effective[key];
            BOOL enabled = [value respondsToSelector:@selector(boolValue)] && [value boolValue];
            if (inverse ? enabled : !enabled) return NO;
        } else return NO;
    }
    return YES;
}

@implementation V26SettingsStore
- (instancetype)initWithPath:(NSString *)path {
    if ((self = [super init])) _path = [path copy];
    return self;
}
- (NSDictionary *)read:(NSError **)error {
    if (error) *error = nil;
    if (![NSFileManager.defaultManager fileExistsAtPath:self.path]) return @{};
    NSData *data = [NSData dataWithContentsOfFile:self.path options:0 error:error];
    if (!data) return nil;
    id result = [NSPropertyListSerialization propertyListWithData:data options:0 format:NULL error:error];
    if (![result isKindOfClass:NSDictionary.class]) {
        if (error && !*error) *error = [NSError errorWithDomain:@"VelvetLiquidGlass.Settings" code:1 userInfo:@{NSLocalizedDescriptionKey:@"The existing settings could not be read. They have not been replaced."}];
        return nil;
    }
    return result;
}
// Use the same destination lock as ordinary writes. The original remains
// untouched for rollback, and an existing destination (even empty) always wins.
- (BOOL)migrateFromPaths:(NSArray<NSString *> *)legacyPaths error:(NSError **)error {
    if(error)*error=nil;
    NSFileManager *fm=NSFileManager.defaultManager;
    if([fm fileExistsAtPath:self.path] || !legacyPaths.count)return YES;
    if(![fm createDirectoryAtPath:self.path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:error])return NO;
    int lock=open([self.path stringByAppendingString:@".velvetliquidglass.lock"].fileSystemRepresentation,O_CREAT|O_RDWR|O_CLOEXEC,0600);
    if(lock<0){if(error)*error=[NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];return NO;}
    if(flock(lock,LOCK_EX)){int code=errno;close(lock);if(error)*error=[NSError errorWithDomain:NSPOSIXErrorDomain code:code userInfo:nil];return NO;}
    @try {
        if([fm fileExistsAtPath:self.path])return YES;
        for(id candidate in legacyPaths) {
            if(![candidate isKindOfClass:NSString.class] || ![candidate length] || [candidate isEqual:self.path])continue;
            if(![fm fileExistsAtPath:candidate])continue;
            NSData *data=[NSData dataWithContentsOfFile:candidate options:0 error:error];if(!data)return NO;
            id values=[NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:error];
            if(![values isKindOfClass:NSDictionary.class]) {
                if(error && !*error)*error=[NSError errorWithDomain:@"VelvetLiquidGlass.Settings" code:2 userInfo:@{NSLocalizedDescriptionKey:@"The previous Velvet settings could not be imported. The original file has not been changed."}];
                return NO;
            }
            if(![data writeToFile:self.path options:NSDataWritingAtomic error:error])return NO;
            return [[self read:error] isEqual:values];
        }
        return YES;
    } @finally {flock(lock,LOCK_UN);close(lock);}
}
- (BOOL)reset:(NSError **)error { return [self change:nil forKey:nil reset:YES identifier:nil replacement:nil error:error]; }
- (BOOL)resetIdentifier:(NSString *)identifier error:(NSError **)error {
    if (![identifier isKindOfClass:NSString.class] || !identifier.length) return NO;
    return [self change:nil forKey:nil reset:NO identifier:identifier replacement:nil error:error];
}
- (BOOL)save:(id)value forKey:(NSString *)key error:(NSError **)error { return [self change:value forKey:key reset:NO identifier:nil replacement:nil error:error]; }
- (BOOL)replaceSettings:(NSDictionary *)settings error:(NSError **)error {
    NSData *encoded=VLGEncodeSettings(settings,error);if(!encoded)return NO;
    NSDictionary *snapshot=VLGDecodeSettings(encoded,error);if(!snapshot)return NO;
    return [self change:nil forKey:nil reset:NO identifier:nil replacement:snapshot error:error];
}
- (BOOL)change:(id)value forKey:(NSString *)key reset:(BOOL)reset identifier:(NSString *)identifier replacement:(NSDictionary *)replacement error:(NSError **)error {
    if (error) *error = nil;
    if (!replacement && !reset && !identifier && (![key isKindOfClass:NSString.class] || !key.length || (value && ![NSPropertyListSerialization propertyList:@[value] isValidForFormat:NSPropertyListXMLFormat_v1_0]))) return NO;
    NSFileManager *fm = NSFileManager.defaultManager;
    if (![fm createDirectoryAtPath:self.path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:error]) return NO;
    int lock = open([self.path stringByAppendingString:@".velvetliquidglass.lock"].fileSystemRepresentation, O_CREAT | O_RDWR | O_CLOEXEC, 0600);
    if (lock < 0) { if (error) *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil]; return NO; }
    if (flock(lock, LOCK_EX)) { int code = errno; close(lock); if (error) *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:code userInfo:nil]; return NO; }
    @try {
        NSDictionary *existing = [self read:error];
        if (!existing && !replacement) return NO;
        if(replacement) {
            // Every explicit import preserves the latest pre-import bytes,
            // even when they need repair. Abort before changing preferences if
            // the backup cannot be written.
            NSData *before=[fm fileExistsAtPath:self.path] ? [NSData dataWithContentsOfFile:self.path options:0 error:error] : [NSPropertyListSerialization dataWithPropertyList:@{} format:NSPropertyListXMLFormat_v1_0 options:0 error:error];
            if(!before || ![before writeToFile:[self.path stringByAppendingString:@".before-import.plist"] options:NSDataWritingAtomic error:error])return NO;
            if(error)*error=nil;
        }
        NSString *backup = [self.path stringByAppendingString:@".before-velvet-liquid-glass"];
        if ([fm fileExistsAtPath:self.path] && ![fm fileExistsAtPath:backup] && ![fm copyItemAtPath:self.path toPath:backup error:error]) return NO;
        NSMutableDictionary *updated = replacement ? [replacement mutableCopy] : reset ? [NSMutableDictionary new] : [existing mutableCopy];
        if (!replacement && identifier) {
            NSString *suffix=[@"_" stringByAppendingString:identifier];
            for (NSString *savedKey in existing) if ([savedKey isKindOfClass:NSString.class] && [savedKey hasSuffix:suffix]) [updated removeObjectForKey:savedKey];
        } else if (!replacement && !reset) { if (value) updated[key] = value; else [updated removeObjectForKey:key]; }
        NSData *data = [NSPropertyListSerialization dataWithPropertyList:updated format:NSPropertyListXMLFormat_v1_0 options:0 error:error];
        if (!data || ![data writeToFile:self.path options:NSDataWritingAtomic error:error]) return NO;
        return [[self read:error] isEqual:updated];
    } @finally { flock(lock, LOCK_UN); close(lock); }
}
@end
