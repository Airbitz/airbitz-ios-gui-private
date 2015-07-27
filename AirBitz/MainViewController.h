//
//  MainViewController.h
//  AirBitz
//
//  Created by Carson Whitsett on 2/28/14.
//  Copyright (c) 2014 AirBitz. All rights reserved.
//
//  CW:  Loads all of the viewControllers used by the app.  Displays the appropriate viewController content based on which
//	tab bar button is selected

#import <UIKit/UIKit.h>
#import "AirbitzViewController.h"

typedef enum eNavBarSide
{
    NAV_BAR_CENTER,
    NAV_BAR_LEFT,
    NAV_BAR_RIGHT
} tNavBarSide;

@interface MainViewController : UIViewController

+ (void)addChildView: (UIView *)view;
+ (void)animateSlideIn:(AirbitzViewController *)viewController;
+ (void)animateFadeIn:(UIView *)view;
+ (void)animateFadeOut:(UIView *)view;
+ (void)animateFadeOut:(UIView *)view remove:(BOOL)removeFromView;

+ (void)animateIn:(NSString *)identifier withBlur:(BOOL)withBlur;
+ (void)animateView:(AirbitzViewController *)viewController withBlur:(BOOL)withBlur;
+ (void)animateView:(AirbitzViewController *)viewController withBlur:(BOOL)withBlur animate:(BOOL)animated;
+ (void)animateOut:(AirbitzViewController *)viewController withBlur:(BOOL)withBlur complete:(void(^)(void))cb;
+ (void)showBackground:(BOOL)loggedIn animate:(BOOL)animated;
+ (void)showBackground:(BOOL)loggedIn animate:(BOOL)animated completion:(void (^)(BOOL finished))completion;

+(void)changeNavBarOwner:(UIViewController *)viewController;
+(void)changeNavBar:(UIViewController *)viewController
              title:(NSString*) titleText
               side:(tNavBarSide)navBarSide
             button:(BOOL)bIsButton
             enable:(BOOL)enable
             action:(SEL)func
         fromObject:(id) object;
+(void)changeNavBarTitle:(UIViewController *)viewController
                   title:(NSString*) titleText;
+(void)changeNavBarTitleWithButton:(UIViewController *)viewController title:(NSString*) titleText action:(SEL)func fromObject:(id) object;
+(void)showHideTabBar:(NSNotification *)notification;
+(void)showTabBarAnimated:(BOOL)animated;
+(void)showNavBarAnimated:(BOOL)animated;
+(void)hideTabBarAnimated:(BOOL)animated;
+(void)hideNavBarAnimated:(BOOL)animated;
+(void)lockSidebar:(BOOL)locked;
+(AirbitzViewController *)getSelectedViewController;
+(void)moveSelectedViewController: (CGFloat) x;
+(void)setAlphaOfSelectedViewController: (CGFloat) alpha;
+(CGFloat) getFooterHeight;
+(CGFloat) getHeaderHeight;
+(CGFloat)getWidth;
+(CGFloat)getHeight;
+(CGFloat)getLargestDimension;
+(CGFloat)getSmallestDimension;
+(CGFloat)getSafeOffscreenOffset:(CGFloat) widthOrHeight;


+ (void)fadingAlertHelpPopup:(NSString *)message;
+ (void)fadingAlert:(NSString *)message;
+ (void)fadingAlert:(NSString *)message holdTime:(CGFloat)holdTime;
+ (void)fadingAlertDismiss;

@end
