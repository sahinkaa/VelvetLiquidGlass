#import "../headers/HeadersPreferences.h"
@implementation Velvet2CustomizationController
- (void)setSpecifier:(PSSpecifier *)specifier {
    [super setSpecifier:specifier];
    self.v26Specifiers = nil;
}
- (NSArray *)specifiers {
    if (!self.v26Specifiers) {
        NSString *section = [self.specifier propertyForKey:@"key"] ?: self.currentKey;
        if (![@[@"Background", @"Border", @"Line", @"Shadow", @"Title", @"Message", @"Date"] containsObject:section]) return @[];
        self.currentKey = section;
        self.v26Specifiers = [self visibleSpecifiersFromPlist:[@"Custom" stringByAppendingString:section]];
        self.title = [section isEqual:@"Shadow"] ? @"Glow" : section;
    }
    return self.v26Specifiers;
}
@end
