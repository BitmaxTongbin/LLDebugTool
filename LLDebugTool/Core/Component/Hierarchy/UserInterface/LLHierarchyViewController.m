//
//  LLHierarchyViewController.m
//
//  Copyright (c) 2018 LLDebugTool Software Foundation (https://github.com/HDB-Li/LLDebugTool)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

#import "LLHierarchyViewController.h"
#import "LLHierarchyView.h"
#import "LLHierarchyInfoView.h"
#import "LLFactory.h"
#import "LLConfig.h"
#import "UIView+LL_Utils.h"
#import "LLConst.h"
#import "LLMacros.h"
#import "LLWindowManager.h"
#import "LLThemeManager.h"
#import "NSObject+LL_Utils.h"
#import "LLHierarchyDetailViewController.h"
#import "LLNavigationController.h"
#import "LLTool.h"

@interface LLHierarchyViewController ()<LLHierarchyViewDelegate, LLHierarchyInfoViewDelegate>

@property (nonatomic, strong) UIView *borderView;

@property (nonatomic, strong) LLHierarchyView *pickerView;

@property (nonatomic, strong) LLHierarchyInfoView *infoView;

@property (nonatomic, strong) NSMutableSet *observeViews;

@property (nonatomic, strong) NSMutableDictionary *borderViews;

@end

@implementation LLHierarchyViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
    self.observeViews = [NSMutableSet set];
    self.borderViews = [[NSMutableDictionary alloc] init];
    
    CGFloat height = 100;
    self.infoView = [[LLHierarchyInfoView alloc] initWithFrame:CGRectMake(kLLGeneralMargin, LL_SCREEN_HEIGHT - kLLGeneralMargin * 2 - height, LL_SCREEN_WIDTH - kLLGeneralMargin * 2, height)];
    self.infoView.delegate = self;
    [self.view addSubview:self.infoView];
    
    self.borderView = [LLFactory getView:self.view frame:CGRectZero backgroundColor:[UIColor clearColor]];
    self.borderView.layer.borderWidth = 2;
    
    self.pickerView = [[LLHierarchyView alloc] initWithFrame:CGRectMake((self.view.LL_width - 60) / 2.0, (self.view.LL_height - 60) / 2.0, 60, 60)];
    self.pickerView.delegate = self;
    [self.view addSubview:self.pickerView];
}

- (void)dealloc {
    for (UIView *view in self.observeViews) {
        [self stopObserveView:view];
    }
    [self.observeViews removeAllObjects];
}

#pragma mark - Primary
- (void)beginObserveView:(UIView *)view borderWidth:(CGFloat)borderWidth {
    if ([self.observeViews containsObject:view]) {
        return;
    }
    
    UIView *borderView = [LLFactory getView:self.view frame:CGRectZero backgroundColor:[UIColor clearColor]];
    [self.view sendSubviewToBack:borderView];
    borderView.layer.borderWidth = borderWidth;
    borderView.layer.borderColor = view.LL_hashColor.CGColor;
    borderView.frame = [self frameInLocalForView:view];
    [self.borderViews setObject:borderView forKey:@(view.hash)];

    [view addObserver:self forKeyPath:@"frame" options:0 context:NULL];
}

- (void)stopObserveView:(UIView *)view {
    if (![self.observeViews containsObject:view]) {
        return;
    }
    
    UIView *borderView = self.borderViews[@(view.hash)];
    [borderView removeFromSuperview];
    [view removeObserver:self forKeyPath:@"frame"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *, id> *)change context:(void *)context {
    if ([object isKindOfClass:[UIView class]]) {
        UIView *view = (UIView *)object;
        [self updateOverlayIfNeeded:view];
    }
}

- (void)updateOverlayIfNeeded:(UIView *)view {
    UIView *borderView = self.borderViews[@(view.hash)];
    if (borderView) {
        borderView.frame = [self frameInLocalForView:view];
    }
}

- (CGRect)frameInLocalForView:(UIView *)view {
    UIWindow *window = [UIApplication sharedApplication].delegate.window;
    CGRect rect = [view convertRect:view.bounds toView:window];
    rect = [self.view convertRect:rect fromView:window];
    return rect;
}

#pragma mark - LLHierarchyPickerViewDelegate
- (void)LLHierarchyView:(LLHierarchyView *)view didMoveTo:(NSArray <UIView *>*)selectedViews {
    
    @synchronized (self) {
        for (UIView *view in self.observeViews) {
            [self stopObserveView:view];
        }
        [self.observeViews removeAllObjects];
        
        for (NSInteger i = selectedViews.count - 1; i >= 0; i--) {
            UIView *view = selectedViews[i];
            CGFloat borderWidth = 1;
            if (i == selectedViews.count - 1) {
                borderWidth = 2;
            }
            [self beginObserveView:view borderWidth:borderWidth];
        }
        [self.observeViews addObjectsFromArray:selectedViews];
    }

    UIView *selectedView = [selectedViews lastObject];
    [self.infoView updateView:selectedView];
}

#pragma mark - LLBaseInfoViewDelegate
- (void)LLBaseInfoViewDidSelectCloseButton:(LLBaseInfoView *)view {
    [self componentDidLoad:nil];
}

#pragma mark - LLHierarchyInfoViewDelegate
- (void)LLHierarchyInfoViewDidSelectMoreInfoButton:(LLHierarchyInfoView *)view {
    UIView *selectView = self.infoView.selectedView;
    if (selectView == nil) {
        [LLTool log:@"Failed to show hierarchy detail viewController"];
        return;
    }
    LLHierarchyDetailViewController *vc = [[LLHierarchyDetailViewController alloc] init];
    vc.selectView = selectView;
    LLNavigationController *nav = [[LLNavigationController alloc] initWithRootViewController:vc];
    [self presentViewController:nav animated:YES completion:nil];
}

@end
