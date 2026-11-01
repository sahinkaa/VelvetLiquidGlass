#import "../headers/HeadersPreferences.h"
@implementation Velvet2SettingsController
- (void)setSpecifier:(PSSpecifier *)specifier {
    [super setSpecifier:specifier];
    self.v26Specifiers = nil;
}
- (NSArray *)specifiers {
    if (!self.v26Specifiers) {
        id key = [self.specifier propertyForKey:@"key"];
        if ([key isKindOfClass:NSString.class] && [key containsString:@"."]) {
            self.identifier = key;
            self.identifierName = self.specifier.name;
        }
        self.v26Specifiers = [self visibleSpecifiersFromPlist:@"Settings"];
        if ([self.identifier isEqual:@"com.noisyflake.velvetFocus"]) {
            for (PSSpecifier *specifier in self.v26Specifiers) {
                if ([@[@"Date", @"appIconCornerRadiusCircle"] containsObject:[specifier propertyForKey:@"key"]])
                    [specifier setProperty:@NO forKey:@"enabled"];
            }
        }
    }
    self.title = self.identifierName ?: @"Global Settings";
    return self.v26Specifiers;
}
@end
