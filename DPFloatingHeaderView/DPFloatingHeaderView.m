//
//  DPFloatingHeaderView.m
//  DPFloatingHeaderViewDemo
//
//  Created by Eric D. Baker on 8/30/13.
//  Copyright (c) 2013 DuneParkSoftware, LLC. All rights reserved.
//

#import "DPFloatingHeaderView.h"

typedef NS_ENUM(NSInteger, DPFloatingHeaderViewAnimationMode) {
    DPFloatingHeaderViewAnimationModeSlide,
    DPFloatingHeaderViewAnimationModeCollapse
};

static NSTimeInterval const kAnimationDuration = 0.2;
static NSTimeInterval const kAnimationDelay = 0.1;

@interface DPFloatingHeaderView () <UIScrollViewDelegate>
@property (weak, nonatomic) id scrollViewDelegate;
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
    __weak typeof(self) weakSelf = self;
    orientationChangeObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIDeviceOrientationDidChangeNotification object:[UIDevice currentDevice] queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        __strong __typeof(weakSelf) strongSelf = weakSelf;
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
    [self setScrollViewDelegate:nil];

    // If the scroll view already has a delegate, keep a pointer to it and forward messages to it.
    if ([self.scrollView delegate]) {
        [self setScrollViewDelegate:self.scrollView.delegate];
    }

    // Become the scroll view's delegate.
    [self.scrollView setDelegate:self];
}

#pragma mark - Internal scroll view delegate methods

- (BOOL)scrollViewShouldScrollToTop:(UIScrollView *)scrollView {
    if ([self isCollapsed]) {
        [self expand];
        return NO;
    }

    if ([self.scrollViewDelegate respondsToSelector:@selector(scrollViewShouldScrollToTop:)]) {
        return [self.scrollViewDelegate scrollViewShouldScrollToTop:scrollView];
    }

    return YES;
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    if ([self.scrollViewDelegate respondsToSelector:@selector(scrollViewWillBeginDragging:)]) {
        [self.scrollViewDelegate scrollViewWillBeginDragging:scrollView];
    }

    if (!scrollView.isTracking) return;

    // Capture initial values for this scroll.
    self.initialContentOffsetY = self.lastContentOffsetY = scrollView.contentOffset.y;
    self.catchPointOffset = [self isCollapsed] ? 0 : self.maximumHeight + scrollView.contentOffset.y;
    if (self.catchPointOffset < 0) self.catchPointOffset = 0;
    self.ignoreScroll = NO;

    // If the scroll view's content height is less than its frame height, then ignore scrolling.
    if (scrollView.contentSize.height <= scrollView.frame.size.height - self.minimumHeight) {
        self.ignoreScroll = YES;
        return;
    }

    // If the scroll content is dragged upward from the bottom, then expand the header and ignore the rest of this scroll.
    self.didStartAtContentBottom = (scrollView.contentOffset.y + scrollView.frame.size.height >= scrollView.contentSize.height);
    // We do not want the header to "jump" if the content is pulled upward from the bottom and the header is already fully expanded.
    if (self.didStartAtContentBottom && [self isExpanded]) {
        self.ignoreScroll = YES;
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if ([self.scrollViewDelegate respondsToSelector:@selector(scrollViewDidScroll:)]) {
        [self.scrollViewDelegate scrollViewDidScroll:scrollView];
    }

    if (self.ignoreScroll) return;

    // This method is called repeatedly while the scroll content offset changes.

    CGFloat y = scrollView.contentOffset.y;
    CGFloat hdrMaxH = self.maximumHeight, hdrMinH = self.minimumHeight;
    CGFloat cp =  self.catchPointOffset;

    // Always keep these state values updated.
    CGFloat delta = self.lastContentOffsetY - scrollView.contentOffset.y;
    self.lastContentOffsetY = scrollView.contentOffset.y;
    self.scrollDirectionIsUp = (delta < 0);

    if (scrollView.isTracking) {
        // User is touching the scroll view.

        // If the scroll content is dragged upward from the bottom, then expand the header and ignore the rest of this scroll.
        if (self.didStartAtContentBottom && self.scrollDirectionIsUp && ![self isExpanded]) {
            self.ignoreScroll = YES;
            [self expand];
            return;
        }

        // The scroll content top is above the header. Make sure the header is fully collapsed.
        if (y - cp >= (0 - hdrMinH)) {
            [self moveTo:hdrMinH];
            // The header is fully collapsed. Reset the catchPointOffset to 0.
            self.catchPointOffset = 0;
            return;
        }

        // The scroll content top is below the header. Pull down the header to meet it, up to its maximum height.
        if (y - cp < (0 - hdrMinH) && y - cp > -hdrMaxH) {
            // If the scroll content is being stretched upward from the bottom, then collapse the header.
            if (y + scrollView.frame.size.height > scrollView.contentSize.height) {
                self.ignoreScroll = YES;
                [self collapse];
                return;
            }
            CGFloat position = hdrMaxH - (hdrMaxH + y) + cp;
            [self moveTo:position];
            return;
        }

        // The scroll content top is being pulled down below the header's maximum height. Make sure the header is fully expanded.
        if (y - cp <= -hdrMaxH) {
            [self moveTo:hdrMaxH];
            // If the content top is below the catchPointOffset, then move the catchpoint down to the content's current top.
            self.catchPointOffset = self.maximumHeight + scrollView.contentOffset.y;
            if (self.catchPointOffset < 0) self.catchPointOffset = 0;
        }
    }
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset {
    if ([self.scrollViewDelegate respondsToSelector:@selector(scrollViewWillEndDragging:withVelocity:targetContentOffset:)]) {
        [self.scrollViewDelegate scrollViewWillEndDragging:scrollView withVelocity:velocity targetContentOffset:targetContentOffset];
    }

    if (self.ignoreScroll) return;

    // This method is called when the user lifts their finger at the end of a drag. The velocity tells us if the content is still moving, and
    // which direction. The targetContentOffset tells us where the content will come to rest.

    // Determine if the scroll view will decelerate. If so, another delegate method will handle the header.
    if (CGPointEqualToPoint(velocity, CGPointZero)) return;

    // Determine direction from velocity.
    self.scrollDirectionIsUp = velocity.y > 0;

    CGFloat y = (*targetContentOffset).y;
    CGFloat hdrMinH = self.minimumHeight;

    // If the scroll content will stop below the header's minimum height, then expand the header.
    if (y < (0 - hdrMinH)) {
        self.ignoreScroll = YES;
        [self expand];
        return;
    }

    // If the scroll content will stop above the header's minimum height...
    if (y >= (0 - hdrMinH)) {
        // If the scroll direction is up, then collapse the header.
        if (self.scrollDirectionIsUp) {
            self.ignoreScroll = YES;
            [self collapse];
            return;
        }

        // If the scroll direction is down, then expand the header.
        if (!self.scrollDirectionIsUp) {
            self.ignoreScroll = YES;
            [self expand];
        }
    }
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if ([self.scrollViewDelegate respondsToSelector:@selector(scrollViewDidEndDragging:willDecelerate:)]) {
        [self.scrollViewDelegate scrollViewDidEndDragging:scrollView willDecelerate:decelerate];
    }

    if (self.ignoreScroll) return;

    // Deceleration is handled in another method.
    if (decelerate) return;

    CGFloat y = scrollView.contentOffset.y;
    CGFloat hdrMinH = self.minimumHeight;

    // If the scroll content stopped below the header's minimum height, then expand the header.
    if (y < (0 - hdrMinH)) {
        [self expand];
        return;
    }

    // If the header is not fully expanded, then collapse it.
    if (![self isExpanded]) {
        [self collapse];
    }
}

#pragma mark - Delegate message forwarding

- (BOOL)respondsToSelector:(SEL)aSelector {
    BOOL retVal = [super respondsToSelector:aSelector];
    if (retVal) return retVal;

    return [self.scrollViewDelegate respondsToSelector:aSelector];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    if ([self.scrollViewDelegate respondsToSelector:aSelector]) {
        return [self.scrollViewDelegate methodSignatureForSelector:aSelector];
    }
    return [super methodSignatureForSelector:aSelector];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
    if ([self.scrollViewDelegate respondsToSelector:[anInvocation selector]]) {
        [anInvocation invokeWithTarget:self.scrollViewDelegate];
    } else {
        [super forwardInvocation:anInvocation];
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

    __weak typeof(self) weakSelf = self;
    [UIView animateWithDuration:kAnimationDuration
                          delay:kAnimationDelay
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         __strong __typeof(weakSelf) strongSelf = weakSelf;

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

    __weak typeof(self) weakSelf = self;
    [UIView animateWithDuration:kAnimationDuration
                          delay:kAnimationDelay
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         __strong __typeof(weakSelf) strongSelf = weakSelf;

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
