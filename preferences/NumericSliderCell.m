#import "NumericSliderCell.h"
#import "../compat/NumericSetting.h"
@interface VLGNumericSliderCell ()
@property(nonatomic, strong) UILabel *nameLabel;
@property(nonatomic, strong) UIButton *valueButton;
@property(nonatomic, strong) UILabel *valueLabel;
@property(nonatomic, strong) UISlider *slider;
@property(nonatomic) double minimum,maximum;
@property(nonatomic) BOOL percent;
@property(nonatomic,strong) UITapGestureRecognizer *shadeThumbReset,*shadeValueReset,*shadeValueEdit;
@end
@implementation VLGNumericSliderCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier {
    if (!(self=[super initWithStyle:style reuseIdentifier:identifier])) return nil;
    self.selectionStyle=UITableViewCellSelectionStyleNone;
    self.nameLabel=[UILabel new];self.nameLabel.font=[UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    self.valueButton=[UIButton buttonWithType:UIButtonTypeSystem];self.valueButton.titleLabel.font=[UIFont monospacedDigitSystemFontOfSize:17 weight:UIFontWeightMedium];
    self.valueButton.accessibilityHint=@"Tap to enter an exact value";
    [self.valueButton addTarget:self action:@selector(edit) forControlEvents:UIControlEventTouchUpInside];
    self.slider=[UISlider new];self.slider.continuous=YES;
    [self.slider addTarget:self action:@selector(moved) forControlEvents:UIControlEventValueChanged];
    [self.slider addTarget:self action:@selector(finished) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside|UIControlEventTouchCancel];
    // A label inside the tappable value control updates during tracking without
    // UIButton's animated/deferred title changes. No rendering or I/O here.
    self.valueLabel=[UILabel new];self.valueLabel.font=self.valueButton.titleLabel.font;
    self.valueLabel.textColor=UIColor.systemBlueColor;self.valueLabel.textAlignment=NSTextAlignmentRight;
    self.valueLabel.translatesAutoresizingMaskIntoConstraints=NO;[self.valueButton addSubview:self.valueLabel];
    [NSLayoutConstraint activateConstraints:@[[self.valueLabel.leadingAnchor constraintEqualToAnchor:self.valueButton.leadingAnchor],
        [self.valueLabel.trailingAnchor constraintEqualToAnchor:self.valueButton.trailingAnchor],
        [self.valueLabel.topAnchor constraintEqualToAnchor:self.valueButton.topAnchor],
        [self.valueLabel.bottomAnchor constraintEqualToAnchor:self.valueButton.bottomAnchor]]];
    UIStackView *heading=[[UIStackView alloc] initWithArrangedSubviews:@[self.nameLabel,self.valueButton]];heading.distribution=UIStackViewDistributionEqualSpacing;
    UIStackView *stack=[[UIStackView alloc] initWithArrangedSubviews:@[heading,self.slider]];
    stack.axis=UILayoutConstraintAxisVertical;stack.spacing=4;stack.translatesAutoresizingMaskIntoConstraints=NO;
    [self.contentView addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[[stack.leadingAnchor constraintEqualToAnchor:self.contentView.layoutMarginsGuide.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:self.contentView.layoutMarginsGuide.trailingAnchor],
        [stack.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:10],
        [stack.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-8],
        [self.slider.heightAnchor constraintGreaterThanOrEqualToConstant:36],
        [self.valueButton.widthAnchor constraintGreaterThanOrEqualToConstant:84],
        [self.valueButton.heightAnchor constraintGreaterThanOrEqualToConstant:44]]];
    self.shadeThumbReset=[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(resetShade)];
    self.shadeThumbReset.numberOfTapsRequired=2;
    self.shadeThumbReset.delaysTouchesBegan=NO;self.shadeThumbReset.delaysTouchesEnded=NO;
    self.shadeThumbReset.cancelsTouchesInView=NO;[self.slider addGestureRecognizer:self.shadeThumbReset];
    self.shadeValueReset=[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(resetShade)];
    self.shadeValueReset.numberOfTapsRequired=2;[self.valueButton addGestureRecognizer:self.shadeValueReset];
    self.shadeValueEdit=[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(enterExactValue)];
    [self.shadeValueEdit requireGestureRecognizerToFail:self.shadeValueReset];
    [self.valueButton addGestureRecognizer:self.shadeValueEdit];
    return self;
}
- (NSString *)formattedValue:(double)value {
    NSString *text=V26NumericText(value,self.percent);
    return self.minimum<0 && value>0 ? [@"+" stringByAppendingString:text] : text;
}
- (double)value {return V26NormalizeNumeric(self.slider.value,self.minimum,self.maximum);}
- (void)configureTitle:(NSString *)title minimum:(double)minimum maximum:(double)maximum value:(double)value percent:(BOOL)percent {
    self.minimum=minimum;self.maximum=maximum;self.percent=percent;
    BOOL shade=minimum<0;
    self.shadeThumbReset.enabled=shade;self.shadeValueReset.enabled=shade;self.shadeValueEdit.enabled=shade;
    self.valueButton.accessibilityHint=shade ? @"Tap to enter an exact value. Double-tap the slider or value to reset Shade to zero." : @"Tap to enter an exact value";
    self.valueButton.accessibilityCustomActions=shade ? @[[[UIAccessibilityCustomAction alloc] initWithName:@"Reset Shade to zero" target:self selector:@selector(resetShade)]] : nil;
    self.nameLabel.text=title;self.slider.accessibilityLabel=title;
    self.valueButton.accessibilityLabel=[title stringByAppendingString:@" value"];
    self.slider.minimumValue=minimum;self.slider.maximumValue=maximum;
    [self setNumericValue:value];
}
- (void)setNumericValue:(double)value {
    double normal=V26NormalizeNumeric(value,self.minimum,self.maximum);self.slider.value=normal;
    NSString *text=[self formattedValue:normal];
    self.valueLabel.text=text;self.valueButton.accessibilityValue=text;self.slider.accessibilityValue=text;
}
- (void)setOverrideHighlighted:(BOOL)highlight {self.nameLabel.textColor=highlight ? UIColor.systemBlueColor : UIColor.labelColor;}
- (void)moved {
    // Never reset the thumb while UIKit is tracking it. Update the visible value
    // before handing the number to the coalesced preview/persistence path.
    double value=self.value;NSString *text=[self formattedValue:value];
    self.valueLabel.text=text;self.valueButton.accessibilityValue=text;self.slider.accessibilityValue=text;
    if(self.changed)self.changed(value,NO);
}
- (void)finished {[self setNumericValue:self.value];if(self.changed)self.changed(self.value,YES);}
- (void)enterExactValue {if(self.enterValue)self.enterValue();}
- (void)edit {if(self.minimum>=0 || UIAccessibilityIsVoiceOverRunning())[self enterExactValue];}
- (BOOL)resetShade {
    if(self.minimum>=0)return NO;
    [self setNumericValue:0];if(self.changed)self.changed(0,YES);return YES;
}
@end
