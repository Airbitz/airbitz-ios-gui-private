//
//  PasswordRecoveryViewController.h
//  AirBitz
//
//  Created by Carson Whitsett on 3/20/14.
//  Copyright (c) 2014 AirBitz. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef enum ePassRecovMode
{
    PassRecovMode_SignUp,
    PassRecovMode_Change,
    PassRecovMode_Recover
} tPassRecovMode;

@protocol PasswordRecoveryViewControllerDelegate;

@interface PasswordRecoveryViewController : UIViewController

@property (assign)              id<PasswordRecoveryViewControllerDelegate>  delegate;
@property (nonatomic, assign)   tPassRecovMode                              mode;
@property (nonatomic, strong)   NSArray                                     *arrayQuestions; // used for recover only
@property (nonatomic, copy)     NSString                                    *strUserName;    // used for recover only

@end

@protocol PasswordRecoveryViewControllerDelegate <NSObject>

@required
-(void)passwordRecoveryViewControllerDidFinish:(PasswordRecoveryViewController *)controller;
@end