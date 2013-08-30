//
//  DPFloatingHeaderView.h
//  DPFloatingHeaderViewDemo
//
//  Created by Eric D. Baker on 8/30/13.
//  Copyright (c) 2013 DuneParkSoftware, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@class DPFloatingHeaderView;

typedef void(^DPFloatingHeaderViewIsAnimatingBlock)(__weak DPFloatingHeaderView *const floatingHeaderView, CGFloat toHeight, NSTimeInterval duration);
typedef void(^DPFloatingHeaderViewDidChangeHeightBlock)(__weak DPFloatingHeaderView *const floatingHeaderView, CGFloat toHeight, CGFloat percentage);

@interface DPFloatingHeaderView : UIView

@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;
@property (weak, nonatomic) IBOutlet UIView *toolbarView;

@property (readonly, assign, nonatomic) CGFloat minimumHeight, maximumHeight, maximumToolbarHeight;

@property (copy, nonatomic) DPFloatingHeaderViewIsAnimatingBlock animationBlock;
@property (copy, nonatomic) DPFloatingHeaderViewDidChangeHeightBlock heightChangedBlock;

- (void)setAnimationBlock:(DPFloatingHeaderViewIsAnimatingBlock)animationBlock;
- (void)setHeightChangedBlock:(DPFloatingHeaderViewDidChangeHeightBlock)heightChangedBlock;

- (void)expand;
- (void)collapse;

@end
