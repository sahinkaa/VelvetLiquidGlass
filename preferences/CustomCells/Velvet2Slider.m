#import "../../headers/HeadersPreferences.h"

@implementation Velvet2Slider
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier specifier:(PSSpecifier *)specifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier specifier:specifier];

    if (self) {
        [((PSSegmentableSlider *)[self control]) setMinimumTrackTintColor:kVelvetColor];

        if (specifier.properties[@"label"]) {
            self.nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(specifier.properties[@"systemIcon"] ? 60 : 15, 11, 0, 0)];
            self.nameLabel.text = specifier.properties[@"label"];
            [self.nameLabel sizeToFit];
            [self.contentView insertSubview:self.nameLabel atIndex:0];
        }

        if (specifier.properties[@"systemIcon"]) {
            UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithFont:[UIFont systemFontOfSize:25]];
            UIImage *image = [UIImage systemImageNamed:specifier.properties[@"systemIcon"] withConfiguration:config];
            [specifier setProperty:image forKey:@"iconImage"];

            self.imageView.tintColor = kVelvetColor;
        }

        // iOS 16 fix
        for (NSLayoutConstraint *c in self.control.constraints) {
            [self.control removeConstraint:c];
        }

        [self.control layoutIfNeeded];
    }

    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    PSViewController *controller = V26PreferenceController(self);
    if ([controller isKindOfClass:NSClassFromString(@"Velvet2PreviewController")]) {
        Velvet2PreviewController *previewController = (Velvet2PreviewController *)controller;

        if (previewController.identifier && [previewController appSettingForKeyExists:self.specifier.properties[@"key"]]) {
            self.backgroundColor = [kVelvetColor colorWithAlphaComponent:0.3];
        }
    }

    // UIKit owns the slider's internal hierarchy on current iOS versions.
    // Place only the public control and our own label.
    UISlider *slider = [self.control isKindOfClass:UISlider.class] ? (UISlider *)self.control : nil;
    if (slider && self.nameLabel) {
        CGFloat left = self.specifier.properties[@"systemIcon"] ? 60 : 15;
        self.nameLabel.frame = CGRectMake(left, (self.contentView.bounds.size.height - 24) / 2, 55, 24);
        slider.frame = CGRectMake(left + 65, 8, MAX(1, self.contentView.bounds.size.width - left - 85), MAX(1, self.contentView.bounds.size.height - 16));
    }
}
@end
