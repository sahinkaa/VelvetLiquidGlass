#import "NativeOutline.h"
#import "Runtime.h"
#ifdef V26_STYLE_HOST
#import "../tests/StyleUIKit.h"
#else
#import <UIKit/UIKit.h>
#endif
#import <objc/runtime.h>
#import <objc/message.h>
#include <string.h>
#include <math.h>
@interface VLGOutlineEntry : NSObject {
@public CGPathRef path;
}
@end
@implementation VLGOutlineEntry
- (void)dealloc {if(path)CGPathRelease(path);}
@end
CGFloat VLGBoundedCornerRadius(CGRect bounds,CGFloat radius) {
    if(!isfinite(radius) || radius<0 || !isfinite(bounds.size.width) || !isfinite(bounds.size.height) || bounds.size.width<=0 || bounds.size.height<=0)return NAN;
    return MIN(radius,MIN(bounds.size.width,bounds.size.height)/2);
}
CGPathRef VLGCreateContinuousOutline(CGRect bounds,CGFloat radius) {
    if(!NSThread.isMainThread || !isfinite(radius) || radius<0 || !isfinite(bounds.origin.x) || !isfinite(bounds.origin.y) || !isfinite(bounds.size.width) || !isfinite(bounds.size.height) || bounds.size.width<=0 || bounds.size.height<=0 || bounds.size.width>4096 || bounds.size.height>4096)return NULL;
    radius=VLGBoundedCornerRadius(bounds,radius);
    static NSCache *cache;static dispatch_once_t once;dispatch_once(&once,^{cache=[NSCache new];cache.countLimit=64;});
    NSArray *key=@[@(bounds.origin.x),@(bounds.origin.y),@(bounds.size.width),@(bounds.size.height),@(radius)];
    VLGOutlineEntry *entry=[cache objectForKey:key];if(entry && entry->path)return CGPathCreateCopy(entry->path);
    Class cls=UIBezierPath.class;
    for(NSString *name in @[@"_continuousRoundedRectBezierPath:withRoundedCorners:cornerRadius:segments:"]) {
        SEL selector=NSSelectorFromString(name);Method method=class_getClassMethod(cls,selector);
        if(!method || method_getNumberOfArguments(method)!=6)continue;
        const char *arguments[]={@encode(CGRect),@encode(NSUInteger),@encode(CGSize),@encode(int)};
        char type[160]={0};method_getReturnType(method,type,sizeof(type));if(type[0]!='@')continue;
        BOOL valid=YES;
        for(unsigned i=0;i<4;++i){method_getArgumentType(method,i+2,type,sizeof(type));if(strcmp(type,arguments[i]))valid=NO;}
        if(!valid){V26Report(@"outline.ABIMismatch",@YES);continue;}
        @try {
            // The regular wrapper clamps continuous corner radii. The CA
            // wrapper explicitly disables that clamping and produces pointed
            // overhangs at pill-sized radii. Keep the verified CGSize/int ABI.
            id result=((id(*)(id,SEL,CGRect,NSUInteger,CGSize,int))objc_msgSend)(cls,selector,bounds,(NSUInteger)15,CGSizeMake(radius,radius),16);
            if([result isKindOfClass:UIBezierPath.class] && ((UIBezierPath *)result).CGPath) {
                CGPathRef candidate=((UIBezierPath *)result).CGPath;
                CGRect extent=CGPathGetPathBoundingBox(candidate);
                if(CGRectIsNull(extent) || !CGRectContainsRect(CGRectInset(bounds,-.01,-.01),extent)) {V26Report(@"outline.rejectedExtent",@YES);continue;}
                entry=[VLGOutlineEntry new];entry->path=CGPathCreateCopy(candidate);
                if(!entry->path)return NULL;
                [cache setObject:entry forKey:key];V26Report(@"outline.nativeSelector",name);
                return CGPathCreateCopy(entry->path);
            }
        } @catch(NSException *exception){V26Report(@"outline.optionalFailure",exception.name);}
    }
    return NULL;
}
