
#import "TwoFactorMenuViewController.h"
#import "TwoFactorScanViewController.h"
#import "MinCharTextField.h"
#import "ScanView.h"
#import "Util.h"
#import "ABCContext.h"
#import "NSDate+Helper.h"
#import "MainViewController.h"
#import "Theme.h"

@interface TwoFactorMenuViewController ()
    <UITextFieldDelegate, UIAlertViewDelegate, UIGestureRecognizerDelegate, TwoFactorScanViewControllerDelegate>
{
    TwoFactorScanViewController *_tfaScanViewController;
}

@property (nonatomic, weak) IBOutlet UILabel  *labelResetDesc;
@property (nonatomic, weak) IBOutlet UILabel  *labelResetDate;
@property (nonatomic, weak) IBOutlet UIButton *buttonReset;
@property (nonatomic, weak) IBOutlet UIButton *buttonScan;

@end

@implementation TwoFactorMenuViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        _bSuccess = NO;
        _bStoreSecret = NO;
        _bTestSecret = NO;
    }
    return self;
}

- (NSString *)formatDate:(NSDate *)date
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateStyle = NSDateFormatterMediumStyle;
    dateFormatter.doesRelativeDateFormatting = YES;
    return [dateFormatter stringFromDate:date];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    if (nil == self.resetDate) {
        _labelResetDate.hidden = YES;
        _labelResetDesc.hidden = YES;
        _buttonReset.hidden = NO;
    } else {
        _buttonReset.hidden = YES;
        _labelResetDate.hidden = NO;
        _labelResetDesc.hidden = NO;
        _labelResetDate.text = [NSString stringWithFormat:@"%@: %@",
                                resetDateText,
                                [self formatDate:self.resetDate]];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [MainViewController showNavBarAnimated:YES];
    [MainViewController changeNavBarOwner:self];
    [self setupNavBar];
}

- (void)setupNavBar;
{
    [MainViewController changeNavBarTitle:self title:twoFactorText];
    [MainViewController changeNavBar:self title:backButtonText side:NAV_BAR_LEFT button:true enable:true action:@selector(Back:) fromObject:self];
    [MainViewController changeNavBar:self title:importText side:NAV_BAR_RIGHT button:true enable:false action:nil fromObject:self];
}

- (IBAction)Back:(id)sender
{
    [self exitWithBackButton:YES];
}

- (IBAction)Scan:(id)sender
{
    UIStoryboard *settingsStoryboard = [UIStoryboard storyboardWithName:@"Settings" bundle: nil];
    _tfaScanViewController = [settingsStoryboard instantiateViewControllerWithIdentifier:@"TwoFactorScanViewController"];
    _tfaScanViewController.delegate = self;
    _tfaScanViewController.bStoreSecret = _bStoreSecret;
    _tfaScanViewController.bTestSecret = _bTestSecret;

    [Util addSubviewControllerWithConstraints:self child:_tfaScanViewController];
    [MainViewController animateSlideIn:_tfaScanViewController];

}

- (IBAction)Reset:(id)sender
{
    [abc requestOTPReset:_username token:_resetToken callback:^(ABCError *error)
    {
        if (!error)
            [MainViewController fadingAlert:resetRequestedText];
        else
            [MainViewController fadingAlert:error.userInfo[NSLocalizedDescriptionKey]];
    }];
}

- (void)twoFactorScanViewControllerDone:(TwoFactorScanViewController *)controller withBackButton:(BOOL)bBack
{
    _secret = controller.secret;
    _bSuccess = controller.bSuccess;
    if (!bBack) {
        [MainViewController animateOut:controller withBlur:NO complete:^(void)
        {
            _tfaScanViewController = nil;
            [self exit];
        }];
    } else {
        [MainViewController animateOut:controller withBlur:NO complete:^(void)
        {
            _tfaScanViewController = nil;
            [self viewWillAppear:YES];
        }];
    }

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
    [self.delegate twoFactorMenuViewControllerDone:self withBackButton:bBack];
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
