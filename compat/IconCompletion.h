#pragma once
#import <Foundation/Foundation.h>
BOOL VLGImageCompletionMethod(Class cls,SEL selector);
void (^VLGAfterImageCompletion(void (^original)(id),dispatch_block_t after))(id);
