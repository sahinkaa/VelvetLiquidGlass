#import "../headers/HeadersPreferences.h"
#import "../compat/SettingsStore.h"

@implementation Velvet2PreviewController
- (void)reloadSpecifiers {
    self.v26Specifiers = nil;
    [super reloadSpecifiers];
}
- (void)v26LoadContext {
    id identifier = [self.specifier propertyForKey:@"v26Identifier"];
    if ([identifier isKindOfClass:NSString.class]) self.identifier = identifier;
}
- (NSMutableArray *)visibleSpecifiersFromPlist:(NSString *)plist {
    [self v26LoadContext];
    Velvet2PrefsManager *manager = [Velvet2PrefsManager sharedInstance];
    NSMutableArray *result = [[self loadSpecifiersFromPlistName:plist target:self] mutableCopy] ?: [NSMutableArray new];
    for (PSSpecifier *specifier in [result copy]) {
        NSString *requirement = [specifier propertyForKey:@"require"];
        NSMutableDictionary *effective = [NSMutableDictionary new];
        for (NSString *part in [requirement componentsSeparatedByString:@"&"]) {
            NSString *key = [[part componentsSeparatedByString:@"="] firstObject];
            if ([key hasPrefix:@"!"]) key = [key substringFromIndex:1];
            id value = [manager settingForKey:key withIdentifier:self.identifier];
            if (value) effective[key] = value;
        }
        if (!V26Requirement(requirement, effective)) [result removeObject:specifier];
        if (self.identifier) [specifier setProperty:self.identifier forKey:@"v26Identifier"];
    }
    return result;
}
- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    Velvet2PrefsManager *manager = [Velvet2PrefsManager sharedInstance];
    NSString *key = [specifier propertyForKey:@"key"];
    NSString *fullKey = V26PreferenceKey(key, self.identifier);
    if (!fullKey) return;
    // Keep the specifier's base key stable across repeated writes and reloads.
    id stored = self.identifier.length && [[manager objectForKey:key] isEqual:value] ? nil : value;
    NSError *error = nil;
    if (![manager saveValue:stored forKey:fullKey error:&error]) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Couldn’t Save Setting" message:error.localizedDescription ?: @"Please reopen this page and try again." preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    [self.preview updatePreview];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.sahinkaa.velvetliquidglass/preferenceUpdate"), NULL, NULL, YES);
    dispatch_async(dispatch_get_main_queue(), ^{ [self reloadSpecifiers]; });
}
- (id)readPreferenceValue:(PSSpecifier *)specifier {
    return [[Velvet2PrefsManager sharedInstance] settingForKey:[specifier propertyForKey:@"key"] withIdentifier:self.identifier];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat width = self.table.bounds.size.width;
    if (width <= 0) return;
    if (!self.preview) {
        self.preview = [[Velvet2PreviewView alloc] initWithFrame:CGRectMake(0, 0, width, 170) notificationWidth:MAX(1, width - 40) identifier:self.identifier];
        self.table.tableHeaderView = self.preview;
    } else if (fabs(self.preview.bounds.size.width - width) > 0.5) {
        self.preview.frame = CGRectMake(0, 0, width, 170);
        self.table.tableHeaderView = self.preview;
    }
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[Velvet2PrefsManager sharedInstance] reloadFromDisk];
    [self.preview updatePreview];
}
- (BOOL)appSettingForKeyExists:(NSString *)key {
    return self.identifier.length && [[Velvet2PrefsManager sharedInstance] objectForKey:V26PreferenceKey(key, self.identifier)] != nil;
}
@end
