#import "CardStyle.h"
#include <math.h>
CGFloat VLGCardRadius(CGSize size,double percent) {
    if(!isfinite(size.width)||!isfinite(size.height)||size.width<=0||size.height<=0||size.width>4096||size.height>4096||!isfinite(percent))return NAN;
    // Continuous corners consume 1.528665 times the requested radius.
    // Stop just below the native smooth-pill branch. New 100% is the previous
    // 99.99% shape, with the entire control scaled continuously to that limit.
    return fmin(size.width,size.height)/(2*1.528665)*.9999*fmax(0,fmin(100,percent))/100;
}
double VLGLegacyRadiusPercent(double points) {
    if(!isfinite(points))return 70;
    // Preserve the approximate rounding of the former 84-point continuous preview
    // without rewriting the user's old keys. New edits use their own percent key.
    return fmax(0,fmin(100,points*1.528665/42*100));
}
CGColorRef VLGCreateShadedColor(CGColorRef color,double shade) {
    if(!color)return NULL;
    shade=isfinite(shade) ? fmax(-100,fmin(100,shade)) : 0;
    if(shade==0)return CGColorRetain(color);
    CGColorRef rgb=NULL;
    CGColorSpaceRef original=CGColorGetColorSpace(color);
    if(original && CGColorSpaceGetModel(original)==kCGColorSpaceModelRGB && CGColorGetNumberOfComponents(color)==4)rgb=CGColorRetain(color);
    else {
        CGColorSpaceRef target=CGColorSpaceCreateWithName(kCGColorSpaceExtendedSRGB);
        if(target){rgb=CGColorCreateCopyByMatchingToColorSpace(target,kCGRenderingIntentDefault,color,NULL);CGColorSpaceRelease(target);}
    }
    if(!rgb || CGColorGetNumberOfComponents(rgb)!=4){if(rgb)CGColorRelease(rgb);return CGColorRetain(color);}
    const CGFloat *source=CGColorGetComponents(rgb);CGFloat components[4];double amount=fabs(shade)/100.;
    for(unsigned i=0;i<3;i++) {
        double c=fmax(0,fmin(1,source[i]));
        components[i]=shade<0 ? c*(1-amount) : c+(1-c)*amount;
    }
    components[3]=source[3];
    CGColorRef result=CGColorCreate(CGColorGetColorSpace(rgb),components);CGColorRelease(rgb);
    return result ?: CGColorRetain(color);
}
