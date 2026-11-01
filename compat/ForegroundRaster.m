#import "ForegroundRaster.h"
#import <QuartzCore/QuartzCore.h>
#include <math.h>

static BOOL V26WideColor(CGColorRef color) {
    CGColorSpaceRef space=color ? CGColorGetColorSpace(color) : NULL;
    // Colored patterns may carry a Display P3 gradient image even though
    // the pattern color itself has no RGB base color-space metadata.
    return space && (CGColorSpaceGetModel(space)==kCGColorSpaceModelPattern || CGColorSpaceIsWideGamutRGB(space));
}
@interface V26ForegroundRaster () {
    CGImageRef _image;
    CGPathRef _outline;
}
@property(nonatomic, copy) NSArray *key;
@property(nonatomic) CGFloat padding;
@property(nonatomic) CGSize pointSize;
@property(nonatomic) NSUInteger renderCount;
@property(nonatomic, copy) NSString *failure;
@end
@implementation V26ForegroundRaster
- (CGImageRef)image { return _image; }
- (void)dealloc { if (_image) CGImageRelease(_image);if(_outline)CGPathRelease(_outline); }
- (void)clear {
    if (_image) CGImageRelease(_image);
    _image=NULL;if(_outline)CGPathRelease(_outline);_outline=NULL;self.key=nil;self.padding=0;self.pointSize=CGSizeZero;self.failure=nil;
}
- (BOOL)updateSize:(CGSize)size radius:(CGFloat)radius scale:(CGFloat)scale
      borderWidth:(CGFloat)borderWidth borderColor:(CGColorRef)borderColor
       glowRadius:(CGFloat)glowRadius glowColor:(CGColorRef)glowColor
         styleKey:(NSArray *)styleKey {
    return [self updateSize:size radius:radius scale:scale borderWidth:borderWidth borderColor:borderColor glowRadius:glowRadius glowColor:glowColor styleKey:styleKey outline:NULL];
}
- (BOOL)updateSize:(CGSize)size radius:(CGFloat)radius scale:(CGFloat)scale
      borderWidth:(CGFloat)borderWidth borderColor:(CGColorRef)borderColor
       glowRadius:(CGFloat)glowRadius glowColor:(CGColorRef)glowColor
         styleKey:(NSArray *)styleKey outline:(CGPathRef)outline {
    if (!NSThread.isMainThread) return NO;
    if (!isfinite(size.width) || !isfinite(size.height) || size.width<=0 || size.height<=0 ||
        size.width>4096 || size.height>4096 || !isfinite(radius) || radius<0 ||
        !isfinite(scale) || scale<1 || scale>4 || !isfinite(borderWidth) || borderWidth<0 || borderWidth>64 ||
        !isfinite(glowRadius) || glowRadius<0 || glowRadius>64 || !styleKey) {
        [self clear];self.failure=@"invalidParameters";return NO;
    }
    radius=MIN(radius,MIN(size.width,size.height)/2);
    borderWidth=MIN(borderWidth,MIN(size.width,size.height)/2);
    BOOL border=borderColor && borderWidth>0 && CGColorGetAlpha(borderColor)>0;
    BOOL glow=glowColor && glowRadius>0 && CGColorGetAlpha(glowColor)>0;
    // Numeric geometry and effective preference values are stable keys even
    // when a gradient recreates an equivalent CGPattern color on each layout.
    BOOL wide=V26WideColor(borderColor) || V26WideColor(glowColor);
    NSArray *key=@[@(wide),@(size.width),@(size.height),@(radius),@(scale),@(borderWidth),@(glowRadius),@(border),@(glow),[styleKey copy]];
    BOOL sameOutline=(!outline && !_outline) || (outline && _outline && CGPathEqualToPath(outline,_outline));
    if ([self.key isEqual:key] && sameOutline) return self.failure==nil;
    [self clear];self.key=key;self.failure=nil;if(outline)_outline=CGPathCreateCopy(outline);
    if (!border && !glow) return YES;
    CGFloat padding=glow ? ceil(glowRadius*3+3) : 1;
    size_t width=(size_t)ceil((size.width+2*padding)*scale);
    size_t height=(size_t)ceil((size.height+2*padding)*scale);
    // Limit each CPU texture to 16 MiB. Allocation failure falls back to the
    // baseline foreground and is cached until the input key changes.
    if (!width || !height || width>4096 || height>4096 || width*height>4*1024*1024) {
        self.failure=@"pixelBudget";return NO;
    }
    CGColorSpaceRef space=wide ? CGColorSpaceCreateWithName(kCGColorSpaceDisplayP3) : CGColorSpaceCreateDeviceRGB();
    if (!space) {self.failure=@"colorSpace";return NO;}
    CGContextRef context=CGBitmapContextCreate(NULL,width,height,8,width*4,space,kCGImageAlphaPremultipliedLast|kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space);
    if (!context) {self.failure=@"allocation";return NO;}
    CGContextClearRect(context,CGRectMake(0,0,width,height));
    CGContextTranslateCTM(context,0,height);CGContextScaleCTM(context,1,-1);
    if(outline) {
        CGAffineTransform transform=CGAffineTransformMake(scale,0,0,scale,padding*scale,padding*scale);
        CGPathRef pixels=CGPathCreateCopyByTransformingPath(outline,&transform);
        if(!pixels){CGContextRelease(context);self.failure=@"outlineAllocation";return NO;}
        if(glow) {
            CGContextSaveGState(context);
            CGContextAddRect(context,CGRectMake(0,0,width,height));CGContextAddPath(context,pixels);CGContextEOClip(context);
            CGFloat distance=width+256;
            CGContextSetShadowWithColor(context,CGSizeMake(distance,0),glowRadius*scale,glowColor);
            CGContextTranslateCTM(context,-distance,0);
            CGPathRef ring=CGPathCreateCopyByStrokingPath(pixels,NULL,MAX(1,MIN(16,glowRadius))*scale,kCGLineCapRound,kCGLineJoinRound,10);
            if(!ring){CGPathRelease(pixels);CGContextRelease(context);self.failure=@"ringAllocation";return NO;}
            CGContextAddPath(context,ring);CGPathRelease(ring);
            CGContextSetRGBFillColor(context,1,1,1,1);CGContextFillPath(context);CGContextRestoreGState(context);
        }
        if(border) {
            CGContextSaveGState(context);
            CGContextTranslateCTM(context,padding*scale,padding*scale);CGContextScaleCTM(context,scale,scale);
            CGContextAddPath(context,outline);CGContextClip(context);CGContextAddPath(context,outline);
            CGContextSetLineWidth(context,2*borderWidth);CGContextSetStrokeColorWithColor(context,borderColor);CGContextStrokePath(context);CGContextRestoreGState(context);
        }
        CGPathRelease(pixels);
    } else {
    // Use the same public continuous-corner renderer as the tint layer.
    // A circular CGPath plus a continuous UIKit corner leaves a visible seam.
    CALayer *shape=[CALayer layer];
    shape.bounds=CGRectMake(0,0,size.width,size.height);
    shape.cornerRadius=radius;shape.cornerCurve=kCACornerCurveContinuous;
    CGColorRef white=CGColorCreateSRGB(1,1,1,1);shape.backgroundColor=white;CGColorRelease(white);
    if (glow) {
        CGContextRef coverage=CGBitmapContextCreate(NULL,width,height,8,width*4,CGBitmapContextGetColorSpace(context),kCGImageAlphaPremultipliedLast|kCGBitmapByteOrder32Big);
        if (!coverage) {CGContextRelease(context);self.failure=@"coverageAllocation";return NO;}
        CGContextTranslateCTM(coverage,padding*scale,padding*scale);CGContextScaleCTM(coverage,scale,scale);
        [shape renderInContext:coverage];
        CGImageRef silhouette=CGBitmapContextCreateImage(coverage);CGContextRelease(coverage);
        if (!silhouette) {CGContextRelease(context);self.failure=@"silhouetteAllocation";return NO;}
        CGRect imageBounds=CGRectMake(0,0,width,height);
        CGFloat distance=width+256;
        CGContextSaveGState(context);
        CGContextSetShadowWithColor(context,CGSizeMake(distance,0),glowRadius*scale,glowColor);
        CGContextDrawImage(context,CGRectOffset(imageBounds,-distance,0),silhouette);
        CGContextRestoreGState(context);
        // Smoothly subtract the identical native silhouette. The emitter is
        // off-canvas, so no white/black source pixels survive at its corners.
        CGContextSaveGState(context);CGContextSetBlendMode(context,kCGBlendModeDestinationOut);
        CGContextDrawImage(context,imageBounds,silhouette);CGContextRestoreGState(context);
        CGImageRelease(silhouette);
    }
    if (border) {
        shape.backgroundColor=NULL;shape.borderWidth=borderWidth;shape.borderColor=borderColor;
        CGContextSaveGState(context);
        CGContextTranslateCTM(context,padding*scale,padding*scale);CGContextScaleCTM(context,scale,scale);
        [shape renderInContext:context];CGContextRestoreGState(context);
    }
    }
    _image=CGBitmapContextCreateImage(context);CGContextRelease(context);
    if (!_image) {self.failure=@"imageCreation";return NO;}
    self.padding=padding;self.pointSize=CGSizeMake(width/scale,height/scale);++self.renderCount;
    return YES;
}
@end
