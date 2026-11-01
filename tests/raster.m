#import "../compat/ForegroundRaster.h"
#import <ImageIO/ImageIO.h>
#include <assert.h>
#include <math.h>
static CFDataRef pixels(V26ForegroundRaster *r) { return CGDataProviderCopyData(CGImageGetDataProvider(r.image)); }
static unsigned alphaAt(V26ForegroundRaster *r, CFDataRef d, size_t x, size_t y) {
    assert(x<CGImageGetWidth(r.image) && y<CGImageGetHeight(r.image));
    return CFDataGetBytePtr(d)[y*CGImageGetBytesPerRow(r.image)+x*4+3];
}
static void pattern(void *info, CGContextRef c) {
    CGContextSetRGBFillColor(c,1,0,0,1);CGContextFillRect(c,CGRectMake(0,0,80,70));
    CGContextSetRGBFillColor(c,0,0,1,1);CGContextFillRect(c,CGRectMake(80,0,80,70));
}
int main(int argc, const char **argv) { @autoreleasepool {
    V26ForegroundRaster *r=[V26ForegroundRaster new];
    CGColorRef border=CGColorCreateSRGB(0,1,0,.65), glow=CGColorCreateSRGB(0,1,0,.77);
    NSArray *key=@[@"green",@.65,@.77];
    assert([r updateSize:CGSizeMake(160,70) radius:8 scale:3 borderWidth:2 borderColor:border glowRadius:3.15 glowColor:glow styleKey:key]);
    assert(r.image && r.renderCount==1);
    CFDataRef data=pixels(r);size_t pad=r.padding*3;
    assert(alphaAt(r,data,pad+240,pad+105)==0);
    for (size_t y=0;y<6;++y) assert(abs((int)alphaAt(r,data,pad+240,pad+y)-166)<=1);
    for (size_t y=7;y<100;++y) assert(alphaAt(r,data,pad+240,pad+y)==0);
    unsigned nearHalo=alphaAt(r,data,pad-1,pad+105), farHalo=alphaAt(r,data,pad-8,pad+105), outerHalo=alphaAt(r,data,pad-15,pad+105);
    assert(nearHalo>farHalo && farHalo>outerHalo && nearHalo<=197);
    assert(alphaAt(r,data,pad-5,pad+105)>0);
    const unsigned char *b=CFDataGetBytePtr(data);size_t count=CFDataGetLength(data)/4, ink=0;
    for (size_t i=0;i<count;++i) if (b[4*i+3]) {
        ++ink;assert(b[4*i]==0 && b[4*i+2]==0 && abs(b[4*i+1]-b[4*i+3])<=1);
    }
    assert(ink>0);
    for (size_t x=0;x<CGImageGetWidth(r.image);++x) {
        assert(alphaAt(r,data,x,0)==0);assert(alphaAt(r,data,x,CGImageGetHeight(r.image)-1)==0);
    }
    CFRelease(data);
    CGImageRef first=r.image;
    for (unsigned i=0;i<1000;++i) assert([r updateSize:CGSizeMake(160,70) radius:8 scale:3 borderWidth:2 borderColor:border glowRadius:3.15 glowColor:glow styleKey:[key copy]]);
    assert(r.image==first && r.renderCount==1);
    // Settings, geometry and display-scale changes invalidate the one-entry cache.
    assert([r updateSize:CGSizeMake(161,70) radius:8 scale:3 borderWidth:2 borderColor:border glowRadius:3.15 glowColor:glow styleKey:key]);assert(r.renderCount==2);
    assert([r updateSize:CGSizeMake(161,70) radius:8 scale:2 borderWidth:2 borderColor:border glowRadius:3.15 glowColor:glow styleKey:key]);assert(r.renderCount==3);
    assert([r updateSize:CGSizeMake(161,70) radius:2 scale:2 borderWidth:2 borderColor:border glowRadius:3.15 glowColor:glow styleKey:key]);assert(r.renderCount==4);
    assert([r updateSize:CGSizeMake(161,70) radius:2 scale:2 borderWidth:2 borderColor:border glowRadius:3.15 glowColor:glow styleKey:@[@"changed-color"]]);assert(r.renderCount==5);
    assert([r updateSize:CGSizeMake(160,70) radius:0 scale:3 borderWidth:0 borderColor:NULL glowRadius:3.15 glowColor:glow styleKey:key]);
    data=pixels(r);pad=r.padding*3;
    // All pixels whose centers are within a square card are fully transparent.
    for (size_t y=pad;y<pad+210;++y) for (size_t x=pad;x<pad+480;++x) assert(alphaAt(r,data,x,y)==0);
    assert(alphaAt(r,data,pad-3,pad+105)>0);CFRelease(data);
    assert([r updateSize:CGSizeMake(160,70) radius:8 scale:3 borderWidth:0 borderColor:NULL glowRadius:0 glowColor:NULL styleKey:@[]]);assert(!r.image);
    // A colored CGPattern, as used by the existing gradient colorizer, must
    // retain its direction and alpha while the center remains transparent.
    CGPatternCallbacks cb={0,pattern,NULL};
    CGPatternRef pat=CGPatternCreate(NULL,CGRectMake(0,0,160,70),CGAffineTransformIdentity,160,70,kCGPatternTilingConstantSpacing,true,&cb);
    CGColorSpaceRef ps=CGColorSpaceCreatePattern(NULL);CGFloat a=.5;CGColorRef pc=CGColorCreateWithPattern(ps,pat,&a);
    assert([r updateSize:CGSizeMake(160,70) radius:0 scale:3 borderWidth:2 borderColor:pc glowRadius:0 glowColor:NULL styleKey:@[@"pattern"]]);
    data=pixels(r);pad=r.padding*3;b=CFDataGetBytePtr(data);
    size_t left=(pad+1)*CGImageGetBytesPerRow(r.image)+(pad+30)*4;
    size_t right=(pad+1)*CGImageGetBytesPerRow(r.image)+(pad+450)*4;
    assert(b[left]>b[left+2]+70 && b[right+2]>b[right]+70);
    assert(abs(b[left+3]-128)<=1 && abs(b[right+3]-128)<=1);
    assert(alphaAt(r,data,pad+240,pad+105)==0);CFRelease(data);
    CGColorRelease(pc);CGColorSpaceRelease(ps);CGPatternRelease(pat);
    CGColorSpaceRef p3=CGColorSpaceCreateWithName(kCGColorSpaceDisplayP3);CGFloat components[]={0,1,0,.65};
    CGColorRef p3color=CGColorCreate(p3,components);
    assert([r updateSize:CGSizeMake(160,70) radius:8 scale:3 borderWidth:2 borderColor:p3color glowRadius:3 glowColor:p3color styleKey:@[@"p3"]]);
    assert(CFEqual(CGColorSpaceGetName(CGImageGetColorSpace(r.image)),kCGColorSpaceDisplayP3));
    CGColorRelease(p3color);CGColorSpaceRelease(p3);
    first=r.image;NSUInteger renders=r.renderCount;
    dispatch_semaphore_t done=dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT,0),^{assert(![r updateSize:CGSizeMake(160,70) radius:0 scale:3 borderWidth:2 borderColor:border glowRadius:0 glowColor:NULL styleKey:key]);dispatch_semaphore_signal(done);});
    dispatch_semaphore_wait(done,DISPATCH_TIME_FOREVER);assert(first==r.image && renders==r.renderCount);
    assert(![r updateSize:CGSizeMake(NAN,70) radius:0 scale:3 borderWidth:2 borderColor:border glowRadius:0 glowColor:NULL styleKey:key]);assert(!r.image);
    assert(![r updateSize:CGSizeMake(4000,4000) radius:0 scale:3 borderWidth:2 borderColor:border glowRadius:3 glowColor:glow styleKey:key]);assert([r.failure isEqual:@"pixelBudget"] && !r.image);
    assert([r updateSize:CGSizeMake(160,70) radius:8 scale:3 borderWidth:2 borderColor:border glowRadius:3.15 glowColor:glow styleKey:key]);
    if (argc>1) {
        CGImageDestinationRef destination=CGImageDestinationCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:[NSString stringWithUTF8String:argv[1]]],CFSTR("public.png"),1,NULL);
        assert(destination);CGImageDestinationAddImage(destination,r.image,NULL);assert(CGImageDestinationFinalize(destination));CFRelease(destination);
    }
    CGPathRef outline=CGPathCreateWithRoundedRect(CGRectMake(0,0,160,70),23.5,23.5,NULL);
    assert([r updateSize:CGSizeMake(160,70) radius:23.5 scale:3 borderWidth:0 borderColor:NULL glowRadius:10 glowColor:glow styleKey:@[@"nativeOutline"] outline:outline]);
    data=pixels(r);pad=r.padding*3;
    for(size_t y=pad+72;y<pad+138;++y)for(size_t x=pad;x<pad+480;++x)assert(alphaAt(r,data,x,y)==0);
    assert(alphaAt(r,data,pad-1,pad+105)>0 && alphaAt(r,data,pad-20,pad+105)>0);
    b=CFDataGetBytePtr(data);
    for(size_t i=0;i<(size_t)CFDataGetLength(data)/4;++i)if(b[4*i+3])assert(b[4*i]==0 && b[4*i+2]==0 && abs(b[4*i+1]-b[4*i+3])<=1);
    CFRelease(data);first=r.image;renders=r.renderCount;
    CGPathRef equivalent=CGPathCreateCopy(outline);
    for(unsigned i=0;i<1000;++i)assert([r updateSize:CGSizeMake(160,70) radius:23.5 scale:3 borderWidth:0 borderColor:NULL glowRadius:10 glowColor:glow styleKey:@[@"nativeOutline"] outline:equivalent]);
    assert(first==r.image && renders==r.renderCount);CGPathRelease(equivalent);CGPathRelease(outline);
    puts("PASS: supplied native-perimeter exterior clipping, correctly scaled halo, no emitter contamination and geometric path cache reuse");
    CGColorRelease(border);CGColorRelease(glow);
    puts("PASS: production foreground raster has clear interior, exact 2-point border at 3x, colored external halo, transparent padding, pattern-color direction/alpha, one-entry reuse, key invalidation, disabled effects and bounded/off-main failure recovery");
} return 0; }
