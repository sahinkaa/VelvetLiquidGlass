#import "../compat/CardStyle.h"
#include <assert.h>
#include <math.h>
static void rgba(CGColorRef c,double r,double g,double b,double a) {
    const CGFloat *v=CGColorGetComponents(c);assert(CGColorGetNumberOfComponents(c)==4);
    assert(fabs(v[0]-r)<1e-9 && fabs(v[1]-g)<1e-9 && fabs(v[2]-b)<1e-9 && fabs(v[3]-a)<1e-9);
}
int main(void){@autoreleasepool {
    for(unsigned h=1;h<=4096;h+=7) {
        CGSize size=CGSizeMake(380,h);double side=fmin(380,h),previous=-1;
        for(double p=0;p<=100;p+=.25) {
            double r=VLGCardRadius(size,p);assert(isfinite(r) && r>=previous);previous=r;
            assert(2*r*1.528665<side); // Never enter Apple's discontinuous smooth-pill branch.
        }
        double old9999=side/(2*1.528665)*.9999;
        assert(fabs(VLGCardRadius(size,100)-old9999)<1e-10);
        assert(VLGCardRadius(size,99.99)<VLGCardRadius(size,100));
    }
    assert(VLGCardRadius(CGSizeMake(380,84),0)==0);
    assert(VLGCardRadius(CGSizeMake(380,200),100)>60);
    assert(isnan(VLGCardRadius(CGSizeMake(380,0),50)) && isnan(VLGCardRadius(CGSizeMake(NAN,84),50)));
    assert(VLGLegacyRadiusPercent(50)==100 && VLGLegacyRadiusPercent(-1)==0);
    CGColorSpaceRef p3=CGColorSpaceCreateWithName(kCGColorSpaceDisplayP3);CGFloat v[]={.2,.4,.6,.37};
    CGColorRef base=CGColorCreate(p3,v);CGColorSpaceRelease(p3);
    CGColorRef zero=VLGCreateShadedColor(base,0);assert(CGColorEqualToColor(base,zero));
    CGColorRef light=VLGCreateShadedColor(base,50),dark=VLGCreateShadedColor(base,-50),white=VLGCreateShadedColor(base,100),black=VLGCreateShadedColor(base,-100),invalid=VLGCreateShadedColor(base,NAN);
    rgba(light,.6,.7,.8,.37);rgba(dark,.1,.2,.3,.37);rgba(white,1,1,1,.37);rgba(black,0,0,0,.37);
    assert(CFEqual(CGColorGetColorSpace(base),CGColorGetColorSpace(light)) && CGColorEqualToColor(base,invalid));
    assert(!VLGCreateShadedColor(NULL,30));
    for(id c in @[(__bridge id)base,(__bridge id)zero,(__bridge id)light,(__bridge id)dark,(__bridge id)white,(__bridge id)black,(__bridge id)invalid])CGColorRelease((__bridge CGColorRef)c);
    puts("PASS: new 100% equals the former 99.99% geometry across card sizes, monotonic sweep stays below the native branch; signed shades preserve neutral color, P3 space and opacity with exact black/white endpoints");
}return 0;}
