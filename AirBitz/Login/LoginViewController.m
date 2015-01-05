//
//  LoginViewController.m
//  AirBitz
//
//  Created by Carson Whitsett on 3/1/14.
//  Copyright (c) 2014 AirBitz. All rights reserved.
//

#import "LoginViewController.h"
#import "ABC.h"
#import "SignUpViewController.h"
#import "User.h"
#import "StylizedTextField.h"
#import "Util.h"
#import "CoreBridge.h"
#import "Config.h"
#import "PasswordRecoveryViewController.h"
#import "CoreBridge.h"
#import "CommonTypes.h"
#import "LocalSettings.h"

typedef enum eLoginMode
{
    MODE_ENTERING_NEITHER,
    MODE_ENTERING_USERNAME,
    MODE_ENTERING_PASSWORD
} tLoginMode;

@interface LoginViewController () <UITextFieldDelegate, SignUpViewControllerDelegate, PasswordRecoveryViewControllerDelegate>
{
    tLoginMode                      _mode;
    CGRect                          _originalContentFrame;
    CGRect                          _originalLogoFrame;
    CGRect                          _originalRightSwipeArrowFrame;
    CGPoint                         _firstTouchPoint;
    BOOL                            _bSuccess;
    BOOL                            _bTouchesEnabled;
    NSString                        *_strReason;
    SignUpViewController            *_signUpController;
    UITextField                     *_activeTextField;
    PasswordRecoveryViewController  *_passwordRecoveryController;
}
@property (nonatomic, weak) IBOutlet UIView             *contentView;
@property (nonatomic, weak) IBOutlet StylizedTextField  *userNameTextField;
@property (nonatomic, weak) IBOutlet StylizedTextField  *passwordTextField;
@property (nonatomic, weak) IBOutlet UIButton           *backButton;
@property (nonatomic, weak) IBOutlet UIImageView        *swipeRightArrow;
@property (nonatomic, weak) IBOutlet UILabel            *swipeText;
@property (nonatomic, weak) IBOutlet UILabel            *titleText;
@property (nonatomic, weak) IBOutlet UIImageView        *logoImage;
@property (nonatomic, weak) IBOutlet UIView             *userEntryView;
@property (nonatomic, weak) IBOutlet UIView             *spinnerView;

@property (nonatomic, weak) IBOutlet UIView				*errorMessageView;
@property (nonatomic, weak) IBOutlet UILabel			*errorMessageText;

@end

@implementation LoginViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    _mode = MODE_ENTERING_NEITHER;
    _originalContentFrame = self.contentView.frame;
    _originalLogoFrame = self.logoImage.frame;
    _originalRightSwipeArrowFrame = _swipeRightArrow.frame;
    
    self.userNameTextField.delegate = self;
    self.passwordTextField.delegate = self;
    self.spinnerView.hidden = YES;
    
    #if HARD_CODED_LOGIN
    
    self.userNameTextField.text = HARD_CODED_LOGIN_NAME;
    self.passwordTextField.text = HARD_CODED_LOGIN_PASSWORD;
    #endif

	self.errorMessageView.alpha = 0.0;
}

- (void)viewWillAppear:(BOOL)animated
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [center addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];

    [self animateSwipeArrowWithRepetitions:3 andDelay:1.0 direction:1 arrow:_swipeRightArrow origFrame:_originalRightSwipeArrowFrame];

    _bTouchesEnabled = YES;

#if !HARD_CODED_LOGIN
    NSString *username = [LocalSettings controller].cachedUsername;
    if (username && 0 < username.length)
    {
        self.userNameTextField.text = username;
    }
    self.passwordTextField.text = [User Singleton].password;
#endif
    
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self dismissErrorMessage];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super viewWillDisappear:animated];
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

#pragma mark - Action Methods

- (IBAction)Back
{
    //spring out
    [UIView animateWithDuration:0.35
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^
     {
         CGRect frame = self.view.frame;
         if(frame.origin.x < 0)
         {
             frame.origin.x = -frame.size.width;
         }
         else
         {
             frame.origin.x = frame.size.width;
         }
         self.view.frame = frame;
     }
                     completion:^(BOOL finished)
     {
         [self.delegate loginViewControllerDidAbort];
     }];
}

- (IBAction)SignIn
{
    [self.userNameTextField resignFirstResponder];
    [self.passwordTextField resignFirstResponder];
    [self animateToInitialPresentation];

    _bSuccess = NO;
    tABC_Error Error;
    ABC_SignIn([self.userNameTextField.text UTF8String],
               [self.passwordTextField.text UTF8String],
               ABC_Request_Callback,
               (__bridge void *)self,
               &Error);
    if (Error.code != ABC_CC_Ok)
    {
        [Util printABC_Error:&Error];
    }
    else
    {
        [self showSpinner:YES];
    }
}

- (IBAction)SignUp
{
    [self dismissErrorMessage];

    [self.userNameTextField resignFirstResponder];
    [self.passwordTextField resignFirstResponder];
    [self animateToInitialPresentation];
    
    UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"Main_iPhone" bundle: nil];
    _signUpController = [mainStoryboard instantiateViewControllerWithIdentifier:@"SignUpViewController"];

    _signUpController.mode = SignUpMode_SignUp;
    _signUpController.delegate = self;
    
    CGRect frame = self.view.bounds;
    frame.origin.x = frame.size.width;
    _signUpController.view.frame = frame;
    [self.view addSubview:_signUpController.view];
    
    
    [UIView animateWithDuration:0.35
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^
     {
         _signUpController.view.frame = self.view.bounds;
     }
     completion:^(BOOL finished)
     {
     }];
}

- (IBAction)buttonForgotTouched:(id)sender
{
    [self dismissErrorMessage];

    [self.userNameTextField resignFirstResponder];
    [self.passwordTextField resignFirstResponder];

    // if they have a username
    if ([self.userNameTextField.text length])
    {
        [self showSpinner:YES];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
            BOOL bSuccess = NO;
            NSMutableString *error = [[NSMutableString alloc] init];
            NSArray *arrayQuestions = [CoreBridge getRecoveryQuestionsForUserName:self.userNameTextField.text
                                                                        isSuccess:&bSuccess
                                                                         errorMsg:error];
            NSArray *params = [NSArray arrayWithObjects:arrayQuestions, nil];
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                [self showSpinner:NO];
                _bSuccess = bSuccess;
                _strReason = error;
                [self performSelectorOnMainThread:@selector(launchQuestionRecovery:) withObject:params waitUntilDone:NO];
            });
        });
    }
    else
    {
        [self showFadingError:NSLocalizedString(@"Please enter a User Name", nil)];
    }
}

- (void)launchQuestionRecovery:(NSArray *)params
{
    if (_bSuccess && [params count] > 0)
    {
        NSArray *arrayQuestions = params[0];
        UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"Main_iPhone" bundle: nil];
        _passwordRecoveryController = [mainStoryboard instantiateViewControllerWithIdentifier:@"PasswordRecoveryViewController"];

        _passwordRecoveryController.delegate = self;
        _passwordRecoveryController.mode = PassRecovMode_Recover;
        _passwordRecoveryController.arrayQuestions = arrayQuestions;
        _passwordRecoveryController.strUserName = self.userNameTextField.text;

        CGRect frame = self.view.bounds;
        frame.origin.x = frame.size.width;
        _passwordRecoveryController.view.frame = frame;
        [self.view addSubview:_passwordRecoveryController.view];


        [UIView animateWithDuration:0.35
                                delay:0.0
                            options:UIViewAnimationOptionCurveEaseInOut
                            animations:^
            {
                _passwordRecoveryController.view.frame = self.view.bounds;
            }
                            completion:^(BOOL finished)
            {
            }];
    }
    else
    {
        [self showFadingError:_strReason];
    }
}

#pragma mark - Misc Methods

- (void)animateSwipeArrowWithRepetitions:(int)repetitions 
                                andDelay:(float)delay 
                               direction:(int)dir
                                   arrow:(UIView *)swipeArrow 
                               origFrame:(CGRect)originalFrame
{
    if (!repetitions)
    {
        return;
    }
    [UIView animateWithDuration:0.35
                          delay:delay
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^
     {
         CGRect frame = swipeArrow.frame;
         if (dir > 0)
            frame.origin.x = originalFrame.origin.x + originalFrame.size.width * 0.5;
         else
            frame.origin.x = originalFrame.origin.x - originalFrame.size.width * 0.5;
         swipeArrow.frame = frame;
         
     }
     completion:^(BOOL finished)
     {
         [UIView animateWithDuration:0.45
                               delay:0.0
                             options:UIViewAnimationOptionCurveEaseInOut
                          animations:^
          {
              CGRect frame = swipeArrow.frame;
              frame.origin.x = originalFrame.origin.x;
              swipeArrow.frame = frame;
              
          }
                          completion:^(BOOL finished)
          {
            [self animateSwipeArrowWithRepetitions:repetitions - 1
                                          andDelay:0
                                         direction:dir
                                             arrow:swipeArrow
                                         origFrame:originalFrame];
          }];
     }];
}

- (CGFloat)StatusBarHeight
{
    CGSize statusBarSize = [[UIApplication sharedApplication] statusBarFrame].size;
    return MIN(statusBarSize.width, statusBarSize.height);
}

- (void)animateToInitialPresentation
{
    [UIView animateWithDuration:0.35
                          delay: 0.0
                        options: UIViewAnimationOptionCurveEaseInOut
                     animations:^
     {
         self.contentView.frame = _originalContentFrame;
         
         _backButton.alpha = 1.0;
         _swipeRightArrow.alpha = 1.0;
         _swipeText.alpha = 1.0;
         _titleText.alpha = 1.0;
         
         self.logoImage.transform = CGAffineTransformMakeScale(1.0, 1.0);
         self.logoImage.frame = _originalLogoFrame;
         self.logoImage.alpha = 1.0;
     }
                     completion:^(BOOL finished)
     {
         _mode = MODE_ENTERING_NEITHER;
     }];
}

#pragma mark - keyboard callbacks

- (void)keyboardWillShow:(NSNotification *)notification
{
    // Logic to move login page elements above keyboard removed. -Allan Wright
}

- (void)keyboardWillHide:(NSNotification *)notification
{
    if(_activeTextField)
    {
         _activeTextField = nil;
    }
}

#pragma mark - touch events (for swiping)

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (!_bTouchesEnabled) {
        return;
    }

    UITouch *touch = [touches anyObject];
    _firstTouchPoint = [touch locationInView:self.view.window];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (!_bTouchesEnabled) {
        return;
    }
    
    UITouch *touch = [touches anyObject];
    CGPoint touchPoint = [touch locationInView:self.view.window];
    
    CGRect frame = self.view.frame;
    CGFloat xPos;
    
    xPos = touchPoint.x - _firstTouchPoint.x;
    
    frame.origin.x = xPos;
    self.view.frame = frame;
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (!_bTouchesEnabled) {
        return;
    }
    
    float xOffset = self.view.frame.origin.x;
    if(xOffset < 0) xOffset = -xOffset;
    if(xOffset < self.view.frame.size.width / 2)
    {
        //spring back
        [UIView animateWithDuration:0.35
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^
         {
             CGRect frame = self.view.frame;
            frame.origin.x = 0.0;
             self.view.frame = frame;
         }
        completion:^(BOOL finished)
         {
         }];
    }
    else
    {
        //spring out
        [UIView animateWithDuration:0.35
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^
         {
             CGRect frame = self.view.frame;
             if(frame.origin.x < 0)
             {
                 frame.origin.x = -frame.size.width;
             }
             else
             {
                 frame.origin.x = frame.size.width;
             }
             self.view.frame = frame;
         }
         completion:^(BOOL finished)
         {
             [self.delegate loginViewControllerDidAbort];
         }];
    }
}

#pragma mark - UITextField delegates

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    [self dismissErrorMessage];
    
    //called when user taps on either search textField or location textField
    _activeTextField = textField;
    
    if(_mode == MODE_ENTERING_NEITHER)
    {
        if(textField == self.userNameTextField)
        {
            _mode = MODE_ENTERING_USERNAME;
        }
        else
        {
            _mode = MODE_ENTERING_PASSWORD;
        }
    }

    // highlight all of the text
    if (textField == self.userNameTextField)
    {
        // highlight all the text
        [textField setSelectedTextRange:[textField textRangeFromPosition:textField.beginningOfDocument toPosition:textField.endOfDocument]];
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    if (textField == self.userNameTextField)
    {
        [self.passwordTextField becomeFirstResponder];

    }
    else
    {
        [self animateToInitialPresentation];
    }

    return NO;
}

- (void)signInComplete
{
    [self showSpinner:NO];
    if (_bSuccess)
    {
        [User login:self.userNameTextField.text
           password:self.passwordTextField.text];

        [self.delegate loginViewControllerDidLogin:NO];
    }
    else
    {
        [self showFadingError:_strReason];
        [User Singleton].name = nil;
        [User Singleton].password = nil; 
    }
}

#pragma mark - SignUpViewControllerDelegates

- (void)signupViewControllerDidFinish:(SignUpViewController *)controller withBackButton:(BOOL)bBack
{
    [controller.view removeFromSuperview];
    _signUpController = nil;

    [self finishIfLoggedIn:YES];
}

#pragma mark - ABC Callbacks

void ABC_Request_Callback(const tABC_RequestResults *pResults)
{
    if (pResults)
    {
        LoginViewController *controller = (__bridge id)pResults->pData;
        controller->_bSuccess = (BOOL)pResults->bSuccess;
        controller->_strReason = [Util errorMap:&(pResults->errorInfo)];
        if (pResults->requestType == ABC_RequestType_AccountSignIn)
        {
            [controller performSelectorOnMainThread:@selector(signInComplete) withObject:nil waitUntilDone:FALSE];
        }
    }
}

#pragma mark - PasswordRecoveryViewController Delegate

- (void)passwordRecoveryViewControllerDidFinish:(PasswordRecoveryViewController *)controller
{
    [controller.view removeFromSuperview];
    _passwordRecoveryController = nil;

    [self finishIfLoggedIn:NO];
}

#pragma mark - Error Message

- (void)dismissErrorMessage
{
    [self.errorMessageView.layer removeAllAnimations];
}

- (void)showFadingError:(NSString *)message
{
    self.errorMessageText.text = message;
    self.errorMessageView.alpha = 1.0;
    [UIView animateWithDuration:ERROR_MESSAGE_FADE_DURATION
                          delay:ERROR_MESSAGE_FADE_DELAY
                        options:UIViewAnimationOptionCurveLinear
                     animations:^
     {
         self.errorMessageView.alpha = 0.0;
     }
                     completion:^(BOOL finished)
     {
     }];
}

#pragma mark - Misc

- (void)showSpinner:(BOOL)bShow
{
    _spinnerView.hidden = !bShow;
    
    // disable touches while the spinner is visible
    _bTouchesEnabled = _spinnerView.hidden;
}

- (void)finishIfLoggedIn:(BOOL)bNewAccount
{
    if([User isLoggedIn])
    {
        _bSuccess = YES;

        [self.delegate loginViewControllerDidLogin:bNewAccount];
    }
}

#pragma mark - Rotation Methods

- (BOOL)shouldAutorotate
{
    return NO;
}

@end
