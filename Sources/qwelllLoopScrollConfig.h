#pragma once

#import <Foundation/Foundation.h>

@interface qwelllLoopScrollConfig : NSObject
+ (instancetype)qwelll_loopscroll_shared;
- (BOOL)qwelll_loopscroll_isEnabled;
- (id)qwelll_loopscroll_valueForKey:(NSString *)key defaultValue:(id)defaultValue;
- (void)qwelll_loopscroll_reload;
@end
