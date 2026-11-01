#pragma once
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
// Rounding is proportional to the actual outer card, never the inner material.
CGFloat VLGCardRadius(CGSize size, double percent);
double VLGLegacyRadiusPercent(double points);
// Independent tint/shade adjustment. Zero preserves the original color exactly.
CGColorRef VLGCreateShadedColor(CGColorRef color,double shade) CF_RETURNS_RETAINED;
