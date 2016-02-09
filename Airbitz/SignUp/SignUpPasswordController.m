//
//  SignUpPasswordController.m
//  AirBitz
//

#import "SignUpPasswordController.h"
#import "MinCharTextField.h"
#import "PasswordVerifyView.h"
#import "Util.h"
#import "User.h"
#import "MainViewController.h"
#import "Theme.h"
#import "LocalSettings.h"
#import "FadingAlertView.h"

#define KEYBOARD_MARGIN         10.0

@interface SignUpPasswordController () <UITextFieldDelegate, PasswordVerifyViewDelegate, UIAlertViewDelegate>
{
    UITextField                     *_activeTextField;
    PasswordVerifyView              *_passwordVerifyView;
    BOOL                            _bBlankFields;
}

@property (nonatomic, weak) IBOutlet MinCharTextField *passwordTextField;
@property (nonatomic, weak) IBOutlet MinCharTextField *reenterPasswordTextField;
@property (nonatomic, weak) IBOutlet MinCharTextField *pinTextField;
@property (nonatomic, weak) IBOutlet UIView                     *masterView;
@property (nonatomic, weak) IBOutlet UIView                     *contentView;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint         *contentStartConstraint;
@property (nonatomic, weak) IBOutlet UIActivityIndicatorView    *activityView;
@property (nonatomic, strong)   UIButton                        *buttonBlocker;
@property (nonatomic)           CGFloat                         contentViewY;
@property (nonatomic, copy)     NSString                        *labelString;
@property (nonatomic, copy)     NSString                        *strReason;
@property (weak, nonatomic) IBOutlet UILabel                    *pinTextLabel;
@property (weak, nonatomic) IBOutlet UILabel                    *setPasswordLabel;
@property (weak, nonatomic) IBOutlet UIButton                   *nextButton;
@property (weak, nonatomic) IBOutlet UIButton                   *skipButton;
@property (strong, nonatomic)        UIAlertView                *noPasswordAlert;


@end

@implementation SignUpPasswordController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    return [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.passwordTextField.delegate = self;
    self.passwordTextField.minimumCharacters = [AirbitzCore getMinimumPasswordLength];
    self.reenterPasswordTextField.delegate = self;
    self.reenterPasswordTextField.minimumCharacters = [AirbitzCore getMinimumPasswordLength];
    self.pinTextField.delegate = self;
    self.pinTextField.minimumCharacters = [AirbitzCore getMinimumPINLength];
    self.contentViewY = self.contentView.frame.origin.y;

    self.labelString = NSLocalizedString(@"Sign Up", @"Sign Up");


}

-(void)viewWillAppear:(BOOL)animated
{
    [self.pinTextField addTarget:self action:@selector(pinTextFieldChanged:) forControlEvents:UIControlEventEditingChanged];
    [self.passwordTextField addTarget:self action:@selector(passwordTextFieldChanged:) forControlEvents:UIControlEventEditingChanged];
    [self.reenterPasswordTextField addTarget:self action:@selector(passwordTextFieldChanged:) forControlEvents:UIControlEventEditingChanged];

    if (self.manager.bAllowPINOnly)
    {
        self.pinTextField.text = [NSString stringWithFormat:@"%@",self.manager.strPIN];
        self.pinTextField.hidden = YES;
        self.pinTextLabel.hidden = YES;
        self.setPasswordLabel.text = setPasswordText;
    }
    else
    {
        self.pinTextField.hidden = NO;
        self.pinTextLabel.hidden = NO;
        self.setPasswordLabel.text = setPasswordAndPinText;
    }
    [self setNextSkipButtonSettings];
//    [self.passwordTextField becomeFirstResponder];
}

- (void)viewWillDisappear:(BOOL)animated
{
    // ABCLog(2,@"%s", __FUNCTION__);
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super viewWillDisappear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - ABC Alert delegate

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if (_noPasswordAlert == alertView && buttonIndex == 1)
    {
        [self createAccount];
    }
}


#pragma mark - Action Methods

- (void)next
{
    // check the new password fields
    if ([self newPasswordFieldsAreValid] == YES && [self fieldsAreValid] == YES)
    {
        if ([self.passwordTextField.text length] == 0)
        {
            _noPasswordAlert = [[UIAlertView alloc]
                                initWithTitle:warningWithoutPasswordTitleText
                                message:warningWithoutPasswordPopupText
                                delegate:self
                                cancelButtonTitle:goBackButtonText
                                otherButtonTitles:okButtonText,nil];
            [_noPasswordAlert show];
        }
        else
        {
            [self createAccount];
        }
    }
}

- (void)createAccount
{
    [FadingAlertView create:self.view message:NSLocalizedString(@"Creating and securing account", nil) holdTime:FADING_ALERT_HOLD_TIME_FOREVER_WITH_SPINNER];
    [_passwordTextField resignFirstResponder];
    [_reenterPasswordTextField resignFirstResponder];
    [_pinTextField resignFirstResponder];

    [abc createAccount:self.manager.strUserName password:self.passwordTextField.text pin:self.pinTextField.text
                            complete:^(ABCUser *user)
     {
         [FadingAlertView dismiss:FadingAlertDismissFast];
         self.manager.strPassword = [NSString stringWithFormat:@"%@",self.passwordTextField.text];
         self.manager.strPIN = [NSString stringWithFormat:@"%@",self.pinTextField.text];
         user.delegate = [MainViewController Singleton];
         [User login:user];
         [MainViewController createFirstWallet];

         [super next];
     }
                               error:^(ABCConditionCode ccode, NSString *errorString)
     {
         [FadingAlertView create:self.view message:errorString holdTime:FADING_ALERT_HOLD_TIME_DEFAULT];
     }];
}

- (IBAction)skipTouched:(id)sender
{
    self.passwordTextField.text = nil;
    self.reenterPasswordTextField.text = nil;
    _bBlankFields = YES;
    [self next];
}

- (IBAction)eyeButtonTouched:(id)sender
{
    self.passwordTextField.secureTextEntry = !self.passwordTextField.secureTextEntry;
    self.reenterPasswordTextField.secureTextEntry = !self.reenterPasswordTextField.secureTextEntry;
}


// checks the password against the password rules
// returns YES if new password fields are good, NO if the new password fields failed the checks
// if the new password fields are bad, an appropriate message box is displayed
// note: this function is aware of the 'mode' of the view controller and will check and display appropriately
- (BOOL)newPasswordFieldsAreValid
{
    // Allow accounts with an empty password ONLY IF background fetch and notifications are allowed
    // We will use background fetch and notifications to remind the user to set a password
    
    if (self.manager.bAllowPINOnly && _bBlankFields)
    {
        return YES;
    }

    BOOL bNewPasswordFieldsAreValid = YES;
    {
        unsigned int count = 0;
        double secondsToCrack;
        NSMutableArray *ruleDescription;
        NSMutableArray *rulePassed;
        NSMutableString *checkResultsMessage;
        ABCConditionCode ccode;
        
        bNewPasswordFieldsAreValid = [abc checkPasswordRules:self.passwordTextField.text
                                              secondsToCrack:&secondsToCrack
                                                       count:&count
                                             ruleDescription:&ruleDescription
                                                  rulePassed:&rulePassed
                                         checkResultsMessage:&checkResultsMessage];
        
        if (bNewPasswordFieldsAreValid == NO)
        {
            UIAlertView *alert = [[UIAlertView alloc]
                    initWithTitle:NSLocalizedString(@"Insufficient Password", @"Title of password check popup alert")
                          message:checkResultsMessage
                         delegate:nil
                cancelButtonTitle:okButtonText
                otherButtonTitles:nil];
            [alert show];
        }
        else if ([self.passwordTextField.text isEqualToString:self.reenterPasswordTextField.text] == NO)
        {
            bNewPasswordFieldsAreValid = NO;
            [self showPasswordMismatch];
        }
    }

    return bNewPasswordFieldsAreValid;
}

- (void)showPasswordMismatch
{
    UIAlertView *alert = [[UIAlertView alloc]
            initWithTitle:self.labelString
                    message:[NSString stringWithFormat:@"%@ failed:\n%@", self.labelString, passwordMismatchText]
                    delegate:nil
        cancelButtonTitle:@"OK"
        otherButtonTitles:nil];
    [alert show];
}

// checks the pin field
// returns YES if field is good
// if the field is bad, an appropriate message box is displayed
// note: this function is aware of the 'mode' of the view controller and will check and display appropriately
- (BOOL)fieldsAreValid
{
    BOOL valid = YES;
    {
        // if the pin isn't long enough
        if (self.pinTextField.text.length < [AirbitzCore getMinimumPINLength])
        {
            valid = NO;
            UIAlertView *alert = [[UIAlertView alloc]
                    initWithTitle:self.labelString
                          message:[NSString stringWithFormat:@"%@ failed:\n%@",
                                                             self.labelString,
                                                             [NSString stringWithFormat:NSLocalizedString(@"PIN must be 4 digits", @""), [AirbitzCore getMinimumPINLength]]]
                         delegate:nil
                cancelButtonTitle:okButtonText
                otherButtonTitles:nil];
            [alert show];
        }
    }

    return valid;
}

#pragma mark - UITextField delegates

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    CGFloat contentTop = [MainViewController getHeaderHeight]; // raise the view
    //called when user taps on either search textField or location textField
    
    //ABCLog(2,@"TextField began editing");
    _activeTextField = textField;
    if(textField == self.passwordTextField)
    {
        if(_passwordVerifyView == nil)
        {
            _passwordVerifyView = [PasswordVerifyView CreateInsideView:self.masterView withDelegate:self];
            CGRect frame = _passwordVerifyView.frame;
            frame.origin.y = [MainViewController getHeaderHeight];
            frame.size.width = [MainViewController getWidth];
            _passwordVerifyView.frame = frame;

            contentTop += _passwordVerifyView.frame.size.height - textField.frame.origin.y + [Theme Singleton].elementPadding;
        }
        _passwordVerifyView.password = textField.text;
    }
    else
    {
        if(_passwordVerifyView)
        {
            [_passwordVerifyView dismiss];
        }
    }

    [UIView animateWithDuration:0.35
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^
                     {

                         _contentStartConstraint.constant = contentTop;
                         [self.view layoutIfNeeded];

                     }
                     completion:^(BOOL finished)
                     {
                     }];

}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if(textField == self.passwordTextField) {
        [_reenterPasswordTextField becomeFirstResponder];
    }
    else if ((textField == self.reenterPasswordTextField) && !self.manager.bAllowPINOnly)
    {
        [_pinTextField becomeFirstResponder];
    }
    else
    {
        [textField resignFirstResponder];
    }
    
    return YES;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString*)string;   // return NO to not change text
{
    if (textField == self.pinTextField)
    {
        NSString *newString = [[string componentsSeparatedByCharactersInSet:
                                [[NSCharacterSet decimalDigitCharacterSet] invertedSet]]
                               componentsJoinedByString:@""];
        if (![newString isEqualToString:string])
        {
            [MainViewController fadingAlert:PINOnlyNumbersText holdTime:FADING_ALERT_HOLD_TIME_DEFAULT];
            return NO;
        }
    }
    return YES;
}

- (void)pinTextFieldChanged:(UITextField *)textField
{
    if (textField.text.length == 4)
    {
        [textField resignFirstResponder];
    }
}

- (void)passwordTextFieldChanged:(UITextField *)textField
{
    if (_passwordTextField == textField)
    {
        if (_passwordVerifyView == nil)
        {
            _passwordVerifyView = [PasswordVerifyView CreateInsideView:self.masterView withDelegate:self];
        }
        _passwordVerifyView.password = textField.text;
    }
    [self setNextSkipButtonSettings];
}

- (void)setNextSkipButtonSettings
{
    _bBlankFields = NO;
    [self.nextButton setTitle:nextButtonText forState:UIControlStateNormal];
    self.skipButton.hidden = YES;

    if (self.manager.bAllowPINOnly)
    {
        if (([self.passwordTextField.text length] == 0) && ([self.reenterPasswordTextField.text length] == 0))
        {
            [self.nextButton setTitle:skipButtonText forState:UIControlStateNormal];
            self.skipButton.hidden = YES;
            _bBlankFields = YES;
        }
        else
        {
            self.skipButton.hidden = NO;
        }
    }
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    if(_activeTextField)
    {
        
        if(_activeTextField == self.passwordTextField)
        {
            if(_passwordVerifyView)
            {
                [_passwordVerifyView dismiss];
            }
        }
        [_activeTextField resignFirstResponder];
    }
}

#pragma mark - PasswordVerifyViewDelegates

- (void)PasswordVerifyViewDismissed:(PasswordVerifyView *)pv
{
    [_passwordVerifyView removeFromSuperview];
    _passwordVerifyView = nil;
}


@end
