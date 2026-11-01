#import "PaneModel.h"
#import "SettingsStore.h"

NSArray<NSDictionary *> *V26PaneSections(NSDictionary *resource, NSDictionary *effective) {
    if (![resource isKindOfClass:NSDictionary.class] || ![resource[@"items"] isKindOfClass:NSArray.class])
        return @[@{@"title": @"Settings Unavailable", @"rows": @[@{@"cell": @"Error", @"label": @"The settings resource could not be loaded."}]}];
    NSMutableArray *sections = [NSMutableArray new];
    NSMutableDictionary *section = nil;
    for (id item in resource[@"items"]) {
        if (![item isKindOfClass:NSDictionary.class]) continue;
        id requirement = item[@"require"];
        if (requirement && (![requirement isKindOfClass:NSString.class] || !V26Requirement(requirement, effective))) continue;
        if ([item[@"cell"] isEqual:@"PSGroupCell"]) {
            section = [@{@"title": item[@"label"] ?: @"", @"footer": item[@"footerText"] ?: @"", @"rows": [NSMutableArray new]} mutableCopy];
            [sections addObject:section];
        } else {
            if (!section) {
                section = [@{@"title": @"", @"rows": [NSMutableArray new]} mutableCopy];
                [sections addObject:section];
            }
            [section[@"rows"] addObject:item];
        }
    }
    NSIndexSet *empty = [sections indexesOfObjectsPassingTest:^BOOL(NSDictionary *group, NSUInteger index, BOOL *stop) { return [group[@"rows"] count] == 0; }];
    [sections removeObjectsAtIndexes:empty];
    if (!sections.count) return @[@{@"title": @"Settings Unavailable", @"rows": @[@{@"cell": @"Error", @"label": @"No settings are available for this page."}]}];
    return sections;
}

NSString *V26Destination(NSDictionary *row) {
    NSString *detail = row[@"detail"];
    if ([detail isEqual:@"Velvet2SettingsController"]) return @"Settings";
    if ([detail isEqual:@"Velvet2AppSelectController"]) return @"Apps";
    if ([detail isEqual:@"Velvet2CustomizationController"] &&
        [@[@"Background", @"BannerBorder", @"Shadow", @"Title", @"Message", @"Time"] containsObject:row[@"key"]])
        return [@"Custom" stringByAppendingString:row[@"key"]];
    return nil;
}
