//
//  TabBarView.m
//  Wallet
//
//  Created by Carson Whitsett on 2/28/14.
//  Copyright (c) 2014 AirBitz. All rights reserved.
//

#import "TabBarView.h"
#import "TabBarButton.h"
#import "Theme.h"

#define TAG_FIRST_DIVIDER    10

@interface TabBarView ()
{
    TabBarButton *selectedButton;
}
@end

@implementation TabBarView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        // Initialization code
    }
    return self;
}

-(void)awakeFromNib
{
    TabBarButton *button;
    
    //set up the button characteristics
    button = [self findButton:0];
    button.label.text = [Theme Singleton].DirectoryText;
    button.icon.image = [UIImage imageNamed:@"icon_directory_dark"];
    button.selectedIcon.image = [UIImage imageNamed:@"icon_directory"];
    
    button = [self findButton:1];
    button.label.text = [Theme Singleton].ReceiveText;
    button.icon.image = [UIImage imageNamed:@"icon_request_dark"];
    button.selectedIcon.image = [UIImage imageNamed:@"icon_request"];
    
    button = [self findButton:2];
    button.label.text = [Theme Singleton].SendText;
    button.icon.image = [UIImage imageNamed:@"icon_send_dark"];
    button.selectedIcon.image = [UIImage imageNamed:@"icon_send"];
    
    button = [self findButton:3];
    button.label.text = [Theme Singleton].WalletsText;
    button.icon.image = [UIImage imageNamed:@"icon_wallet_dark"];
    button.selectedIcon.image = [UIImage imageNamed:@"icon_wallet"];
    
    button = [self findButton:4];
    button.label.text = [Theme Singleton].MoreText;
    button.icon.image = [UIImage imageNamed:@"icon_more_dark"];
    button.selectedIcon.image = [UIImage imageNamed:@"icon_more"];
    
}

-(void)showAllDividers
{
    for(UIView *view in self.subviews)
    {
        if(view.tag >= TAG_FIRST_DIVIDER)
        {
            view.hidden = NO;
        }
    }
}

-(void)updateDividers
{
    [self showAllDividers];
    UIView *view = [self viewWithTag:selectedButton.tag - 1 + TAG_FIRST_DIVIDER];
    view.hidden = YES;
    view = [self viewWithTag:selectedButton.tag + TAG_FIRST_DIVIDER];
    view.hidden = YES;
}


-(void)selectButtonAtIndex:(int)index
{
    for(UIView *view in self.subviews)
    {
        if([view isKindOfClass:[TabBarButton class]])
        {
            TabBarButton *button = (TabBarButton *)view;
            if(button.tag == index)
            {
                if(selectedButton != button)
                {
                    [selectedButton deselect];
                    [button select];
                    if ([self.delegate respondsToSelector:@selector(tabBarView:selectedSubview:reselected:)])
                    {
                        [self.delegate tabBarView:self selectedSubview:button reselected:NO];
                    }
                    selectedButton = button;
                    [self updateDividers];
                }
            } else {
                [button deselect];
            }
        }
    }
}

-(void)highlighButtonAtIndex:(int)index
{
    for (UIView *view in self.subviews)
    {
        if ([view isKindOfClass:[TabBarButton class]])
        {
            TabBarButton *button = (TabBarButton *)view;
            if (button.tag == index)
            {
                if (selectedButton != button)
                {
                    [selectedButton deselect];
                    [button select];
                    selectedButton = button;
                    [self updateDividers];
                }
            } else {
                [button deselect];
            }
        }
    }
}

-(void)selectButtonAtPoint:(CGPoint)point
{
    for(UIView *view in self.subviews)
    {
        if([view isKindOfClass:[TabBarButton class]])
        {
            TabBarButton *button = (TabBarButton *)view;
            if(CGRectContainsPoint(button.frame, point))
            {
                if(selectedButton != button)
                {
                    [selectedButton deselect];
                    [button select];
                    if([self.delegate respondsToSelector:@selector(tabBarView:selectedSubview:reselected:)])
                    {
                        [self.delegate tabBarView:self selectedSubview:button reselected:NO];
                    }
                    selectedButton = button;
                    [self updateDividers];
                }
            } else {
                [button deselect];
            }
        }
    }
}

-(void)highlightButtonAtPoint:(CGPoint)point
{
    for(TabBarButton *view in self.subviews)
    {
        if([view isKindOfClass:[TabBarButton class]])
        {
            TabBarButton *button = (TabBarButton *)view;
            if(CGRectContainsPoint(view.frame, point))
            {
                if(![button.label.text isEqualToString:@"MORE"])
                {
                    [selectedButton deselect];
                    [button highlight];
                }
                
                if(selectedButton != button)
                {
                    if ([self.delegate respondsToSelector:@selector(tabBarView:selectedSubview:reselected:)])
                    {
                        [self.delegate tabBarView:self selectedSubview:button reselected:NO];
                    }
                    if(![button.label.text isEqualToString:@"MORE"])
                    {
                        selectedButton = button;
                        [self updateDividers];
                    }
                }
                else
                {
                    if ([self.delegate respondsToSelector:@selector(tabBarView:selectedSubview:reselected:)])
                    {
                        [self.delegate tabBarView:self selectedSubview:button reselected:YES];
                    }
                }
            } else {
//                [button deselect];
            }
        }
    }
}

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGPoint startPoint = [[touches anyObject] locationInView:self];
    TabBarButton *button = [self findButtonAtPoint:startPoint];
    if (!button.locked) {
        [self highlightButtonAtPoint:startPoint];
    } else {
        if ([self.delegate respondsToSelector:@selector(tabBarView:selectedLockedSubview:)]) {
            [self.delegate tabBarView:self selectedLockedSubview:button];
        }
    }
}

-(void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGPoint startPoint = [[touches anyObject] locationInView:self];
    TabBarButton *button = [self findButtonAtPoint:startPoint];
    if (!button.locked) {
        [self highlightButtonAtPoint:startPoint];
    } else {
        if ([self.delegate respondsToSelector:@selector(tabBarView:selectedLockedSubview:)]) {
            [self.delegate tabBarView:self selectedLockedSubview:button];
        }
    }
}

-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    if(![selectedButton.label.text isEqualToString:@"MORE"])
    {
        [selectedButton select];
    }
}

-(void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [selectedButton select];
}

- (void)lockButton:(int)idx
{
    TabBarButton *button = [self findButton:idx];
    button.locked = YES;
    button.alpha = 0.5;
}

- (void)unlockButton:(int)idx
{
    TabBarButton *button = [self findButton:idx];
    button.locked = NO;
    button.alpha = 1.0;
}

- (TabBarButton *)findButton:(int)index
{
    for (UIView *view in self.subviews) {
        if ([view isKindOfClass:[TabBarButton class]]) {
            TabBarButton *button = (TabBarButton *)view;
            if (button.tag == index) {
                return button;
            }
        }
    }
    return nil;
}

- (TabBarButton *)findButtonAtPoint:(CGPoint)point
{
    for (TabBarButton *view in self.subviews) {
        if ([view isKindOfClass:[TabBarButton class]]) {
            TabBarButton *button = (TabBarButton *)view;
            if (CGRectContainsPoint(view.frame, point)) {
                return button;
            }
        }
    }
    return nil;
}

@end
