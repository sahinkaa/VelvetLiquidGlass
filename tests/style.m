#define V26_STYLE_HOST 1
#import "StyleUIKit.h"
#import "../compat/NotificationStyle.m"
#include <assert.h>
#import "../compat/SettingsStore.h"
#import "../compat/NativePreviewMaterial.h"
#import "../compat/BannerTemplate.h"
#import "../compat/IconCompletion.h"
#import "../compat/NativeOutline.h"
static NSDictionary *settings;
static unsigned samples, animationScope;
@implementation UIColor
+ (instancetype)blackColor{return [self rgb:0 g:0 b:0];}
+ (instancetype)whiteColor{return [self rgb:1 g:1 b:1];}
+ (instancetype)rgb:(double)r g:(double)g b:(double)b { UIColor *v=[self new];v.CGColor=CGColorCreateSRGB(r,g,b,1);return v; }
- (void)dealloc { if (_CGColor) CGColorRelease(_CGColor); }
@end
@implementation UIImage
- (void)setCGImage:(CGImageRef)v { if (v) CGImageRetain(v);if (_CGImage) CGImageRelease(_CGImage);_CGImage=v; }
- (void)dealloc { if (_CGImage) CGImageRelease(_CGImage); }
@end
@implementation UIResponder
@end
@implementation UITraitCollection
@end
@implementation UIView
- (UIResponder *)nextResponder { return [super nextResponder] ?: self.superview; }
- (instancetype)init { if ((self=[super init])) {self.layer=[CALayer layer];self.alpha=1;self.subviews=@[];self.traitCollection=[UITraitCollection new];self.traitCollection.userInterfaceStyle=1;self.traitCollection.displayScale=3;}return self; }
- (void)layoutIfNeeded {}
- (void)setFrame:(CGRect)v { _frame=v;self.bounds=CGRectMake(0,0,v.size.width,v.size.height); }
- (void)setBounds:(CGRect)v { _bounds=v;self.layer.bounds=v; }
- (void)insertSubview:(UIView *)v atIndex:(NSInteger)i { [v removeFromSuperview];NSMutableArray *a=[self.subviews mutableCopy];[a insertObject:v atIndex:MIN((NSUInteger)i,a.count)];self.subviews=a;v.superview=self; }
- (void)insertSubview:(UIView *)v aboveSubview:(UIView *)other { [self insertSubview:v atIndex:self.subviews.count]; }
- (void)removeFromSuperview { NSMutableArray *a=[self.superview.subviews mutableCopy];[a removeObjectIdenticalTo:self];self.superview.subviews=a;self.superview=nil; }
- (BOOL)isDescendantOfView:(UIView *)v { for (UIView *p=self;p;p=p.superview) if (p==v) return YES;return NO; }
- (CGRect)convertRect:(CGRect)r toView:(UIView *)v { return r; }
+ (void)performWithoutAnimation:(dispatch_block_t)b { ++animationScope;@try {b();}@finally {--animationScope;} }
+ (NSTimeInterval)inheritedAnimationDuration { return 1; }
@end
@implementation UIVisualEffect
+ (BOOL)supportsSecureCoding {return YES;}
- (void)encodeWithCoder:(NSCoder *)coder {[coder encodeInteger:self.marker forKey:@"marker"];}
- (instancetype)initWithCoder:(NSCoder *)coder {if((self=[super init]))self.marker=[coder decodeIntegerForKey:@"marker"];return self;}
@end
@implementation UIBlurEffect
+ (instancetype)effectWithStyle:(UIBlurEffectStyle)style { return [self new]; }
@end
@implementation UIVisualEffectView
- (instancetype)initWithEffect:(UIVisualEffect *)effect { if ((self=[super init])) self.effect=effect;return self; }
@end
@implementation UILabel
@end
@implementation UIImageView
@end
@implementation UIBezierPath
+ (instancetype)_continuousRoundedCARectBezierPath:(CGRect)r withRoundedCorners:(NSUInteger)corners cornerRadius:(CGSize)radii segments:(int)segments {abort();}
+ (instancetype)_continuousRoundedRectBezierPath:(CGRect)r withRoundedCorners:(NSUInteger)corners cornerRadius:(CGSize)radii segments:(int)segments {
    assert(corners==15 && segments==16 && radii.width==radii.height);
    return [self bezierPathWithRoundedRect:r cornerRadius:radii.width];
}
+ (instancetype)bezierPathWithRoundedRect:(CGRect)r cornerRadius:(double)c { UIBezierPath *p=[self new];p.CGPath=CGPathCreateWithRoundedRect(r,c,c,NULL);return p; }
- (void)dealloc { if (_CGPath) CGPathRelease(_CGPath); }
@end
@implementation NSValue (V26Geometry)
+ (instancetype)valueWithCGRect:(CGRect)r { return [self valueWithBytes:&r objCType:@encode(CGRect)]; }
- (CGRect)CGRectValue { CGRect r;[self getValue:&r size:sizeof(r)];return r; }
@end
@implementation UIGraphicsImageRendererFormat
+ (instancetype)defaultFormat { return [self new]; }
@end
@implementation UIGraphicsImageRendererContext
@end
@implementation UIGraphicsImageRenderer
- (instancetype)initWithSize:(CGSize)s format:(UIGraphicsImageRendererFormat *)f { if ((self=[super init])) self.size=s;return self; }
- (UIImage *)imageWithActions:(void (^)(UIGraphicsImageRendererContext *))actions {
    CGColorSpaceRef space=CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx=CGBitmapContextCreate(NULL,self.size.width,self.size.height,8,self.size.width*4,space,kCGImageAlphaPremultipliedLast|kCGBitmapByteOrder32Big);
    UIGraphicsImageRendererContext *context=[UIGraphicsImageRendererContext new];context.CGContext=ctx;actions(context);
    UIImage *image=[UIImage new];CGImageRef cg=CGBitmapContextCreateImage(ctx);image.CGImage=cg;CGImageRelease(cg);
    unsigned char *pixels=CGBitmapContextGetData(ctx);if (pixels[3]) image.color=[UIColor rgb:pixels[0]/255.0 g:pixels[1]/255.0 b:pixels[2]/255.0];
    CGContextRelease(ctx);CGColorSpaceRelease(space);return image;
}
@end
@implementation Velvet2PrefsManager
+ (instancetype)sharedInstance { static id value;static dispatch_once_t once;dispatch_once(&once,^{value=[self new];});return value; }
- (id)settingForKey:(NSString *)key withIdentifier:(NSString *)identifier { return V26PreferenceSupported(key) ? settings[key] : nil; }
@end
@implementation Velvet2Colorizer
- (instancetype)initWithIdentifier:(NSString *)identifier {if((self=[super init])){self.identifier=identifier;self.manager=Velvet2PrefsManager.sharedInstance;}return self;}
- (UIColor *)iconColor { if (!self.v26PaletteResolved) {++samples;self.v26PaletteResolved=YES;_iconColor=self.appIcon.color;}return _iconColor; }
- (void)colorBackground:(UIView *)v { assert(animationScope);v.backgroundColor=self.iconColor; }
- (void)colorBorder:(UIView *)v {
    BOOL enabled=[settings[@"bannerBorderEnabled"] boolValue];
    v.layer.borderWidth=enabled ? [settings[@"bannerBorderWidth"] doubleValue] : 0;
    v.layer.borderColor=enabled ? self.iconColor.CGColor : NULL;
}
- (void)colorShadow:(UIView *)v { v.layer.shadowRadius=[settings[@"shadowEnabled"] boolValue] ? [settings[@"shadowWidth"] doubleValue] : 0;v.layer.shadowColor=[settings[@"shadowEnabled"] boolValue] ? self.iconColor.CGColor : NULL;v.layer.shadowOpacity=1; }
- (void)colorLine:(UIView *)v inFrame:(CGRect)r { abort(); }
- (void)setBackgroundBlur:(UIView *)v {}
- (void)setAppearance:(UIView *)v {}
- (void)colorTitle:(UILabel *)v {v.textColor=self.iconColor;}
- (void)colorMessage:(UILabel *)v {v.textColor=self.iconColor;}
- (void)colorDate:(UILabel *)v {v.textColor=self.iconColor;}
- (void)setAppIconCornerRadius:(UIView *)v { abort(); }
@end
@interface IconDescriptor : NSObject
@property(nonatomic, strong) id prominentIconDescription;
@end
@implementation IconDescriptor
@end
@interface NCBadgedIconView : UIView
@property(nonatomic, strong) UIImageView *iconView;
- (UIImageView *)_prominentImageView;
@end
@implementation NCBadgedIconView
- (UIImageView *)_prominentImageView { return self.iconView; }
@end
@interface NCNotificationSeamlessContentView : UIView
@property(nonatomic, strong) NCBadgedIconView *badgedIconView;
@property(nonatomic, strong) IconDescriptor *badgedIconDescription;
@property(nonatomic, strong) UILabel *primaryTextLabel,*secondaryTextElementTopAligned,*secondaryTextElementBottomAligned,*secondaryTextElementTopAlignedGroupCollapsed,*dateLabel;
@end
@implementation NCNotificationSeamlessContentView
@end
@interface NCNotificationShortLookView : UIView
@property(nonatomic, strong) UIView *backgroundMaterialView;
@property(nonatomic, strong) NCNotificationSeamlessContentView *notificationContentView;
@property(nonatomic) double nativeRadius;
@property(nonatomic) unsigned nativeWrites;
- (double)_continuousCornerRadius;
- (void)_setContinuousCornerRadius:(double)r;
@end
@implementation NCNotificationShortLookView
- (double)_continuousCornerRadius { return self.nativeRadius; }
- (void)_setContinuousCornerRadius:(double)r { assert(animationScope || r==25);++self.nativeWrites;self.nativeRadius=r;V26RefreshForView(self); }
@end
@interface Request : NSObject
@property(nonatomic, copy) NSString *sectionIdentifier;
@end
@implementation Request
@end
@interface NCNotificationShortLookViewController : UIResponder
@property(nonatomic, strong) Request *notificationRequest;
@property(nonatomic, strong) NCNotificationShortLookView *root;
- (id)_notificationShortLookViewIfLoaded;
- (id)viewIfLoaded;
- (id)viewForPreview;
@end
@implementation NCNotificationShortLookViewController
- (id)_notificationShortLookViewIfLoaded { return self.root; }
- (id)viewIfLoaded { return self.root; }
- (id)viewForPreview { abort(); } // must never force the preview accessor
@end
@interface NCNotificationListCell : UIView
@end
@implementation NCNotificationListCell
@end
static NCNotificationShortLookViewController *fixture(NSString *icon) {
    NCNotificationShortLookViewController *owner=[NCNotificationShortLookViewController new];owner.notificationRequest=[Request new];owner.notificationRequest.sectionIdentifier=@"fixture-app";
    NCNotificationShortLookView *root=[NCNotificationShortLookView new];root.frame=CGRectMake(0,0,300,100);root.nativeRadius=25;root.nextResponder=owner;owner.root=root;
    root.backgroundMaterialView=[UIView new];root.backgroundMaterialView.frame=root.bounds;[root insertSubview:root.backgroundMaterialView atIndex:0];
    root.notificationContentView=[NCNotificationSeamlessContentView new];[root insertSubview:root.notificationContentView atIndex:1];
    root.notificationContentView.badgedIconDescription=[IconDescriptor new];root.notificationContentView.badgedIconDescription.prominentIconDescription=icon;
    NCBadgedIconView *badge=[NCBadgedIconView new];badge.iconView=[UIImageView new];badge.iconView.frame=CGRectMake(0,0,32,32);root.notificationContentView.badgedIconView=badge;
    [root.notificationContentView insertSubview:badge atIndex:0];[badge insertSubview:badge.iconView atIndex:0];return owner;
}
@interface BNContentViewControllerView : UIView
@end
@implementation BNContentViewControllerView
@end
@interface NCPlatterView : UIView
@end
@implementation NCPlatterView
@end
static unsigned nativeInitializers;
@interface NativePreviewFixture : UIView
- (instancetype)initWithRecipe:(NSInteger)recipe supportsGlass:(BOOL)glass;
@end
@implementation NativePreviewFixture
- (instancetype)initWithRecipe:(NSInteger)recipe supportsGlass:(BOOL)glass {assert(recipe==1 && glass);++nativeInitializers;return [super init];}
@end
@interface WrongNativePreview : UIView
- (instancetype)initWithRecipe:(double)recipe supportsGlass:(BOOL)glass;
@end
@implementation WrongNativePreview
- (instancetype)initWithRecipe:(double)recipe supportsGlass:(BOOL)glass {abort();}
@end
@interface TemplatePlatter : UIView
@property(nonatomic,strong) UIView *customContentView,*backgroundMaterialView;
@property(nonatomic) NSInteger materialRecipe;
@property(nonatomic) NSUInteger glassMode;
@property(nonatomic) BOOL supportsGlass;
- (void)updateWithGlassMode:(NSUInteger)mode;
@end
@implementation TemplatePlatter
- (void)updateWithGlassMode:(NSUInteger)mode {self.glassMode=mode;}
@end
@interface TemplateRoot : UIView
@property(nonatomic,strong) TemplatePlatter *platterView;
@property(nonatomic) NSInteger materialRecipe;
@property(nonatomic,getter=internalGlassMode) NSUInteger glassMode;
@property(nonatomic) BOOL supportsGlass;
@end
@implementation TemplateRoot
@end
static void checkCardSurface(void) {
    TemplateRoot *root=[TemplateRoot new];root.frame=CGRectMake(0,0,380,120);
    TemplatePlatter *platter=[TemplatePlatter new];platter.frame=CGRectMake(0,0,380,90);root.platterView=platter;[root insertSubview:platter atIndex:0];
    UIView *material=[UIView new];material.frame=CGRectMake(10,10,360,50);[platter insertSubview:material atIndex:0];
    UIVisualEffectView *effect=[UIVisualEffectView new];effect.frame=platter.bounds;effect.alpha=.7;
    [platter insertSubview:effect atIndex:1];effect.contentView=[UIView new];effect.contentView.frame=effect.bounds;[effect insertSubview:effect.contentView atIndex:0];
    platter.customContentView=effect;
    UILabel *text=[UILabel new];[effect.contentView insertSubview:text atIndex:0];UIView *tint=[UIView new];V26MarkOwnedDecoration(tint);
    assert(VLGPlaceCardTint(tint,root,material,text));
    assert(tint.superview==effect.contentView && effect.contentView.subviews.firstObject==tint);
    assert(VLGCardFrame(root,material).size.height==90 && tint.frame.size.height==90);
    assert(!effect.hidden && effect.alpha==.7 && material.alpha==1);
    for(unsigned i=0;i<1000;i++)assert(VLGPlaceCardTint(tint,root,material,text));
    assert(effect.contentView.subviews.count==2); // No duplicate tint or effect replacement.
    platter.customContentView=[UIView new]; // Reject a property pointing outside this card.
    UIView *fallback=[UIView new];[effect.contentView insertSubview:fallback atIndex:0];[fallback insertSubview:text atIndex:0];
    assert(VLGPlaceCardTint(tint,root,material,fallback) && tint.superview==fallback && fallback.subviews.firstObject==tint);
    assert(!VLGPlaceCardTint(tint,root,material,text)); // Never cover text by treating a label as a content container.
    puts("PASS: tint occupies the native foreground effect content below text, uses outer platter bounds, preserves glass visibility/alpha, stays idempotent and rejects foreign content hosts");
}
static void checkTemplate(void) {
    UIView *window=[UIView new];TemplateRoot *root=[TemplateRoot new];root.window=window;root.frame=CGRectMake(0,0,380,80);root.traitCollection.userInterfaceStyle=UIUserInterfaceStyleDark;
    root.materialRecipe=1;root.glassMode=2;root.supportsGlass=YES;
    TemplatePlatter *platter=[TemplatePlatter new];root.platterView=platter;[root insertSubview:platter atIndex:0];
    UIVisualEffectView *effect=[UIVisualEffectView new];effect.effect=[UIVisualEffect new];effect.effect.marker=42;effect.backgroundEffects=@[effect.effect];effect.contentEffects=@[];effect.effect=nil;effect.alpha=.75;
    [platter insertSubview:effect atIndex:0];UIView *owned=[UIView new];V26MarkOwnedDecoration(owned);[platter insertSubview:owned atIndex:1];
    platter.customContentView=effect; // Copy only its effect descriptions even when it hosts content.
    platter.backgroundMaterialView=[UIView new];platter.backgroundMaterialView.hidden=YES;platter.backgroundMaterialView.alpha=0;[platter insertSubview:platter.backgroundMaterialView atIndex:3];
    VLGCaptureBannerTemplate(root);
    [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    NSDictionary *profile=VLGReadBannerTemplate(UIUserInterfaceStyleDark);assert(profile && [profile[@"effects"] count]==1);
    TemplatePlatter *copy=[TemplatePlatter new];UIVisualEffectView *copiedEffect=[UIVisualEffectView new];[copy insertSubview:copiedEffect atIndex:0];
    copy.customContentView=[UIView new];[copy insertSubview:copy.customContentView atIndex:1];copy.backgroundMaterialView=[UIView new];[copy insertSubview:copy.backgroundMaterialView atIndex:2];
    assert(VLGApplyBannerTemplate(copy,profile));assert(copy.supportsGlass && copy.materialRecipe==1 && copy.glassMode==2);
    assert(((UIVisualEffect *)copiedEffect.backgroundEffects.firstObject).marker==42 && copiedEffect.alpha==.75 && copy.backgroundMaterialView.hidden && copy.backgroundMaterialView.alpha==0);
    NSMutableDictionary *invalid=[profile mutableCopy];invalid[@"effects"]=@[@{@"path":@[@999],@"effect":[NSData data]}];assert(!VLGApplyBannerTemplate(copy,invalid));
    invalid[@"effects"]=@[@{@"path":@[@0],@"effect":[@"garbage" dataUsingEncoding:NSUTF8StringEncoding],@"class":@"UIVisualEffectView"}];assert(!VLGApplyBannerTemplate(copy,invalid));
    assert(((UIVisualEffect *)copiedEffect.backgroundEffects.firstObject).marker==42); // Failure preserves an existing effect.
    puts("PASS: production banner-template background-only secure archive, native configuration copy, owned-view index exclusion, exact effect/visibility recovery and malformed-path/archive fallback");
}
@interface AutomaticTextProvider : NSObject
@property(nonatomic,strong) NSMapTable *registered;
@property(nonatomic,strong) UIColor *nativeColor;
@property(nonatomic) unsigned stops,resumes;
- (void)automaticallyUpdateView:(UIView *)view withStyle:(NSInteger)style;
- (void)stopAutomaticallyUpdatingView:(UIView *)view;
- (void)deliverNativeUpdate;
@end
@implementation AutomaticTextProvider
- (instancetype)init {if((self=[super init])){self.registered=NSMapTable.weakToStrongObjectsMapTable;self.nativeColor=UIColor.whiteColor;}return self;}
- (void)automaticallyUpdateView:(UIView *)view withStyle:(NSInteger)style {++self.resumes;[self.registered setObject:@(style) forKey:view];}
- (void)stopAutomaticallyUpdatingView:(UIView *)view {++self.stops;[self.registered removeObjectForKey:view];}
- (void)deliverNativeUpdate {for(UIView *view in self.registered.keyEnumerator.allObjects)if([view isKindOfClass:UILabel.class])((UILabel *)view).textColor=self.nativeColor;}
@end
@interface WrongTextProvider : NSObject
@property(nonatomic) unsigned stops;
- (void)automaticallyUpdateView:(id)view withStyle:(float)style;
- (void)stopAutomaticallyUpdatingView:(id)view;
@end
@implementation WrongTextProvider
- (void)automaticallyUpdateView:(id)view withStyle:(float)style {abort();}
- (void)stopAutomaticallyUpdatingView:(id)view {++self.stops;}
@end
int main(void) { @autoreleasepool {
    settings=@{@"backgroundEnabled":@YES,@"backgroundType":@"icon",@"shadowEnabled":@YES,@"shadowWidth":@3.15,@"shadowIconAlpha":@77,@"cornerRadiusEnabled":@YES,@"cornerRadiusPercent":@30,
        @"borderEnabled":@YES,@"lineEnabled":@YES,@"appIconHidden":@YES,@"appIconCornerRadiusCircle":@YES,@"stackDimmingViewHidden":@YES};
    NSMutableArray *jobs=[NSMutableArray array];V26Schedule scheduler=^(NSTimeInterval d,dispatch_block_t b){[jobs addObject:[b copy]];};
    NCNotificationShortLookViewController *owner=fixture(@"source-a");
    owner.root.backgroundMaterialView.alpha=0;owner.root.backgroundMaterialView.hidden=YES;
    NCNotificationListCell *cell=[NCNotificationListCell new];[cell insertSubview:owner.root atIndex:0];
    UIView *native=[UIView new];native.frame=owner.root.bounds;[owner.root insertSubview:native atIndex:0];
    UIVisualEffectView *back=[UIVisualEffectView new],*front=[UIVisualEffectView new];
    [native insertSubview:back atIndex:0];[native insertSubview:owner.root.backgroundMaterialView atIndex:1];[native insertSubview:front atIndex:2];[native insertSubview:owner.root.notificationContentView atIndex:3];
    NCNotificationSeamlessContentView *content=owner.root.notificationContentView;
    content.primaryTextLabel=[UILabel new];content.secondaryTextElementTopAligned=[UILabel new];content.secondaryTextElementBottomAligned=[UILabel new];content.secondaryTextElementTopAlignedGroupCollapsed=[UILabel new];content.dateLabel=[UILabel new];
    V26Decoration *state=V26State(owner);state.cycle=[[V26UpdateCycle alloc] initWithOwner:owner scheduler:scheduler];
    V26Refresh(owner);assert(state.cycle.scheduled && !state.tint.backgroundColor);
    state.captureTime=NSProcessInfo.processInfo.systemUptime+10;
    unsigned before=samples;for (unsigned i=0;i<1000;++i) V26Refresh(owner);assert(before==samples && jobs.count==1);
    UIImage *green=[UIImage new];green.color=[UIColor rgb:0 g:1 b:0];content.badgedIconView.iconView.image=green;
    V26RefreshForView(content.badgedIconView);
    assert(state.tint.backgroundColor==green.color && state.rasterActive && state.foreground.image);
    assert(!back.hidden && !front.hidden && !state.surface.blur.superview);
    assert(state.tint.superview==content && content.subviews.firstObject==state.tint);
    assert(owner.root.overrideUserInterfaceStyle==UIUserInterfaceStyleDark);
    assert(owner.root.backgroundMaterialView.hidden && owner.root.backgroundMaterialView.alpha==0);
    assert(!content.badgedIconView.hidden && content.badgedIconView.layer.cornerRadius==0);
    assert(content.primaryTextLabel.textColor==green.color && content.secondaryTextElementTopAligned.textColor==green.color);
    assert(content.secondaryTextElementBottomAligned.textColor==green.color && content.secondaryTextElementTopAlignedGroupCollapsed.textColor==green.color && content.dateLabel.textColor==green.color);
    assert(fabs(owner.root.nativeRadius-VLGCardRadius(owner.root.bounds.size,30))<.001 && owner.root.nativeWrites==1);
    NSUInteger renders=state.foreground.renderCount;before=samples;
    for (unsigned i=0;i<1000;++i) V26Refresh(owner);
    assert(state.foreground.renderCount==renders && samples==before && owner.root.nativeWrites==1);
    NSMutableDictionary *withBorder=[settings mutableCopy];withBorder[@"bannerBorderEnabled"]=@YES;withBorder[@"bannerBorderWidth"]=@5;settings=withBorder;
    V26Refresh(owner);assert(state.borderStyle.layer.borderWidth==0); // List never gets banner borders.
    UIView *bannerParent=[BNContentViewControllerView new];[bannerParent insertSubview:owner.root atIndex:0];
    V26Refresh(owner);assert(state.borderStyle.layer.borderWidth==5 && state.foreground.image);
    [cell insertSubview:owner.root atIndex:0];V26Refresh(owner);assert(state.borderStyle.layer.borderWidth==0);
    [owner.root removeFromSuperview];V26Refresh(owner);assert(!state.surface.blur.superview && !back.hidden && !front.hidden);
    // Native trait and visual-styling passes can replace the custom colors.
    // Reapply text without touching geometry or resampling a missing icon.
    UIColor *retained=state.lastColor;assert(retained);
    unsigned nativeWrites=owner.root.nativeWrites,sampled=samples;
    content.primaryTextLabel.textColor=nil;content.dateLabel.textColor=nil;
    VLGNativeTextDidUpdate(content);
    assert(content.primaryTextLabel.textColor==retained && content.dateLabel.textColor==retained);
    assert(samples==sampled && owner.root.nativeWrites==nativeWrites);
    // Native provider registration outlives a one-shot repaint. Only enabled
    // custom text is detached, then restored when that individual override ends.
    NSMutableDictionary *customText=[settings mutableCopy];
    for(NSString *part in @[@"title",@"message",@"date"]) {customText[[part stringByAppendingString:@"Enabled"]]=@YES;customText[[part stringByAppendingString:@"Type"]]=@"icon";}
    settings=customText;
    AutomaticTextProvider *provider=[AutomaticTextProvider new];
    for(UIView *view in @[content.primaryTextLabel,content.secondaryTextElementTopAligned,content.dateLabel,content.badgedIconView]) {
        [provider automaticallyUpdateView:view withStyle:0];
        VLGNativeTextProviderRegistered(content,view,0,provider);
    }
    assert(provider.stops==3 && provider.registered.count==1);
    [provider deliverNativeUpdate];assert(content.primaryTextLabel.textColor==retained && content.dateLabel.textColor==retained);
    // The first update following fresh registration must detach again, even if
    // registration happened during a full refresh or preference change.
    [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];assert(!state.textFollowupPending);
    [provider automaticallyUpdateView:content.primaryTextLabel withStyle:0];state.updating=YES;
    VLGNativeTextProviderRegistered(content,content.primaryTextLabel,0,provider);
    assert(state.textFollowupPending);state.updating=NO;
    [provider deliverNativeUpdate];assert(content.primaryTextLabel.textColor==provider.nativeColor);
    [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];
    [provider deliverNativeUpdate];assert(!state.textFollowupPending && content.primaryTextLabel.textColor==retained && provider.registered.count==1);
    customText=[settings mutableCopy];customText[@"titleEnabled"]=@NO;settings=customText;VLGReapplyText(content);
    assert([provider.registered objectForKey:content.primaryTextLabel]);
    [provider deliverNativeUpdate];assert(content.primaryTextLabel.textColor==provider.nativeColor && content.dateLabel.textColor==retained);
    WrongTextProvider *wrong=[WrongTextProvider new];
    VLGNativeTextProviderRegistered(content,content.dateLabel,0,wrong);assert(wrong.stops==0);
    // Recycled or unrelated view registrations never remove native styling.
    UIView *stranger=[UIView new];VLGNativeTextProviderRegistered(content,stranger,0,provider);assert(!objc_getAssociatedObject(stranger,&VLGTextProviderKey));
    puts("PASS: fresh native text registrations cannot overwrite enabled custom labels; disabled labels restore native registration, busy refreshes retain a deferred correction and wrong provider ABIs/unrelated views stay untouched");
    // Settings notification retains this request's palette while icon reloads.
    content.badgedIconView.iconView.image=nil;state.lastCapture=nil;
    state.captureTime=NSProcessInfo.processInfo.systemUptime+10;
    [NSNotificationCenter.defaultCenter postNotificationName:@"com.sahinkaa.velvetliquidglass/updateStyle" object:nil];
    assert(state.lastColor==retained && content.primaryTextLabel.textColor==retained);
    // A style-only cache-key transition may not replace text with fallback colors.
    owner.root.traitCollection.userInterfaceStyle=UIUserInterfaceStyleLight;
    V26Refresh(owner);assert(state.lastColor==retained && content.primaryTextLabel.textColor==retained);
    puts("PASS: post-native text restoration avoids geometry and sampling; preference/appearance changes retain same-request palette while the icon reloads");
    Request *request=[Request new];request.sectionIdentifier=@"other-app";owner.notificationRequest=request;content.badgedIconView.iconView.image=nil;V26RequestChanged(owner);assert(!state.tint.backgroundColor && state.cycle.scheduled);
    content.badgedIconView.iconView.image=green;V26Refresh(owner);assert(state.tint.backgroundColor==green.color && !state.cycle.scheduled);
    dispatch_semaphore_t done=dispatch_semaphore_create(0);before=owner.root.nativeWrites;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT,0),^{V26Refresh(owner);dispatch_semaphore_signal(done);});dispatch_semaphore_wait(done,DISPATCH_TIME_FOREVER);assert(owner.root.nativeWrites==before);
    assert(VLGNativePlatterABI(NativePreviewFixture.class));assert(!VLGNativePlatterABI(WrongNativePreview.class));assert(!VLGNativePlatterABI(NSObject.class));
    assert(VLGCreateNativePlatter(NativePreviewFixture.class) && nativeInitializers==1);assert(!VLGCreateNativePlatter(WrongNativePreview.class));
    puts("PASS: retained background/glow/corner/readiness engine, native glass unchanged, legacy feature keys ignored, banner-only border gating, all modern message labels styled, cache reuse and off-main avoidance");
    puts("PASS: native preview constructor exact ABI guard, recipe/support arguments and invalid-type rejection");
    CGPathRef outline=VLGCreateContinuousOutline(CGRectMake(0,0,200,80),23.5);assert(outline && !CGPathIsEmpty(outline));CGPathRelease(outline);
    assert(VLGBoundedCornerRadius(CGRectMake(0,0,200,80),100)==40);
    assert(isnan(VLGBoundedCornerRadius(CGRectZero,20)));
    outline=VLGCreateContinuousOutline(CGRectMake(0,0,200,80),100);assert(outline);
    assert(CGRectContainsRect(CGRectMake(0,0,200,80),CGPathGetPathBoundingBox(outline)));
    CGPathRef clamped=VLGCreateContinuousOutline(CGRectMake(0,0,200,80),40);assert(clamped && CGPathEqualToPath(outline,clamped));
    CGPathRelease(clamped);CGPathRelease(outline);
    __block unsigned completed=0,after=0;NSObject *imageToken=[NSObject new];
    void (^wrapped)(id)=VLGAfterImageCompletion(^(id value){assert(value==imageToken);++completed;assert(after==0);},^{++after;});
    wrapped(imageToken);assert(completed==1 && after==1);assert(!VLGAfterImageCompletion(nil,^{abort();}));
    @try {VLGAfterImageCompletion(^(id value){@throw [NSException exceptionWithName:@"nativeCompletion" reason:nil userInfo:nil];},^{abort();})(nil);assert(0);}
    @catch(NSException *exception){assert([exception.name isEqual:@"nativeCompletion"]);}
    NSUInteger generation=state.iconGeneration;
    VLGIconDidComplete(content.badgedIconView);VLGIconDidComplete(content.badgedIconView);
    checkCardSurface();
    checkTemplate(); // Also drains the coalesced icon-ready refresh on main.
    assert(state.iconGeneration==generation+1);
    puts("PASS: exact native outline CGSize/int ABI, unsigned/missing scalar getter handling, split effect arrays, coalesced image-completion refresh and original callback/exception preservation");
    puts("NOTE: UIKit doubles test control flow; private framework loading and visible preview require device validation.");
} return 0; }
