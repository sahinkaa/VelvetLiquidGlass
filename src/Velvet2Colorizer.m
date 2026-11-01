#ifdef VLG_COLORIZER_HOST
#import "../tests/ColorizerUIKit.h"
#else
#import "../headers/HeadersTweak.h"
#endif

#import "../compat/CardStyle.h"
#include <math.h>

@implementation Velvet2Colorizer

- (instancetype)initWithIdentifier:(NSString *)identifier {
    Velvet2Colorizer *colorizer = [super init];

    if (!colorizer) return nil;
    colorizer.identifier = identifier;
    colorizer.manager = [Velvet2PrefsManager sharedInstance];
    // The preview, LS/NC and banner share text fallback rules. Material style
    // does not substitute a separate background-brightness text decision.
    colorizer.vlgDefaultTextColor=[[colorizer.manager settingForKey:@"appearance" withIdentifier:identifier] isEqual:@"light"] ? UIColor.blackColor : UIColor.whiteColor;

    return colorizer;
}

- (UIColor*)iconColor {
    if (!self.v26PaletteResolved) {
        self.v26PaletteResolved = YES;
        NSArray *iconColors = [[CCColorCube new] extractColorsFromImage:self.appIcon flags:CCAvoidWhite|CCOnlyBrightColors count:1];
        if (!iconColors.count) iconColors = [[CCColorCube new] extractColorsFromImage:self.appIcon flags:CCAvoidBlack count:1];
        _iconColor = iconColors.count ? iconColors[0] : nil;
    }

    return _iconColor;
}

- (UIColor *)iconColorForElement:(NSString *)element {
    UIColor *base=self.iconColor;if(!base)return nil;
    double shade=[[self.manager settingForKey:[element stringByAppendingString:@"IconShade"] withIdentifier:self.identifier] doubleValue];
    if(!isfinite(shade) || shade==0)return base;
    CGColorRef adjusted=VLGCreateShadedColor(base.CGColor,shade);
    UIColor *result=adjusted ? [UIColor colorWithCGColor:adjusted] : base;
    if(adjusted)CGColorRelease(adjusted);
    return result;
}

// Adjust endpoints before gradient rasterization. Neutral defaults preserve
// the chosen color, its color space and its picker alpha exactly.
- (UIColor *)configuredColor:(NSString *)key element:(NSString *)element type:(NSString *)type {
    UIColor *base=[self.manager colorForKey:key withIdentifier:self.identifier];if(!base)return nil;
    NSString *prefix=[element stringByAppendingString:type];
    id opacity=[self.manager settingForKey:[prefix stringByAppendingString:@"Alpha"] withIdentifier:self.identifier];
    double alpha=opacity ? [opacity doubleValue] : 100;
    if(!isfinite(alpha))alpha=100;alpha=fmax(0,fmin(100,alpha))/100.;
    double shade=[[self.manager settingForKey:[prefix stringByAppendingString:@"Shade"] withIdentifier:self.identifier] doubleValue];
    if(!isfinite(shade))shade=0;
    if(shade!=0) {
        CGColorRef adjusted=VLGCreateShadedColor(base.CGColor,shade);
        if(adjusted){base=[UIColor colorWithCGColor:adjusted];CGColorRelease(adjusted);}
    }
    return alpha==1 ? base : [base colorWithAlphaComponent:CGColorGetAlpha(base.CGColor)*alpha];
}

- (void)colorBackground:(UIView *)backgroundView {
    UIColor *backgroundColor = nil;

    BOOL backgroundEnabled = [[self.manager settingForKey:@"backgroundEnabled" withIdentifier:self.identifier] boolValue];

    if (backgroundEnabled) {
        NSString *backgroundType = [self.manager settingForKey:@"backgroundType" withIdentifier:self.identifier];
        
        if ([backgroundType isEqual:@"color"]) {
            backgroundColor = [self configuredColor:@"backgroundColor" element:@"background" type:@"Color"];
        } else if ([backgroundType isEqual:@"gradient"]) {
            NSArray *gradientColors = @[(id)[self configuredColor:@"backgroundGradient1" element:@"background" type:@"Gradient"].CGColor, (id)[self configuredColor:@"backgroundGradient2" element:@"background" type:@"Gradient"].CGColor];
            backgroundColor = [UIColor colorFromGradient:gradientColors withDirection:[self.manager settingForKey:@"backgroundGradientDirection" withIdentifier:self.identifier] inFrame:backgroundView.frame];
        } else if ([backgroundType isEqual:@"icon"]) {
            backgroundColor = self.iconColor ? [[self iconColorForElement:@"background"] colorWithAlphaComponent:[self.manager alphaValueForKey:@"backgroundIconAlpha" withIdentifier:self.identifier]] : nil;
        }
    }

    backgroundView.backgroundColor = backgroundColor;
}

- (void)setBackgroundBlur:(UIView *)materialView {
    BOOL hideBackground = [[self.manager settingForKey:@"backgroundBlurHidden" withIdentifier:self.identifier] boolValue];
    materialView.alpha = hideBackground ? 0 : 1;
    materialView.hidden = hideBackground ? YES : NO;
}

- (void)colorBorder:(UIView *)borderView {
    UIColor *borderColor = nil;

    BOOL borderEnabled = [[self.manager settingForKey:@"bannerBorderEnabled" withIdentifier:self.identifier] boolValue];

    if (borderEnabled) {
        NSString *borderType = [self.manager settingForKey:@"bannerBorderType" withIdentifier:self.identifier];

        if ([borderType isEqual:@"color"]) {
            borderColor = [self configuredColor:@"bannerBorderColor" element:@"bannerBorder" type:@"Color"];
        } else if ([borderType isEqual:@"gradient"]) {
            NSArray *gradientColors = @[(id)[self configuredColor:@"bannerBorderGradient1" element:@"bannerBorder" type:@"Gradient"].CGColor, (id)[self configuredColor:@"bannerBorderGradient2" element:@"bannerBorder" type:@"Gradient"].CGColor];
            borderColor = [UIColor colorFromGradient:gradientColors withDirection:[self.manager settingForKey:@"bannerBorderGradientDirection" withIdentifier:self.identifier] inFrame:borderView.frame flipY:YES];
        } else if ([borderType isEqual:@"icon"]) {
            borderColor = self.iconColor ? [[self iconColorForElement:@"bannerBorder"] colorWithAlphaComponent:[self.manager alphaValueForKey:@"bannerBorderIconAlpha" withIdentifier:self.identifier]] : nil;
        }
    }

    borderView.layer.borderWidth = borderColor ? [[self.manager settingForKey:@"bannerBorderWidth" withIdentifier:self.identifier] floatValue] : 0;
    borderView.layer.borderColor = borderColor ? borderColor.CGColor : nil;
}

- (void)colorShadow:(UIView *)shadowView {
    UIColor *shadowColor = nil;

    BOOL shadowEnabled = [[self.manager settingForKey:@"shadowEnabled" withIdentifier:self.identifier] boolValue];

    if (shadowEnabled) {
        NSString *shadowType = [self.manager settingForKey:@"shadowType" withIdentifier:self.identifier];

        if ([shadowType isEqual:@"color"]) {
            shadowColor = [self configuredColor:@"shadowColor" element:@"shadow" type:@"Color"];
        } else if ([shadowType isEqual:@"icon"]) {
            shadowColor = self.iconColor ? [[self iconColorForElement:@"shadow"] colorWithAlphaComponent:[self.manager alphaValueForKey:@"shadowIconAlpha" withIdentifier:self.identifier]] : nil;
        }
    }

    shadowView.layer.shadowRadius = shadowColor ? [[self.manager settingForKey:@"shadowWidth" withIdentifier:self.identifier] floatValue] : 0;
    shadowView.layer.shadowOffset = CGSizeZero;
    shadowView.layer.shadowColor = shadowColor ? shadowColor.CGColor : nil;
    shadowView.layer.shadowOpacity = 1;
}

- (void)colorLine:(UIView *)lineView inFrame:(CGRect)frame {
    if (!lineView || lineView.layer.sublayers.count < 2) return;
    NSString *position = [self.manager settingForKey:@"linePosition" withIdentifier:self.identifier];
    CGFloat size = [[self.manager settingForKey:@"lineWidth" withIdentifier:self.identifier] floatValue];

    CGFloat x = [position isEqual:@"right"] || [position isEqual:@"leftRight"] ? frame.size.width - size : 0;
    CGFloat y = [position isEqual:@"bottom"] || [position isEqual:@"topBottom"] ? frame.size.height - size : 0;
    CGFloat width = [position isEqual:@"top"] || [position isEqual:@"bottom"] || [position isEqual:@"topBottom"] ? frame.size.width : size;
    CGFloat height = [position isEqual:@"left"] || [position isEqual:@"right"] || [position isEqual:@"leftRight"] ? frame.size.height : size;
    lineView.layer.sublayers[0].frame = CGRectMake(x, y, width, height);

    if ([position isEqual:@"topBottom"] || [position isEqual:@"leftRight"]) {
        lineView.layer.sublayers[1].frame = CGRectMake(0, 0, width, height);
    } else {
        lineView.layer.sublayers[1].frame = CGRectZero;
    }

    UIColor *lineColor = nil;

    BOOL lineEnabled = [[self.manager settingForKey:@"lineEnabled" withIdentifier:self.identifier] boolValue];

    if (lineEnabled) {
        NSString *lineType = [self.manager settingForKey:@"lineType" withIdentifier:self.identifier];

        if ([lineType isEqual:@"color"]) {
            lineColor = [self.manager colorForKey:@"lineColor" withIdentifier:self.identifier];
        } else if ([lineType isEqual:@"gradient"]) {
            NSArray *gradientColors = @[(id)[self.manager colorForKey:@"lineGradient1" withIdentifier:self.identifier].CGColor, (id)[self.manager colorForKey:@"lineGradient2" withIdentifier:self.identifier].CGColor];
            lineColor = [UIColor colorFromGradient:gradientColors withDirection:[self.manager settingForKey:@"lineGradientDirection" withIdentifier:self.identifier] inFrame:lineView.layer.sublayers[0].frame flipY:YES];
        } else if ([lineType isEqual:@"icon"]) {
            lineColor = self.iconColor ? [self.iconColor colorWithAlphaComponent:[self.manager alphaValueForKey:@"lineIconAlpha" withIdentifier:self.identifier]] : nil;
        }
    }

    lineView.layer.sublayers[0].backgroundColor = lineColor ? lineColor.CGColor : nil;
    lineView.layer.sublayers[1].backgroundColor = lineColor ? lineColor.CGColor : nil;
}

- (void)colorTitle:(UILabel*)title {
    if (![title isKindOfClass:UILabel.class]) return;
    UIColor *titleColor = nil;

    BOOL titleEnabled = [[self.manager settingForKey:@"titleEnabled" withIdentifier:self.identifier] boolValue];

    if (titleEnabled) {
        NSString *titleType = [self.manager settingForKey:@"titleType" withIdentifier:self.identifier];
        
        if ([titleType isEqual:@"color"]) {
            titleColor = [self configuredColor:@"titleColor" element:@"title" type:@"Color"];
        } else if ([titleType isEqual:@"gradient"]) {
            NSArray *gradientColors = @[(id)[self configuredColor:@"titleGradient1" element:@"title" type:@"Gradient"].CGColor, (id)[self configuredColor:@"titleGradient2" element:@"title" type:@"Gradient"].CGColor];
            CGSize size = [title sizeThatFits:title.frame.size];
            titleColor = [UIColor colorFromGradient:gradientColors withDirection:[self.manager settingForKey:@"titleGradientDirection" withIdentifier:self.identifier] inFrame:CGRectMake(title.frame.origin.x, title.frame.origin.y, size.width, size.height)];
        } else if ([titleType isEqual:@"icon"]) {
            titleColor = self.iconColor ? [[self iconColorForElement:@"title"] colorWithAlphaComponent:[self.manager alphaValueForKey:@"titleIconAlpha" withIdentifier:self.identifier]] : nil;
        }
    }

    title.textColor = titleColor ? titleColor : [(self.vlgDefaultTextColor ?: UIColor.labelColor) colorWithAlphaComponent:0.9];
}

- (void)colorMessage:(UILabel*)message {
    if (![message isKindOfClass:UILabel.class] && ![message isKindOfClass:UITextView.class]) return;
    UIColor *messageColor = nil;

    BOOL messageEnabled = [[self.manager settingForKey:@"messageEnabled" withIdentifier:self.identifier] boolValue];

    if (messageEnabled) {
        NSString *messageType = [self.manager settingForKey:@"messageType" withIdentifier:self.identifier];
        
        if ([messageType isEqual:@"color"]) {
            messageColor = [self configuredColor:@"messageColor" element:@"message" type:@"Color"];
        } else if ([messageType isEqual:@"gradient"]) {
            NSArray *gradientColors = @[(id)[self configuredColor:@"messageGradient1" element:@"message" type:@"Gradient"].CGColor, (id)[self configuredColor:@"messageGradient2" element:@"message" type:@"Gradient"].CGColor];
            CGSize size = [message sizeThatFits:message.frame.size];
            messageColor = [UIColor colorFromGradient:gradientColors withDirection:[self.manager settingForKey:@"messageGradientDirection" withIdentifier:self.identifier] inFrame:CGRectMake(message.frame.origin.x, message.frame.origin.y, size.width, size.height)];
        } else if ([messageType isEqual:@"icon"]) {
            messageColor = self.iconColor ? [[self iconColorForElement:@"message"] colorWithAlphaComponent:[self.manager alphaValueForKey:@"messageIconAlpha" withIdentifier:self.identifier]] : nil;
        }
    }

    message.textColor = messageColor ? messageColor : [(self.vlgDefaultTextColor ?: UIColor.labelColor) colorWithAlphaComponent:0.9];
}

- (void)colorDate:(UILabel*)date {
    if (![date isKindOfClass:UILabel.class]) return;
    UIColor *dateColor = nil;

    BOOL dateEnabled = [[self.manager settingForKey:@"dateEnabled" withIdentifier:self.identifier] boolValue];

    if (dateEnabled) {
        NSString *dateType = [self.manager settingForKey:@"dateType" withIdentifier:self.identifier];
        
        if ([dateType isEqual:@"color"]) {
            dateColor = [self configuredColor:@"dateColor" element:@"date" type:@"Color"];
        } else if ([dateType isEqual:@"gradient"]) {
            NSArray *gradientColors = @[(id)[self configuredColor:@"dateGradient1" element:@"date" type:@"Gradient"].CGColor, (id)[self configuredColor:@"dateGradient2" element:@"date" type:@"Gradient"].CGColor];
            dateColor = [UIColor colorFromGradient:gradientColors withDirection:[self.manager settingForKey:@"dateGradientDirection" withIdentifier:self.identifier] inFrame:date.frame];
        } else if ([dateType isEqual:@"icon"]) {
            dateColor = self.iconColor ? [[self iconColorForElement:@"date"] colorWithAlphaComponent:[self.manager alphaValueForKey:@"dateIconAlpha" withIdentifier:self.identifier]] : nil;
        }
    }

    date.layer.filters = nil;

    // Let's fake the label color here, since the stupid filter won't play nice
    date.textColor = dateColor ? dateColor : [(self.vlgDefaultTextColor ?: UIColor.labelColor) colorWithAlphaComponent:0.5];
}

- (void)setAppIconCornerRadius:(UIView*)appIcon {
    appIcon.clipsToBounds = YES;
    appIcon.layer.cornerRadius = [[self.manager settingForKey:@"appIconCornerRadiusCircle" withIdentifier:self.identifier] boolValue] ? appIcon.frame.size.height / 2 : 0;
}

- (void)toggleAppIconVisibility:(UIView*)appIcon withTitle:(UILabel*)title message:(UILabel*)message footer:(UILabel*)footer alwaysUpdate:(BOOL)alwaysUpdate {
    BOOL shouldHide = [[self.manager settingForKey:@"appIconHidden" withIdentifier:self.identifier] boolValue];

    // AlwaysUpdate is necessary for the real notification, as layoutSubviews gets called constantly and would override our one-time change.
    // However, in the Settings preview, this is not necessary and would only move the labels too far to the left
    
    if (shouldHide && (!appIcon.hidden || alwaysUpdate)) {
        appIcon.alpha = 0; // For smooth animations in the preview
        appIcon.hidden = YES;
        title.frame = CGRectMake(title.frame.origin.x - appIcon.frame.size.width - 8, title.frame.origin.y, title.frame.size.width + appIcon.frame.size.width, title.frame.size.height);
        message.frame = CGRectMake(message.frame.origin.x - appIcon.frame.size.width - 8, message.frame.origin.y, message.frame.size.width + appIcon.frame.size.width, message.frame.size.height);
        if (footer) footer.frame = CGRectMake(footer.frame.origin.x - appIcon.frame.size.width - 8, footer.frame.origin.y, footer.frame.size.width + appIcon.frame.size.width, footer.frame.size.height);
    } else if (!shouldHide && appIcon.hidden) {
        appIcon.alpha = 1;
        appIcon.hidden = NO;
        title.frame = CGRectMake(title.frame.origin.x + appIcon.frame.size.width + 8, title.frame.origin.y, title.frame.size.width - appIcon.frame.size.width, title.frame.size.height);
        message.frame = CGRectMake(message.frame.origin.x + appIcon.frame.size.width + 8, message.frame.origin.y, message.frame.size.width - appIcon.frame.size.width, message.frame.size.height);
        if (footer) footer.frame = CGRectMake(footer.frame.origin.x + appIcon.frame.size.width + 8, footer.frame.origin.y, footer.frame.size.width - appIcon.frame.size.width, footer.frame.size.height);
    }
}

- (void)setAppearance:(UIView*)view {
    NSString *appearance = [self.manager settingForKey:@"appearance" withIdentifier:self.identifier];
	UIUserInterfaceStyle style=[appearance isEqual:@"dark"] ? UIUserInterfaceStyleDark : [appearance isEqual:@"light"] ? UIUserInterfaceStyleLight : UIUserInterfaceStyleUnspecified;
    if(view.overrideUserInterfaceStyle!=style)view.overrideUserInterfaceStyle=style;
}

@end