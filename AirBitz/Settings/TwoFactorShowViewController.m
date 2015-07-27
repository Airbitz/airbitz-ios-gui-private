
#import "TwoFactorShowViewController.h"
#import "TwoFactorMenuViewController.h"
#import "NotificationChecker.h"
#import "MinCharTextField.h"
#import "ABC.h"
#import "CoreBridge.h"
#import "Util.h"
#import "User.h"
#import "MainViewController.h"
#import "Theme.h"

@interface TwoFactorShowViewController () <UITextFieldDelegate, UIAlertViewDelegate, UIGestureRecognizerDelegate, TwoFactorMenuViewControllerDelegate>
{
    NSString                    *_secret;
    TwoFactorMenuViewController *_tfaMenuViewController;
    BOOL                        _isOn;
    long                        _timeout;
}

@property (nonatomic, weak) IBOutlet UIScrollView            *scrollView;
@property (nonatomic, weak) IBOutlet MinCharTextField        *passwordTextField;
@property (nonatomic, weak) IBOutlet UIView                  *requestView;
@property (nonatomic, weak) IBOutlet UIButton                *buttonApprove;
@property (nonatomic, weak) IBOutlet UIButton                *buttonCancel;
@property (nonatomic, weak) IBOutlet UISwitch                *tfaEnabledSwitch;
@property (nonatomic, weak) IBOutlet UIImageView             *qrCodeImageView;
@property (nonatomic, weak) IBOutlet UIView                  *viewQRCodeFrame;
@property (nonatomic, weak) IBOutlet UIView                  *loadingSpinner;
@property (nonatomic, weak) IBOutlet UILabel                 *onOffLabel;
@property (nonatomic, weak) IBOutlet UIActivityIndicatorView *requestSpinner;

@property (nonatomic)                BOOL                    bNoImportButton;

@end

@implementation TwoFactorShowViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
    {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    _viewQRCodeFrame.layer.cornerRadius = 8;
    _viewQRCodeFrame.layer.masksToBounds = YES;

    CGSize size = CGSizeMake(_scrollView.frame.size.width, _scrollView.frame.size.height);
    _scrollView.contentSize = size;
    [self initUI];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.bNoImportButton = ![CoreBridge otpHasError];
    [MainViewController changeNavBarOwner:self];

    [self updateViews];
}

- (void) updateViews
{
    [MainViewController changeNavBarTitle:self title:[Theme Singleton].twoFactorText];
    [MainViewController changeNavBar:self title:[Theme Singleton].backButtonText side:NAV_BAR_LEFT button:true enable:true action:@selector(Back:) fromObject:self];
    [MainViewController changeNavBar:self title:[Theme Singleton].importText side:NAV_BAR_RIGHT button:true enable:!self.bNoImportButton action:@selector(Import:) fromObject:self];
}

- (void)initUI
{
    _passwordTextField.text = @"";
    _passwordTextField.delegate = self;
    _passwordTextField.minimumCharacters = ABC_MIN_PASS_LENGTH;
    _passwordTextField.delegate = self;
    _passwordTextField.returnKeyType = UIReturnKeyDone;
    if (![CoreBridge passwordExists]) {
        _passwordTextField.hidden = YES;
    }

    _isOn = NO;
    [self updateTwoFactorUi:NO];
    _loadingSpinner.hidden = NO;

    // Check for any pending reset requests
    [self checkStatus:NO];
}

- (void)checkStatus:(BOOL)bMsg
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        [self doCheckStatus:bMsg];
    });
}

- (void)doCheckStatus:(BOOL)bMsg
{
    tABC_Error Error;
    bool on = NO;
    long timeout = 0;
    tABC_CC cc = ABC_OtpAuthGet([[User Singleton].name UTF8String],
            [[User Singleton].password UTF8String], &on, &timeout, &Error);
    if (cc == ABC_CC_Ok) {
        dispatch_async(dispatch_get_main_queue(), ^(void){
            _isOn = on == true ? YES : NO;
            _timeout = timeout;
            [self updateTwoFactorUi:_isOn == true];
            [self checkSecret:bMsg];
        });
    } else {
        dispatch_async(dispatch_get_main_queue(), ^(void){
            _isOn = on == true ? YES : NO;
            [self updateTwoFactorUi:NO];
            [MainViewController fadingAlert:NSLocalizedString(@"Unable to determine two factor status", nil)];
        });
    }
}

- (void)checkSecret:(BOOL)bMsg
{
    char *szSecret = NULL;
    _secret = nil;
    tABC_Error error;
    if (_isOn) {
        tABC_CC cc = ABC_OtpKeyGet([[User Singleton].name UTF8String], &szSecret, &error);
        if (cc == ABC_CC_Ok && szSecret) {
            _secret = [NSString stringWithUTF8String:szSecret];
        } else {
            _secret = nil;
            _viewQRCodeFrame.hidden = YES;
        }
        if (szSecret) {
            free(szSecret);
            _requestSpinner.hidden = NO;
        }
    }
    [self showQrCode:_isOn];

    if (_secret != nil) {
        _requestSpinner.hidden = NO;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
            [self checkRequest];
        });
        if (bMsg) {
            [MainViewController fadingAlert:NSLocalizedString(@"Two Factor Enabled", nil)];
        }
    } else {
        if (bMsg) {
            [MainViewController fadingAlert:NSLocalizedString(@"Two Factor Disabled", nil)];
        }
    }
}

- (void)showQrCode:(BOOL)show
{
    if (show) {
        unsigned char *pData = NULL;
        unsigned int width;

        tABC_Error error;
        tABC_CC cc = ABC_QrEncode([_secret UTF8String], &pData, &width, &error);
        if (cc == ABC_CC_Ok) {
            UIImage *qrImage = [Util dataToImage:pData withWidth:width andHeight:width];
            _qrCodeImageView.image = qrImage;
            _qrCodeImageView.layer.magnificationFilter = kCAFilterNearest;
            [self animateQrCode:YES];
        } else {
            _viewQRCodeFrame.hidden = YES;
        }
        if (pData) {
            free(pData);
        }
    } else {
        [self animateQrCode:NO];
    }
}
- (void)animateQrCode:(BOOL)show
{
    if (show) {
        if (_viewQRCodeFrame.hidden) {
            _viewQRCodeFrame.hidden = NO;
            _viewQRCodeFrame.alpha = 0;
            [UIView animateWithDuration:1 delay:0 options:UIViewAnimationOptionCurveLinear animations:^ {
                _viewQRCodeFrame.alpha = 1.0;
            } completion:^(BOOL finished) {
            }];
        }
    } else {
        if (!_viewQRCodeFrame.hidden) {
            _viewQRCodeFrame.alpha = 1;
            [UIView animateWithDuration:1 delay:0 options:UIViewAnimationOptionCurveLinear animations:^ {
                _viewQRCodeFrame.alpha = 0;
            } completion:^(BOOL finished) {
                _viewQRCodeFrame.hidden = YES;
            }];
        }
    }
}

- (void)checkRequest
{
    tABC_Error error;
    BOOL pending = [self isResetPending:&error];
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        if (error.code == ABC_CC_Ok) {
            _requestView.hidden = !pending;
        } else {
            _requestView.hidden = YES;
            [MainViewController fadingAlert:[Util errorMap:&error]];
        }
        _requestSpinner.hidden = YES;
    });
}

- (BOOL)isResetPending:(tABC_Error *)error
{
    BOOL bPending = NO;
    char *szUsernames = NULL;
    tABC_CC cc = ABC_OtpResetGet(&szUsernames, error);
    if (cc == ABC_CC_Ok) {
        NSString *usernames;
        NSString *loggedInUser;
        usernames = [[NSString alloc] initWithUTF8String:szUsernames];
        loggedInUser = [User Singleton].name;
        bPending = [usernames rangeOfString:loggedInUser].length > 0;
    }
    return bPending;
}

#pragma mark - Keyboard Notifications

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

#pragma mark - Action Methods

- (IBAction)switchFlipped:(UISwitch *)uiSwitch
{
    [self checkPassword];
}

- (void)checkPassword
{
    _loadingSpinner.hidden = NO;
    [_passwordTextField resignFirstResponder];
    [Util checkPasswordAsync:_passwordTextField.text withSelector:@selector(handleSwitchFlip:) controller:self];
}

- (void)invalidPasswordAlert
{
    UIAlertView *alert = [[UIAlertView alloc]
                        initWithTitle:NSLocalizedString(@"Incorrect password", nil)
                        message:NSLocalizedString(@"Incorrect password", nil)
                        delegate:self
                        cancelButtonTitle:@"Cancel"
                        otherButtonTitles:@"OK", nil];
    [alert show];
}

- (void)handleSwitchFlip:(NSNumber *)authenticated
{
    _loadingSpinner.hidden = YES;
    BOOL bAuthenticated = [authenticated boolValue];
    if (bAuthenticated) {
        if (![self switchTwoFactor:_tfaEnabledSwitch.on]) {
            _tfaEnabledSwitch.on = !_tfaEnabledSwitch.on;
        }
    } else {
        [_passwordTextField becomeFirstResponder];
        _tfaEnabledSwitch.on = !_tfaEnabledSwitch.on;
        _loadingSpinner.hidden = YES;
        [self invalidPasswordAlert];
    }
}

- (void)updateTwoFactorUi:(BOOL)on
{
    if (on) {
        _requestView.hidden = YES;
        _requestView.hidden = YES;
        _requestSpinner.hidden = YES;
        self.bNoImportButton = NO;
    } else {
        _requestView.hidden = YES;
        _requestView.hidden = YES;
        _requestSpinner.hidden = YES;
        _viewQRCodeFrame.hidden = YES;
        self.bNoImportButton = YES;
    }
    self.bNoImportButton = ![CoreBridge otpHasError];
    [self setText:on];
    _tfaEnabledSwitch.on = on;
    _loadingSpinner.hidden = YES;
    [self updateViews];
}

- (void)setText:(BOOL)on
{
    if (on) {
        _onOffLabel.text = NSLocalizedString(@"Enabled", nil);
    } else {
        _onOffLabel.text = NSLocalizedString(@"Disabled", nil);
    }
}

- (BOOL)switchTwoFactor:(BOOL)on
{
    tABC_Error error;
    tABC_CC cc;
    if (on) {
        cc = [self enableTwoFactor:&error];
    } else {
        cc = [self disableTwoFactor:&error];
    }
    if (cc == ABC_CC_Ok) {
        [self updateTwoFactorUi:on];
        [self checkSecret:YES];
        return YES;
    } else {
        return NO;
    }
}

- (tABC_CC)enableTwoFactor:(tABC_Error *)error
{
    tABC_CC cc = ABC_OtpAuthSet([[User Singleton].name UTF8String],
        [[User Singleton].password UTF8String], OTP_RESET_DELAY, error);
    if (cc == ABC_CC_Ok) {
        _isOn = YES;
    }
    return cc;
}

- (tABC_CC)disableTwoFactor:(tABC_Error *)error
{
    tABC_CC cc = ABC_OtpAuthRemove([[User Singleton].name UTF8String],
        [[User Singleton].password UTF8String], error);
    if (cc == ABC_CC_Ok) {
        _secret = nil;
        _isOn = NO;
        [NotificationChecker resetOtpNotifications];

        ABC_OtpKeyRemove([[User Singleton].name UTF8String], error);
    }
    return cc;
}

- (IBAction)Back:(id)sender
{
    [self exitWithBackButton:YES];
}

- (IBAction)Import:(id)sender
{
    UIStoryboard *settingsStoryboard = [UIStoryboard storyboardWithName:@"Settings" bundle: nil];
    _tfaMenuViewController = [settingsStoryboard instantiateViewControllerWithIdentifier:@"TwoFactorMenuViewController"];
    _tfaMenuViewController.delegate = self;
    _tfaMenuViewController.username = [User Singleton].name;
    _tfaMenuViewController.bStoreSecret = YES;

    [Util addSubviewControllerWithConstraints:self child:_tfaMenuViewController];
    [MainViewController animateSlideIn:_tfaMenuViewController];

    [self initUI];
}

- (IBAction)confirmRequest:(id)sender
{
    [self checkConfirm];
}

- (void)checkConfirm
{
    _loadingSpinner.hidden = NO;
    [_passwordTextField resignFirstResponder];
    [Util checkPasswordAsync:_passwordTextField.text withSelector:@selector(doConfirmRequest:) controller:self];
}

- (void)doConfirmRequest:(NSNumber *)object
{
    BOOL authenticated = [object boolValue];
    if (authenticated) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
            tABC_Error error;
            tABC_CC cc = [self disableTwoFactor:&error];
            dispatch_async(dispatch_get_main_queue(), ^(void){
                if (cc == ABC_CC_Ok) {
                    [MainViewController fadingAlert:NSLocalizedString(@"Request confirmed, Two Factor off.", nil)];
                    [self updateTwoFactorUi:NO];
                } else {
                    [MainViewController fadingAlert:[Util errorMap:&error]];
                }
                _loadingSpinner.hidden = YES;
            });

        });
    } else {
        [self invalidPasswordAlert];
        _loadingSpinner.hidden = YES;
    }
}

- (IBAction)cancelRequest:(id)sender
{
    [self checkCancel];
}

- (void)checkCancel
{
    _loadingSpinner.hidden = NO;
    [_passwordTextField resignFirstResponder];
    [Util checkPasswordAsync:_passwordTextField.text withSelector:@selector(doCancelRequest:) controller:self];
}

- (void)doCancelRequest:(NSNumber *)object
{
    BOOL authenticated = [object boolValue];
    if (authenticated) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
            tABC_Error Error;
            tABC_CC cc = ABC_OtpResetRemove([[User Singleton].name UTF8String],
                                            [[User Singleton].password UTF8String],
                                            &Error);
            dispatch_async(dispatch_get_main_queue(), ^(void){
                if (cc == ABC_CC_Ok) {
                    [MainViewController fadingAlert:NSLocalizedString(@"Reset Cancelled", nil)];
                    _requestView.hidden = YES;
                } else {
                    [MainViewController fadingAlert:[Util errorMap:&Error]];
                }
                _loadingSpinner.hidden = YES;
            });
        });
    } else {
        [self invalidPasswordAlert];
        _loadingSpinner.hidden = YES;
    }
}

#pragma mark - TwoFactorMenuViewControllerDelegate

- (void)twoFactorMenuViewControllerDone:(TwoFactorMenuViewController *)controller withBackButton:(BOOL)bBack
{
    BOOL success = controller.bSuccess;
    [MainViewController animateOut:controller withBlur:NO complete:^(void)
    {
        _tfaMenuViewController = nil;
    }];
    if (!bBack && !success) {
        [MainViewController fadingAlert:NSLocalizedString(@("Unable to import secret"), nil)];
    }

    [MainViewController changeNavBarOwner:self];

    [self updateViews];
    [self checkStatus:success];
}

#pragma mark - Misc Methods

- (void)installLeftToRightSwipeDetection
{
    UISwipeGestureRecognizer *gesture = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(didSwipeLeftToRight:)];
    gesture.direction = UISwipeGestureRecognizerDirectionRight;
    [self.view addGestureRecognizer:gesture];
}

- (void)exit
{
    [self exitWithBackButton:NO];
}

- (void)exitWithBackButton:(BOOL)bBack
{
    [self.delegate twoFactorShowViewControllerDone:self withBackButton:bBack];
}

#pragma mark - GestureReconizer methods

- (void)didSwipeLeftToRight:(UIGestureRecognizer *)gestureRecognizer
{
    [self Back:nil];
}

#pragma mark - Custom Notification Handlers

// called when a tab bar button that is already selected, is reselected again
- (void)tabBarButtonReselect:(NSNotification *)notification
{
    [self Back:nil];
}

@end

/* vim:set ft=objc sw=4 ts=4 et: */
