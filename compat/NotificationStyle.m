#ifdef V26_STYLE_HOST
#import "../tests/StyleUIKit.h"
#else
#import "../headers/HeadersTweak.h"
#endif
#import "Runtime.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import "UpdateCycle.h"
#import "NativeShape.h"
#import "DecorationSurface.h"
#import "ForegroundRaster.h"
#import "NotificationStyle.h"
#import "NativeOutline.h"
#import "CardStyle.h"
#import "CardSurface.h"
#import "BannerTypography.h"

void V26Refresh(id owner);
static V26PaletteCache *V26Cache(void) {
    static V26PaletteCache *cache; static dispatch_once_t once;
    dispatch_once(&once, ^{ cache = [V26PaletteCache new]; }); return cache;
}
static char V26DecorationKey, V26RootIDKey, VLGIconGenerationKey;
static NSHashTable *V26ActiveStates;
static NSUInteger V26NextStateID, V26NextRootID;

@interface V26Decoration : NSObject
@property(nonatomic, weak) id owner;
@property(nonatomic) NSUInteger serial;
@property(nonatomic, weak) UIView *paintedRoot;
@property(nonatomic, strong) UIView *tint;
@property(nonatomic, strong) UIView *glow;
@property(nonatomic, strong) UIView *glowStyle;
@property(nonatomic, strong) V26ForegroundRaster *foreground;
@property(nonatomic) BOOL rasterActive;
@property(nonatomic, strong) V26DecorationSurface *surface;
@property(nonatomic, strong) UIView *borderStyle;
@property(nonatomic, strong) NSArray *presentationFingerprint;
@property(nonatomic) unsigned presentationEvents;
@property(nonatomic) BOOL settledPresentationRecorded;
@property(nonatomic, strong) id observer;
@property(nonatomic) BOOL updating;
@property(nonatomic) BOOL refreshing;
@property(nonatomic) BOOL textUpdating;
@property(nonatomic) BOOL textFollowupPending;
@property(nonatomic, strong) V26UpdateCycle *cycle;
@property(nonatomic, strong) V26NativeShape *shape;
@property(nonatomic, weak) id request;
@property(nonatomic, strong) id paletteKey;
@property(nonatomic, strong) UIImage *lastImage;
@property(nonatomic, strong) UIImage *lastCapture;
@property(nonatomic, strong) UIColor *lastColor;
@property(nonatomic) BOOL lastSampleFailed;
@property(nonatomic) NSTimeInterval captureTime;
@property(nonatomic) BOOL retryCapture;
@property(nonatomic) NSUInteger iconGeneration;
@property(nonatomic) BOOL palettePending;
@property(nonatomic) NSTimeInterval startedAt;
@property(nonatomic) BOOL firstPaint;
@property(nonatomic) BOOL paletteReported;
@property(nonatomic, copy) NSString *pendingStage;
@property(nonatomic, copy) NSString *waitReason;

@end
@implementation V26Decoration
- (instancetype)init {
    if ((self = [super init])) {
        self.tint = [UIView new];
        self.tint.userInteractionEnabled = NO;
        self.tint.accessibilityElementsHidden = YES;
        self.tint.clipsToBounds = YES;
        self.glowStyle=[UIView new];
        self.foreground=[V26ForegroundRaster new];
        self.surface = [V26DecorationSurface new];
        self.borderStyle=[UIView new];
        V26MarkOwnedDecoration(self.tint);
        self.glow = [UIView new];
        self.glow.userInteractionEnabled = NO;
        self.glow.accessibilityElementsHidden = YES;
        self.glow.clipsToBounds = NO;
        V26MarkOwnedDecoration(self.glow);
        __weak V26Decoration *weakSelf = self;
        self.observer = [NSNotificationCenter.defaultCenter addObserverForName:@"com.sahinkaa.velvetliquidglass/updateStyle" object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
            V26Decoration *state = weakSelf;
            // Preferences change derived shades, not the icon's raw palette.
            // Keep it as a fallback while the native icon reloads for new traits.
            [V26Cache() clear]; state.lastImage = nil; state.lastCapture = nil;
            [state.cycle reset]; V26Refresh(state.owner);
        }];
    }
    return self;
}
- (void)dealloc {
    if (self.observer) [NSNotificationCenter.defaultCenter removeObserver:self.observer];
    [self.tint removeFromSuperview];
    [self.glow removeFromSuperview];
    [self.surface.blur removeFromSuperview];

}
@end

static UIView *V26View(id object) { return [object isKindOfClass:UIView.class] ? object : nil; }
static UILabel *V26Label(id object) { return [object isKindOfClass:UILabel.class] ? object : nil; }
static UIView *V26Find(UIView *root, Class cls) {
    if (!root || !cls) return nil;
    NSMutableArray *pending = [NSMutableArray arrayWithObject:root];
    for (NSUInteger index = 0; index < pending.count && index < 64; ++index) {
        UIView *view = pending[index];
        if ([view isKindOfClass:cls]) return view;
        if (pending.count < 128) [pending addObjectsFromArray:view.subviews];
    }
    return nil;
}
static UILabel *V26MessageElement(UIView *element) {
    UIView *target=V26Label(element) ?: V26Find(element,UILabel.class);
    Class textView=NSClassFromString(@"UITextView");
    if (!target && textView) target=[element isKindOfClass:textView] ? element : V26Find(element,textView);
    if (target) V26Report(@"message.resolvedClass",NSStringFromClass(target.class));
    return (UILabel *)target;
}
static UIImage *V26Icon(id content, UIView *iconView, V26Decoration *state) {
    id badged = V26Object(content, @"badgedIconView");
    NSUInteger generation=[objc_getAssociatedObject(badged,&VLGIconGenerationKey) unsignedIntegerValue];
    if(state.iconGeneration!=generation) {
        state.iconGeneration=generation;state.lastCapture=nil;state.lastImage=nil;state.lastSampleFailed=NO;
        [state.cycle reset];
    }
    id prominent = V26Object(badged, @"_prominentImageView");
    if (prominent) V26Report(@"icon.nativeImageViewClass", NSStringFromClass(object_getClass(prominent)));
    id image = V26Object(prominent, @"image");
    if (![image isKindOfClass:UIImage.class]) image = V26Object(content, @"prominentIcon") ?: V26Object(content, @"subordinateIcon");
    if ([image isKindOfClass:UIImage.class]) return image;
    UIImageView *imageView = (UIImageView *)V26Find(iconView, UIImageView.class);
    if ([imageView.image isKindOfClass:UIImage.class]) return imageView.image;
    if (!iconView || iconView.bounds.size.width <= 0 || iconView.bounds.size.height <= 0) return nil;
    NSTimeInterval now = NSProcessInfo.processInfo.systemUptime;
    if (!state.retryCapture && state.lastCapture && now - state.captureTime < 1) return state.lastCapture;
    state.captureTime = now;
    // Use only the dedicated icon's existing rendered layer, with bounded output.
    @try {
        UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
        format.scale = 1;
        format.opaque = NO;
        format.preferredRange = UIGraphicsImageRendererFormatRangeStandard;
        state.lastCapture = [[[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(64, 64) format:format] imageWithActions:^(UIGraphicsImageRendererContext *context) {
            CGContextScaleCTM(context.CGContext, 64 / iconView.bounds.size.width, 64 / iconView.bounds.size.height);
            CGContextTranslateCTM(context.CGContext, -iconView.bounds.origin.x, -iconView.bounds.origin.y);
            [iconView.layer renderInContext:context.CGContext];
        }];
        return state.lastCapture;
    } @catch (NSException *exception) { V26Report(@"icon.renderFallback", exception.name); return nil; }
}

static BOOL V26ListContext(UIView *root) {
    Class cell = NSClassFromString(@"NCNotificationListCell");
    Class list = NSClassFromString(@"NCNotificationListView");
    UIView *view = root.superview;
    for (unsigned depth = 0; view && depth < 20; ++depth, view = view.superview) {
        if ((cell && [view isKindOfClass:cell]) || (list && [view isKindOfClass:list])) return YES;
        if (view == root.window) break;
    }
    return NO;
}
static BOOL V26BannerContext(UIView *root) {
    Class bannerWindow=NSClassFromString(@"SBBannerWindow"),bannerContent=NSClassFromString(@"BNContentViewControllerView");
    unsigned depth=0;
    for(UIView *view=root;view && depth<20;view=view.superview,++depth) {
        if((bannerWindow && [view isKindOfClass:bannerWindow]) || (bannerContent && [view isKindOfClass:bannerContent]))return YES;
        if(view==root.window)break;
    }
    return NO;
}
static UIView *V26Branch(UIView *root, UIView *descendant) {
    UIView *view = descendant;
    for (unsigned depth = 0; view && depth < 20; ++depth, view = view.superview)
        if (view.superview == root) return view;
    return nil;
}
static void V26PlaceAbove(UIView *view, UIView *parent, UIView *anchor) {
    if (!view || !parent || !anchor || anchor.superview != parent || view == anchor) return;
    NSArray *siblings = parent.subviews;
    if (view.superview != parent || [siblings indexOfObjectIdenticalTo:view] <= [siblings indexOfObjectIdenticalTo:anchor])
        [parent insertSubview:view aboveSubview:anchor];
}

// The system registers these labels for future provider-driven updates. A
// post-trait repaint alone cannot prevent those later automatic overwrites.
@interface VLGTextProviderBinding : NSObject
@property(nonatomic,weak) id provider;
@property(nonatomic) NSInteger style;
@property(nonatomic) BOOL detached;
@end
@implementation VLGTextProviderBinding
@end
static char VLGTextProviderKey;
static BOOL VLGProviderCanResume(id provider) {
    Method method=provider ? class_getInstanceMethod(object_getClass(provider),NSSelectorFromString(@"automaticallyUpdateView:withStyle:")) : NULL;
    if(!method || method_getNumberOfArguments(method)!=4)return NO;
    char result[16]={0},view[64]={0},style[16]={0};
    method_getReturnType(method,result,sizeof(result));method_getArgumentType(method,2,view,sizeof(view));method_getArgumentType(method,3,style,sizeof(style));
    return !strcmp(result,"v") && view[0]=='@' && view[1]!='?' && (!strcmp(style,"q") || !strcmp(style,"Q"));
}
static void VLGControlTextProvider(UIView *view,BOOL custom) {
    VLGTextProviderBinding *binding=objc_getAssociatedObject(view,&VLGTextProviderKey);
    id provider=binding.provider;if(!view || !provider)return;
    SEL stop=NSSelectorFromString(@"stopAutomaticallyUpdatingView:");
    if(custom && !binding.detached && V26Method(object_getClass(provider),stop,"v",1) && VLGProviderCanResume(provider)) {
        ((void(*)(id,SEL,id))objc_msgSend)(provider,stop,view);binding.detached=YES;
    } else if(!custom && binding.detached && VLGProviderCanResume(provider)) {
        ((void(*)(id,SEL,id,NSInteger))objc_msgSend)(provider,NSSelectorFromString(@"automaticallyUpdateView:withStyle:"),view,binding.style);binding.detached=NO;
    }
}
static BOOL VLGCustomTextReady(Velvet2Colorizer *colorizer,NSString *part) {
    if(![[colorizer.manager settingForKey:[part stringByAppendingString:@"Enabled"] withIdentifier:colorizer.identifier] boolValue])return NO;
    NSString *type=[colorizer.manager settingForKey:[part stringByAppendingString:@"Type"] withIdentifier:colorizer.identifier];
    return ![type isEqual:@"icon"] || colorizer.iconColor!=nil;
}
void VLGNativeTextProviderRegistered(UIView *content,UIView *view,NSInteger style,id provider) {
    if(!NSThread.isMainThread || ![view isKindOfClass:UIView.class])return;
    BOOL text=NO;
    for(NSString *key in @[@"primaryTextLabel",@"secondaryTextElement",@"secondaryTextElementTopAligned",@"secondaryTextElementBottomAligned",@"secondaryTextElementTopAlignedGroupCollapsed",@"dateLabel"]) {
        UIView *element=V26View(V26Object(content,key));
        if(element==view || (element && V26MessageElement(element)==view)){text=YES;break;}
    }
    if(!text)return; // Never detach icons, actions or other native views.
    VLGTextProviderBinding *binding=[VLGTextProviderBinding new];binding.provider=provider;binding.style=style;
    objc_setAssociatedObject(view,&VLGTextProviderKey,binding,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    VLGNativeTextDidUpdate(content);
}
static void VLGApplyText(Velvet2Colorizer *colorizer,id content,BOOL summary) {
    UILabel *title=V26Label(V26Object(content,summary ? @"summaryTitleLabel" : @"primaryTextLabel"));
    UILabel *date=V26Label(V26Object(content,@"dateLabel"));
    VLGControlTextProvider(title,VLGCustomTextReady(colorizer,@"title"));
    [colorizer colorTitle:title];
    NSArray *messageKeys=summary ? @[@"summaryLabel"] : @[@"secondaryTextElement",@"secondaryTextElementTopAligned",@"secondaryTextElementBottomAligned",@"secondaryTextElementTopAlignedGroupCollapsed"];
    BOOL customMessage=VLGCustomTextReady(colorizer,@"message");
    for(NSString *key in messageKeys) {
        UIView *element=V26View(V26Object(content,key));UILabel *label=V26MessageElement(element);
        VLGControlTextProvider(element,customMessage);
        if(label!=element)VLGControlTextProvider(label,customMessage);
        if(label)[colorizer colorMessage:label];
    }
    VLGControlTextProvider(date,VLGCustomTextReady(colorizer,@"date"));
    [colorizer colorDate:date];
}

static void VLGCaptureBannerFontSizes(id content) {
#if !defined(V26_STYLE_HOST)
    UIFont *title=V26Object(V26Object(content,@"primaryTextLabel"),@"font");
    UIFont *message=nil;
    for(NSString *key in @[@"secondaryTextElementTopAligned",@"secondaryTextElement",@"secondaryTextElementBottomAligned"]) {
        message=V26Object(V26MessageElement(V26View(V26Object(content,key))),@"font");
        if([message isKindOfClass:UIFont.class])break;
    }
    UIFont *date=V26Object(V26Object(content,@"dateLabel"),@"font");
    if([title isKindOfClass:UIFont.class] && [message isKindOfClass:UIFont.class] && [date isKindOfClass:UIFont.class])
        VLGStoreBannerTypography(@{@"title":@(title.pointSize),@"message":@(message.pointSize),@"date":@(date.pointSize)});
#endif
}

static BOOL V26Style(id owner, UIView *root, UIView *material, id content, NSString *identifier, BOOL summary) {
    V26Decoration *decoration = objc_getAssociatedObject(owner, &V26DecorationKey);
    decoration.pendingStage = @"geometry";
    if (!root || !material.superview || ![material isDescendantOfView:root] ||
        !isfinite(material.bounds.size.width) || !isfinite(material.bounds.size.height) ||
        material.bounds.size.width <= 0 || material.bounds.size.height <= 0 ||
        material.bounds.size.width > 4096 || material.bounds.size.height > 4096 ||
        !CGRectIntersectsRect(root.bounds, [material convertRect:material.bounds toView:root])) return NO;
    if (!decoration || decoration.updating) return NO;
    decoration.updating = YES;
    __block BOOL ready = NO;
    NSTimeInterval inheritedAnimation = [UIView inheritedAnimationDuration];
    [UIView performWithoutAnimation:^{
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    @try {
        decoration.tint.hidden = NO;
        decoration.glow.hidden = NO;
        id badged = V26Object(content, @"badgedIconView");
        UIView *icon = V26View(V26Object(badged, @"iconView")) ?: V26View(badged);
        Velvet2Colorizer *colorizer = [[Velvet2Colorizer alloc] initWithIdentifier:identifier];
        BOOL needsPalette = NO;
        Velvet2PrefsManager *manager = [Velvet2PrefsManager sharedInstance];
        BOOL listContext = V26ListContext(root);
        BOOL bannerContext = !listContext && V26BannerContext(root);
        BOOL stable = NO; // Native list glass remains under iOS control.
        UIView *base = [decoration.surface applyToMaterial:material root:root stableBlur:stable hideBlur:NO];
        if (!base) return;
        UIView *nativeBranch = V26Branch(root, material);
        UIView *contentBranch = V26Branch(root, V26View(content));
        if (contentBranch && (!nativeBranch || [root.subviews indexOfObjectIdenticalTo:contentBranch] > [root.subviews indexOfObjectIdenticalTo:nativeBranch])) nativeBranch = contentBranch;
        if (decoration.tint.superview == root && (!nativeBranch || [root.subviews indexOfObjectIdenticalTo:decoration.tint] > [root.subviews indexOfObjectIdenticalTo:nativeBranch])) nativeBranch = decoration.tint;
        V26PlaceAbove(decoration.glow, root, nativeBranch);
        CGFloat nativeZ = 0;
        unsigned zBudget = 64;
        for (UIView *view in root.subviews) {
            if (!zBudget--) break;
            if (!V26IsOwnedDecoration(view) && isfinite(view.layer.zPosition)) nativeZ = MAX(nativeZ, view.layer.zPosition);
        }
        if (nativeZ < 1000000) {
            decoration.glow.layer.zPosition = nativeZ + 1;
        }
        UIView *platter=VLGCardPlatter(root);
        CGRect cardFrame=VLGCardFrame(root,material);
        VLGPlaceCardTint(decoration.tint,root,material,V26View(content));
        for (NSString *part in @[@"background", @"shadow", @"title", @"message", @"date"]) {
            if ([[manager settingForKey:[part stringByAppendingString:@"Enabled"] withIdentifier:identifier] boolValue] &&
                [[manager settingForKey:[part stringByAppendingString:@"Type"] withIdentifier:identifier] isEqual:@"icon"]) needsPalette = YES;
        }
        if (bannerContext && [[manager settingForKey:@"bannerBorderEnabled" withIdentifier:identifier] boolValue] && [[manager settingForKey:@"bannerBorderType" withIdentifier:identifier] isEqual:@"icon"]) needsPalette=YES;
        V26PaletteEntry *entry = [V26Cache() entry:decoration.paletteKey];
        UIColor *palette = decoration.lastColor ?: entry.color;
        decoration.palettePending = NO;
        if (needsPalette) {
            UIImage *image = V26Icon(content, icon, decoration);
            if (image && image == decoration.lastImage) {
                decoration.palettePending = decoration.lastSampleFailed;
                if (!decoration.lastSampleFailed) palette = decoration.lastColor;
            }
            else if (image && image == entry.image && entry.color) palette = entry.color;
            else if (image) {
                colorizer.appIcon = image;
                UIColor *sampled = colorizer.iconColor;
                decoration.lastImage = image;
                decoration.lastSampleFailed = sampled == nil;
                if (sampled) {
                    palette = sampled;
                    [V26Cache() storeColor:sampled image:image key:decoration.paletteKey];
                } else decoration.palettePending = YES;
            } else decoration.palettePending = YES;
            if (palette) decoration.lastColor = palette;
            colorizer.iconColor = palette; colorizer.v26PaletteResolved = YES;
        }
        decoration.pendingStage = decoration.palettePending ? @"iconPalette" : @"decoration";
        if (palette && !decoration.palettePending && !decoration.paletteReported) {
            decoration.paletteReported = YES;
            V26Event(@"paletteReady", @{@"decoration":@(decoration.serial), @"elapsedMilliseconds":@((NSProcessInfo.processInfo.systemUptime - decoration.startedAt) * 1000)});
        }
        BOOL customRadius = [[manager settingForKey:@"cornerRadiusEnabled" withIdentifier:identifier] boolValue];
        double radius;
        if (customRadius) {
            radius = VLGCardRadius(cardFrame.size, [[manager settingForKey:@"cornerRadiusPercent" withIdentifier:identifier] doubleValue]);
            if(!isfinite(radius))return;
            BOOL nativeApplied = [decoration.shape applyRadius:radius to:platter];
            V26Report(@"shape.nativeAttemptSucceeded", @(nativeApplied));
        } else {
            [decoration.shape restore];
            radius = [decoration.shape radiusOn:platter fallback:25];
        }
        NSMutableArray *rounded = [@[decoration.tint] mutableCopy];
        if (decoration.surface.blur.superview) [rounded addObject:decoration.surface.blur];
        for (UIView *view in rounded) {
            view.layer.cornerRadius = radius;
            view.layer.cornerCurve = kCACornerCurveContinuous;
        }
        [colorizer colorBackground:decoration.tint];
        decoration.glowStyle.frame=(CGRect){CGPointZero,cardFrame.size};
        [colorizer colorShadow:decoration.glowStyle];
        decoration.borderStyle.frame=(CGRect){CGPointZero,cardFrame.size};
        if (bannerContext) [colorizer colorBorder:decoration.borderStyle];
        else {decoration.borderStyle.layer.borderWidth=0;decoration.borderStyle.layer.borderColor=NULL;}
        NSMutableArray *styleKey=[NSMutableArray arrayWithObject:palette ?: NSNull.null];
        for (NSString *setting in @[@"shadowEnabled",@"shadowType",@"shadowWidth",@"shadowColor",@"shadowIconAlpha",@"shadowIconShade",@"shadowColorAlpha",@"shadowColorShade",@"bannerBorderEnabled",@"bannerBorderType",@"bannerBorderWidth",@"bannerBorderColor",@"bannerBorderIconAlpha",@"bannerBorderIconShade",@"bannerBorderGradient1",@"bannerBorderGradient2",@"bannerBorderGradientDirection",@"bannerBorderColorAlpha",@"bannerBorderColorShade",@"bannerBorderGradientAlpha",@"bannerBorderGradientShade"])
            [styleKey addObject:[manager settingForKey:setting withIdentifier:identifier] ?: NSNull.null];
        CGFloat scale=root.traitCollection.displayScale;
        if (!isfinite(scale) || scale<1 || scale>4) scale=1;
        CGPathRef perimeter=VLGCreateContinuousOutline((CGRect){CGPointZero,cardFrame.size},radius);
        decoration.rasterActive=[decoration.foreground updateSize:cardFrame.size radius:radius scale:scale
            borderWidth:decoration.borderStyle.layer.borderWidth borderColor:decoration.borderStyle.layer.borderColor glowRadius:decoration.glowStyle.layer.shadowRadius
            glowColor:decoration.glowStyle.layer.shadowColor styleKey:styleKey outline:perimeter];
        if(perimeter)CGPathRelease(perimeter);
        if (decoration.rasterActive) {
            decoration.glow.layer.shadowOpacity=0;decoration.glow.layer.shadowColor=NULL;
            decoration.glow.layer.shadowPath=NULL;decoration.glow.layer.mask=nil;
            decoration.glow.layer.contents=(__bridge id)decoration.foreground.image;
            decoration.glow.layer.contentsScale=scale;
            decoration.glow.frame=(CGRect){CGPointMake(cardFrame.origin.x-decoration.foreground.padding,cardFrame.origin.y-decoration.foreground.padding),decoration.foreground.pointSize};
            decoration.glow.hidden=decoration.foreground.image==NULL;
        } else {
            decoration.glow.layer.contents=nil;
            decoration.glow.layer.shadowColor=decoration.glowStyle.layer.shadowColor;
            decoration.glow.layer.shadowRadius=decoration.glowStyle.layer.shadowRadius;
            decoration.glow.layer.shadowOffset=CGSizeZero;decoration.glow.layer.shadowOpacity=1;
            if (!V26ConfigureOuterGlow(decoration.glowStyle,cardFrame,radius)) decoration.glow.hidden=YES;
            else {
                decoration.glow.frame=decoration.glowStyle.frame;
                decoration.glow.layer.shadowPath=decoration.glowStyle.layer.shadowPath;
                CAShapeLayer *sourceMask=(CAShapeLayer *)decoration.glowStyle.layer.mask;
                CAShapeLayer *mask=[CAShapeLayer layer];mask.frame=sourceMask.frame;
                mask.path=sourceMask.path;mask.fillRule=sourceMask.fillRule;decoration.glow.layer.mask=mask;
            }
            V26Report(@"foreground.fallback",decoration.foreground.failure ?: @"unknown");
        }
        if(listContext) {
            root.overrideUserInterfaceStyle=UIUserInterfaceStyleDark;
            material.overrideUserInterfaceStyle=UIUserInterfaceStyleDark;
        } else {
            [colorizer setAppearance:root];[colorizer setAppearance:material];
        }
        if (decoration.surface.blur) [colorizer setAppearance:decoration.surface.blur];
        VLGApplyText(colorizer,content,summary);
        if(bannerContext)VLGCaptureBannerFontSizes(content);
        V26Report(@"styling.reached", @YES);
        ready = !needsPalette || palette != nil;
        if (ready && !decoration.firstPaint) {
            decoration.firstPaint = YES;
            V26Event(@"firstPaint", @{@"decoration":@(decoration.serial), @"elapsedMilliseconds":@((NSProcessInfo.processInfo.systemUptime - decoration.startedAt) * 1000),
                @"rootClass":NSStringFromClass(root.class), @"materialClass":NSStringFromClass(material.class),
                @"cachedPalette":@(entry.color != nil), @"customRadius":@(customRadius),
                @"inheritedAnimationSeconds":@(inheritedAnimation)});
        }
        V26Report(@"styling.iconClass", NSStringFromClass(colorizer.appIcon.class) ?: @"nil");
        V26Report(@"styling.hasColor", @(palette != nil));
        CGFloat fillAlpha = decoration.tint.backgroundColor ? CGColorGetAlpha(decoration.tint.backgroundColor.CGColor) : 0;
        CGFloat haloAlpha = decoration.glowStyle.layer.shadowColor ? CGColorGetAlpha(decoration.glowStyle.layer.shadowColor) : 0;
        NSArray *fingerprint = @[@(listContext), @(stable), @(palette != nil), @(material.alpha), @(material.hidden),
            @(root.layer.opacity), @(decoration.glowStyle.layer.shadowRadius),
            @(fillAlpha), @(haloAlpha), @(decoration.rasterActive), @(decoration.foreground.renderCount), @((long)root.traitCollection.userInterfaceStyle), @((long)material.traitCollection.userInterfaceStyle)];
        BOOL firstSettledSnapshot = !decoration.palettePending && !decoration.settledPresentationRecorded;
        if ((decoration.presentationEvents < 8 || firstSettledSnapshot) && ![decoration.presentationFingerprint isEqual:fingerprint]) {
            decoration.presentationFingerprint = fingerprint; ++decoration.presentationEvents;
            if (!decoration.palettePending) decoration.settledPresentationRecorded = YES;
            NSMutableArray *ancestors = [NSMutableArray array];
            UIView *view = root;
            for (unsigned depth = 0; view && depth < 6; ++depth, view = view.superview) {
                NSMutableArray *filters=[NSMutableArray array];
                for (id filter in view.layer.filters) {
                    if (filters.count>=8) break;
                    id type=V26Object(filter,@"type");
                    [filters addObject:@{@"class":NSStringFromClass([filter class]),@"type":[type isKindOfClass:NSString.class] ? type : @"unavailable"}];
                }
                [ancestors addObject:@{@"class":NSStringFromClass(view.class), @"clips":@(view.clipsToBounds), @"opacity":@(view.layer.opacity), @"mask":@(view.layer.mask != nil), @"filterCount":@(view.layer.filters.count), @"filters":filters, @"compositingFilter":@(view.layer.compositingFilter != nil)}];
            }
            unsigned tints=0, glows=0, blurs=0, budget=256;
            for (V26Decoration *other in V26ActiveStates.allObjects) {
                if (!budget--) break;
                if ([other.tint isDescendantOfView:root]) ++tints;
                if ([other.glow isDescendantOfView:root]) ++glows;
                if ([other.surface.blur isDescendantOfView:root]) ++blurs;
            }
            NSMutableArray *children = [NSMutableArray array];
            for (UIView *child in root.subviews) {
                if (children.count >= 16) break;
                [children addObject:@{@"class":NSStringFromClass(child.class), @"owned":@(V26IsOwnedDecoration(child)),
                    @"hidden":@(child.hidden), @"alpha":@(child.alpha), @"z":@(child.layer.zPosition)}];
            }
            V26Event(@"presentationState", @{@"decoration":@(decoration.serial), @"root":objc_getAssociatedObject(root, &V26RootIDKey) ?: @0,
                @"bannerBorderDrawn":@(bannerContext && decoration.borderStyle.layer.borderWidth>0), @"foregroundMode":decoration.rasterActive ? @"raster" : @"legacyFallback", @"rasterRenders":@(decoration.foreground.renderCount),
                @"rasterPixelWidth":@(decoration.foreground.image ? CGImageGetWidth(decoration.foreground.image) : 0),
                @"rasterPixelHeight":@(decoration.foreground.image ? CGImageGetHeight(decoration.foreground.image) : 0), @"settledPalette":@(!decoration.palettePending), @"hasPalette":@(palette != nil),
                @"listContext":@(listContext), @"stableBlur":@(stable),
                @"nativeAlpha":@(material.alpha), @"nativeHidden":@(material.hidden),
                @"appearance":[manager settingForKey:@"appearance" withIdentifier:identifier] ?: @"default",
                @"rootStyle":@((long)root.traitCollection.userInterfaceStyle), @"materialStyle":@((long)material.traitCollection.userInterfaceStyle),
                @"backgroundOpacity":@([[manager settingForKey:@"backgroundIconAlpha" withIdentifier:identifier] doubleValue]),
                @"fillColorAlpha":@(fillAlpha), @"glowColorAlpha":@(haloAlpha),
                @"glowRadius":@(decoration.glowStyle.layer.shadowRadius),
                @"ownedTints":@(tints), @"ownedGlows":@(glows), @"ownedBlurs":@(blurs),
                @"children":children, @"ancestors":ancestors});
        }
    } @catch (NSException *exception) {
        // Only optional decoration is contained here; original UIKit calls below
        // remain outside this handler and are never swallowed or retried.
        decoration.tint.hidden = YES;
        decoration.glow.hidden = YES;
        [decoration.surface restore];

        decoration.pendingStage = @"stylingException";
        ready = NO;
        V26Report(@"styling.fallback", exception.name);
    } @finally { decoration.updating = NO; [CATransaction commit]; }
    }];
    return ready && !decoration.palettePending;
}

@interface V26OwnerBox : NSObject
@property(nonatomic, weak) id owner;
@end
@implementation V26OwnerBox
@end
static char V26OwnerKey;
static void V26Bind(UIView *view, id owner) {
    if (!view) return;
    V26OwnerBox *box = objc_getAssociatedObject(view, &V26OwnerKey);
    if (box.owner == owner) return;
    if (!box) box = [V26OwnerBox new];
    box.owner = owner;
    objc_setAssociatedObject(view, &V26OwnerKey, box, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
static V26Decoration *V26State(id owner) {
    V26Decoration *state = objc_getAssociatedObject(owner, &V26DecorationKey);
    if (!state) {
        state = [V26Decoration new]; state.owner = owner; state.serial = ++V26NextStateID;
        if (!V26ActiveStates) V26ActiveStates = [NSHashTable weakObjectsHashTable];
        [V26ActiveStates addObject:state];
        state.cycle = [[V26UpdateCycle alloc] initWithOwner:owner scheduler:nil];
        state.shape = [V26NativeShape new];
        state.startedAt = NSProcessInfo.processInfo.systemUptime;
        objc_setAssociatedObject(owner, &V26DecorationKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return state;
}
static void V26Wait(V26Decoration *state, NSString *reason) {
    if (![state.waitReason isEqual:reason]) {
        state.waitReason = reason;
        V26Event(@"waiting", @{@"decoration":@(state.serial), @"reason":reason, @"attempt":@(state.cycle.attempts)});
    }
    [state.cycle schedule:^(id owner) {
        V26Decoration *current = V26State(owner);
        current.retryCapture = YES;
        @try { V26Refresh(owner); }
        @finally { current.retryCapture = NO; }
    }];
    if (!state.cycle.scheduled) V26Report(@"retry.exhausted", @YES);
}
void V26Refresh(id owner) {
    if (!owner || !NSThread.isMainThread) return;
    V26Decoration *state = V26State(owner);
    if (state.refreshing) return;
    state.refreshing = YES;
    @try {
        BOOL summary = [owner isKindOfClass:NSClassFromString(@"NCNotificationSummaryPlatterView")];
        id request = summary ? owner : V26Object(owner, @"notificationRequest");
        UIView *root;
        if (summary) root = V26View(owner);
        else {
            root = V26View(V26Object(owner, @"_notificationShortLookViewIfLoaded"));
            if (!root) root = V26Find(V26View(V26Object(owner, @"viewIfLoaded")), NSClassFromString(@"NCNotificationShortLookView"));
        }
        id identifier = summary ? @"com.noisyflake.velvetFocus" : V26Object(request, @"sectionIdentifier");
        if (![identifier isKindOfClass:NSString.class]) identifier = nil;
        id content = V26Object(root, summary ? @"summaryContentView" : @"notificationContentView");
        if (!content && !summary) content = V26Find(root, NSClassFromString(@"NCNotificationSeamlessContentView"));
        id descriptor = V26Object(content, @"badgedIconDescription") ?: V26Object(V26Object(content, @"badgedIconView"), @"badgedIconDescription");
        id sourceKey = V26Object(descriptor, @"prominentIconDescription") ?: V26Object(content, @"prominentIcon");
        // A bundle identifier alone cannot distinguish a contact avatar from an
        // app icon. Share only when the actual icon descriptions compare equal.
        id key = identifier && sourceKey ? @[identifier, @((long)root.traitCollection.userInterfaceStyle), sourceKey] : nil;
        if (state.request != request || !((!key && !state.paletteKey) || [key isEqual:state.paletteKey])) {
            // A trait transition can temporarily replace the icon description
            // before its rendered image is ready. Reuse only this request/app's
            // raw palette until its new image is sampled, never another request.
            NSArray *oldKey=[state.paletteKey isKindOfClass:NSArray.class] ? state.paletteKey : nil;
            BOOL sameRequest=state.request==request && request!=nil;
            BOOL sameApp=oldKey.count==3 && key && [oldKey[0] isEqual:key[0]];
            BOOL sameSource=sameApp && [oldKey[2] isEqual:key[2]];
            BOOL changedStyle=sameApp && ![oldKey[1] isEqual:key[1]];
            UIColor *fallback=sameRequest && (sameSource || changedStyle) ? state.lastColor : nil;
            [state.cycle reset]; [state.shape restore]; [state.surface restore];
            state.request = request; state.paletteKey = key;
            state.lastImage = nil; state.lastColor = fallback; state.lastCapture = nil;
            state.tint.hidden = YES; state.glow.hidden = YES;
            state.glow.layer.contents=nil;[state.foreground clear];state.rasterActive=NO;
            state.startedAt = NSProcessInfo.processInfo.systemUptime;
            state.firstPaint = NO; state.paletteReported = NO; state.waitReason = nil;
            state.presentationEvents = 0; state.settledPresentationRecorded = NO; state.presentationFingerprint = nil;
            V26Event(@"contentCycle", @{@"decoration":@(state.serial), @"summary":@(summary), @"hasIdentifier":@(identifier != nil)});
        }
        if (!root) { V26Wait(state, @"loadedView"); return; }
        if (!objc_getAssociatedObject(root, &V26RootIDKey)) objc_setAssociatedObject(root, &V26RootIDKey, @(++V26NextRootID), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        state.paintedRoot = root;
        V26Bind(root, owner);
        UIView *material = V26View(V26Object(root, @"backgroundMaterialView"));
        if (!material && summary) material = V26Find(root, NSClassFromString(@"MTMaterialView"));

        V26Bind(V26View(content), owner);
        V26Bind(V26View(V26Object(content, @"badgedIconView")), owner);
        if (!material || !content) { V26Wait(state, @"materialOrContent"); return; }
        if (!V26Style(owner, root, material, content, identifier, summary)) { V26Wait(state, state.pendingStage ?: @"geometryOrPalette"); return; }
        [state.cycle cancel]; state.waitReason = nil;
    } @catch (NSException *exception) {
        [state.cycle cancel]; V26Report(@"refresh.guardedException", exception.name);
    } @finally { state.refreshing = NO; }
}
static id V26OwnerForView(UIView *view) {
    if (!NSThread.isMainThread || ![view isKindOfClass:UIView.class]) return nil;
    // Prefer the current responder owner. A recycled icon/content view may
    // still carry a weak binding from the previous notification controller.
    UIResponder *responder = view;
    for (unsigned depth = 0; responder && depth < 12; ++depth, responder = responder.nextResponder) {
        if ([responder isKindOfClass:NSClassFromString(@"NCNotificationShortLookViewController")]) return responder;
    }
    UIView *parent = view;
    for (unsigned depth = 0; parent && depth < 16; ++depth, parent = parent.superview) {
        V26OwnerBox *box = objc_getAssociatedObject(parent, &V26OwnerKey);
        id owner = box.owner;
        UIView *loaded = [owner isKindOfClass:NSClassFromString(@"NCNotificationSummaryPlatterView")] ? V26View(owner) : V26View(V26Object(owner, @"_notificationShortLookViewIfLoaded"));
        if (loaded && [view isDescendantOfView:loaded]) return owner;
        if (parent == view.window) break;
    }
    return nil;
}
void V26RefreshForView(UIView *view) { V26Refresh(V26OwnerForView(view)); }
static void VLGReapplyText(UIView *view) {
    if(!NSThread.isMainThread)return;
    id owner=V26OwnerForView(view);if(!owner)return;
    V26Decoration *state=objc_getAssociatedObject(owner,&V26DecorationKey);
    if(!state || state.updating || state.refreshing || state.textUpdating)return;
    BOOL summary=[owner isKindOfClass:NSClassFromString(@"NCNotificationSummaryPlatterView")];
    UIView *root=state.paintedRoot;
    if(!root || ![view isDescendantOfView:root])return;
    id request=summary ? owner : V26Object(owner,@"notificationRequest");
    if(request!=state.request)return;
    id content=V26Object(root,summary ? @"summaryContentView" : @"notificationContentView");
    if(!content && !summary)content=V26Find(root,NSClassFromString(@"NCNotificationSeamlessContentView"));
    NSString *identifier=summary ? @"com.noisyflake.velvetFocus" : V26Object(request,@"sectionIdentifier");
    if(![identifier isKindOfClass:NSString.class] || !content)return;
    state.textUpdating=YES;
    @try {
        Velvet2Colorizer *colorizer=[[Velvet2Colorizer alloc] initWithIdentifier:identifier];
        colorizer.iconColor=state.lastColor; colorizer.v26PaletteResolved=YES;
        VLGApplyText(colorizer,content,summary);
    } @catch(NSException *exception) {V26Report(@"text.guardedException",exception.name);}
    @finally {state.textUpdating=NO;}
}
void VLGNativeTextDidUpdate(UIView *view) {
    if(!NSThread.isMainThread || !view)return;
    id owner=V26OwnerForView(view);
    V26Decoration *state=owner ? objc_getAssociatedObject(owner,&V26DecorationKey) : nil;
    if(!state || state.textUpdating)return;
    if(!state.updating && !state.refreshing)VLGReapplyText(view);
    // One coalesced next-turn pass covers native deferred visual styling.
    // It never changes traits or geometry and does not schedule itself.
    if(state.textFollowupPending)return;
    state.textFollowupPending=YES;
    __weak UIView *weakView=view;__weak V26Decoration *weakState=state;
    dispatch_async(dispatch_get_main_queue(),^{
        V26Decoration *current=weakState;current.textFollowupPending=NO;
        if(current && V26OwnerForView(weakView)==current.owner)VLGReapplyText(weakView);
    });
}
void V26RequestChanged(id owner) {
    if (!NSThread.isMainThread || !owner) return;
    [V26State(owner).cycle reset];
    V26Refresh(owner);
}

void VLGIconDidComplete(UIView *view) {
    if(!view)return;
    static char pendingKey;
    if(!NSThread.isMainThread) {__weak UIView *weak=view;dispatch_async(dispatch_get_main_queue(),^{VLGIconDidComplete(weak);});return;}
    if([objc_getAssociatedObject(view,&pendingKey) boolValue])return;
    objc_setAssociatedObject(view,&pendingKey,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    __weak UIView *weak=view;
    dispatch_async(dispatch_get_main_queue(),^{
        UIView *current=weak;if(!current)return;
        objc_setAssociatedObject(current,&pendingKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(current,&VLGIconGenerationKey,@([objc_getAssociatedObject(current,&VLGIconGenerationKey) unsignedIntegerValue]+1),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        V26Event(@"iconCompletion",@{});
        V26RefreshForView(current);
    });
}
