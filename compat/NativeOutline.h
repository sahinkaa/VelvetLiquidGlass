#pragma once
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
CGPathRef VLGCreateContinuousOutline(CGRect bounds,CGFloat radius) CF_RETURNS_RETAINED;

CGFloat VLGBoundedCornerRadius(CGRect bounds,CGFloat radius);
