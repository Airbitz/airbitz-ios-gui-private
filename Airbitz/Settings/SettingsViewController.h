//
//  SettingsViewController.h
//  AirBitz
//
//  Created by Carson Whitsett on 2/28/14.
//  Copyright (c) 2014 AirBitz. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SignUpViewController.h"
#import "AirbitzViewController.h"

@protocol SettingsViewControllerDelegate;

@interface SettingsViewController : AirbitzViewController

@property (assign) id<SettingsViewControllerDelegate> delegate;

- (void)bringUpSignUpViewInMode:(tSignUpMode)mode;
- (void)bringUpRecoveryQuestionsView;
- (void)resetViews;
+ (void) enableTouchID;
+ (void) disableTouchID;

@end



@protocol SettingsViewControllerDelegate <NSObject>

@required
-(void)SettingsViewControllerDone:(SettingsViewController *)controller;
@optional
@end
