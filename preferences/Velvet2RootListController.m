#import "../headers/HeadersPreferences.h"
#import "../compat/Runtime.h"
#include <spawn.h>

@implementation Velvet2RootListController
- (void)reloadSpecifiers {
    self.v26Specifiers = nil;
    [super reloadSpecifiers];
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    return [[Velvet2PrefsManager sharedInstance] objectForKey:[specifier propertyForKey:@"key"]];
}
- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSError *error = nil;
    if (![[Velvet2PrefsManager sharedInstance] saveValue:value forKey:[specifier propertyForKey:@"key"] error:&error]) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Couldn’t Save Setting" message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}
- (NSArray *)specifiers {
	if (!self.v26Specifiers) {
		self.v26Specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
	}

	return self.v26Specifiers;
}

-(void)viewDidLayoutSubviews {
	[super viewDidLayoutSubviews];

	[self setupHeader];
	[self setupFooterVersion];
}

-(void)setupHeader {
    if (self.table.tableHeaderView) return;
	UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 140)];

    UIImage *image = [UIImage imageNamed:@"velvet-header-icon.png" inBundle:[NSBundle bundleForClass:NSClassFromString(@"Velvet2RootListController")] compatibleWithTraitCollection:nil];
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 30 - 4, self.view.bounds.size.width, 80)];
    imageView.contentMode = UIViewContentModeScaleAspectFit;
    [imageView setImage:image];

    [header addSubview:imageView];
	self.table.tableHeaderView = header;
}

-(void)setupFooterVersion {
    if (self.table.tableFooterView) return;
	NSString *firstLine = [NSString stringWithFormat:@"Velvet %@", PACKAGE_VERSION];

	NSMutableAttributedString *fullFooter =  [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\nwith \u2665 by NoisyFlake", firstLine]];

	[fullFooter beginEditing];
	[fullFooter addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:18] range:NSMakeRange(0, [firstLine length])];
	[fullFooter endEditing];
	
	UILabel *footerLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 100)];
	footerLabel.font = [UIFont systemFontOfSize:13];
	footerLabel.textColor = UIColor.systemGrayColor;
	footerLabel.numberOfLines = 2;
	footerLabel.attributedText = fullFooter;
	footerLabel.textAlignment = NSTextAlignmentCenter;
	self.table.tableFooterView = footerLabel;
}

- (void)resetSettings {
    NSError *error = nil;
    if ([[Velvet2PrefsManager sharedInstance] reset:&error]) {
        [self reloadSpecifiers];
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.sahinkaa.velvetliquidglass/preferenceUpdate"), NULL, NULL, YES);
    } else {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Couldn’t Reset Settings" message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}
-(void)twitter {
	NSURL *tweetbot = [NSURL URLWithString:@"tweetbot://NoisyFlake/user_profile/NoisyFlake"];
	NSURL *twitterrific = [NSURL URLWithString:@"twitterrific://profile?screen_name=NoisyFlake"];
	NSURL *twitter = [NSURL URLWithString:@"twitter://user?screen_name=NoisyFlake"];
	NSURL *web = [NSURL URLWithString:@"http://www.twitter.com/NoisyFlake"];
	
	if ([[UIApplication sharedApplication] canOpenURL:tweetbot]) {
        [[UIApplication sharedApplication] openURL:tweetbot options:@{} completionHandler:nil];
    } else if ([[UIApplication sharedApplication] canOpenURL:twitterrific]) {
        [[UIApplication sharedApplication] openURL:twitterrific options:@{} completionHandler:nil];
    } else if ([[UIApplication sharedApplication] canOpenURL:twitter]) {
        [[UIApplication sharedApplication] openURL:twitter options:@{} completionHandler:nil];
    } else {
        [[UIApplication sharedApplication] openURL:web options:@{} completionHandler:nil];
    }
}

-(void)paypal {
	[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://www.paypal.me/NoisyFlake"] options:@{} completionHandler:nil];
}

-(void)setTweakEnabled:(id)value specifier:(PSSpecifier *)specifier {
	[self setPreferenceValue:value specifier:specifier];

	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Respring" style:UIBarButtonItemStylePlain target:self action:@selector(respring)];
}

-(void)respring {
	pid_t pid;
	const char* args[] = {"sbreload", NULL};
	posix_spawn(&pid, V26RootPath(@"/usr/bin/sbreload").fileSystemRepresentation, NULL, NULL, (char* const*)args, NULL);
}
@end
