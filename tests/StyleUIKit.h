#pragma once
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <QuartzCore/QuartzCore.h>
@interface UIColor : NSObject
@property(nonatomic) CGColorRef CGColor;
+ (instancetype)blackColor;
+ (instancetype)whiteColor;
+ (instancetype)rgb:(double)r g:(double)g b:(double)b;
@end
@interface UIImage : NSObject
@property(nonatomic) CGImageRef CGImage;
@property(nonatomic, strong) UIColor *color;
@end
@interface UIResponder : NSObject
@property(nonatomic, weak) UIResponder *nextResponder;
@end
typedef NS_ENUM(NSInteger,UIUserInterfaceStyle) {UIUserInterfaceStyleUnspecified=0,UIUserInterfaceStyleLight=1,UIUserInterfaceStyleDark=2};
@interface UITraitCollection : NSObject
@property(nonatomic) NSInteger userInterfaceStyle;
@property(nonatomic) CGFloat displayScale;
@end
@interface UIView : UIResponder
@property(nonatomic) CGRect frame;
@property(nonatomic) CGRect bounds;
@property(nonatomic, strong) CALayer *layer;
@property(nonatomic, strong) NSArray *subviews;
@property(nonatomic, weak) UIView *superview;
@property(nonatomic, weak) UIView *window;
@property(nonatomic) BOOL hidden, clipsToBounds, userInteractionEnabled, accessibilityElementsHidden;
@property(nonatomic) CGFloat alpha;
@property(nonatomic) UIUserInterfaceStyle overrideUserInterfaceStyle;
@property(nonatomic, strong) UIColor *backgroundColor;
@property(nonatomic, strong) UITraitCollection *traitCollection;
- (void)insertSubview:(UIView *)view aboveSubview:(UIView *)other;
- (void)insertSubview:(UIView *)view atIndex:(NSInteger)index;
- (void)removeFromSuperview;
- (void)layoutIfNeeded;
- (BOOL)isDescendantOfView:(UIView *)view;
- (CGRect)convertRect:(CGRect)rect toView:(UIView *)view;
+ (void)performWithoutAnimation:(dispatch_block_t)block;
+ (NSTimeInterval)inheritedAnimationDuration;
@end
typedef NS_ENUM(NSInteger, UIBlurEffectStyle) { UIBlurEffectStyleSystemMaterial = 0 };
@interface UIVisualEffect : NSObject <NSSecureCoding>
@property(nonatomic) NSInteger marker;
@end
@interface UIBlurEffect : UIVisualEffect
+ (instancetype)effectWithStyle:(UIBlurEffectStyle)style;
@end
@interface UIVisualEffectView : UIView
@property(nonatomic, strong) UIVisualEffect *effect;
@property(nonatomic, strong) UIView *contentView;
@property(nonatomic,copy) NSArray *backgroundEffects,*contentEffects;
- (instancetype)initWithEffect:(UIVisualEffect *)effect;
@end
@interface UILabel : UIView
@property(nonatomic, strong) UIColor *textColor;
@end
@interface UIImageView : UIView
@property(nonatomic, strong) UIImage *image;
@end
@interface UIBezierPath : NSObject
@property(nonatomic) CGPathRef CGPath;
+ (instancetype)bezierPathWithRoundedRect:(CGRect)rect cornerRadius:(double)radius;
@end
@interface NSValue (V26Geometry)
+ (instancetype)valueWithCGRect:(CGRect)rect;
- (CGRect)CGRectValue;
@end
#define UIGraphicsImageRendererFormatRangeStandard 1
@interface UIGraphicsImageRendererFormat : NSObject
@property(nonatomic) CGFloat scale;
@property(nonatomic) BOOL opaque;
@property(nonatomic) NSInteger preferredRange;
+ (instancetype)defaultFormat;
@end
@interface UIGraphicsImageRendererContext : NSObject
@property(nonatomic) CGContextRef CGContext;
@end
@interface UIGraphicsImageRenderer : NSObject
@property(nonatomic) CGSize size;
- (instancetype)initWithSize:(CGSize)size format:(UIGraphicsImageRendererFormat *)format;
- (UIImage *)imageWithActions:(void (^)(UIGraphicsImageRendererContext *))actions;
@end
@interface Velvet2PrefsManager : NSObject
+ (instancetype)sharedInstance;
- (id)settingForKey:(NSString *)key withIdentifier:(NSString *)identifier;
@end
@interface Velvet2Colorizer : NSObject
@property(nonatomic,strong) NSString *identifier;
@property(nonatomic,strong) Velvet2PrefsManager *manager;
@property(nonatomic, strong) UIImage *appIcon;
@property(nonatomic, strong) UIColor *iconColor;
@property(nonatomic) BOOL v26PaletteResolved;
@property(nonatomic,strong) UIColor *vlgDefaultTextColor;
- (instancetype)initWithIdentifier:(NSString *)identifier;
- (void)colorBackground:(UIView *)view;
- (void)colorBorder:(UIView *)view;
- (void)colorShadow:(UIView *)view;
- (void)colorLine:(UIView *)view inFrame:(CGRect)frame;
- (void)setBackgroundBlur:(UIView *)view;
- (void)setAppearance:(UIView *)view;
- (void)colorTitle:(UILabel *)view;
- (void)colorMessage:(UILabel *)view;
- (void)colorDate:(UILabel *)view;
- (void)setAppIconCornerRadius:(UIView *)view;
@end
