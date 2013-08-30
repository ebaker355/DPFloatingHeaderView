//
//  DPFloatingHeaderView.m
//  DPFloatingHeaderViewDemo
//
//  Created by Eric D. Baker on 8/30/13.
//  Copyright (c) 2013 DuneParkSoftware, LLC. All rights reserved.
//

#import <objc/message.h>
#import "DPFloatingHeaderView.h"

static char DPFloatingHeaderInstanceKey;

typedef NS_ENUM(NSInteger, DPFloatingHeaderViewAnimationMode) {
    DPFloatingHeaderViewAnimationModeSlide,
    DPFloatingHeaderViewAnimationModeCollapse
};

static NSTimeInterval const kAnimationDuration = 0.2;
static NSTimeInterval const kAnimationDelay = 0.1;

@interface DPFloatingHeaderView () <UIScrollViewDelegate>
@property (assign, nonatomic) CGFloat minimumHeight, maximumHeight, maximumToolbarHeight;
@property (assign, nonatomic) UIEdgeInsets originalContentInsets, originalScrollIndicatorInsets;
@property (assign, nonatomic) CGFloat initialContentOffsetY, lastContentOffsetY;
@property (assign, nonatomic) BOOL scrollDirectionIsUp;
@property (assign, nonatomic) CGFloat catchPointOffset;
@property (assign, nonatomic) BOOL didStartAtContentBottom, ignoreScroll;
@property (assign, nonatomic) DPFloatingHeaderViewAnimationMode animationMode;
@end

@implementation DPFloatingHeaderView {
    id orientationChangeObserver;
    BOOL _capturedOriginalInsets;
}

#pragma mark - UIView class overrides

// Return YES if the view must be in a window using constraint-based layout to function properly, NO otherwise.
// Custom views should override this to return YES if they can not layout correctly using autoresizing.
+ (BOOL)requiresConstraintBasedLayout {
    return YES;
}

#pragma mark - Initialization

- (id)init {
    self = [super init];
    if (self) {
        [self initSelf];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self initSelf];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self initSelf];
    }
    return self;
}

- (void)initSelf {
    __weak DPFloatingHeaderView *weakSelf = self;
    orientationChangeObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIDeviceOrientationDidChangeNotification object:[UIDevice currentDevice] queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        __strong DPFloatingHeaderView *strongSelf = weakSelf;
        // If the scroll view's content height is less than its frame height, then expand.
        if (strongSelf.scrollView.contentSize.height <= strongSelf.scrollView.frame.size.height - strongSelf.minimumHeight) {
            [strongSelf expand];
        }
    }];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:orientationChangeObserver];
    orientationChangeObserver = nil;
}

#pragma mark - Scroll view control and delegate integration

- (void)setScrollView:(UIScrollView *)scrollView {
    [self detachFromScrollView];

    _scrollView = scrollView;

    // Integrate with this new scroll view control.
    if (self.scrollView) {
        [self attachToScrollView];

        // If the header view is in the same container view as the scroll view, then make sure the header
        // appears above the scroll view.
        if (self.superview == self.scrollView.superview) {
            [self.superview bringSubviewToFront:self];
        }
    }
}

- (void)attachToScrollView {
    if (!self.scrollView) return;

    // Set a weak pointer to reference ourself.
    objc_setAssociatedObject(self.scrollView, &DPFloatingHeaderInstanceKey, self, OBJC_ASSOCIATION_ASSIGN);

    // Capture the current value of the height constraint constant. This becomes our view's maximum height.
    [self setMaximumHeight:[self.heightConstraint constant]];

    // Capture the value of the minimum height constraint, if defined. This determines our minimum height and
    // our animation mode.
    [self setMinimumHeight:[self.minimumHeightConstraint constant]];
    [self setAnimationMode:(self.minimumHeight > 0 ? DPFloatingHeaderViewAnimationModeCollapse : DPFloatingHeaderViewAnimationModeSlide)];

    [self adjustScrollViewInsets];
    [self configureScrollViewDelegate];
}

- (void)detachFromScrollView {
    if (!self.scrollView) return;

    // Remove weak pointer reference to ourself.
    objc_setAssociatedObject(self.scrollView, &DPFloatingHeaderInstanceKey, nil, OBJC_ASSOCIATION_ASSIGN);

    [self restoreScrollViewInsets];
}

- (void)adjustScrollViewInsets {
    if (!_capturedOriginalInsets) {
        [self setOriginalContentInsets:self.scrollView.contentInset];
        [self setOriginalScrollIndicatorInsets:self.scrollView.scrollIndicatorInsets];
        _capturedOriginalInsets = YES;
    }
    [self.scrollView setContentInset:UIEdgeInsetsMake([self maximumHeight] + self.originalContentInsets.top, self.originalContentInsets.left, [self maximumToolbarHeight] + self.originalContentInsets.bottom, self.originalContentInsets.right)];
    [self.scrollView setScrollIndicatorInsets:UIEdgeInsetsMake([self maximumHeight] + self.originalScrollIndicatorInsets.top, self.originalScrollIndicatorInsets.left, [self maximumToolbarHeight] + self.originalScrollIndicatorInsets.bottom, self.originalScrollIndicatorInsets.right)];
}

- (void)restoreScrollViewInsets {
    [self.scrollView setContentInset:self.originalContentInsets];
    [self.scrollView setScrollIndicatorInsets:self.originalScrollIndicatorInsets];
    _capturedOriginalInsets = NO;
}

#pragma mark - Toolbar view control integration

- (void)setToolbarView:(UIView *)toolbarView {
    _toolbarView = toolbarView;

    // Integrate with this new toolbar view control.
    if (self.toolbarView) {
        [self attachToToolbarView];

        // If the toolbar view is in the same container as the scroll view, then make sure the toolbar
        // appears above the scroll view.
        if (self.scrollView.superview == self.toolbarView.superview) {
            [self.scrollView.superview bringSubviewToFront:self.toolbarView];
        }
    }
}

- (void)attachToToolbarView {
    if (!self.toolbarView) return;

    // Capture the current value of the toolbar's height constraint constant. This becomes the toolbar's maximum height.
    [self setMaximumToolbarHeight:[self.toolbarHeightConstraint constant]];

    [self adjustScrollViewInsets];
}

#pragma mark - Scroll view delegate integration

- (void)configureScrollViewDelegate {
    if (![self.scrollView delegate]) {
        [self.scrollView setDelegate:self];
    }
    else {
        [self attachToScrollViewDelegate:self.scrollView.delegate];

        // Reassign the delegate. This is needed because the scroll may view cache responses to respondsToSelector: calls
        // for certain delegate methods. Since we've injected methods into the existing delegate, some of the cached
        // responses may need to be updated.
        id delegate = self.scrollView.delegate;
        [self.scrollView setDelegate:nil];
        [self.scrollView setDelegate:delegate];
    }
}

- (void)attachToScrollViewDelegate:(id <UIScrollViewDelegate>)delegate {
    [self attachToScrollViewDelegate:delegate forSelector:@selector(scrollViewShouldScrollToTop:)];
    [self attachToScrollViewDelegate:delegate forSelector:@selector(scrollViewDidScroll:)];
    [self attachToScrollViewDelegate:delegate forSelector:@selector(scrollViewWillBeginDragging:)];
    [self attachToScrollViewDelegate:delegate forSelector:@selector(scrollViewWillEndDragging:withVelocity:targetContentOffset:)];
    [self attachToScrollViewDelegate:delegate forSelector:@selector(scrollViewDidEndDragging:willDecelerate:)];
}

- (void)attachToScrollViewDelegate:(id <UIScrollViewDelegate>)delegate forSelector:(SEL)selector {
    // If the delegate responds to the standard UIScrollView method already, then we inject our own responder method
    // into the instance, switch its method implementation with the existing method, and finally call the original
    // method from our injected method.
    // Otherwise, we simply inject our own method.
    if ([delegate respondsToSelector:selector]) {
        SEL injectSEL = NSSelectorFromString([NSString stringWithFormat:@"_DPFloatingHeaderView_injected_%@", NSStringFromSelector(selector)]);
        // Make sure the delegate does not already contain the method we're going to inject.
        if ([delegate respondsToSelector:injectSEL]) {[NSException raise:NSInternalInconsistencyException format:@"The scroll view delegate has already been attached to a header controller."];}
        [self injectInstanceSelector:injectSEL fromClass:[self class] toClass:[delegate class]];
        [self exchangeInstanceSelector:selector andSelector:injectSEL forClass:[delegate class]];
    }
    else {
        [self injectInstanceSelector:selector fromClass:[self class] toClass:[delegate class]];
    }
}

- (void)injectInstanceSelector:(SEL)selector fromClass:(Class)fromClass toClass:(Class)toClass {
    IMP imp = class_getMethodImplementation(fromClass, selector);
    const char *types = method_getTypeEncoding(class_getInstanceMethod(fromClass, selector));
    if (!class_addMethod(toClass, selector, imp, types)) {[NSException raise:NSInternalInconsistencyException format:@"Failed to inject method into scroll view delegate class."];}
}

- (void)exchangeInstanceSelector:(SEL)selector andSelector:(SEL)otherSelector forClass:(Class)class {
    Method fromMethod = class_getInstanceMethod(class, selector),
    toMethod = class_getInstanceMethod(class, otherSelector);
    method_exchangeImplementations(fromMethod, toMethod);
}

#pragma mark - Externally-injected view delegate methods

- (BOOL)_DPFloatingHeaderView_injected_scrollViewShouldScrollToTop:(UIScrollView *)scrollView {
    // "self" in this method refers to the scroll view's original delegate instance, since this method was injected.
    DPFloatingHeaderView *headerView = objc_getAssociatedObject(scrollView, &DPFloatingHeaderInstanceKey);
    if (!headerView) [NSException raise:NSInternalInconsistencyException format:@"The header view is not associated with a scroll view."];

    // Call the original delegate's method first for this method to get its return value. (This looks recursive, but it is not!)
    // Note: We're not using one of the objc_msgSend variants here because, well, I can't get any of them to work with a method that returns a primitive BOOL.
    BOOL retVal = [self _DPFloatingHeaderView_injected_scrollViewShouldScrollToTop:scrollView];

    // Call the header view's delegate method, unless the original delegate returned NO.
    if (retVal) {
        [headerView scrollViewShouldScrollToTop:scrollView];
    }

    // Return the original delegate's result.
    return retVal;
}

- (void)_DPFloatingHeaderView_injected_scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    // "self" in this method refers to the scroll view's original delegate instance, since this method was injected.
    DPFloatingHeaderView *headerView = objc_getAssociatedObject(scrollView, &DPFloatingHeaderInstanceKey);
    if (!headerView) [NSException raise:NSInternalInconsistencyException format:@"The header view is not associated with a scroll view."];

    // Call the header view's delegate method.
    objc_msgSend(headerView, @selector(scrollViewWillBeginDragging:), scrollView);

    // Call the original delegate's method. (This looks recursive, but it is not!)
    objc_msgSend(self, @selector(_DPFloatingHeaderView_injected_scrollViewWillBeginDragging:), scrollView);
}

- (void)_DPFloatingHeaderView_injected_scrollViewDidScroll:(UIScrollView *)scrollView {
    // "self" in this method refers to the scroll view's original delegate instance, since this method was injected.
    DPFloatingHeaderView *headerView = objc_getAssociatedObject(scrollView, &DPFloatingHeaderInstanceKey);
    if (!headerView) [NSException raise:NSInternalInconsistencyException format:@"The header view is not associated with a scroll view."];

    // Call the header view's delegate method.
    objc_msgSend(headerView, @selector(scrollViewDidScroll:), scrollView);

    // Call the original delegate's method. (This looks recursive, but it is not!)
    objc_msgSend(self, @selector(_DPFloatingHeaderView_injected_scrollViewDidScroll:), scrollView);
}

- (void)_DPFloatingHeaderView_injected_scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    // "self" in this method refers to the scroll view's original delegate instance, since this method was injected.
    DPFloatingHeaderView *headerView = objc_getAssociatedObject(scrollView, &DPFloatingHeaderInstanceKey);
    if (!headerView) [NSException raise:NSInternalInconsistencyException format:@"The header view is not associated with a scroll view."];

    // Call the header view's delegate method.
    objc_msgSend(headerView, @selector(scrollViewDidEndDragging:willDecelerate:), scrollView, decelerate);

    // Call the original delegate's method. (This looks recursive, but it is not!)
    objc_msgSend(self, @selector(_DPFloatingHeaderView_injected_scrollViewDidEndDragging:willDecelerate:), scrollView, decelerate);
}

- (void)_DPFloatingHeaderView_injected_scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset {
    // "self" in this method refers to the scroll view's original delegate instance, since this method was injected.
    DPFloatingHeaderView *headerView = objc_getAssociatedObject(scrollView, &DPFloatingHeaderInstanceKey);
    if (!headerView) [NSException raise:NSInternalInconsistencyException format:@"The header view is not associated with a scroll view."];

    // Call the original delegate's method first for this method, since it has an alterable inout arg. (This looks recursive, but it is not!)
    objc_msgSend(self, @selector(_DPFloatingHeaderView_injected_scrollViewWillEndDragging:withVelocity:targetContentOffset:), scrollView, velocity, targetContentOffset);

    // Call the header view's delegate method.
    objc_msgSend(headerView, @selector(scrollViewWillEndDragging:withVelocity:targetContentOffset:), scrollView, velocity, targetContentOffset);
}

#pragma mark - Internal scroll view delegate methods

- (BOOL)scrollViewShouldScrollToTop:(UIScrollView *)scrollView {
    // "self" in this method *may* refer to this header class, or the scroll view's original delegate instance, if this
    // method was injected. Therefore, never rely on self! Use headerView instead.
    DPFloatingHeaderView *headerView = objc_getAssociatedObject(scrollView, &DPFloatingHeaderInstanceKey);
    if (!headerView) [NSException raise:NSInternalInconsistencyException format:@"The header view is not associated with the scroll view."];

    if ([headerView isCollapsed]) {
        [headerView expand];
        return NO;
    }
    return YES;
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    // "self" in this method *may* refer to this header class, or the scroll view's original delegate instance, if this
    // method was injected. Therefore, never rely on self! Use headerView instead.
    DPFloatingHeaderView *headerView = objc_getAssociatedObject(scrollView, &DPFloatingHeaderInstanceKey);
    if (!headerView) [NSException raise:NSInternalInconsistencyException format:@"The header view is not associated with the scroll view."];

    if (!scrollView.isTracking) return;

    // Capture initial values for this scroll.
    headerView.initialContentOffsetY = headerView.lastContentOffsetY = scrollView.contentOffset.y;
    headerView.catchPointOffset = [headerView isCollapsed] ? 0 : headerView.maximumHeight + scrollView.contentOffset.y;
    if (headerView.catchPointOffset < 0) headerView.catchPointOffset = 0;
    headerView.ignoreScroll = NO;

    // If the scroll view's content height is less than its frame height, then ignore scrolling.
    if (scrollView.contentSize.height <= scrollView.frame.size.height - headerView.minimumHeight) {
        headerView.ignoreScroll = YES;
        return;
    }

    // If the scroll content is dragged upward from the bottom, then expand the header and ignore the rest of this scroll.
    headerView.didStartAtContentBottom = (scrollView.contentOffset.y + scrollView.frame.size.height >= scrollView.contentSize.height);
    // We do not want the header to "jump" if the content is pulled upward from the bottom and the header is already fully expanded.
    if (headerView.didStartAtContentBottom && [headerView isExpanded]) {
        headerView.ignoreScroll = YES;
        return;
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    // "self" in this method *may* refer to this header class, or the scroll view's original delegate instance, if this
    // method was injected. Therefore, never rely on self! Use headerView instead.
    DPFloatingHeaderView *headerView = objc_getAssociatedObject(scrollView, &DPFloatingHeaderInstanceKey);
    if (!headerView) [NSException raise:NSInternalInconsistencyException format:@"The header view is not associated with the scroll view."];

    if (headerView.ignoreScroll) return;

    // This method is called repeatedly while the scroll content offset changes.

    CGFloat y = scrollView.contentOffset.y;
    CGFloat hdrMaxH = headerView.maximumHeight, hdrMinH = headerView.minimumHeight;
    CGFloat cp = headerView.catchPointOffset;

    // Always keep these state values updated.
    CGFloat delta = headerView.lastContentOffsetY - scrollView.contentOffset.y;
    headerView.lastContentOffsetY = scrollView.contentOffset.y;
    headerView.scrollDirectionIsUp = (delta < 0);

    if (scrollView.isTracking) {
        // User is touching the scroll view.

        // If the scroll content is dragged upward from the bottom, then expand the header and ignore the rest of this scroll.
        if (headerView.didStartAtContentBottom && headerView.scrollDirectionIsUp && ![headerView isExpanded]) {
            headerView.ignoreScroll = YES;
            [headerView expand];
            return;
        }

        // The scroll content top is above the header. Make sure the header is fully collapsed.
        if (y - cp >= (0 - hdrMinH)) {
            [headerView moveTo:hdrMinH];
            // The header is fully collapsed. Reset the catchPointOffset to 0.
            headerView.catchPointOffset = 0;
            return;
        }

        // The scroll content top is below the header. Pull down the header to meet it, up to its maximum height.
        if (y - cp < (0 - hdrMinH) && y - cp > -hdrMaxH) {
            // If the scroll content is being stretched upward from the bottom, then collapse the header.
            if (y + scrollView.frame.size.height > scrollView.contentSize.height) {
                headerView.ignoreScroll = YES;
                [headerView collapse];
                return;
            }
            CGFloat position = hdrMaxH - (hdrMaxH + y) + cp;
            [headerView moveTo:position];
            return;
        }

        // The scroll content top is being pulled down below the header's maximum height. Make sure the header is fully expanded.
        if (y - cp <= -hdrMaxH) {
            [headerView moveTo:hdrMaxH];
            // If the content top is below the catchPointOffset, then move the catchpoint down to the content's current top.
            headerView.catchPointOffset = headerView.maximumHeight + scrollView.contentOffset.y;
            if (headerView.catchPointOffset < 0) headerView.catchPointOffset = 0;
            return;
        }
    }
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset {
    // "self" in this method *may* refer to this header class, or the scroll view's original delegate instance, if this
    // method was injected. Therefore, never rely on self! Use headerView instead.
    DPFloatingHeaderView *headerView = objc_getAssociatedObject(scrollView, &DPFloatingHeaderInstanceKey);
    if (!headerView) [NSException raise:NSInternalInconsistencyException format:@"The header view is not associated with the scroll view."];

    if (headerView.ignoreScroll) return;

    // This method is called when the user lifts their finger at the end of a drag. The velocity tells us if the content is still moving, and
    // which direction. The targetContentOffset tells us where the content will come to rest.

    // Determine if the scroll view will decelerate. If so, another delegate method will handle the header.
    if (CGPointEqualToPoint(velocity, CGPointZero)) return;

    // Determine direction from velocity.
    headerView.scrollDirectionIsUp = velocity.y > 0;

    CGFloat y = (*targetContentOffset).y;
    CGFloat hdrMinH = headerView.minimumHeight;

    // If the scroll content will stop below the header's minimum height, then expand the header.
    if (y < (0 - hdrMinH)) {
        headerView.ignoreScroll = YES;
        [headerView expand];
        return;
    }

    // If the scroll content will stop above the header's minimum height...
    if (y >= (0 - hdrMinH)) {
        // If the scroll direction is up, then collapse the header.
        if (headerView.scrollDirectionIsUp) {
            headerView.ignoreScroll = YES;
            [headerView collapse];
            return;
        }

        // If the scroll direction is down, then expand the header.
        if (!headerView.scrollDirectionIsUp) {
            headerView.ignoreScroll = YES;
            [headerView expand];
            return;
        }
    }
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    // "self" in this method *may* refer to this header class, or the scroll view's original delegate instance, if this
    // method was injected. Therefore, never rely on self! Use headerView instead.
    DPFloatingHeaderView *headerView = objc_getAssociatedObject(scrollView, &DPFloatingHeaderInstanceKey);
    if (!headerView) [NSException raise:NSInternalInconsistencyException format:@"The header view is not associated with the scroll view."];

    if (headerView.ignoreScroll) return;

    // Deceleration is handled in another method.
    if (decelerate) return;

    CGFloat y = scrollView.contentOffset.y;
    CGFloat hdrMinH = headerView.minimumHeight;

    // If the scroll content stopped below the header's minimum height, then expand the header.
    if (y < (0 - hdrMinH)) {
        [headerView expand];
        return;
    }

    // If the header is not fully expanded, then collapse it.
    if (![headerView isExpanded]) {
        [headerView collapse];
        return;
    }
}

#pragma mark - Height adjusters

- (void)expand {
    if (self.scrollView.contentOffset.y < 0 && self.scrollView.contentOffset.y > -(self.maximumHeight)) {
        if (!self.scrollView.isTracking && !self.scrollView.isDragging && !self.scrollView.isDecelerating) {
            [self.scrollView setContentOffset:CGPointMake(self.scrollView.contentOffset.x, -self.maximumHeight) animated:YES];
        }
    }

    if ([self isExpanded]) return;

    __weak DPFloatingHeaderView *weakSelf = self;
    [UIView animateWithDuration:kAnimationDuration
                          delay:kAnimationDelay
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         __strong DPFloatingHeaderView *strongSelf = weakSelf;

                         if (strongSelf.animationBlock) {
                             strongSelf.animationBlock(strongSelf, strongSelf.maximumHeight, kAnimationDuration);
                         }

                         [strongSelf moveTo:strongSelf.maximumHeight];
                         [strongSelf.superview layoutIfNeeded];
                     }
                     completion:nil];
}

- (void)collapse {
    if (self.scrollView.contentOffset.y < -(self.minimumHeight)) {
        if (!self.scrollView.isTracking && !self.scrollView.isDragging && !self.scrollView.isDecelerating) {
            [self.scrollView setContentOffset:CGPointMake(self.scrollView.contentOffset.x, -self.minimumHeight) animated:YES];
        }
    }

    if ([self isCollapsed]) return;

    __weak DPFloatingHeaderView *weakSelf = self;
    [UIView animateWithDuration:kAnimationDuration
                          delay:kAnimationDelay
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         __strong DPFloatingHeaderView *strongSelf = weakSelf;

                         if (strongSelf.animationBlock) {
                             strongSelf.animationBlock(strongSelf, strongSelf.minimumHeight, kAnimationDuration);
                         }

                         [strongSelf moveTo:strongSelf.minimumHeight];
                         [strongSelf.superview layoutIfNeeded];
                     }
                     completion:nil];
}

- (BOOL)isExpanded {
    BOOL expanded = NO;
    switch (self.animationMode) {
        case DPFloatingHeaderViewAnimationModeCollapse:
            expanded = [self.heightConstraint constant] >= self.maximumHeight;
            break;

        case DPFloatingHeaderViewAnimationModeSlide:
            expanded = [self.topEdgeConstraint constant] >= 0;
            break;
    }
    return expanded;
}

- (BOOL)isCollapsed {
    BOOL collapsed = NO;
    switch (self.animationMode) {
        case DPFloatingHeaderViewAnimationModeCollapse:
            collapsed = [self.heightConstraint constant] <= self.minimumHeight;
            break;

        case DPFloatingHeaderViewAnimationModeSlide:
            collapsed = [self.topEdgeConstraint constant] <= -self.maximumHeight;
            break;
    }
    return collapsed;
}

// Moves the header to the given position, depending on the animation mode.
// If the animation mode is Collapse:
//      not yet implemented
//
// If the animation mode is Slide:
//      0 = fully hidden
//      max height = fully visible
//
- (void)moveTo:(CGFloat)position {
    if (position < self.minimumHeight) position = self.minimumHeight;
    if (position > self.maximumHeight) position = self.maximumHeight;

    switch (self.animationMode) {
        case DPFloatingHeaderViewAnimationModeCollapse:
            if ([self.heightConstraint constant] != position) {
                [self.heightConstraint setConstant:position];

                CGFloat percentage = (position - self.minimumHeight) / (self.maximumHeight - self.minimumHeight);
                [self moveToolbarViewToPercentage:percentage];

                if (self.heightChangedBlock) {
                    self.heightChangedBlock(self, position, percentage);
                }
            }
            break;

        case DPFloatingHeaderViewAnimationModeSlide:
            position = -(self.maximumHeight - position);
            if ([self.topEdgeConstraint constant] != position) {
                [self.topEdgeConstraint setConstant:position];

                position = self.maximumHeight + position;
                CGFloat percentage = position / self.maximumHeight;
                [self moveToolbarViewToPercentage:percentage];

                if (self.heightChangedBlock) {
                    self.heightChangedBlock(self, position, percentage);
                }
            }
            break;
    }
}

- (void)moveToolbarViewToPercentage:(CGFloat)percentage {
    CGFloat height = self.maximumToolbarHeight * percentage;
    [self.toolbarBottomEdgeConstraint setConstant:-(self.maximumToolbarHeight - height)];

    UIEdgeInsets insets = [self.scrollView contentInset];
    [self.scrollView setContentInset:UIEdgeInsetsMake(insets.top, insets.left, height, insets.right)];
    insets = [self.scrollView scrollIndicatorInsets];
    [self.scrollView setScrollIndicatorInsets:UIEdgeInsetsMake(insets.top, insets.left, height, insets.right)];
}

#pragma mark - Autolayout constraint helpers

// Returns the constraint that defines the view's height. This constraint's constant is adjusted to collapse/expand the view *if* a minimum height
// constraint is defined. Otherwise, the top edge constraint's constant is adjusted to show/hide the view.
- (NSLayoutConstraint *)heightConstraint {
    return [self constraintInConstraints:self.constraints matchingBlock:^BOOL(NSLayoutConstraint *constraint) {
        return (constraint.firstItem == self && constraint.firstAttribute == NSLayoutAttributeHeight && constraint.relation != NSLayoutRelationGreaterThanOrEqual);
    }];
}

// Returns the constraint that defines the view's minimum height. This constraint is optional and may not be defined (see heightConstraint).
- (NSLayoutConstraint *)minimumHeightConstraint {
    return [self constraintInConstraints:self.constraints matchingBlock:^BOOL(NSLayoutConstraint *constraint) {
        return (constraint.firstItem == self && constraint.firstAttribute == NSLayoutAttributeHeight && constraint.relation == NSLayoutRelationGreaterThanOrEqual);
    }];
}

// Returns the constraint that defines the view's top edge distance from its container view. If the minimum height constraint is not defined, then
// this constraint's constant is adjusted to show/hide the view.
- (NSLayoutConstraint *)topEdgeConstraint {
    return [self constraintInConstraints:self.superview.constraints matchingBlock:^BOOL(NSLayoutConstraint *constraint) {
        return ((constraint.firstItem == self && constraint.firstAttribute == NSLayoutAttributeTop) ||
                (constraint.secondItem == self && constraint.secondAttribute == NSLayoutAttributeTop));
    }];
}

- (NSLayoutConstraint *)toolbarHeightConstraint {
    return [self constraintInConstraints:self.toolbarView.constraints matchingBlock:^BOOL(NSLayoutConstraint *constraint) {
        return (constraint.firstItem == self.toolbarView && constraint.firstAttribute == NSLayoutAttributeHeight);
    }];
}

- (NSLayoutConstraint *)toolbarBottomEdgeConstraint {
    return [self constraintInConstraints:self.toolbarView.superview.constraints matchingBlock:^BOOL(NSLayoutConstraint *constraint) {
        return ((constraint.firstItem == self.toolbarView && constraint.firstAttribute == NSLayoutAttributeBottom) ||
                (constraint.secondItem == self.toolbarView && constraint.secondAttribute == NSLayoutAttributeBottom));
    }];
}

// Searches through an array of constraints for a constraint that matches the conditions described in the match block, and returns that constraint, or nil of not found.
- (NSLayoutConstraint *)constraintInConstraints:(NSArray *)constraints matchingBlock:(BOOL (^)(NSLayoutConstraint *constraint))matchBlock {
    __block NSLayoutConstraint *theConstraint = nil;
    [constraints enumerateObjectsUsingBlock:^(NSLayoutConstraint *constraint, NSUInteger idx, BOOL *stop) {
        if (matchBlock(constraint)) {
            theConstraint = constraint;
            *stop = YES;
        }
    }];
    return theConstraint;
}

// Sets the maximum height that the view is allowed to expand to. This is not allowed to be less than the minimum height, or 0 if not defined.
- (void)setMaximumHeight:(CGFloat)maximumHeight {
    CGFloat minimumHeight = [self.minimumHeightConstraint constant];
    _maximumHeight = MAX(minimumHeight, maximumHeight);
}

- (void)setMaximumToolbarHeight:(CGFloat)maximumToolbarHeight {
    _maximumToolbarHeight = MAX(0, maximumToolbarHeight);
}

@end
