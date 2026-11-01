#import "ColorizerUIKit.h"
#import "../compat/CardStyle.h"
#include <assert.h>
#include <math.h>
static NSDictionary *values,*colors;
static NSArray *lastGradient;
@implementation UIColor
+ (instancetype)rgb:(double)r g:(double)g b:(double)b {UIColor *c=[self new];c.CGColor=CGColorCreateSRGB(r,g,b,1);return c;}
+ (instancetype)colorWithCGColor:(CGColorRef)color {UIColor *c=[self new];c.CGColor=CGColorRetain(color);return c;}
+ (instancetype)blackColor{return [self rgb:0 g:0 b:0];}
+ (instancetype)whiteColor{return [self rgb:1 g:1 b:1];}
+ (instancetype)labelColor{return self.whiteColor;}
+ (instancetype)clearColor{return [self.blackColor colorWithAlphaComponent:0];}
- (instancetype)colorWithAlphaComponent:(CGFloat)a {UIColor *c=[UIColor new];c.CGColor=CGColorCreateCopyWithAlpha(self.CGColor,a);return c;}
+ (instancetype)colorFromGradient:(NSArray *)c withDirection:(NSString *)d inFrame:(CGRect)r {return [self colorFromGradient:c withDirection:d inFrame:r flipY:NO];}
+ (instancetype)colorFromGradient:(NSArray *)c withDirection:(NSString *)d inFrame:(CGRect)r flipY:(BOOL)flip {lastGradient=c;UIColor *color=[self new];color.CGColor=CGColorRetain((__bridge CGColorRef)c[0]);return color;}
- (void)dealloc{if(_CGColor)CGColorRelease(_CGColor);}
@end
@implementation UIResponder
@end
@implementation UIView
- (instancetype)init{if((self=[super init]))self.layer=[CALayer layer];return self;}
@end
@implementation UILabel
- (CGSize)sizeThatFits:(CGSize)s{return s;}
@end
@implementation UITextView
@end
@implementation Velvet2PrefsManager
+ (instancetype)sharedInstance{static id m;static dispatch_once_t once;dispatch_once(&once,^{m=[self new];});return m;}
- (id)settingForKey:(NSString *)key withIdentifier:(NSString *)identifier{return values[key];}
- (UIColor *)colorForKey:(NSString *)key withIdentifier:(NSString *)identifier{return colors[key];}
- (CGFloat)alphaValueForKey:(NSString *)key withIdentifier:(NSString *)identifier{return [values[key] doubleValue]/100.;}
@end
@implementation CCColorCube
- (NSArray *)extractColorsFromImage:(UIImage *)image flags:(NSUInteger)flags count:(NSUInteger)count {abort();}
@end
static void check(UIColor *c,double r,double g,double b,double a){const CGFloat *v=CGColorGetComponents(c.CGColor);assert(CGColorGetNumberOfComponents(c.CGColor)==4 && fabs(v[0]-r)<.001 && fabs(v[1]-g)<.001 && fabs(v[2]-b)<.001 && fabs(v[3]-a)<.001);}
int main(void){@autoreleasepool {
    values=@{@"backgroundEnabled":@YES,@"backgroundType":@"icon",@"backgroundIconAlpha":@100,@"messageEnabled":@YES,@"messageType":@"color",@"titleEnabled":@NO,@"dateEnabled":@NO};
    colors=@{@"messageColor":[UIColor rgb:0 g:.8 b:0]};
    Velvet2Colorizer *c=[[Velvet2Colorizer alloc] initWithIdentifier:@"fixture.app"];c.v26PaletteResolved=YES;c.iconColor=[UIColor rgb:1 g:1 b:0];
    UIView *tint=[UIView new];tint.frame=CGRectMake(0,0,380,84);[c colorBackground:tint];check(tint.backgroundColor,1,1,0,1);
    c.vlgDefaultTextColor=UIColor.whiteColor;
    UILabel *title=[UILabel new],*message=[UILabel new],*date=[UILabel new];
    [c colorTitle:title];[c colorMessage:message];[c colorDate:date];
    check(title.textColor,1,1,1,.9);check(message.textColor,0,.8,0,1);check(date.textColor,1,1,1,.5);
    NSMutableDictionary *next=[values mutableCopy];next[@"backgroundIconAlpha"]=@0;next[@"titleEnabled"]=@YES;next[@"titleType"]=@"color";next[@"dateEnabled"]=@YES;next[@"dateType"]=@"color";values=next;
    colors=@{@"messageColor":[UIColor rgb:0 g:.8 b:0],@"titleColor":[UIColor rgb:1 g:0 b:0],@"dateColor":[UIColor rgb:0 g:0 b:1]};
    [c colorBackground:tint];assert(CGColorGetAlpha(tint.backgroundColor.CGColor)==0);
    c.vlgDefaultTextColor=UIColor.whiteColor;[c colorTitle:title];[c colorMessage:message];[c colorDate:date];
    check(title.textColor,1,0,0,1);check(message.textColor,0,.8,0,1);check(date.textColor,0,0,1,1);
    // All six Icon Color branches use independent shade keys and preserve opacity.
    for(NSString *part in @[@"background",@"bannerBorder",@"shadow",@"title",@"message",@"date"]) {
        values=@{[part stringByAppendingString:@"Enabled"]:@YES,[part stringByAppendingString:@"Type"]:@"icon",
            [part stringByAppendingString:@"IconAlpha"]:@40,[part stringByAppendingString:@"IconShade"]:@50,
            @"bannerBorderWidth":@2,@"shadowWidth":@3};
        c=[[Velvet2Colorizer alloc] initWithIdentifier:@"fixture"];c.v26PaletteResolved=YES;c.iconColor=[UIColor rgb:.2 g:.4 b:.6];
        UIView *view=[part isEqual:@"title"]||[part isEqual:@"message"]||[part isEqual:@"date"] ? [UILabel new] : [UIView new];
        CGColorRef result=NULL;
        if([part isEqual:@"background"]) {[c colorBackground:view];result=view.backgroundColor.CGColor;}
        else if([part isEqual:@"bannerBorder"]) {[c colorBorder:view];result=view.layer.borderColor;}
        else if([part isEqual:@"shadow"]) {[c colorShadow:view];result=view.layer.shadowColor;}
        else {if([part isEqual:@"title"])[c colorTitle:(UILabel *)view];else if([part isEqual:@"message"])[c colorMessage:(UILabel *)view];else [c colorDate:(UILabel *)view];result=((UILabel *)view).textColor.CGColor;}
        UIColor *wrapped=[UIColor colorWithCGColor:result];check(wrapped,.6,.7,.8,.4);
        check(c.iconColor,.2,.4,.6,1); // Derived shades must never mutate the raw cached palette.
    }
    // Every retained color type applies shade independently before rasterization,
    // multiplies the picker alpha and preserves neutral defaults and raw inputs.
    for(NSString *part in @[@"background",@"bannerBorder",@"shadow",@"title",@"message",@"date"]) {
        for(NSString *type in ([part isEqual:@"shadow"] ? @[@"color"] : @[@"color",@"gradient"])) {
            NSString *suffix=[type isEqual:@"color"] ? @"Color" : @"Gradient";
            NSString *base=[part stringByAppendingString:suffix];
            values=@{[part stringByAppendingString:@"Enabled"]:@YES,[part stringByAppendingString:@"Type"]:type,
                [base stringByAppendingString:@"Alpha"]:@40,[base stringByAppendingString:@"Shade"]:@50,
                @"bannerBorderWidth":@2,@"shadowWidth":@3};
            UIColor *first=[[UIColor rgb:.2 g:.4 b:.6] colorWithAlphaComponent:.5],*second=[[UIColor rgb:.6 g:.4 b:.2] colorWithAlphaComponent:.75];
            colors=[type isEqual:@"color"] ? @{base:first} : @{[base stringByAppendingString:@"1"]:first,[base stringByAppendingString:@"2"]:second};
            c=[[Velvet2Colorizer alloc] initWithIdentifier:@"fixture"];c.v26PaletteResolved=YES;
            UIView *v=[@[@"title",@"message",@"date"] containsObject:part] ? [UILabel new] : [UIView new];
            v.frame=CGRectMake(0,0,380,84);CGColorRef result=NULL;
            if([part isEqual:@"background"]){[c colorBackground:v];result=v.backgroundColor.CGColor;}
            else if([part isEqual:@"bannerBorder"]){[c colorBorder:v];result=v.layer.borderColor;}
            else if([part isEqual:@"shadow"]){[c colorShadow:v];result=v.layer.shadowColor;}
            else {if([part isEqual:@"title"])[c colorTitle:(UILabel *)v];else if([part isEqual:@"message"])[c colorMessage:(UILabel *)v];else [c colorDate:(UILabel *)v];result=((UILabel *)v).textColor.CGColor;}
            check([UIColor colorWithCGColor:result],.6,.7,.8,.2);check(first,.2,.4,.6,.5);
            if([type isEqual:@"gradient"])check([UIColor colorWithCGColor:(__bridge CGColorRef)lastGradient[1]],.8,.7,.6,.3);
        }
    }
    values=@{@"titleEnabled":@YES,@"titleType":@"color",@"titleColorAlpha":@100,@"titleColorShade":@0};
    UIColor *chosen=[[UIColor rgb:.2 g:.4 b:.6] colorWithAlphaComponent:.7];colors=@{@"titleColor":chosen};
    c=[[Velvet2Colorizer alloc] initWithIdentifier:@"fixture"];[c colorTitle:title];assert(title.textColor==chosen);
    puts("PASS: static/gradient shade and opacity reach all eleven supported branches, preserve picker alpha and neutral identity and adjust both gradient endpoints before rendering");
    values=@{@"appearance":@"light"};c=[[Velvet2Colorizer alloc] initWithIdentifier:@"fixture"];[c colorTitle:title];[c colorMessage:message];[c colorDate:date];
    check(title.textColor,0,0,0,.9);check(message.textColor,0,0,0,.9);check(date.textColor,0,0,0,.5);
    values=@{@"appearance":@"dark"};c=[[Velvet2Colorizer alloc] initWithIdentifier:@"fixture"];[c colorTitle:title];check(title.textColor,1,1,1,.9);
    puts("PASS: six independent icon shades preserve opacity and raw palette; text defaults follow banner appearance without a brightness override");
    puts("PASS: production colorizer reaches exact zero/full background alpha, shares banner fallback rules and independently preserves explicit Title, Message and Date colors");
}return 0;}
