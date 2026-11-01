#import "StyleUIKit.h"
@interface UIColor (ColorizerFixture)
+ (instancetype)labelColor;
+ (instancetype)colorWithCGColor:(CGColorRef)color;
+ (instancetype)clearColor;
- (instancetype)colorWithAlphaComponent:(CGFloat)alpha;
+ (instancetype)colorFromGradient:(NSArray *)colors withDirection:(NSString *)direction inFrame:(CGRect)frame;
+ (instancetype)colorFromGradient:(NSArray *)colors withDirection:(NSString *)direction inFrame:(CGRect)frame flipY:(BOOL)flip;
@end
@interface UILabel (ColorizerFixture)
- (CGSize)sizeThatFits:(CGSize)size;
@end
@interface UITextView : UILabel
@end
@interface Velvet2PrefsManager (ColorizerFixture)
- (UIColor *)colorForKey:(NSString *)key withIdentifier:(NSString *)identifier;
- (CGFloat)alphaValueForKey:(NSString *)key withIdentifier:(NSString *)identifier;
@end
#define CCAvoidWhite 1
#define CCOnlyBrightColors 2
#define CCAvoidBlack 4
@interface CCColorCube : NSObject
- (NSArray *)extractColorsFromImage:(UIImage *)image flags:(NSUInteger)flags count:(NSUInteger)count;
@end
