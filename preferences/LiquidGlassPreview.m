#import "LiquidGlassPreview.h"
#import "../headers/HeadersTweak.h"
#import "../headers/UIImage+Private.h"
#import "../compat/Runtime.h"
#import "../compat/NativePreviewMaterial.h"
#import "../compat/NativeShape.h"
#import "../compat/NativeOutline.h"
#import "../compat/ForegroundRaster.h"
#import "../compat/DecorationSurface.h"
#import "../compat/CardSurface.h"
#import "../compat/CardStyle.h"
#import "../compat/BannerTypography.h"

static void VLGPreviewAppearance(UIView *root,UIUserInterfaceStyle style) {
    NSMutableArray *queue=[NSMutableArray arrayWithObject:root];
    for(NSUInteger i=0;i<queue.count && i<128;++i) {
        UIView *view=queue[i];if(view.overrideUserInterfaceStyle!=style)view.overrideUserInterfaceStyle=style;
        if(queue.count<128)[queue addObjectsFromArray:view.subviews];
    }
}
@interface VLGLivePreviewView ()
@property(nonatomic, copy) NSString *identifier,*loadedIconIdentifier;
@property(nonatomic, strong) UIView *card,*nativePlatter,*contentHost,*tint,*halo;
@property(nonatomic, strong) UIVisualEffectView *publicGlass;
@property(nonatomic, strong) UIImageView *icon;
@property(nonatomic, strong) UILabel *titleLabel,*messageLabel,*dateLabel,*hint;
@property(nonatomic, strong) UIView *shadowProbe;
@property(nonatomic, strong) V26NativeShape *shape;
@property(nonatomic, strong) V26ForegroundRaster *raster;
@property(nonatomic, strong) UIImage *sampledIcon;
@property(nonatomic, strong) UIColor *palette;
@property(nonatomic) BOOL updating,nativeMode,reportScheduled;
@end
@implementation VLGLivePreviewView
- (instancetype)initWithFrame:(CGRect)frame identifier:(NSString *)identifier {
    if (!(self=[super initWithFrame:frame])) return nil;
    self.identifier=identifier;self.clipsToBounds=NO;
    self.overrideUserInterfaceStyle=UIUserInterfaceStyleDark;
    // Construct at the real final width, not the old hardcoded 320 points.
    // Native material geometry is ready before the first tint is installed.
    self.card=[[UIView alloc] initWithFrame:CGRectMake(16,12,MAX(1,frame.size.width-32),84)];self.card.clipsToBounds=NO;[self addSubview:self.card];
    self.halo=[UIView new];self.halo.userInteractionEnabled=NO;self.halo.accessibilityElementsHidden=YES;[self.card addSubview:self.halo];
    static dispatch_once_t once;
    dispatch_once(&once,^{
        if (!NSClassFromString(@"NCPlatterView")) {
            @try {
                NSError *error=nil;
                [[NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/UserNotificationsUIKit.framework"] loadAndReturnError:&error];
                if (error) V26Report(@"preview.frameworkError",error.localizedDescription);
            } @catch (NSException *exception) {V26Report(@"preview.frameworkError",exception.name);}
        }
    });
    Class cls=NSClassFromString(@"NCPlatterView");
    V26Report(@"preview.nativeABIValid",@(VLGNativePlatterABI(cls)));
    self.nativePlatter=VLGCreateNativePlatter(cls);
    UIView *content=VLGCardContent(self.nativePlatter);
    if (self.nativePlatter && [content isKindOfClass:UIView.class]) {
        self.nativeMode=YES;self.contentHost=content;self.contentHost.clipsToBounds=YES;
        self.nativePlatter.frame=self.card.bounds;[self.card addSubview:self.nativePlatter];
        [self.nativePlatter layoutIfNeeded];
    } else {
        self.nativePlatter=nil;
        // A modern system-glass fallback is explicitly identified. It never
        // invokes the retired generic-blur Velvet2 preview implementation.
        if (@available(iOS 26.0,*)) self.publicGlass=[[UIVisualEffectView alloc] initWithEffect:[UIGlassEffect effectWithStyle:UIGlassEffectStyleRegular]];
        self.contentHost=[UIView new];
        if (self.publicGlass) [self.card addSubview:self.publicGlass];
        [self.card addSubview:self.contentHost];
    }
    [self.card bringSubviewToFront:self.halo];
    self.tint=[UIView new];self.tint.userInteractionEnabled=NO;self.tint.accessibilityElementsHidden=YES;self.tint.clipsToBounds=YES;
    if (!self.nativeMode) {if (self.publicGlass) [self.card insertSubview:self.tint aboveSubview:self.publicGlass];else [self.card insertSubview:self.tint atIndex:0];}
    self.icon=[UIImageView new];self.icon.contentMode=UIViewContentModeScaleAspectFit;[self.contentHost addSubview:self.icon];
    self.titleLabel=[UILabel new];self.titleLabel.text=@"Lock Screen / Notification Center";self.titleLabel.numberOfLines=0;self.titleLabel.font=[UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];[self.contentHost addSubview:self.titleLabel];
    self.messageLabel=[UILabel new];self.messageLabel.text=@"Lock Screen and Notification Center follow the dark Banner settings.";self.messageLabel.font=[UIFont systemFontOfSize:15];self.messageLabel.numberOfLines=0;[self.contentHost addSubview:self.messageLabel];
    self.dateLabel=[UILabel new];self.dateLabel.text=@"now";self.dateLabel.font=[UIFont systemFontOfSize:13];self.dateLabel.textAlignment=NSTextAlignmentRight;[self.contentHost addSubview:self.dateLabel];
    self.hint=[UILabel new];self.hint.font=[UIFont systemFontOfSize:12];self.hint.numberOfLines=3;self.hint.textAlignment=NSTextAlignmentCenter;self.hint.textColor=UIColor.secondaryLabelColor;[self addSubview:self.hint];
    self.hint.text=identifier.length ? @"" : @"Tap to change the app.";
    V26MarkOwnedDecoration(self.tint);V26MarkOwnedDecoration(self.halo);
    self.shadowProbe=[UIView new];self.shape=[V26NativeShape new];self.raster=[V26ForegroundRaster new];
    [self.card addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(changeIcon)]];
    self.card.gestureRecognizers.lastObject.enabled=!identifier.length;
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(typographyChanged:) name:@"VLGPreviewTypographyChanged" object:nil];
    [self refreshFonts];
    [self loadIcon:identifier ?: [[Velvet2PrefsManager sharedInstance] objectForKey:@"currentIcon"]];
    V26Report(@"preview.backend",self.nativeMode ? @"nativeNCPlatterViewRecipe1" : @"publicSystemGlassApproximation");
    return self;
}
- (void)configureIdentifier:(NSString *)identifier {
    BOOL same=(!self.identifier && !identifier) || [self.identifier isEqual:identifier];
    if(!same) {
        self.identifier=[identifier copy];
        self.card.gestureRecognizers.lastObject.enabled=!identifier.length;
        self.hint.text=identifier.length ? @"" : @"Tap to change the app.";
    }
    [self updatePreview];
}
- (void)dealloc {[NSNotificationCenter.defaultCenter removeObserver:self];}
- (void)refreshFonts {
    NSDictionary *sizes=VLGReadBannerTypography();
    NSArray *labels=@[self.titleLabel,self.messageLabel,self.dateLabel];NSArray *keys=@[@"title",@"message",@"date"];
    NSDictionary *initial=VLGInitialBannerTypography();
    BOOL changed=NO;
    for(NSUInteger i=0;i<labels.count;++i) {
        UILabel *label=labels[i];
        CGFloat initialSize=[[UIFontMetrics metricsForTextStyle:i==2 ? UIFontTextStyleFootnote : UIFontTextStyleSubheadline] scaledValueForValue:[initial[keys[i]] doubleValue] compatibleWithTraitCollection:self.traitCollection];
        CGFloat size=sizes[keys[i]] ? [sizes[keys[i]] doubleValue] : initialSize;
        if(fabs(label.font.pointSize-size)>.005) {label.font=[UIFont systemFontOfSize:size weight:i==0 ? UIFontWeightSemibold : UIFontWeightRegular];changed=YES;}
    }
    if(changed){[self setNeedsLayout];[self.superview.superview setNeedsLayout];}
}
- (void)typographyChanged:(NSNotification *)notification {[self refreshFonts];[self setNeedsLayout];[self.superview.superview setNeedsLayout];[self updatePreview];}
- (CGFloat)cardHeightForWidth:(CGFloat)width {
    CGFloat cardWidth=MAX(1,width-32);
    CGFloat titleHeight=ceil([self.titleLabel sizeThatFits:CGSizeMake(MAX(1,cardWidth-115),CGFLOAT_MAX)].height);
    CGFloat messageHeight=ceil([self.messageLabel sizeThatFits:CGSizeMake(MAX(1,cardWidth-73),CGFLOAT_MAX)].height);
    return MAX(84,20+titleHeight+2+messageHeight);
}
- (CGFloat)preferredHeightForWidth:(CGFloat)width {
    [self refreshFonts];return [self cardHeightForWidth:width]+37;
}
- (void)layoutSubviews {
    [super layoutSubviews];[self refreshFonts];
    CGFloat height=[self cardHeightForWidth:self.bounds.size.width];
    self.card.frame=CGRectMake(16,12,MAX(1,self.bounds.size.width-32),height);
    self.nativePlatter.frame=self.card.bounds;self.publicGlass.frame=self.card.bounds;
    if(self.nativeMode)[self.nativePlatter layoutIfNeeded];else self.contentHost.frame=self.card.bounds;
    CGFloat width=self.card.bounds.size.width;
    CGFloat titleHeight=ceil([self.titleLabel sizeThatFits:CGSizeMake(MAX(1,width-115),CGFLOAT_MAX)].height);
    CGFloat messageHeight=ceil([self.messageLabel sizeThatFits:CGSizeMake(MAX(1,width-73),CGFLOAT_MAX)].height);
    self.icon.frame=CGRectMake(10,(height-38)/2,38,38);
    self.titleLabel.frame=CGRectMake(58,10,MAX(1,width-115),titleHeight);
    self.messageLabel.frame=CGRectMake(58,12+titleHeight,MAX(1,width-73),messageHeight);
    self.dateLabel.frame=CGRectMake(MAX(0,width-49),10,39,ceil(self.dateLabel.font.lineHeight));
    self.hint.frame=CGRectMake(15,12+height+5,MAX(1,self.bounds.size.width-30),20);
    [self updatePreview];
}
- (void)updatePreview {
    if (!NSThread.isMainThread || self.updating) return;
    self.updating=YES;
    [UIView performWithoutAnimation:^{
        [CATransaction begin];[CATransaction setDisableActions:YES];
        @try {
            Velvet2PrefsManager *manager=[Velvet2PrefsManager sharedInstance];
            NSString *desired=self.identifier ?: [manager objectForKey:@"currentIcon"];
            if(![desired isKindOfClass:NSString.class] || !desired.length)desired=@"com.apple.Preferences";
            if(![self.loadedIconIdentifier isEqual:desired]) [self loadIcon:desired];
            Velvet2Colorizer *colorizer=[[Velvet2Colorizer alloc] initWithIdentifier:self.identifier];
            // LS/NC stays dark, independently of the banner's Light/Dark choice.
            self.card.overrideUserInterfaceStyle=UIUserInterfaceStyleDark;
            if(self.nativePlatter)VLGPreviewAppearance(self.nativePlatter,UIUserInterfaceStyleDark);
            self.publicGlass.overrideUserInterfaceStyle=UIUserInterfaceStyleDark;
            if (self.sampledIcon!=self.icon.image) {
                colorizer.appIcon=self.icon.image;self.palette=colorizer.iconColor;self.sampledIcon=self.icon.image;
            }
            colorizer.iconColor=self.palette;colorizer.v26PaletteResolved=YES;
            BOOL custom=[[manager settingForKey:@"cornerRadiusEnabled" withIdentifier:self.identifier] boolValue];
            CGFloat requested=custom ? VLGCardRadius(self.card.bounds.size,[[manager settingForKey:@"cornerRadiusPercent" withIdentifier:self.identifier] doubleValue]) : 23.5;
            CGFloat radius=VLGBoundedCornerRadius(self.card.bounds,requested);
            if(!isfinite(radius))return;
            UIView *material=nil;
            if (self.nativeMode) {
                if(custom) [self.shape applyRadius:radius to:self.nativePlatter];
                else {
                    [self.shape restore];
                    radius=VLGBoundedCornerRadius(self.card.bounds,[self.shape radiusOn:self.nativePlatter fallback:23.5]);
                    if(!isfinite(radius))radius=23.5;
                }
                [self.nativePlatter layoutIfNeeded];
                material=V26Object(self.nativePlatter,@"backgroundMaterialView");
                if ([material isKindOfClass:UIView.class] && [material isDescendantOfView:self.nativePlatter] && material.superview) {
                    VLGPlaceCardTint(self.tint,self.nativePlatter,material,self.contentHost);
                    material.overrideUserInterfaceStyle=UIUserInterfaceStyleDark;
                    V26Report(@"preview.nativeMaterialClass",NSStringFromClass(material.class));
                } else {self.tint.hidden=YES;V26Report(@"preview.nativeMaterialMissing",@YES);}
            } else {
                self.tint.frame=self.card.bounds;

            }
            if (!self.nativeMode || material) self.tint.hidden=NO;
            self.tint.layer.cornerRadius=radius;self.tint.layer.cornerCurve=kCACornerCurveContinuous;
            self.publicGlass.layer.cornerRadius=radius;self.publicGlass.layer.cornerCurve=kCACornerCurveContinuous;self.publicGlass.clipsToBounds=YES;
            [colorizer colorBackground:self.tint];
            self.shadowProbe.frame=self.card.bounds;[colorizer colorShadow:self.shadowProbe];
            NSMutableArray *key=[NSMutableArray arrayWithObject:self.palette ?: NSNull.null];
            for (NSString *name in @[@"shadowEnabled",@"shadowType",@"shadowWidth",@"shadowColor",@"shadowIconAlpha",@"shadowIconShade",@"shadowColorAlpha",@"shadowColorShade"])
                [key addObject:[manager settingForKey:name withIdentifier:self.identifier] ?: NSNull.null];
            CGFloat scale=self.traitCollection.displayScale;if (!isfinite(scale) || scale<1 || scale>4) scale=1;
            CGPathRef perimeter=VLGCreateContinuousOutline(self.card.bounds,radius);
            BOOL rendered=[self.raster updateSize:self.card.bounds.size radius:radius scale:scale borderWidth:0 borderColor:NULL glowRadius:self.shadowProbe.layer.shadowRadius glowColor:self.shadowProbe.layer.shadowColor styleKey:key outline:perimeter];
            if(perimeter)CGPathRelease(perimeter);
            self.halo.layer.contents=rendered ? (__bridge id)self.raster.image : nil;self.halo.layer.contentsScale=scale;
            self.halo.frame=(CGRect){CGPointMake(-self.raster.padding,-self.raster.padding),self.raster.pointSize};self.halo.hidden=!rendered || !self.raster.image;
            for(UIView *view in @[self.contentHost,self.titleLabel,self.messageLabel,self.dateLabel]) view.overrideUserInterfaceStyle=UIUserInterfaceStyleDark;
            [colorizer colorTitle:self.titleLabel];[colorizer colorMessage:self.messageLabel];[colorizer colorDate:self.dateLabel];
            V26Report(@"preview.hasColor",@(self.palette!=nil));
            [self scheduleReport];
        } @catch (NSException *exception) {V26Report(@"preview.guardedError",exception.name);}
        @finally {self.updating=NO;[CATransaction commit];}
    }];
}
- (void)scheduleReport {
    if (self.reportScheduled) return;self.reportScheduled=YES;
    __weak typeof(self) weakSelf=self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(.4*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
        typeof(self) view=weakSelf;if(!view)return;view.reportScheduled=NO;
        unsigned effects=0;
        for(UIView *child in view.nativePlatter.subviews) if([child isKindOfClass:UIVisualEffectView.class] && !child.hidden)++effects;
        V26Event(@"livePreview",@{@"native":@(view.nativeMode),@"style":@(view.card.traitCollection.userInterfaceStyle),
            @"tintAlpha":@(view.tint.backgroundColor ? CGColorGetAlpha(view.tint.backgroundColor.CGColor) : 0),
            @"tintVisible":@(!view.tint.hidden && view.tint.superview!=nil),@"visibleNativeEffects":@(effects),@"lsncPreview":@YES,@"contentStyle":@(view.contentHost.traitCollection.userInterfaceStyle),@"glowRenders":@(view.raster.renderCount)});
    });
}
- (void)loadIcon:(NSString *)identifier {
    if (![identifier isKindOfClass:NSString.class] || !identifier.length) identifier=@"com.apple.Preferences";
    self.loadedIconIdentifier=identifier;
    UIImage *image=nil;
    @try {if ([UIImage respondsToSelector:@selector(_applicationIconImageForBundleIdentifier:format:scale:)]) image=[UIImage _applicationIconImageForBundleIdentifier:identifier format:2 scale:UIScreen.mainScreen.scale];}
    @catch (NSException *exception) {V26Report(@"preview.iconError",exception.name);}
    self.icon.image=image ?: [UIImage systemImageNamed:@"app.fill"];
    [self setNeedsLayout];
}
- (void)changeIcon {
    id workspace=V26Object(NSClassFromString(@"LSApplicationWorkspace"),@"defaultWorkspace"),apps=V26Object(workspace,@"allInstalledApplications");
    NSMutableArray *identifiers=[NSMutableArray array];
    if ([apps isKindOfClass:NSArray.class]) for (id app in apps) {
        id identifier=V26Object(app,@"applicationIdentifier");
        if ([V26Object(app,@"applicationType") isEqual:@"User"] && [identifier isKindOfClass:NSString.class]) [identifiers addObject:identifier];
    }
    if (identifiers.count) {
        NSString *selected=identifiers[arc4random_uniform((uint32_t)identifiers.count)];
        NSError *error=nil;
        if([[Velvet2PrefsManager sharedInstance] saveValue:selected forKey:@"currentIcon" error:&error]) [self loadIcon:selected];
        else V26Report(@"preview.iconSaveError",error.localizedDescription ?: @"Save failed");
        if(self.appChanged)self.appChanged();
    }
}
- (void)traitCollectionDidChange:(UITraitCollection *)previous { [super traitCollectionDidChange:previous];[self updatePreview]; }
@end
