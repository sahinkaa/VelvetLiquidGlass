#import <Foundation/Foundation.h>
@interface UIImage:NSObject
+ (id)systemImageNamed:(NSString *)name;
+ (id)_applicationIconImageForBundleIdentifier:(id)identifier format:(NSInteger)format scale:(double)scale;
@end
@interface UIScreen:NSObject
+ (instancetype)mainScreen;
@property(nonatomic,readonly) double scale;
@end
@interface UIApplication:NSObject
+ (instancetype)sharedApplication;
@end
