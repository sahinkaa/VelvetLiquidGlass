#import "../headers/HeadersPreferences.h"

@implementation Velvet2AppSelectController

- (NSArray *)specifiers {
	if (!self.v26Specifiers) {
        NSMutableArray *mutableSpecifiers = [NSMutableArray new];
		
        LSApplicationWorkspace *workspace = [NSClassFromString(@"LSApplicationWorkspace") defaultWorkspace];
		NSArray *apps = [workspace allInstalledApplications];

        for (LSApplicationProxy *app in apps) {
            if ([app.applicationType isEqual:@"User"] || ([app.applicationType isEqual:@"System"] && ![app.appTags containsObject:@"hidden"] && !app.launchProhibited && !app.placeholder && !app.removedSystemApp)) {

				if ([app.applicationIdentifier isEqual:@"com.apple.webapp"]) continue;

				PSSpecifier* specifier = [PSSpecifier preferenceSpecifierNamed:app.localizedName
										target:self
										set:@selector(setPreferenceValue:specifier:)
										get:@selector(readPreferenceValue:)
										detail:Nil
										cell:PSLinkCell
										edit:Nil];

				[specifier setProperty:app.applicationIdentifier forKey:@"key"];
				[specifier setProperty:app.localizedName forKey:@"label"];
				[specifier setProperty:@"com.sahinkaa.velvetliquidglass" forKey:@"defaults"];
				[specifier setProperty:@"1" forKey:@"isController"];
				specifier.detailControllerClass = NSClassFromString(@"Velvet2SettingsController");

				[mutableSpecifiers addObject:specifier];
				
				UIImage *icon = [UIImage _applicationIconImageForBundleIdentifier:app.applicationIdentifier format:0 scale:UIScreen.mainScreen.scale];

                if ([icon isKindOfClass:UIImage.class]) {
                    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
                    format.scale = UIScreen.mainScreen.scale;
                    UIImage *resized = [[[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(29, 29) format:format] imageWithActions:^(UIGraphicsImageRendererContext *context) { [icon drawInRect:CGRectMake(0, 0, 29, 29)]; }];
                    if (resized) [specifier setProperty:resized forKey:@"iconImage"];
                }

            }
        }

		// Add Focus Specifier
		PSSpecifier* specifier = [PSSpecifier preferenceSpecifierNamed:@"Focus"
										target:self
										set:@selector(setPreferenceValue:specifier:)
										get:@selector(readPreferenceValue:)
										detail:Nil
										cell:PSLinkCell
										edit:Nil];

		[specifier setProperty:@"com.noisyflake.velvetFocus" forKey:@"key"];
		[specifier setProperty:@"Focus" forKey:@"label"];
		[specifier setProperty:@"com.sahinkaa.velvetliquidglass" forKey:@"defaults"];
		[specifier setProperty:@"1" forKey:@"isController"];
		specifier.detailControllerClass = NSClassFromString(@"Velvet2SettingsController");

		UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithFont:[UIFont systemFontOfSize:24]];
		UIImage *icon = [[UIImage systemImageNamed:@"moon.fill" withConfiguration:config] imageWithTintColor:[UIColor colorWithRed: 0.34 green: 0.34 blue: 0.81 alpha: 1.00] renderingMode:UIImageRenderingModeAlwaysOriginal];
		[specifier setProperty:icon forKey:@"iconImage"];

		[mutableSpecifiers addObject:specifier];


		// Sort specifiers alphabetically
        [mutableSpecifiers sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES selector:@selector(caseInsensitiveCompare:)]]];

        self.v26Specifiers = mutableSpecifiers;
	}

	return self.v26Specifiers;
}

@end
