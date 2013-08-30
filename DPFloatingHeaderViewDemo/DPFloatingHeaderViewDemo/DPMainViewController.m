//
//  DPMainViewController.m
//  DPFloatingHeaderViewDemo
//
//  Created by Eric D. Baker on 8/30/13.
//  Copyright (c) 2013 DuneParkSoftware, LLC. All rights reserved.
//

#import "DPMainViewController.h"
#import "DPFloatingHeaderView.h"

@interface DPMainViewController () <UITableViewDataSource, UITableViewDelegate>

@property (readwrite, strong, nonatomic) IBOutlet DPFloatingHeaderView *headerView;
@property (readwrite, strong, nonatomic) IBOutlet UITableView *tableView;

@end

@implementation DPMainViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [self.tableView setDecelerationRate:UIScrollViewDecelerationRateFast];

    [self.headerView setHeightChangedBlock:^(DPFloatingHeaderView *const __weak floatingHeaderView, CGFloat toHeight, CGFloat percentage) {
        [floatingHeaderView setAlpha:(CGFloat)MAX(.1, (toHeight / 100.0))];
    }];

    [self.headerView setAnimationBlock:^(DPFloatingHeaderView *const __weak floatingHeaderView, CGFloat toHeight, NSTimeInterval duration) {
        [floatingHeaderView setAlpha:(CGFloat)MAX(.1, (toHeight / 100.0))];
    }];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 30;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *const CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }

    [cell.textLabel setText:[NSString stringWithFormat:@"Cell %@", @(indexPath.row)]];

    return cell;
}

@end
