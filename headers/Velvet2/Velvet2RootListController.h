#import <Preferences/PSListController.h>
#import <spawn.h>

@interface Velvet2RootListController : PSListController
@property(nonatomic, strong) NSArray *v26Specifiers;
-(void)setupHeader;
-(void)setupFooterVersion;
-(void)resetSettings;
-(void)twitter;
-(void)paypal;
-(void)setTweakEnabled:(id)value specifier:(PSSpecifier *)specifier;
-(void)respring;
@end
