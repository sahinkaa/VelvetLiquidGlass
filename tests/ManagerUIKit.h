#pragma once
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
@interface UIColor : NSObject
+ (instancetype)clearColor;
+ (instancetype)colorFromP3String:(NSString *)string;
@end
#import "../headers/Velvet2/Velvet2PrefsManager.h"
