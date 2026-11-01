#pragma once
#if defined(V26_PREFS_HOST)
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
@class UIColor;
#else
#import <UIKit/UIKit.h>
#endif

@interface Velvet2PrefsManager : NSObject
+ (instancetype)sharedInstance;
- (instancetype)initWithSuiteName:(NSString *)suitename;
- (id)settingForKey:(NSString *)key withIdentifier:(NSString *)identifier;
- (UIColor *)colorForKey:(NSString *)key withIdentifier:(NSString *)identifier;
- (CGFloat)alphaValueForKey:(NSString *)key withIdentifier:(NSString *)identifier;
- (id)objectForKey:(NSString *)key;
- (void)setObject:(id)value forKey:(NSString *)key;
- (void)removeObjectForKey:(NSString *)key;
- (void)reloadFromDisk;
- (void)setTransientValue:(id)value forKey:(NSString *)key;
- (void)clearTransientValueForKey:(NSString *)key;
- (NSData *)exportSettingsData:(NSError **)error;
- (BOOL)importSettingsData:(NSData *)data error:(NSError **)error;
- (BOOL)resetIdentifier:(NSString *)identifier error:(NSError **)error;
- (BOOL)reset:(NSError **)error;
- (BOOL)saveValue:(id)value forKey:(NSString *)key error:(NSError **)error;
@end
