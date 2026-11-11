#import "qwelllLoopScrollConfig.h"
#import "qwelllLoopScrollPreferences.h"

@interface qwelllLoopScrollConfig ()
@property (atomic, copy) NSDictionary *snapshot;
@property (nonatomic, strong) dispatch_queue_t reloadQueue;
@end

static void qwelll_loopscroll_preferencesDidChange(CFNotificationCenterRef center, void *observer,
                                          CFStringRef name, const void *object, CFDictionaryRef info) {
    qwelllLoopScrollConfig *config = (__bridge qwelllLoopScrollConfig *)observer;
    dispatch_async(config.reloadQueue, ^{
        [config qwelll_loopscroll_reload];
    });
}

@implementation qwelllLoopScrollConfig

+ (instancetype)qwelll_loopscroll_shared {
    static qwelllLoopScrollConfig *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _reloadQueue = dispatch_queue_create("com.qwelll.loopscroll.preferences", DISPATCH_QUEUE_SERIAL);
        [self qwelll_loopscroll_reload];
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
            (__bridge const void *)self, qwelll_loopscroll_preferencesDidChange,
            (__bridge CFStringRef)qwelllLoopScrollPreferencesChanged, NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately);
        // Close the window between the first read and observer registration.
        dispatch_async(_reloadQueue, ^{ [self qwelll_loopscroll_reload]; });
    }
    return self;
}

- (void)qwelll_loopscroll_reload {
    self.snapshot = qwelll_loopscroll_readPreferences();
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:qwelllLoopScrollPreferencesChanged object:self];
    });
}

- (id)qwelll_loopscroll_valueForKey:(NSString *)key defaultValue:(id)defaultValue {
    return self.snapshot[key] ?: defaultValue;
}

- (BOOL)qwelll_loopscroll_isEnabled {
    id value = [self qwelll_loopscroll_valueForKey:@"enabled" defaultValue:@(YES)];
    return [value isKindOfClass:[NSNumber class]] ? [value boolValue] : YES;
}

- (void)dealloc {
    CFNotificationCenterRemoveEveryObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                            (__bridge const void *)self);
}

@end
