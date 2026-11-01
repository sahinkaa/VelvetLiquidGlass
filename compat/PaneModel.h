#import <Foundation/Foundation.h>

// The native table consumes these groups directly; no PSListController or
// PSSpecifier cache participates in the data source.
NSArray<NSDictionary *> *V26PaneSections(NSDictionary *resource, NSDictionary *effective);
NSString *V26Destination(NSDictionary *row);
