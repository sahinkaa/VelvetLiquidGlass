#pragma once
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

// One cached, transparent foreground texture per notification decoration.
// No UIKit view capture, notification content or wallpaper is rasterized.
@interface V26ForegroundRaster : NSObject
@property(nonatomic, readonly) CGImageRef image;
@property(nonatomic, readonly) CGFloat padding;
@property(nonatomic, readonly) CGSize pointSize;
@property(nonatomic, readonly) NSUInteger renderCount;
@property(nonatomic, copy, readonly) NSString *failure;
- (BOOL)updateSize:(CGSize)size radius:(CGFloat)radius scale:(CGFloat)scale
      borderWidth:(CGFloat)borderWidth borderColor:(CGColorRef)borderColor
       glowRadius:(CGFloat)glowRadius glowColor:(CGColorRef)glowColor
         styleKey:(NSArray *)styleKey;
- (BOOL)updateSize:(CGSize)size radius:(CGFloat)radius scale:(CGFloat)scale
      borderWidth:(CGFloat)borderWidth borderColor:(CGColorRef)borderColor
       glowRadius:(CGFloat)glowRadius glowColor:(CGColorRef)glowColor
         styleKey:(NSArray *)styleKey outline:(CGPathRef)outline;
- (void)clear;
@end
