#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "qwelllLoopScrollConfig.h"
#import "qwelllLoopScrollPrivate.h"

// 桌面图标页无限循环滚动。
// 原理：包装 SBHomeScreenScrollView 的 delegate；在 scrollViewWillEndDragging:
// withVelocity:targetContentOffset: 中检测"已在最后一页仍向左甩 / 已在第一页仍向右甩"，
// 瞬移 contentOffset 到对侧端点并保留动量继续滑向下一页（惯性续滑），
// 手感与正常翻页一致：末页→（首页）→第二页，首页→（末页）→倒数第二页。
// 慢速拖拽松手（无甩动速度）不循环，保持系统橡皮筋回弹。

static void *qwelll_loopscroll_associatedProxyKey = &qwelll_loopscroll_associatedProxyKey;
static const CGFloat qwelll_loopscroll_wrapVelocityThreshold = 0.4;

static void qwelll_loopscroll_wrapTargetOffset(UIScrollView *scrollView,
                                               CGPoint velocity,
                                               CGPoint *targetContentOffset) {
    if (![[qwelllLoopScrollConfig qwelll_loopscroll_shared] qwelll_loopscroll_isEnabled]) {
        return;
    }
    CGFloat pageWidth = scrollView.bounds.size.width;
    CGFloat contentWidth = scrollView.contentSize.width;
    if (pageWidth < 1.0 || contentWidth <= pageWidth) {
        return;
    }
    NSInteger pageCount = (NSInteger)lround(contentWidth / pageWidth);
    if (pageCount < 2) {
        return;
    }
    CGFloat maxOffset = contentWidth - pageWidth;
    CGFloat x = scrollView.contentOffset.x;
    NSInteger page = (NSInteger)lround(x / pageWidth);

    if (velocity.x > qwelll_loopscroll_wrapVelocityThreshold && page >= pageCount - 1) {
        // 最后一页继续向左甩。
        // 惯性续滑：瞬移回第一页，再让动量滑到第二页，手感与正常翻页一致。
        // 仅两页时无需瞬移，直接改写吸附目标滑回第一页，动画与正常翻页相同。
        if (pageCount == 2) {
            targetContentOffset->x = 0;
        } else {
            scrollView.contentOffset = CGPointMake(0, scrollView.contentOffset.y);
            targetContentOffset->x = pageWidth;
        }
    } else if (velocity.x < -qwelll_loopscroll_wrapVelocityThreshold && page <= 0) {
        // 第一页继续向右甩：瞬移到最后一页，动量继续滑到倒数第二页。
        // 仅两页时直接改写吸附目标滑到最后一页。
        if (pageCount == 2) {
            targetContentOffset->x = maxOffset;
        } else {
            scrollView.contentOffset = CGPointMake(maxOffset, scrollView.contentOffset.y);
            targetContentOffset->x = maxOffset - pageWidth;
        }
    }
}

@interface qwelllLoopScrollDelegateProxy : NSObject
@property (nonatomic, weak) id loopscrollTarget;
- (instancetype)qwelll_loopscroll_initWithTarget:(id)target;
@end

@implementation qwelllLoopScrollDelegateProxy

- (instancetype)qwelll_loopscroll_initWithTarget:(id)target {
    self = [super init];
    if (self) {
        _loopscrollTarget = target;
    }
    return self;
}

// 始终应答 willEndDragging：即使原代理没实现它，也要保证循环逻辑有机会执行；
// 其余查询转发给原代理，避免 SpringBoard 内部对 delegate 的能力判断失真。
- (BOOL)respondsToSelector:(SEL)selector {
    if (selector == @selector(scrollViewWillEndDragging:withVelocity:targetContentOffset:)) {
        return YES;
    }
    return [super respondsToSelector:selector]
        || [_loopscrollTarget respondsToSelector:selector];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    NSMethodSignature *signature = [super methodSignatureForSelector:selector];
    if (!signature) {
        signature = [_loopscrollTarget methodSignatureForSelector:selector];
    }
    return signature;
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    id target = _loopscrollTarget;
    if (target && [target respondsToSelector:invocation.selector]) {
        [invocation invokeWithTarget:target];
    }
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView
                     withVelocity:(CGPoint)velocity
              targetContentOffset:(CGPoint *)targetContentOffset {
    id<UIScrollViewDelegate> target = _loopscrollTarget;
    if (target && [target respondsToSelector:_cmd]) {
        // 先让原代理按自己的规则给出吸附点，再在边界上改写。
        [target scrollViewWillEndDragging:scrollView
                             withVelocity:velocity
                      targetContentOffset:targetContentOffset];
    }
    qwelll_loopscroll_wrapTargetOffset(scrollView, velocity, targetContentOffset);
}

@end

%hook SBHomeScreenScrollView

- (void)setDelegate:(id)delegate {
    if (!delegate
        || ![[qwelllLoopScrollConfig qwelll_loopscroll_shared] qwelll_loopscroll_isEnabled]) {
        %orig;
        return;
    }
    qwelllLoopScrollDelegateProxy *proxy =
        objc_getAssociatedObject(self, qwelll_loopscroll_associatedProxyKey);
    if (!proxy || proxy.loopscrollTarget != delegate) {
        proxy = [[qwelllLoopScrollDelegateProxy alloc] qwelll_loopscroll_initWithTarget:delegate];
        objc_setAssociatedObject(self, qwelll_loopscroll_associatedProxyKey, proxy,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    %orig(proxy);
}

%end

%ctor {
    @autoreleasepool {
        // 只读配置快照；默认 enabled = YES，无面板。
        // 手动停用：defaults write com.qwelll.loopscroll enabled -bool false 后注销（respring）。
        [qwelllLoopScrollConfig qwelll_loopscroll_shared];
        if (!objc_getClass("SBHomeScreenScrollView")) {
            NSLog(@"[qwelllLoopScroll] SBHomeScreenScrollView not found on this iOS version; "
                  @"verify the home screen scroll view class name on iOS 17.2.1.");
        }
    }
}
