#import <Foundation/Foundation.h>
NSDictionary *V26Defaults(void);
NSString *V26PreferenceKey(NSString *key, NSString *identifier);
BOOL V26Requirement(NSString *requirement, NSDictionary *effective);
@interface V26SettingsStore : NSObject
@property(nonatomic, copy, readonly) NSString *path;
- (instancetype)initWithPath:(NSString *)path;
- (BOOL)migrateFromPaths:(NSArray<NSString *> *)legacyPaths error:(NSError **)error;
- (BOOL)replaceSettings:(NSDictionary *)settings error:(NSError **)error;
- (BOOL)resetIdentifier:(NSString *)identifier error:(NSError **)error;
- (BOOL)reset:(NSError **)error;
- (NSDictionary *)read:(NSError **)error;
- (BOOL)save:(id)value forKey:(NSString *)key error:(NSError **)error;
@end

BOOL V26PreferenceSupported(NSString *key);
