// Host-only adapters let the unmodified production ColorCube algorithm consume
// real CoreGraphics pixels. They do not model SpringBoard or UIKit layout.
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

@interface UIColor : NSObject
@property(nonatomic, readonly) CGColorRef CGColor;
+ (instancetype)colorWithRed:(CGFloat)r green:(CGFloat)g blue:(CGFloat)b alpha:(CGFloat)a;
@end
@interface UIImage : NSObject
@property(nonatomic, readonly) CGImageRef CGImage;
- (instancetype)initWithColor:(UIColor *)color empty:(BOOL)empty;
- (void)drawInRect:(CGRect)rect;
@end
typedef NS_ENUM(NSInteger, UIGraphicsImageRendererFormatRange) { UIGraphicsImageRendererFormatRangeStandard = 1 };
@interface UIGraphicsImageRendererFormat : NSObject
@property(nonatomic) CGFloat scale;
@property(nonatomic) BOOL opaque;
@property(nonatomic) UIGraphicsImageRendererFormatRange preferredRange;
+ (instancetype)defaultFormat;
@end
@interface UIGraphicsImageRendererContext : NSObject
@property(nonatomic) CGContextRef CGContext;
@end
@interface UIGraphicsImageRenderer : NSObject
- (instancetype)initWithSize:(CGSize)size format:(UIGraphicsImageRendererFormat *)format;
- (UIImage *)imageWithActions:(void (^)(UIGraphicsImageRendererContext *context))actions;
@end
