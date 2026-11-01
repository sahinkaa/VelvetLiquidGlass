#import <Foundation/Foundation.h>
#import "../compat/PaneModel.h"
#import "../compat/SettingsStore.h"
#include <assert.h>
#include <math.h>

static NSDictionary *resource(NSString *folder, NSString *name) {
    NSString *path = [folder stringByAppendingPathComponent:[name stringByAppendingPathExtension:@"plist"]];
    NSData *data = [NSData dataWithContentsOfFile:path];
    assert(data);
    id object = [NSPropertyListSerialization propertyListWithData:data options:0 format:NULL error:nil];
    assert([object isKindOfClass:NSDictionary.class]);
    return object;
}
static NSArray *rows(NSArray *sections) {
    NSMutableArray *result = [NSMutableArray new];
    for (NSDictionary *section in sections) [result addObjectsFromArray:section[@"rows"]];
    return result;
}
static NSDictionary *find(NSArray *items, NSString *key) {
    for (NSDictionary *row in items) if ([row[@"key"] isEqual:key]) return row;
    return nil;
}
int main(int argc, char **argv) {
    @autoreleasepool {
        assert(argc == 2);
        NSString *folder = @(argv[1]);
        NSMutableDictionary *values = [V26Defaults() mutableCopy];
        [values addEntriesFromDictionary:@{@"backgroundEnabled": @YES, @"borderEnabled": @YES,
            @"shadowEnabled": @YES, @"shadowWidth": @3.1465, @"shadowIconAlpha": @48.4125,
            @"cornerRadiusEnabled": @YES, @"cornerRadiusPercent": @30}];
        NSArray *root = rows(V26PaneSections(resource(folder, @"Root"), values));
        assert(root.count == 9);
        assert(find(root, @"enabled"));
        NSUInteger links = 0;
        for (NSDictionary *row in root) if (V26Destination(row)) ++links;
        assert(links == 2);
        NSUInteger reset=NSNotFound,export=NSNotFound,import=NSNotFound;
        for(NSUInteger i=0;i<root.count;++i){NSString *a=root[i][@"action"];if([a isEqual:@"resetSettings"])reset=i;else if([a isEqual:@"exportSettings"])export=i;else if([a isEqual:@"importSettings"])import=i;}
        assert(reset!=NSNotFound && export==reset+1 && import==export+1);
        assert([root[export][@"label"] isEqual:@"Export Settings"] && [root[import][@"label"] isEqual:@"Import Settings"]); // Global and per-app routes need no parent callback.
        NSArray *global = rows(V26PaneSections(resource(folder, @"Settings"), values));
        assert(global.count == 8);
        for (NSString *key in @[@"Border",@"Line",@"appIconHidden",@"appIconCornerRadiusCircle",@"stackDimmingViewHidden"]) assert(!find(global,key));
        for (NSString *key in @[@"borderEnabled",@"backgroundBlurHidden",@"lineWidth",@"appIconHidden",@"appIconCornerRadiusCircle",@"stackDimmingViewHidden"]) {assert(!V26PreferenceSupported(key));assert(!V26PreferenceSupported(V26PreferenceKey(key,@"fixture.app")));}
        assert(V26PreferenceSupported(@"shadowWidth_fixture.app"));
        assert(!find(global,@"appearance")); // Persistent header owns this control.
        assert(find(global,@"BannerBorder"));
        assert([find(global,@"BannerBorder")[@"label"] isEqual:@"Banner Borders"]);
        assert([V26Destination(find(global,@"BannerBorder")) isEqual:@"CustomBannerBorder"]);
        assert([global indexOfObject:find(global,@"BannerBorder")]<[global indexOfObject:find(global,@"Background")]);
        assert([global indexOfObject:find(global,@"BannerBorder")]<[global indexOfObject:find(global,@"Shadow")]);
        assert(V26PreferenceSupported(@"bannerBorderEnabled_fixture.app"));
        assert(!find(rows(V26PaneSections(resource(folder,@"CustomBackground"),values)),@"backgroundBlurHidden"));
        assert(find(global, @"Shadow"));
        assert([V26Destination(find(global, @"Shadow")) isEqual:@"CustomShadow"]);
        assert([V26Destination(find(global, @"Background")) isEqual:@"CustomBackground"]);
        assert(find(global,@"Time") && [find(global,@"Time")[@"label"] isEqual:@"Time"]);
        assert([V26Destination(find(global,@"Time")) isEqual:@"CustomTime"] && !find(global,@"Date"));
        assert([find(global,@"Time")[@"systemIcon"] isEqual:@"clock"]);
        assert(find(global, @"cornerRadiusPercent"));
        NSDictionary *radius=find(global,@"cornerRadiusPercent");
        assert([radius[@"min"] doubleValue]==0 && [radius[@"max"] doubleValue]==100);
        assert([find(global,@"cornerRadiusEnabled")[@"label"] isEqual:@"Enabled"]);
        NSDictionary *banner=resource(folder,@"CustomBannerBorder");
        assert([find(rows(V26PaneSections(banner,@{@"bannerBorderEnabled":@YES})),@"bannerBorderWidth")[@"min"] doubleValue]==0);
        assert([find(root,@"enabled")[@"label"] length]);
        BOOL github=NO;for(NSDictionary *r in root)if([r[@"action"] isEqual:@"github"])github=[r[@"label"] isEqual:@"github.com/sahinkaa"];
        assert(github);
        NSDictionary *glow = resource(folder, @"CustomShadow");
        assert([glow[@"title"] isEqual:@"Glow"]);
        NSArray *glowRows = rows(V26PaneSections(glow, values));
        assert(glowRows.count == 5);
        assert([find(glowRows,@"shadowWidth")[@"min"] doubleValue]==0);
        assert(find(glowRows, @"shadowEnabled") && find(glowRows, @"shadowWidth"));
        assert(find(glowRows, @"shadowType") && find(glowRows, @"shadowIconAlpha"));
        values[@"shadowType"] = @"color";
        glowRows = rows(V26PaneSections(glow, values));
        assert(glowRows.count == 6 && find(glowRows, @"shadowColor") && !find(glowRows, @"shadowIconAlpha"));
        values[@"shadowEnabled"] = @NO;
        glowRows = rows(V26PaneSections(glow, values));
        assert(glowRows.count == 1 && find(glowRows, @"shadowEnabled"));
        for(NSString *page in @[@"Background",@"BannerBorder",@"Shadow",@"Title",@"Message",@"Time"]) {
            NSString *prefix=[page isEqual:@"Time"] ? @"date" : [page stringByReplacingCharactersInRange:NSMakeRange(0,1) withString:[[page substringToIndex:1] lowercaseString]];
            NSMutableDictionary *v=[V26Defaults() mutableCopy];v[[prefix stringByAppendingString:@"Enabled"]]=@YES;v[[prefix stringByAppendingString:@"Type"]]=@"icon";
            NSDictionary *model=resource(folder,[@"Custom" stringByAppendingString:page]);NSArray *shown=rows(V26PaneSections(model,v));
            NSString *shadeKey=[prefix stringByAppendingString:@"IconShade"],*opacityKey=[prefix stringByAppendingString:@"IconAlpha"];
            NSDictionary *shade=find(shown,shadeKey);assert(shade && [shade[@"min"] doubleValue]==-100 && [shade[@"max"] doubleValue]==100);
            assert([V26Defaults()[shadeKey] doubleValue]==0 && [shown indexOfObject:shade]==[shown indexOfObject:find(shown,opacityKey)]+1);
            for(NSString *type in ([page isEqual:@"Shadow"] ? @[@"color"] : @[@"color",@"gradient"])) {
                v[[prefix stringByAppendingString:@"Type"]]=type;NSArray *typed=rows(V26PaneSections(model,v));assert(!find(typed,shadeKey));
                NSString *suffix=[type isEqual:@"color"] ? @"Color" : @"Gradient";
                NSString *base=[prefix stringByAppendingString:suffix];
                NSDictionary *alpha=find(typed,[base stringByAppendingString:@"Alpha"]),*shade=find(typed,[base stringByAppendingString:@"Shade"]);
                assert(alpha && shade && [alpha[@"min"] doubleValue]==0 && [alpha[@"max"] doubleValue]==100);
                assert([shade[@"min"] doubleValue]==-100 && [shade[@"max"] doubleValue]==100);
                NSDictionary *lastColor=find(typed,[base stringByAppendingString:[type isEqual:@"color"] ? @"" : @"2"]);
                assert(lastColor && [typed indexOfObject:alpha]==[typed indexOfObject:lastColor]+1 && [typed indexOfObject:shade]==[typed indexOfObject:alpha]+1);
                assert([V26Defaults()[alpha[@"key"]] doubleValue]==100 && [V26Defaults()[shade[@"key"]] doubleValue]==0);
                v[[prefix stringByAppendingString:@"Enabled"]]=@NO;
                assert(!find(rows(V26PaneSections(model,v)),alpha[@"key"]));v[[prefix stringByAppendingString:@"Enabled"]]=@YES;
            }
        }
        assert(!find(rows(V26PaneSections(banner,@{@"bannerBorderEnabled":@YES})),@"bannerBorderEnabled")[@"cellSubtitleText"]);
        // All original gradient and direction controls survive the native table.
        for (NSString *name in @[@"Background", @"Title", @"Message", @"Time"]) {
            NSString *prefix = [name isEqual:@"Time"] ? @"date" : name.lowercaseString;
            values[[prefix stringByAppendingString:@"Enabled"]] = @YES;
            values[[prefix stringByAppendingString:@"Type"]] = @"gradient";
            NSArray *items = rows(V26PaneSections(resource(folder, [@"Custom" stringByAppendingString:name]), values));
            assert(find(items, [prefix stringByAppendingString:@"Gradient1"]));
            assert(find(items, [prefix stringByAppendingString:@"Gradient2"]));
            assert(find(items, [prefix stringByAppendingString:@"GradientDirection"]));
        }
        assert([rows(V26PaneSections(nil, values)).firstObject[@"cell"] isEqual:@"Error"]);
        assert([rows(V26PaneSections(@{@"items": @"bad"}, values)).firstObject[@"cell"] isEqual:@"Error"]);
        assert([rows(V26PaneSections(@{@"items": @[]}, values)).firstObject[@"cell"] isEqual:@"Error"]);
        assert(!V26Destination(@{@"detail": @"Velvet2CustomizationController", @"key": @"Invalid"}));
        puts("PASS: native data-source models load 9 root rows, 8 retained global rows with removed features unavailable and all five Icon Color Glow controls; conditional/static/gradient controls, navigation and visible resource-error fallbacks");
    }
    return 0;
}
