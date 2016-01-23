//
//  LoginViewController.m
//  AirBitz
//
//  Created by Carson Whitsett on 3/1/14.
//  Copyright (c) 2014 AirBitz. All rights reserved.
//

#import "LoginViewController.h"
#import "ABC.h"
#import "PickerTextView.h"
#import "SignUpViewController.h"
#import "User.h"
#import "StylizedTextField.h"
#import "Util.h"
#import "CoreBridge.h"
#import "Config.h"
#import "SignUpManager.h"
#import "PasswordRecoveryViewController.h"
#import "TwoFactorMenuViewController.h"
#import "CoreBridge.h"
#import "CommonTypes.h"
#import "LocalSettings.h"
#import "MainViewController.h"
#import "ButtonSelectorView.h"
#import "APPINView.h"
#import "Theme.h"
#import "FadingAlertView.h"
#import "Keychain.h"
#import "NSMutableData+Secure.h"
#import "SettingsViewController.h"
#import "InfoView.h"

typedef enum eLoginMode
{
    MODE_NO_USERS,
    MODE_ENTERING_NEITHER,
    MODE_ENTERING_USERNAME,
    MODE_ENTERING_PASSWORD
} tLoginMode;

#define SWIPE_ARROW_ANIM_PIXELS 10

@interface LoginViewController () <UITextFieldDelegate, SignUpManagerDelegate, PasswordRecoveryViewControllerDelegate, PickerTextViewDelegate,
    TwoFactorMenuViewControllerDelegate, APPINViewDelegate, UIAlertViewDelegate, FadingAlertViewDelegate, ButtonSelectorDelegate, InfoViewDelegate >
{
    tLoginMode                      _mode;
    CGPoint                         _firstTouchPoint;
//    ABCConditionCode                _conditionCode;
    BOOL                            _bSuccess;
    BOOL                            _bTouchesEnabled;
    BOOL                            _bUsedTouchIDToLogin;
    NSString                        *_strReason;
    NSString                        *_accountToDelete;
    tABC_CC                         _resultCode;
    SignUpManager                   *_signupManager;
    UITextField                     *_activeTextField;
    PasswordRecoveryViewController  *_passwordRecoveryController;
    TwoFactorMenuViewController     *_tfaMenuViewController;
    float                           _keyboardFrameOriginY;
    CGFloat                         _originalLogoHeight;
    CGFloat                         _originalUsernameHeight;
    CGFloat                         _originalPasswordHeight;
    CGFloat                         _originalPasswordWidth;
    CGFloat                         _originalPINSelectorWidth;
    CGFloat                         _originalTextBitcoinWalletHeight;
    UIAlertView                     *_enableTouchIDAlertView;
    UIAlertView                     *_passwordCheckAlert;
    UIAlertView                     *_passwordIncorrectAlert;
    UIAlertView                     *_uploadLogAlert;
    UIAlertView                     *_deleteAccountAlert;
    NSString                        *_tempPassword;
    NSString                        *_tempPin;
    BOOL                            _bNewDeviceLogin;
    


}

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *usernameHeight;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *passwordHeight;
@property (weak, nonatomic) IBOutlet UIButton           *forgotPassworddButton;
@property (weak, nonatomic) IBOutlet APPINView          *PINCodeView;
@property (weak, nonatomic) IBOutlet ButtonSelectorView *PINusernameSelector;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *textBitcoinWalletHeight;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *logoHeight;
@property (nonatomic, weak) IBOutlet UIView             *contentView;
@property (weak, nonatomic) IBOutlet UIView             *credentialsView;
@property (nonatomic, weak) IBOutlet StylizedTextField  *passwordTextField;
@property (nonatomic, weak) IBOutlet UIButton           *backButton;
@property (nonatomic, weak) IBOutlet UIImageView        *swipeRightArrow;
@property (nonatomic, weak) IBOutlet UILabel            *swipeText;
@property (nonatomic, weak) IBOutlet UILabel            *titleText;
@property (nonatomic, weak) IBOutlet UIImageView        *logoImage;
@property (nonatomic, weak) IBOutlet UIView             *userEntryView;
@property (nonatomic, weak) IBOutlet UIView             *spinnerView;
@property (weak, nonatomic) IBOutlet UIView             *credentialsPINView;

@property (nonatomic, weak) IBOutlet UILabel			*errorMessageText;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *swipeArrowLeft;

@property (nonatomic, weak) IBOutlet    PickerTextView      *usernameSelector;
@property (nonatomic, strong)           NSArray             *arrayAccounts;
@property (nonatomic, strong)           NSArray             *otherAccounts;
@property (weak, nonatomic) IBOutlet    UIButton            *buttonOutsideTap;
@property (weak, nonatomic) IBOutlet    InfoView            *disclaimerInfoView;

@end

static BOOL bPINModeEnabled = false;
static BOOL bInitialized = false;

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

    self.usernameSelector.textField.delegate = self;
    self.usernameSelector.delegate = self;
    self.passwordTextField.delegate = self;
    self.PINCodeView.delegate = self;
    self.PINusernameSelector.delegate = self;
    self.spinnerView.hidden = YES;
    self.buttonOutsideTap.enabled = NO;

    [self getAllAccounts];

    if (!bInitialized)
    {
        bInitialized = true;
        _originalLogoHeight = self.logoHeight.constant = [Theme Singleton].heightLoginScreenLogo;
        _originalTextBitcoinWalletHeight = self.textBitcoinWalletHeight.constant;
        _originalUsernameHeight = self.usernameHeight.constant;
        _originalPasswordHeight = self.passwordHeight.constant;
        _originalPasswordWidth = self.passwordTextField.frame.size.width;
        _originalPINSelectorWidth = self.PINusernameSelector.frame.size.width;

        if ([self.arrayAccounts count] == 0)
        {
            _mode = MODE_NO_USERS;
        }
    }

    // set up the specifics on our picker text view
    self.usernameSelector.textField.borderStyle = UITextBorderStyleNone;
    self.usernameSelector.textField.backgroundColor = [UIColor clearColor];
    self.usernameSelector.textField.font = [UIFont fontWithName:AppFont size:16.0];
    self.usernameSelector.textField.clearButtonMode = UITextFieldViewModeNever;
    self.usernameSelector.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.usernameSelector.textField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.usernameSelector.textField.spellCheckingType = UITextSpellCheckingTypeNo;
    self.usernameSelector.textField.textColor = [UIColor whiteColor];
    self.usernameSelector.textField.returnKeyType = UIReturnKeyDone;
    self.usernameSelector.textField.tintColor = [UIColor whiteColor];
    self.usernameSelector.textField.textAlignment = NSTextAlignmentLeft;

    // Add shadows to some text for visibility
    self.PINusernameSelector.textLabel.layer.shadowRadius = 3.0f;
    self.PINusernameSelector.textLabel.layer.shadowOpacity = 1.0f;
    self.PINusernameSelector.textLabel.layer.masksToBounds = NO;
    self.PINusernameSelector.textLabel.layer.shadowColor = [ColorPinUserNameSelectorShadow CGColor];
    self.PINusernameSelector.textLabel.layer.shadowOffset = CGSizeMake(0.0, 0.0);

    self.swipeText.layer.shadowRadius = 3.0f;
    self.swipeText.layer.shadowOpacity = 1.0f;
    self.swipeText.layer.masksToBounds = NO;
    self.swipeText.layer.shadowColor = [[UIColor darkGrayColor] CGColor];
    self.swipeText.layer.shadowOffset = CGSizeMake(0.0, 0.0);

    self.titleText.layer.shadowRadius = LoginTitleTextShadowRadius;
    self.titleText.layer.shadowOpacity = 1.0f;
    self.titleText.layer.masksToBounds = NO;
    self.titleText.layer.shadowColor = [[UIColor whiteColor] CGColor];
    self.titleText.layer.shadowOffset = CGSizeMake(0.0, 0.0);
    self.titleText.textColor = ColorLoginTitleText;

    self.PINusernameSelector.button.layer.shadowRadius = PinEntryTextShadowRadius;
    self.PINusernameSelector.button.layer.shadowOpacity = 1.0f;
    self.PINusernameSelector.button.layer.masksToBounds = NO;
    self.PINusernameSelector.button.layer.shadowColor = [ColorPinUserNameSelectorShadow CGColor];
    self.PINusernameSelector.button.layer.shadowOffset = CGSizeMake(0.0, 0.0);
    
    self.forgotPassworddButton.layer.shadowRadius = 3.0f;
    self.forgotPassworddButton.layer.shadowOpacity = 1.0f;
    self.forgotPassworddButton.layer.masksToBounds = NO;
    self.forgotPassworddButton.layer.shadowColor = [ColorLoginTitleTextShadow CGColor];
    self.forgotPassworddButton.layer.shadowOffset = CGSizeMake(0.0, 0.0);

    self.usernameSelector.textField.placeholder = NSLocalizedString(@"Username", @"Username");
    self.usernameSelector.textField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:self.usernameSelector.textField.placeholder attributes:@{NSForegroundColorAttributeName: [UIColor lightTextColor]}];

    [self.usernameSelector setTopMostView:self.view];
    self.usernameSelector.pickerMaxChoicesVisible = 3;
    [self.usernameSelector setAccessoryImage:[UIImage imageNamed:@"btn_close.png"]];
    [Util stylizeTextField:self.usernameSelector.textField];

    [self.PINusernameSelector.button setBackgroundImage:nil forState:UIControlStateNormal];
    [self.PINusernameSelector.button setBackgroundImage:nil forState:UIControlStateSelected];
    [self.PINusernameSelector.button setBackgroundColor:[UIColor clearColor]];

    self.PINusernameSelector.textLabel.text = NSLocalizedString(@"", @"username");
    [self.PINusernameSelector setButtonWidth:_originalPINSelectorWidth];
    self.PINusernameSelector.accessoryImage = [UIImage imageNamed:@"btn_close.png"];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationEnteredForeground:)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];

}

- (void)viewWillAppear:(BOOL)animated
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [center addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];

    [self animateSwipeArrowWithRepetitions:3 andDelay:1.0 direction:1];

    _bTouchesEnabled = YES;
    _bUsedTouchIDToLogin = NO;
    _bNewDeviceLogin = NO;

    [self getAllAccounts];
    if (self.arrayAccounts.count > 0 && ![[AppDelegate abc] accountExistsLocal:[LocalSettings controller].cachedUsername])
        [LocalSettings controller].cachedUsername = self.arrayAccounts[0];

    [self updateUsernameSelector:[LocalSettings controller].cachedUsername];

    if (bPINModeEnabled)
    {
        self.textBitcoinWalletHeight.constant = 0;
        self.credentialsPINView.hidden = false;
        self.credentialsView.hidden = true;
        self.userEntryView.hidden = true;
        [self.passwordTextField resignFirstResponder];
        [self.usernameSelector.textField resignFirstResponder];
        [self.PINCodeView becomeFirstResponder];
    }
    else
    {
        self.textBitcoinWalletHeight.constant = _originalTextBitcoinWalletHeight;
        self.credentialsPINView.hidden = true;
        self.credentialsView.hidden = false;
        self.userEntryView.hidden = false;
        [self.passwordTextField resignFirstResponder];
        [self.usernameSelector.textField resignFirstResponder];
        [self.PINCodeView resignFirstResponder];
    }

    if (_mode == MODE_NO_USERS)
    {
        self.usernameSelector.textField.hidden = true;
        self.usernameHeight.constant = 0;
        self.passwordHeight.constant = 0;
        self.forgotPassworddButton.hidden = true;
    }
    else
    {
        [self.view.superview layoutIfNeeded];
        self.usernameHeight.constant = _originalUsernameHeight;
        self.passwordHeight.constant = _originalPasswordHeight;
        [UIView animateWithDuration:[Theme Singleton].animationDurationTimeDefault
                              delay:[Theme Singleton].animationDelayTimeDefault
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^
                         {
                             self.usernameSelector.textField.hidden = false;
                             self.forgotPassworddButton.hidden = false;
                             [self.view.superview layoutIfNeeded];
                         }
                         completion:^(BOOL finished)
                         {
                         }];
    }


    UITapGestureRecognizer *debug = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(uploadLog)];
    debug.numberOfTapsRequired = 5;
    [_logoImage addGestureRecognizer:debug];
    [_logoImage setUserInteractionEnabled:YES];

}

- (void)applicationEnteredForeground:(NSNotification *)notification {
    ABLog(1, @"LoginViewController:applicationEnteredForeground");
    [self autoReloginOrTouchIDIfPossible];
}

- (void)uploadLog {
    NSString *title = NSLocalizedString(@"Upload Log File", nil);
    NSString *message = NSLocalizedString(@"Enter any notes you would like to send to our support staff", nil);
    // show password reminder test
    _uploadLogAlert = [[UIAlertView alloc] initWithTitle:title
                                                     message:message
                                                    delegate:self
                                           cancelButtonTitle:@"Cancel"
                                           otherButtonTitles:@"Upload Log", nil];
    _uploadLogAlert.alertViewStyle = UIAlertViewStylePlainTextInput;
    [_uploadLogAlert show];
}

typedef enum eReloginState
{
    RELOGIN_DISABLE = 0,
    RELOGIN_USE_PASSWORD,
}tReloginState;

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [[User Singleton] loadLocalSettings:nil];
    
    //
    // Check if Disclaimer has ever been displayed on this device. If not, display it now
    //
    if ([[User Singleton] offerDisclaimer])
    {
        [self.passwordTextField resignFirstResponder];
        [self.usernameSelector.textField resignFirstResponder];
        [self.PINCodeView resignFirstResponder];

        self.disclaimerInfoView = [InfoView CreateWithHTML:@"infoDisclaimer" forView:self.view agreeButton:YES delegate:self];
    }
    else
    {
        [self autoReloginOrTouchIDIfPossible];
    }
    
}

#pragma InfoViewDelegate
- (void) InfoViewFinished:(InfoView *)infoView
{
    [infoView removeFromSuperview];
    if (infoView == self.disclaimerInfoView)
    {
        [[User Singleton] saveDisclaimerViewed];
    }
    if (bPINModeEnabled)
        [self.PINCodeView becomeFirstResponder];
    else
        [self.PINCodeView resignFirstResponder];

    [self autoReloginOrTouchIDIfPossible];
}

- (void)autoReloginOrTouchIDIfPossible
{
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [self autoReloginOrTouchIDIfPossibleMain];
    });
}

- (void)autoReloginOrTouchIDIfPossibleMain
{
    ABLog(1, @"ENTER autoReloginOrTouchIDIfPossibleMain");
    _bUsedTouchIDToLogin = NO;
    
    if (HARD_CODED_LOGIN) {
        self.usernameSelector.textField.text = HARD_CODED_LOGIN_NAME;
        self.passwordTextField.text = HARD_CODED_LOGIN_PASSWORD;
        [self showSpinner:YES];
        [self SignIn];
        return;
    }
    
    if (! [Keychain bHasSecureEnclave] )
    {
        abDebugLog(1, @"EXIT autoReloginOrTouchIDIfPossibleMain: No secure enclave");
        return;
    }

    NSString *username = [LocalSettings controller].cachedUsername;
    ABLog(1, @"Checking username=%@", username);
    

    //
    // If login expired, then disable relogin but continue validation of TouchID
    //
    if ([[AppDelegate abc] didLoginExpire:username])
    {
        ABLog(1, @"Login expired. Continuing with TouchID validation");
        [Keychain disableRelogin:username];
    }

    //
    // Look for cached username & password or PIN in the keychain. Use it if present
    //
    tReloginState reloginState = RELOGIN_DISABLE;


    NSString *strReloginKey  = [Keychain createKeyWithUsername:username key:RELOGIN_KEY];
    NSString *strUseTouchID  = [Keychain createKeyWithUsername:username key:USE_TOUCHID_KEY];
    NSString *strPasswordKey = [Keychain createKeyWithUsername:username key:PASSWORD_KEY];
    
    int64_t bRelogin = [Keychain getKeychainInt:strReloginKey error:nil];
    int64_t bUseTouchID = [Keychain getKeychainInt:strUseTouchID error:nil];
    NSString *kcPassword = [Keychain getKeychainString:strPasswordKey error:nil];

    if (!bRelogin && !bUseTouchID)
    {
        ABLog(1, @"EXIT autoReloginOrTouchIDIfPossibleMain No relogin or touchid settings in keychain");
        return;
    }

    if ([kcPassword length] >= 10)
    {
        reloginState = RELOGIN_USE_PASSWORD;
    }

    if (reloginState)
    {
        if (bUseTouchID && !bRelogin)
        {
            NSString *prompt = [NSString stringWithFormat:@"%@ [%@]",touchIDPromptText, username];

            ABLog(1, @"Launching TouchID prompt");
            if ([Keychain authenticateTouchID:prompt fallbackString:usePasswordText]) {
                bRelogin = YES;
                _bUsedTouchIDToLogin = YES;
            }
            else
            {
                ABLog(1, @"EXIT autoReloginOrTouchIDIfPossibleMain TouchID authentication failed");
                return;
            }
        }
        else
        {
            ABLog(1, @"autoReloginOrTouchIDIfPossibleMain Failed to enter TouchID");
        }

        if (bRelogin)
        {
            if (reloginState == RELOGIN_USE_PASSWORD)
            {
                // try to login
                self.usernameSelector.textField.text = username;
                self.passwordTextField.text = kcPassword;
                [self showSpinner:YES];
                [self SignIn];
            }
        }
    }
    else
    {
        ABLog(1, @"EXIT autoReloginOrTouchIDIfPossibleMain reloginState DISABLED");
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self dismissErrorMessage];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    self.PINCodeView.PINCode = nil;
    _tempPin = nil;
    _tempPassword = nil;
    [super viewWillDisappear:animated];
}

#pragma mark - APPINViewDelegate Methods

- (void)PINCodeView:(APPINView *)view didEnterPIN:(NSString *)PINCode
{
    [view resignFirstResponder];
    [self showSpinner:YES];
    [self SignInPIN:PINCode];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

#pragma mark - FadingAlertView delegate

- (void)fadingAlertDismissedNew
{
    if (bPINModeEnabled)
        [self.PINCodeView becomeFirstResponder];
    else
        [self.PINCodeView resignFirstResponder];
}



#pragma mark - Action Methods

- (IBAction)Back
{
    //spring out
    [MainViewController moveSelectedViewController:-self.view.frame.size.width];
    [self.view layoutIfNeeded];

    [UIView animateWithDuration:0.35
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^
     {
         [MainViewController moveSelectedViewController:0.0];
         [MainViewController setAlphaOfSelectedViewController:1.0];
         self.leftConstraint.constant = self.view.frame.size.width;
         [self.view.superview layoutIfNeeded];
     }
                     completion:^(BOOL finished)
     {
         [self.delegate loginViewControllerDidAbort];
     }];
}

- (IBAction)OutsideTapButton:(id)sender {
    [self.PINusernameSelector close];
    [self.usernameSelector dismissPopupPicker];
    self.buttonOutsideTap.enabled = NO;
}

#pragma mark - Misc Methods

- (void)updateUsernameSelector:(NSString *)username
{
    [self setUsernameText:username];
    NSMutableArray *stringArray = [[NSMutableArray alloc] init];
    for(NSString *str in self.arrayAccounts)
    {
        [stringArray addObject:str];
    }
    self.otherAccounts = [stringArray copy];
    self.PINusernameSelector.arrayItemsToSelect = self.otherAccounts;
}

- (void)setUsernameText:(NSString *)username
{
    // Update non-PIN username
    if (!username || 0 == username.length)
    {
        if (self.arrayAccounts && [self.arrayAccounts count] > 0)
            username = self.arrayAccounts[0];
    }
    
    if (username && username.length)
    {
        //
        // Set the PIN username default
        //
        UIFont *boldFont = [UIFont fontWithName:@"Lato-Regular" size:[Theme Singleton].fontSizeEnterPINText];
        UIFont *regularFont = [UIFont fontWithName:@"Lato-Regular" size:[Theme Singleton].fontSizeEnterPINText];
        UIColor *boldColor = [UIColor colorWithRed:60./255. green:140.5/255. blue:200/255. alpha:1.];
        NSString *title = [NSString stringWithFormat:@"Enter PIN for (%@)",
                           username];
        // Define general attributes like color and fonts for the entire text
        NSDictionary *attr = @{NSForegroundColorAttributeName:ColorPinEntryText,
                               NSFontAttributeName:regularFont};
        NSMutableAttributedString *attributedText = [ [NSMutableAttributedString alloc]
                                                     initWithString:title
                                                     attributes:attr];
        // blue and bold text attributes
        NSRange usernameTextRange = [title rangeOfString:username];
        [attributedText setAttributes:@{NSForegroundColorAttributeName:ColorPinEntryUsernameText,
                                        NSFontAttributeName:boldFont}
                                range:usernameTextRange];
        [self.PINusernameSelector.button setAttributedTitle:attributedText forState:UIControlStateNormal];

        //
        // Set the regular username field
        //
        self.usernameSelector.textField.text = username;
    }
    self.passwordTextField.text = [User Singleton].password;

}


- (IBAction)SignIn
{
    if (_mode == MODE_NO_USERS)
    {
        _mode = MODE_ENTERING_USERNAME;
        [self viewWillAppear:true];
    }
    else
    {
        [self.usernameSelector resignFirstResponder];
        [self.passwordTextField resignFirstResponder];

//        _bSuccess = NO;
        [self showSpinner:YES];
        [MainViewController showBackground:YES animate:YES];
        _bNewDeviceLogin = ![[AppDelegate abc] accountExistsLocal:self.usernameSelector.textField.text];
        ABLog(1, @"_bNewDeviceLogin=%d", (int) _bNewDeviceLogin);

        [[AppDelegate abc]
                signIn:self.usernameSelector.textField.text
                 password:self.passwordTextField.text
                      otp:nil
                 complete:^(void) {
                     [self signInComplete];
                 }
                error:^(ABCConditionCode ccode, NSString *errorString)
                {
                    [self showSpinner:NO];
//                    [[AppDelegate abc] otpSetError:_resultCode];

                    if (ABCConditionCodeInvalidOTP == ccode)
                    {
                        [MainViewController showBackground:NO animate:YES];
                        [self launchTwoFactorMenu];
                    }
                    else if (ABCConditionCodeError == ccode)
                    {
                        [MainViewController fadingAlert:NSLocalizedString(@"An error occurred. Possible network connection issue or incorrect username & password", nil)];
                    }
                    else
                    {
                        [MainViewController showBackground:NO animate:YES];
                        [MainViewController fadingAlert:errorString];
                        [User Singleton].name = nil;
                        [User Singleton].password = nil;
                    }
                }];

    }
}

- (IBAction)SignUp
{
    [self dismissErrorMessage];

    [MainViewController showBackground:YES animate:YES completion:^(BOOL finished)
    {
        [self.usernameSelector.textField resignFirstResponder];
        [self.passwordTextField resignFirstResponder];

        _signupManager = [[SignUpManager alloc] initWithController:self];
        _signupManager.delegate = self;
        _signupManager.strInUserName = nil;
        [MainViewController animateFadeOut:self.view];

        [_signupManager startSignup];

    }];
}

- (IBAction)buttonForgotTouched:(id)sender
{
    [self dismissErrorMessage];
    [self.usernameSelector.textField resignFirstResponder];
    [self.passwordTextField resignFirstResponder];

    // if they have a username
    if ([self.usernameSelector.textField.text length])
    {
        [self showSpinner:YES];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
            BOOL bSuccess = NO;
            NSMutableString *error = [[NSMutableString alloc] init];
            NSArray *arrayQuestions = [[AppDelegate abc] getRecoveryQuestionsForUserName:self.usernameSelector.textField.text
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
        [MainViewController fadingAlert:NSLocalizedString(@"Please enter a User Name", nil)];
    }
}

- (IBAction)buttonLoginWithPasswordTouched:(id)sender
{
    [self dismissErrorMessage];
    bPINModeEnabled = false;

    [self viewDidLoad];
    [self viewWillAppear:true];
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
        _passwordRecoveryController.strUserName = self.usernameSelector.textField.text;

        [MainViewController showNavBarAnimated:YES];
        [MainViewController animateView:_passwordRecoveryController withBlur:NO];
    }
    else
    {
        [MainViewController fadingAlert:_strReason];
    }
}

#pragma mark - ReLogin Methods


- (void)SignInPIN:(NSString *)pin
{
    [MainViewController showBackground:YES animate:YES];

    [[AppDelegate abc]
            signInWithPIN:[LocalSettings controller].cachedUsername
                         pin:pin
                    complete:^(void)
            {
                [User login:[LocalSettings controller].cachedUsername password:NULL];
                [self.delegate LoginViewControllerDidPINLogin];

                if ([Keychain bHasSecureEnclave] && [[AppDelegate abc] passwordExists])
                {
                    //
                    // Check if user has not yet been asked to enable touchID on this device
                    //

                    BOOL onEnabled = ([[LocalSettings controller].touchIDUsersEnabled indexOfObject:self.usernameSelector.textField.text] != NSNotFound);
                    BOOL onDisabled = ([[LocalSettings controller].touchIDUsersDisabled indexOfObject:self.usernameSelector.textField.text] != NSNotFound);

                    if (!onEnabled && !onDisabled)
                    {
                        //
                        // Ask if they want TouchID enabled for this user on this device
                        //
                        NSString *title = NSLocalizedString(@"Enable Touch ID", nil);
                        NSString *message = NSLocalizedString(@"Would you like to enable TouchID for this account and device?", nil);
                        _enableTouchIDAlertView = [[UIAlertView alloc] initWithTitle:title
                                                                             message:message
                                                                            delegate:self
                                                                   cancelButtonTitle:@"Later"
                                                                   otherButtonTitles:@"OK", nil];
                        _enableTouchIDAlertView.alertViewStyle = UIAlertViewStyleDefault;
                        [_enableTouchIDAlertView show];
                    }
                    else
                    {
                        [Keychain updateLoginKeychainInfo:[User Singleton].name
                                                 password:[User Singleton].password
                                               useTouchID:!onDisabled];
                    }
                }
                [self showSpinner:NO];
                self.PINCodeView.PINCode = nil;

            }
            error:^(ABCConditionCode ccode, NSString *errorString)
            {

                [MainViewController showBackground:NO animate:YES];
                [self.PINCodeView becomeFirstResponder];
                [self showSpinner:NO];
                self.PINCodeView.PINCode = nil;

                if (ABCConditionCodeBadPassword == ccode)
                {
                    [MainViewController fadingAlert:NSLocalizedString(@"Invalid PIN", nil)];
                    [self.PINCodeView becomeFirstResponder];
                }
                else if (ABCConditionCodeInvalidOTP == ccode)
                {
                    [MainViewController showBackground:NO animate:YES];
                    [self launchTwoFactorMenu];
                }
                else
                {
                    NSString *reason;
                    // Core doesn't return anything specific for the case where network is down.
                    // Make up a better response in this case
                    if (ccode == ABCConditionCodeError)
                        reason = NSLocalizedString(@"An error occurred. Please check your network connection. You may also exit PIN login and use your username & password to login offline", nil);
                    else
                        reason = errorString;

                    [MainViewController fadingAlert:reason];
                }
            }];
}




#pragma mark - Misc Methods

- (void)animateSwipeArrowWithRepetitions:(int)repetitions 
                                andDelay:(float)delay 
                               direction:(int)dir
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
         if (dir > 0)
             self.swipeArrowLeft.constant = SWIPE_ARROW_ANIM_PIXELS;
         else
             self.swipeArrowLeft.constant = -SWIPE_ARROW_ANIM_PIXELS;
         [self.view layoutIfNeeded];


     }
     completion:^(BOOL finished)
     {
         [UIView animateWithDuration:0.45
                               delay:0.0
                             options:UIViewAnimationOptionCurveEaseInOut
                          animations:^
          {
              self.swipeArrowLeft.constant = 0;
              [self.view layoutIfNeeded];

          }
                          completion:^(BOOL finished)
          {
            [self animateSwipeArrowWithRepetitions:repetitions - 1
                                          andDelay:0
                                         direction:dir];
          }];
     }];
}

- (CGFloat)StatusBarHeight
{
    CGSize statusBarSize = [[UIApplication sharedApplication] statusBarFrame].size;
    return MIN(statusBarSize.width, statusBarSize.height);
}

#pragma mark - keyboard callbacks

- (void)keyboardWillShow:(NSNotification *)notification
{
    [self updateDisplayForKeyboard:YES];

    //ABLog(2,@"Keyboard will show for SignUpView");
    NSDictionary *userInfo = [notification userInfo];
    CGRect keyboardFrame = [[userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];

    _keyboardFrameOriginY = keyboardFrame.origin.y;


}

- (void)keyboardWillHide:(NSNotification *)notification
{
    if(_activeTextField)
    {
         _activeTextField = nil;
    }
    [self updateDisplayForKeyboard:NO];
    _keyboardFrameOriginY = 0.0;
}

- (void)updateDisplayForKeyboard:(BOOL)up
{
    if(up)
    {
        [UIView animateWithDuration:0.35
                              delay: 0.0
                            options: UIViewAnimationOptionCurveEaseInOut
                         animations:^
        {
                 if(self.usernameSelector.textField.isEditing)
                 {
                     [self.usernameSelector updateChoices:self.arrayAccounts];
                 }

                 self.logoHeight.constant = _originalLogoHeight * 0.75;
                 self.textBitcoinWalletHeight.constant = 0;

                 [self.view layoutIfNeeded];

         }
            completion:^(BOOL finished)
         {

         }];
    }
    else
    {
        [UIView animateWithDuration:0.35
                              delay: 0.0
                            options: UIViewAnimationOptionCurveEaseInOut
                         animations:^
         {
             self.logoHeight.constant = _originalLogoHeight;
             self.textBitcoinWalletHeight.constant = _originalTextBitcoinWalletHeight;
             [self.view layoutIfNeeded];

         }
                         completion:^(BOOL finished)
         {
         }];

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
    CGFloat alpha;


    xPos = touchPoint.x - _firstTouchPoint.x;

    if (xPos < 0)
    {
        // Swiping to left
        [MainViewController moveSelectedViewController:(frame.size.width + xPos)];
        alpha = -xPos / frame.size.width;
    }
    else
    {
        // Swiping to right
        [MainViewController moveSelectedViewController:(-frame.size.width + xPos)];
        alpha = xPos / frame.size.width;
    }

    [MainViewController setAlphaOfSelectedViewController:alpha];
//    frame.origin.x = xPos;
//    self.view.frame = frame;
    self.leftConstraint.constant = xPos;
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
        [self.view.superview layoutIfNeeded];

        //spring back
        if (self.view.frame.origin.x > 0)
        {
            // sliding to right. Move directory back to left
            [MainViewController moveSelectedViewController:-self.view.frame.size.width];
        }
        else if (self.view.frame.origin.x < 0)
        {
            // sliding to left. Move directory back to right
            [MainViewController moveSelectedViewController:self.view.frame.size.width];
        }

//        [MainViewController setAlphaOfSelectedViewController:0.0];
        self.leftConstraint.constant = 0;

        [UIView animateWithDuration:0.35
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^
         {
             [self.view.superview layoutIfNeeded];
         }
        completion:^(BOOL finished)
         {
         }];
    }
    else
    {
        //spring out
        [self.view.superview layoutIfNeeded];

        CGRect frame = self.view.frame;
        if(frame.origin.x < 0)
        {
            self.leftConstraint.constant = -frame.size.width;
        }
        else
        {
            self.leftConstraint.constant = frame.size.width;
        }
        [MainViewController moveSelectedViewController:0.0];
        [MainViewController setAlphaOfSelectedViewController:1.0];

        [UIView animateWithDuration:0.35
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^
         {
             [self.view setAlpha:0];
             [self.view.superview layoutIfNeeded];
         }
         completion:^(BOOL finished)
         {
             self.leftConstraint.constant = 0;
             [self.view layoutIfNeeded];
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
        if(textField == self.usernameSelector.textField)
        {
            _mode = MODE_ENTERING_USERNAME;
        }
        else
        {
            _mode = MODE_ENTERING_PASSWORD;
        }
    }
    else if (_mode == MODE_NO_USERS)
    {
        ABLog(2,@"XXX error. should not happen");
    }

    // highlight all of the text
    if (textField == self.usernameSelector.textField)
    {
        [self getAllAccounts];
        [self.usernameSelector updateChoices:self.arrayAccounts];

        [textField setSelectedTextRange:[textField textRangeFromPosition:textField.beginningOfDocument toPosition:textField.endOfDocument]];
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    if (textField == self.usernameSelector.textField)
    {
        [self.usernameSelector dismissPopupPicker];
        [self.passwordTextField becomeFirstResponder];
    }

    return NO;
}

- (void)signInComplete
{
    [self showSpinner:NO];
//    [[AppDelegate abc] otpSetError:_resultCode];

    [User login:self.usernameSelector.textField.text
       password:self.passwordTextField.text
       setupPIN:YES];
    [self.delegate loginViewControllerDidLogin:NO newDevice:_bNewDeviceLogin usedTouchID:_bUsedTouchIDToLogin];

    if ([Keychain bHasSecureEnclave])
    {
        //
        // Check if user has not yet been asked to enable touchID on this device
        //

        BOOL onEnabled  = ( [[LocalSettings controller].touchIDUsersEnabled indexOfObject:self.usernameSelector.textField.text] != NSNotFound );
        BOOL onDisabled = ( [[LocalSettings controller].touchIDUsersDisabled indexOfObject:self.usernameSelector.textField.text] != NSNotFound );

        if (!onEnabled && !onDisabled)
        {
            //
            // Ask if they want TouchID enabled for this user on this device
            //
            NSString *title = NSLocalizedString(@"Enable Touch ID", nil);
            NSString *message = NSLocalizedString(@"Would you like to enable TouchID for this account and device?", nil);
            _enableTouchIDAlertView = [[UIAlertView alloc] initWithTitle:title
                                                                 message:message
                                                                delegate:self
                                                       cancelButtonTitle:@"Later"
                                                       otherButtonTitles:@"OK", nil];
            _enableTouchIDAlertView.alertViewStyle = UIAlertViewStyleDefault;
            [_enableTouchIDAlertView show];
        }
        else
        {
            [Keychain updateLoginKeychainInfo:[User Singleton].name
                                     password:[User Singleton].password
                                   useTouchID:!onDisabled];
        }
    }
}

- (void)launchTwoFactorMenu
{
    _tfaMenuViewController = (TwoFactorMenuViewController *)[Util animateIn:@"TwoFactorMenuViewController" storyboard:@"Settings" parentController:self];
    _tfaMenuViewController.delegate = self;
    _tfaMenuViewController.username = self.usernameSelector.textField.text;
    _tfaMenuViewController.bStoreSecret = NO;
    _tfaMenuViewController.bTestSecret = NO;
    _bTouchesEnabled = NO;
}

#pragma mark - SignUpManagerDelegate

-(void)signupAborted
{
    [MainViewController showBackground:NO animate:YES];
    [MainViewController animateFadeIn:self.view];
    _bTouchesEnabled = YES;
}

-(void)signupFinished
{
    [self finishIfLoggedIn:YES];
    _bTouchesEnabled = YES;
}

#pragma mark - TwoFactorScanViewControllerDelegate


- (void)twoFactorMenuViewControllerDone:(TwoFactorMenuViewController *)controller withBackButton:(BOOL)bBack
{
    BOOL success = controller.bSuccess;
    NSString *secret = controller.secret;

    [MainViewController hideNavBarAnimated:YES];
    _bTouchesEnabled = YES;

    [MainViewController animateOut:controller withBlur:NO complete:^(void)
    {
        _tfaMenuViewController = nil;

        if (!success) {
            return;
        }
        [self.usernameSelector.textField resignFirstResponder];
        [self.passwordTextField resignFirstResponder];

        [self showSpinner:YES];
        // Perform the two factor sign in

        [[AppDelegate abc]
                signIn:self.usernameSelector.textField.text
                 password:self.passwordTextField.text
                      otp:secret
                 complete:^(void) {
                            [self signInComplete];
                        }
                    error:^(ABCConditionCode ccode, NSString *errorString){
                        [self showSpinner:NO];
                        if (ccode == ABCConditionCodeError)
                            [MainViewController fadingAlert:NSLocalizedString(@"An error occurred. Possible network connection issue or incorrect username & password", nil)];
                        else
                            [MainViewController fadingAlert:errorString];
                    }];
    }];
}


#pragma mark - PasswordRecoveryViewController Delegate

- (void)passwordRecoveryViewControllerDidFinish:(PasswordRecoveryViewController *)controller
{
    [MainViewController animateOut:controller withBlur:NO complete:^(void)
    {
        _passwordRecoveryController = nil;
        [MainViewController hideNavBarAnimated:YES];
        [self finishIfLoggedIn:NO];
        _bTouchesEnabled = YES;

    }];
}

#pragma mark - Error Message

- (void)dismissErrorMessage
{
//    [self.errorMessageView.layer removeAllAnimations];
//    [_fadingAlert dismiss:NO];
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
        [SettingsViewController enableTouchID];

        [self.delegate loginViewControllerDidLogin:bNewAccount newDevice:NO usedTouchID:NO];
    }
}

- (void)getAllAccounts
{
    NSString *strError;
    self.arrayAccounts = [[AppDelegate abc] getLocalAccounts:&strError];
    if (nil == self.arrayAccounts)
    {
        if (strError)
            [MainViewController fadingAlert:strError];
    }
}

#pragma mark - PickerTextView delegates

- (void)pickerTextViewPopupSelected:(PickerTextView *)pickerTextView onRow:(NSInteger)row
{
    [self.usernameSelector.textField resignFirstResponder];
    [self.usernameSelector dismissPopupPicker];
    self.buttonOutsideTap.enabled = NO;
    
    // set the text field to the choice
    NSString *account = [self.arrayAccounts objectAtIndex:row];
    if([[AppDelegate abc] PINLoginExists:account])
    {
        [LocalSettings controller].cachedUsername = account;
        bPINModeEnabled = true;
        [self viewDidLoad];
        [self viewWillAppear:true];
        [self autoReloginOrTouchIDIfPossible];
    }
    else
    {
        self.usernameSelector.textField.text = account;
        [self.usernameSelector dismissPopupPicker];
        [self autoReloginOrTouchIDIfPossible];
    }
}

- (void)removeAccount:(NSString *)account
{
    tABC_CC cc = [[AppDelegate abc] accountDeleteLocal:account];
    if(ABC_CC_Ok == cc)
    {
        [self getAllAccounts];
        [self.usernameSelector updateChoices:self.arrayAccounts];

        if ([account isEqualToString:[LocalSettings controller].cachedUsername])
            [LocalSettings controller].cachedUsername = self.arrayAccounts[0];

        [self updateUsernameSelector:[LocalSettings controller].cachedUsername];
    }
    else
    {
        [MainViewController fadingAlert:[Util errorCC:cc]];
    }
}

- (void)pickerTextViewDidTouchAccessory:(PickerTextView *)pickerTextView categoryString:(NSString *)string
{
    [self deleteAccountPopup:string];
    [self.usernameSelector dismissPopupPicker];
    self.buttonOutsideTap.enabled = NO;
}

- (void)deleteAccountPopup:(NSString *)acct;
{
    NSString *warningText;
    if ([[AppDelegate abc] passwordExists:acct])
        warningText = deleteAccountWarning;
    else
        warningText = deleteAccountNoPasswordWarningText;
    
    _accountToDelete = acct;
    NSString *message = [NSString stringWithFormat:warningText, acct];
    _deleteAccountAlert = [[UIAlertView alloc]
                          initWithTitle:deleteAccountText
                          message:NSLocalizedString(message, nil)
                          delegate:self
                          cancelButtonTitle:noButtonText
                          otherButtonTitles:yesButtonText, nil];
    [_deleteAccountAlert show];
}

- (void)pickerTextViewFieldDidShowPopup:(PickerTextView *)pickerTextView
{
    CGRect frame = pickerTextView.popupPicker.frame;
    pickerTextView.popupPicker.frame = frame;

    CGRect pickerWindowFrame = [self.contentView convertRect:frame toView:self.view.window];

    // Shrink the popup if it would be behind the keyboard.

    if (_keyboardFrameOriginY > 0)
    {
        float overlap = _keyboardFrameOriginY - (pickerWindowFrame.origin.y + pickerWindowFrame.size.height);
        
        if (overlap < 0)
        {
            frame.size.height += overlap;
        }
        pickerTextView.popupPicker.frame = frame;
        
    }
    self.buttonOutsideTap.enabled = YES;

}

- (void)pickerTextViewFieldDidChange:(PickerTextView *)pickerTextView;
{
    //
    // Do not show popup if user has text in the field
    //
    if ([pickerTextView.textField.text length] > 0)
    {
        [pickerTextView dismissPopupPicker];
        self.buttonOutsideTap.enabled = NO;
    }
    else if ([pickerTextView.textField.text length] == 0)
    {
        [pickerTextView createPopupPicker];
        self.buttonOutsideTap.enabled = YES;
    }
}

- (void)pickerTextViewFieldDidEndEditing:(PickerTextView *)pickerTextView;
{
    [pickerTextView dismissPopupPicker];
    self.buttonOutsideTap.enabled = NO;
}

#pragma mark - UIAlertView Delegate

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if (alertView == _enableTouchIDAlertView)
    {
        if (0 == buttonIndex)
        {
            [SettingsViewController disableTouchID];
        }
        else
        {
            if ([[User Singleton].password length] > 0)
                [SettingsViewController enableTouchID];
            else
            {
                [self showPasswordCheckAlertForTouchID];
            }
        }

        return;
    }
    else if (alertView == _passwordCheckAlert)
    {
        if (0 == buttonIndex)
        {
            //
            // Need to disable TouchID in settings.
            //
            // Disable TouchID in LocalSettings
            [SettingsViewController disableTouchID];
            [MainViewController fadingAlert:NSLocalizedString(@"Touch ID Disabled", nil)];
        }
        else
        {
            //
            // Check the password
            //
            _tempPassword = [[alertView textFieldAtIndex:0] text];

            [Util checkPasswordAsync:_tempPassword
                        withSelector:@selector(handlePasswordResults:)
                          controller:self];
            [MainViewController fadingAlert:NSLocalizedString(@"Checking password...", nil)
                                   holdTime:FADING_ALERT_HOLD_TIME_FOREVER_WITH_SPINNER];
        }
        return;
    }
    else if (_passwordIncorrectAlert == alertView)
    {
        if (buttonIndex == 0)
        {
            [MainViewController fadingAlert:NSLocalizedString(@"Touch ID Disabled", nil)];
            [SettingsViewController disableTouchID];
        }
        else if (buttonIndex == 1)
        {
            [self showPasswordCheckAlertForTouchID];
        }
    }
    else if (_uploadLogAlert == alertView)
    {
        if (1 == buttonIndex)
        {
            [_logoImage setUserInteractionEnabled:NO];
            _spinnerView.hidden = NO;
            [[AppDelegate abc] uploadLogs:[[alertView textFieldAtIndex:0] text] notify:^
            {
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Debug Log File"
                                                                message:@"Upload Succeeded"
                                                               delegate:self
                                                      cancelButtonTitle:@"Ok"
                                                      otherButtonTitles:nil];
                [alert show];
                [_logoImage setUserInteractionEnabled:YES];
                _spinnerView.hidden = YES;
            }
            error:^
            {
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Debug Log File"
                                                                message:@"Upload Failed. Please check your network connection or contact support@airbitz.co"
                                                               delegate:self
                                                      cancelButtonTitle:@"Ok"
                                                      otherButtonTitles:nil];
                [alert show];
                [_logoImage setUserInteractionEnabled:YES];
                _spinnerView.hidden = YES;
            }];
        }
    }
    else if (_deleteAccountAlert == alertView)
    {
        [self.usernameSelector.textField resignFirstResponder];
        // if they said they wanted to delete the account
        if (buttonIndex == 1)
        {
            [self removeAccount:_accountToDelete];
            self.usernameSelector.textField.text = @"";
            [self.usernameSelector dismissPopupPicker];
        }
    }
}

- (void)showPasswordCheckAlertForTouchID
{
    // Popup to ask user for their password
    NSString *title = NSLocalizedString(@"Touch ID", nil);
    NSString *message = NSLocalizedString(@"Please enter your password to enable Touch ID", nil);
    // show password reminder test
    _passwordCheckAlert = [[UIAlertView alloc] initWithTitle:title
                                                     message:message
                                                    delegate:self
                                           cancelButtonTitle:@"Later"
                                           otherButtonTitles:@"OK", nil];
    _passwordCheckAlert.alertViewStyle = UIAlertViewStyleSecureTextInput;
    [_passwordCheckAlert show];
}

- (void)handlePasswordResults:(NSNumber *)authenticated
{
    BOOL bAuthenticated = [authenticated boolValue];
    if (bAuthenticated)
    {
        [User Singleton].password = _tempPassword;
        _tempPassword = nil;
        [MainViewController fadingAlert:NSLocalizedString(@"Touch ID Enabled", nil)];

        // Enable Touch ID
        [SettingsViewController enableTouchID];

    }
    else
    {
        _passwordIncorrectAlert = [[UIAlertView alloc]
                initWithTitle:NSLocalizedString(@"Incorrect Password", nil)
                      message:NSLocalizedString(@"Try again?", nil)
                     delegate:self
            cancelButtonTitle:@"NO"
            otherButtonTitles:@"YES", nil];
        [_passwordIncorrectAlert show];
    }
}


#pragma mark - ButtonSelectorView delegates

- (void)ButtonSelector:(ButtonSelectorView *)view selectedItem:(int)itemIndex
{
    [LocalSettings controller].cachedUsername = [self.otherAccounts objectAtIndex:itemIndex];
    if([[AppDelegate abc] PINLoginExists:[LocalSettings controller].cachedUsername])
    {
        [self updateUsernameSelector:[LocalSettings controller].cachedUsername];
        [self autoReloginOrTouchIDIfPossible];
    }
    else
    {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            [self viewDidLoad];
            [self viewWillAppear:true];
            [self autoReloginOrTouchIDIfPossible];
        }];
    }
}

- (void)ButtonSelectorWillShowTable:(ButtonSelectorView *)view
{
    [self.PINusernameSelector.textLabel resignFirstResponder];
    [self.PINCodeView resignFirstResponder];
    self.buttonOutsideTap.enabled = YES;

}

- (void)ButtonSelectorWillHideTable:(ButtonSelectorView *)view
{
    [self.PINCodeView becomeFirstResponder];
    self.buttonOutsideTap.enabled = NO;

}

- (void)ButtonSelectorDidTouchAccessory:(ButtonSelectorView *)selector accountString:(NSString *)string
{
    [self deleteAccountPopup:string];
    [self.PINCodeView becomeFirstResponder];

}


+ (void)setModePIN:(BOOL)enable
{
    if (enable)
        bPINModeEnabled = true;
    else
        bPINModeEnabled = false;

}

@end
