#import "UIKit/UIKit.h"
#import "../headers/Velvet2/ColorDetection.h"
#include <assert.h>

static _Thread_local CGContextRef currentContext;
@implementation UIColor {
    CGColorRef _color;
}
+ (instancetype)colorWithRed:(CGFloat)r green:(CGFloat)g blue:(CGFloat)b alpha:(CGFloat)a {
    UIColor *color = [self new];
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGFloat components[] = {r, g, b, a};
    color->_color = CGColorCreate(space, components);
    CGColorSpaceRelease(space);
    return color;
}
- (CGColorRef)CGColor { return _color; }
- (void)dealloc { if (_color) CGColorRelease(_color); }
@end
@implementation UIImage {
    UIColor *_color;
    BOOL _empty;
    CGImageRef _raster;
}
- (instancetype)initWithColor:(UIColor *)color empty:(BOOL)empty {
    if ((self = [super init])) { _color = color; _empty = empty; }
    return self;
}
- (instancetype)initWithRaster:(CGImageRef)image {
    if ((self = [super init])) _raster = CGImageRetain(image);
    return self;
}
- (CGImageRef)CGImage { return _raster; }
- (void)drawInRect:(CGRect)rect {
    if (_raster) CGContextDrawImage(currentContext, rect, _raster);
    else if (!_empty) { CGContextSetFillColorWithColor(currentContext, _color.CGColor); CGContextFillRect(currentContext, rect); }
}
- (void)dealloc { if (_raster) CGImageRelease(_raster); }
@end
@implementation UIGraphicsImageRendererFormat
+ (instancetype)defaultFormat { return [self new]; }
@end
@implementation UIGraphicsImageRendererContext
@end
@implementation UIGraphicsImageRenderer {
    CGSize _size;
}
- (instancetype)initWithSize:(CGSize)size format:(UIGraphicsImageRendererFormat *)format {
    if ((self = [super init])) _size = size;
    return self;
}
- (UIImage *)imageWithActions:(void (^)(UIGraphicsImageRendererContext *))actions {
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef context = CGBitmapContextCreate(NULL, _size.width, _size.height, 8, _size.width * 4, space, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space);
    UIGraphicsImageRendererContext *wrapper = [UIGraphicsImageRendererContext new];
    wrapper.CGContext = context;
    CGContextRef previous = currentContext;
    currentContext = context;
    @try { actions(wrapper); } @finally { currentContext = previous; }
    CGImageRef image = CGBitmapContextCreateImage(context);
    UIImage *result = [[UIImage alloc] initWithRaster:image];
    CGImageRelease(image);
    CGContextRelease(context);
    return result;
}
@end
int main(void) {
    @autoreleasepool {
        CCColorCube *cube = [CCColorCube new];
        UIImage *drawable = [[UIImage alloc] initWithColor:[UIColor colorWithRed:0.9 green:0.2 blue:0.3 alpha:1] empty:NO];
        assert(drawable.CGImage == NULL); // Reproduces the old nil-CGImage path.
        NSArray *colors = [cube extractColorsFromImage:drawable flags:CCAvoidWhite|CCOnlyBrightColors count:1];
        assert(colors.count == 1);
        const CGFloat *rgba = CGColorGetComponents([colors[0] CGColor]);
        assert(fabs(rgba[0] - 0.9) < 0.02 && fabs(rgba[1] - 0.2) < 0.02);
        UIImage *transparent = [[UIImage alloc] initWithColor:nil empty:YES];
        assert([[cube extractColorsFromImage:transparent flags:0 count:1] count] == 0);
        assert([[cube extractColorsFromImage:nil flags:0 count:1] count] == 0);
        UIImage *gray = [[UIImage alloc] initWithColor:[UIColor colorWithRed:0.45 green:0.45 blue:0.45 alpha:1] empty:NO];
        assert([[cube extractColorsFromImage:gray flags:CCOnlyBrightColors count:1] count] == 0);
        assert([[cube extractColorsFromImage:gray flags:CCAvoidBlack count:1] count] == 1);
        UIImage *translucent = [[UIImage alloc] initWithColor:[UIColor colorWithRed:0.9 green:0.2 blue:0.3 alpha:0.5] empty:NO];
        colors = [cube extractColorsFromImage:translucent flags:CCOnlyBrightColors count:1];
        assert(colors.count == 1);
        rgba = CGColorGetComponents([colors[0] CGColor]);
        assert(fabs(rgba[0] - 0.9) < 0.03);
        puts("PASS: production ColorCube with drawable non-bitmap images, bounded rasterization, transparent and nil inputs, dark-icon fallback and premultiplied alpha");
    }
    return 0;
}
