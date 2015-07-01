//
//  MainViewController.m
//  AirBitz
//
//  Created by Carson Whitsett on 2/28/14.
//  Copyright (c) 2014 AirBitz. All rights reserved.
//

#import "ABC.h"
#import "MainViewController.h"
#import "SlideoutView.h"
#import "DirectoryViewController.h"
#import "RequestViewController.h"
#import "SendViewController.h"
#import "WalletsViewController.h"
#import "TransactionsViewController.h"
#import "LoginViewController.h"
#import "Notifications.h"
#import "SettingsViewController.h"
#import "SignUpViewController.h"
#import "SendStatusViewController.h"
#import "TransactionDetailsViewController.h"
#import "TwoFactorScanViewController.h"
#import "BuySellViewController.h"
#import "AddressRequestController.h"
#import "BlurView.h"
#import "User.h"
#import "Config.h"
#import "Util.h"
#import "Theme.h"
#import "CoreBridge.h"
#import "CommonTypes.h"
#import "LocalSettings.h"
#import "AudioController.h"
#import "FadingAlertView.h"
#import "InfoView.h"
#import "DL_URLServer.h"
#import "NotificationChecker.h"
#import "LocalSettings.h"
#import "AirbitzViewController.h"
#import <MessageUI/MessageUI.h>
#import <MessageUI/MFMailComposeViewController.h>
#import "DropDownAlertView.h"
#import "Theme.h"

typedef enum eAppMode
{
	APP_MODE_DIRECTORY = TAB_BAR_BUTTON_DIRECTORY,
	APP_MODE_REQUEST = TAB_BAR_BUTTON_APP_MODE_REQUEST,
	APP_MODE_SEND = TAB_BAR_BUTTON_APP_MODE_SEND,
	APP_MODE_WALLETS = TAB_BAR_BUTTON_APP_MODE_WALLETS,
	APP_MODE_MORE = TAB_BAR_BUTTON_APP_MODE_MORE
} tAppMode;



@interface MainViewController () <UITabBarDelegate,RequestViewControllerDelegate, SettingsViewControllerDelegate,
                                  LoginViewControllerDelegate, SendViewControllerDelegate,
                                  TransactionDetailsViewControllerDelegate, UIAlertViewDelegate, FadingAlertViewDelegate, SlideoutViewDelegate,
                                  TwoFactorScanViewControllerDelegate, AddressRequestControllerDelegate, InfoViewDelegate, SignUpViewControllerDelegate,
                                  MFMailComposeViewControllerDelegate, BuySellViewControllerDelegate>
{
	DirectoryViewController     *_directoryViewController;
	RequestViewController       *_requestViewController;
	AddressRequestController    *_addressRequestController;
	TransactionsViewController       *_transactionsViewController;
    SendViewController          *_importViewController;
    SendViewController          *_sendViewController;
	LoginViewController         *_loginViewController;
	SettingsViewController      *_settingsViewController;
	BuySellViewController       *_buySellViewController;
    TransactionDetailsViewController *_txDetailsController;
    TwoFactorScanViewController      *_tfaScanViewController;
    SignUpViewController            *_signUpController;
    UIAlertView                 *_receivedAlert;
    UIAlertView                 *_passwordChangeAlert;
    UIAlertView                 *_passwordCheckAlert;
    UIAlertView                 *_passwordSetAlert;
    UIAlertView                 *_passwordIncorrectAlert;
    UIAlertView                 *_otpRequiredAlert;
    UIAlertView                 *_otpSkewAlert;
    UIAlertView                 *_userReviewAlert;
    UIAlertView                 *_userReviewOKAlert;
    UIAlertView                 *_userReviewNOAlert;
	tAppMode                    _appMode;
    NSURL                       *_uri;
    InfoView                    *_notificationInfoView;
    BOOL                        firstLaunch;

    CGRect                      _closedSlideoutFrame;
    SlideoutView                *slideoutView;
    FadingAlertView             *fadingAlertView;
}

@property (weak, nonatomic) IBOutlet UIView *blurViewContainer;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *blurViewLeft;
@property (weak, nonatomic) IBOutlet UITabBar *tabBar;
@property (weak, nonatomic) IBOutlet UINavigationBar *navBar;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *tabBarBottom;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *navBarTop;

@property (weak, nonatomic) IBOutlet UIImageView *backgroundView;
@property (weak, nonatomic) IBOutlet UIImageView *backgroundViewBlue;
@property AirbitzViewController                  *selectedViewController;
@property UIViewController            *navBarOwnerViewController;

@property (nonatomic, copy) NSString *strWalletUUID; // used when bringing up wallet screen for a specific wallet
@property (nonatomic, copy) NSString *strTxID;       // used when bringing up wallet screen for a specific wallet

@end

MainViewController *singleton;

@implementation MainViewController

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

    [User initAll];
    [Theme initAll];
    [DropDownAlertView initAll];
    [FadingAlertView initAll];

    singleton = self;

    NSMutableData *seedData = [[NSMutableData alloc] init];
    [self fillSeedData:seedData];
#if !DIRECTORY_ONLY
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docs_dir = [paths objectAtIndex:0];
    NSString *ca_path = [[NSBundle mainBundle] pathForResource:@"ca-certificates" ofType:@"crt"];

    tABC_Error Error;
    Error.code = ABC_CC_Ok;
    ABC_Initialize([docs_dir UTF8String],
                   [ca_path UTF8String],
                   (unsigned char *)[seedData bytes],
                   (unsigned int)[seedData length],
                   &Error);
    [Util printABC_Error:&Error];

    // Fetch general info as soon as possible
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        tABC_Error error;
        ABC_GeneralInfoUpdate(&error);
        [Util printABC_Error:&error];
    });
#endif

	// Do any additional setup after loading the view.
	UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"Main_iPhone" bundle: nil];
    UIStoryboard *directoryStoryboard = [UIStoryboard storyboardWithName:@"BusinessDirectory" bundle: nil];
	_directoryViewController = [directoryStoryboard instantiateViewControllerWithIdentifier:@"DirectoryViewController"];
	_loginViewController = [mainStoryboard instantiateViewControllerWithIdentifier:@"LoginViewController"];
	_loginViewController.delegate = self;

    [self loadUserViews];

    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];

    // resgister for transaction details screen complete notification
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(transactionDetailsExit:) name:NOTIFICATION_TRANSACTION_DETAILS_EXITED object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(launchSend:) name:NOTIFICATION_LAUNCH_SEND_FOR_WALLET object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(launchRequest:) name:NOTIFICATION_LAUNCH_REQUEST_FOR_WALLET object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(launchRecoveryQuestions:) name:NOTIFICATION_LAUNCH_RECOVERY_QUESTIONS object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleBitcoinUri:) name:NOTIFICATION_HANDLE_BITCOIN_URI object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loggedOffRedirect:) name:NOTIFICATION_MAIN_RESET object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyRemotePasswordChange:) name:NOTIFICATION_REMOTE_PASSWORD_CHANGE object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyOtpRequired:) name:NOTIFICATION_OTP_REQUIRED object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyOtpSkew:) name:NOTIFICATION_OTP_SKEW object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(launchReceiving:) name:NOTIFICATION_TX_RECEIVED object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(launchViewSweep:) name:NOTIFICATION_VIEW_SWEEP_TX object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(displayNextNotification) name:NOTIFICATION_NOTIFICATION_RECEIVED object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(lockTabbar) name:NOTIFICATION_WALLETS_LOADING object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(unlockTabbar) name:NOTIFICATION_WALLETS_LOADED object:nil];

    // init and set API key
    [DL_URLServer initAll];
    NSString *token = [NSString stringWithFormat:@"Token %@", AUTH_TOKEN];
    [[DL_URLServer controller] setHeaderRequestValue:token forKey: @"Authorization"];
    [[DL_URLServer controller] setHeaderRequestValue:[LocalSettings controller].clientID forKey:@"X-Client-ID"];
    [[DL_URLServer controller] verbose: SERVER_MESSAGES_TO_SHOW];
    
    [NotificationChecker initAll];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    UIInterfaceOrientation toOrientation = [[UIDevice currentDevice] orientation];
    NSNumber *nOrientation = [NSNumber numberWithInteger:toOrientation];
    NSDictionary *dictNotification = @{ KEY_ROTATION_ORIENTATION : nOrientation };

    NSLog(@"Woohoo we WILL rotate %d", toOrientation);
    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_ROTATION_CHANGED object:self userInfo:dictNotification];
}

/**
 * These views need to be cleaned out after a login
 */
- (void)loadUserViews
{
	UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"Main_iPhone" bundle: nil];
	_requestViewController = [mainStoryboard instantiateViewControllerWithIdentifier:@"RequestViewController"];
	_requestViewController.delegate = self;
	_sendViewController = [mainStoryboard instantiateViewControllerWithIdentifier:@"SendViewController"];
    _sendViewController.delegate = self;

    _importViewController = [mainStoryboard instantiateViewControllerWithIdentifier:@"SendViewController"];
    _importViewController.delegate = self;

    _transactionsViewController = [mainStoryboard instantiateViewControllerWithIdentifier:@"TransactionsViewController"];
    UIStoryboard *settingsStoryboard = [UIStoryboard storyboardWithName:@"Settings" bundle: nil];
    _settingsViewController = [settingsStoryboard instantiateViewControllerWithIdentifier:@"SettingsViewController"];
    _settingsViewController.delegate = self;
    [_settingsViewController resetViews];

	UIStoryboard *pluginStoryboard = [UIStoryboard storyboardWithName:@"Plugins" bundle: nil];
	_buySellViewController = [pluginStoryboard instantiateViewControllerWithIdentifier:@"BuySellViewController"];
    _buySellViewController.delegate = self;

    slideoutView = [SlideoutView CreateWithDelegate:self parentView:self.view withTab:self.tabBar];
    [self loadSlideOutViewConstraints];

    _otpRequiredAlert = nil;
    _otpSkewAlert = nil;
    firstLaunch = YES;
    [self.view layoutIfNeeded];
}

- (void) loadSlideOutViewConstraints
{
    NSLayoutConstraint *x;
    UIView *parentView = self.view;
    NSMutableArray *constraints = [[NSMutableArray alloc] init];

    [slideoutView setTranslatesAutoresizingMaskIntoConstraints:NO];
    NSDictionary *viewsDictionary = NSDictionaryOfVariableBindings(slideoutView, parentView);
    [parentView insertSubview:slideoutView aboveSubview:self.tabBar];

    x = [NSLayoutConstraint constraintWithItem:slideoutView
                                     attribute:NSLayoutAttributeLeading
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:parentView
                                     attribute:NSLayoutAttributeTrailing
                                    multiplier:1.0
                                      constant:0];
    [parentView addConstraint:x];

    // Align 64 pixels from top and 49 pixels from bottom to avoid nav bar and tabbar
    [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-64-[slideoutView]-49-|" options:0 metrics:nil views:viewsDictionary]];

    // Width is 280
    [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[slideoutView(==280)]" options:0 metrics:nil views:viewsDictionary]];

    [parentView addConstraints:constraints];
    slideoutView.leftConstraint = x;

}

- (void)viewWillAppear:(BOOL)animated
{
	self.tabBar.delegate = self;

	//originalTabBarPosition = self.tabBar.frame.origin;
#if DIRECTORY_ONLY
	[self hideTabBarAnimated:NO];
#else
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showHideTabBar:) name:NOTIFICATION_SHOW_TAB_BAR object:nil];
#endif


    // Launch biz dir into background

    _appMode = APP_MODE_DIRECTORY;

    [self launchViewControllerBasedOnAppMode];

    // Start on the Wallets tab to launch login screen
    _appMode = APP_MODE_WALLETS;

    self.tabBar.selectedItem = self.tabBar.items[_appMode];

    NSLog(@"navBar:%f %f\ntabBar: %f %f\n",
            self.navBar.frame.origin.y, self.navBar.frame.size.height,
            self.tabBar.frame.origin.y, self.tabBar.frame.size.height);

    NSLog(@"DVC topLayoutGuide: self=%f", self.topLayoutGuide.length);


    [self.tabBar setTranslucent:[Theme Singleton].bTranslucencyEnable];
    [self launchViewControllerBasedOnAppMode];
    firstLaunch = NO;
}

- (void)dealloc
{
    //remove all notifications associated with self
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Misc Methods


- (void)fillSeedData:(NSMutableData *)data
{
    NSMutableString *strSeed = [[NSMutableString alloc] init];

    // add the advertiser identifier
    if ([[UIDevice currentDevice] respondsToSelector:@selector(identifierForVendor)])
    {
        [strSeed appendString:[[[UIDevice currentDevice] identifierForVendor] UUIDString]];
    }

    // add the UUID
    CFUUIDRef theUUID = CFUUIDCreate(NULL);
    CFStringRef string = CFUUIDCreateString(NULL, theUUID);
    CFRelease(theUUID);
    [strSeed appendString:[[NSString alloc] initWithString:(__bridge NSString *)string]];
    CFRelease(string);

    // add the device name
    [strSeed appendString:[[UIDevice currentDevice] name]];

    // add the string to the data
    [data appendData:[strSeed dataUsingEncoding:NSUTF8StringEncoding]];

    double time = CACurrentMediaTime();

    [data appendBytes:&time length:sizeof(double)];

    UInt32 randomBytes = 0;
    if (0 == SecRandomCopyBytes(kSecRandomDefault, sizeof(int), (uint8_t*)&randomBytes)) {
        [data appendBytes:&randomBytes length:sizeof(UInt32)];
    }

    u_int32_t rand = arc4random();
    [data appendBytes:&rand length:sizeof(u_int32_t)];
}

-(void)showFastestLogin
{
//    self.backgroundView.image = [Theme Singleton].backgroundLogin;

    if (firstLaunch) {
        bool exists = [CoreBridge PINLoginExists];
        [self showLogin:NO withPIN:exists];
    } else {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^ {
            bool exists = [CoreBridge PINLoginExists];
            dispatch_async(dispatch_get_main_queue(), ^ {
                [self showLogin:YES withPIN:exists];
            });
        });
    }
}

+ (void)showBackground:(BOOL)loggedIn animate:(BOOL)animated
{
    [MainViewController showBackground:loggedIn animate:animated completion:nil];
}

+ (void)showBackground:(BOOL)loggedIn animate:(BOOL)animated completion:(void (^)(BOOL finished))completion
{
    CGFloat bvStart, bvEnd, bvbStart, bvbEnd;

    if (loggedIn)
    {
        bvStart = bvbEnd = 1.0;
        bvEnd = bvbStart = 0.0;
    }
    else
    {
        bvStart = bvbEnd = 0.0;
        bvEnd = bvbStart = 1.0;
    }
    if(animated)
    {
        [singleton.backgroundView setAlpha:bvStart];
        [singleton.backgroundViewBlue setAlpha:bvbStart];
        [UIView animateWithDuration:1.0
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                         animations:^
                         {
                             [singleton.backgroundView setAlpha:bvEnd];
                             [singleton.backgroundViewBlue setAlpha:bvbEnd];
                         }
                         completion:completion];
    }
    else
    {
        [singleton.backgroundView setAlpha:bvEnd];
        [singleton.backgroundViewBlue setAlpha:bvbEnd];
    }

}

+(void)setAlphaOfSelectedViewController: (CGFloat) alpha
{
    [singleton.selectedViewController.view setAlpha:alpha];
}


+(void)moveSelectedViewController: (CGFloat) x
{
    singleton.selectedViewController.leftConstraint.constant = x;
    singleton.blurViewLeft.constant = x;

}

-(void)showLogin:(BOOL)animated withPIN:(BOOL)bWithPIN
{
    [LoginViewController setModePIN:bWithPIN];
    _loginViewController.leftConstraint.constant = 0;
    [self.view layoutIfNeeded];

    if (_selectedViewController != _directoryViewController)
    {
        [MainViewController animateFadeOut:_selectedViewController.view remove:YES];
        _selectedViewController = _directoryViewController;

        NSArray *constraints = [Util insertSubviewWithConstraints:self.view child:_selectedViewController.view belowSubView:self.tabBar];

        _selectedViewController.leftConstraint = [constraints objectAtIndex:0];
    }
    [MainViewController animateFadeOut:_selectedViewController.view];
    [MainViewController moveSelectedViewController: -[MainViewController getLargestDimension]];
    NSArray *constraints = [Util insertSubviewWithConstraints:singleton.view child:_loginViewController.view belowSubView:singleton.tabBar];
    _loginViewController.leftConstraint = [constraints objectAtIndex:0];
    _loginViewController.leftConstraint.constant = 0;
    [self.view layoutIfNeeded];

    [MainViewController hideTabBarAnimated:animated];
    [MainViewController hideNavBarAnimated:animated];
    [MainViewController animateFadeIn:_loginViewController.view];
    [MainViewController showBackground:NO animate:YES];

}

+(void)showHideTabBar:(NSNotification *)notification
{
	BOOL showTabBar = ((NSNumber *)notification.object).boolValue;
	if(showTabBar)
	{
		[MainViewController showTabBarAnimated:YES];
	}
	else
	{
		[MainViewController hideTabBarAnimated:YES];
	}
}

+(void)showTabBarAnimated:(BOOL)animated
{
    if(animated)
    {
        [UIView animateWithDuration:0.25
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                         animations:^
                         {
                             singleton.tabBarBottom.constant = 0;
                             [singleton.view layoutIfNeeded];

                         }
                         completion:^(BOOL finished)
                         {
                             NSLog(@"view: %f, %f, tab bar origin: %f", singleton.view.frame.origin.y, singleton.view.frame.size.height, singleton.tabBar.frame.origin.y);

                         }];
    }
    else
    {
        singleton.tabBarBottom.constant = 0;
    }
}

+(void)showNavBarAnimated:(BOOL)animated
{

    if(animated)
    {
        [UIView animateWithDuration:0.25
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionBeginFromCurrentState
                         animations:^
                         {

                             singleton.navBarTop.constant = 0;

                             [singleton.view layoutIfNeeded];
                         }
                         completion:^(BOOL finished)
                         {
                             NSLog(@"view: %f, %f, tab bar origin: %f", singleton.view.frame.origin.y, singleton.view.frame.size.height, singleton.tabBar.frame.origin.y);
                         }];
    }
    else
    {
        singleton.navBarTop.constant = 0;
        [singleton.view layoutIfNeeded];
    }
}


+(void)hideTabBarAnimated:(BOOL)animated
{

	if(animated)
	{
		[UIView animateWithDuration:0.25
							  delay:0.0
							options:UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionBeginFromCurrentState
						 animations:^
		 {

             singleton.tabBarBottom.constant = -singleton.tabBar.frame.size.height;

             [singleton.view layoutIfNeeded];
		 }
		completion:^(BOOL finished)
		 {
			NSLog(@"view: %f, %f, tab bar origin: %f", singleton.view.frame.origin.y, singleton.view.frame.size.height, singleton.tabBar.frame.origin.y);
		 }];
	}
	else
	{
        singleton.tabBarBottom.constant = -singleton.tabBar.frame.size.height;
    }
}

+(void)hideNavBarAnimated:(BOOL)animated
{

    if(animated)
    {
        [UIView animateWithDuration:0.25
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionBeginFromCurrentState
                         animations:^
                         {

                             singleton.navBarTop.constant = -singleton.navBar.frame.size.height;

                             [singleton.view layoutIfNeeded];
                         }
                         completion:^(BOOL finished)
                         {
                             NSLog(@"view: %f, %f, tab bar origin: %f", singleton.view.frame.origin.y, singleton.view.frame.size.height, singleton.tabBar.frame.origin.y);
                         }];
    }
    else
    {
        singleton.navBarTop.constant = -singleton.navBar.frame.size.height;
        [singleton.view layoutIfNeeded];
    }
}

+(UIViewController *)getSelectedViewController
{
    return singleton.selectedViewController;
}

//
// Call this at initialization of viewController (NOT in an async queued call)
// Once a viewController takes ownership, it can send async'ed updates to navbar. In case an update comes in
// after another controller takes ownsership, the update will be dropped.
//
+(void)changeNavBarOwner:(UIViewController *)viewController
{
    singleton.navBarOwnerViewController = viewController;
}

+(void)changeNavBar:(UIViewController *)viewController
              title:(NSString*) titleText
               side:(tNavBarSide)navBarSide
             button:(BOOL)bIsButton
             enable:(BOOL)enable
             action:(SEL)func
         fromObject:(id) object
{
    if (singleton.navBarOwnerViewController != viewController)
        return;

    UIButton *titleLabelButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [titleLabelButton setTitle:titleText forState:UIControlStateNormal];
    titleLabelButton.frame = CGRectMake(0, 0, 70, 44);
    if (bIsButton)
    {
        [titleLabelButton setTitleColor:[Theme Singleton].colorTextLink forState:UIControlStateNormal];
        [titleLabelButton addTarget:object action:func forControlEvents:UIControlEventTouchUpInside];
    }
    else
    {
        titleLabelButton.enabled = false;
        [titleLabelButton setTitleColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
    }
    titleLabelButton.titleLabel.font = [UIFont fontWithName:[Theme Singleton].appFont size:16];
    titleLabelButton.titleLabel.adjustsFontSizeToFitWidth = YES;

    if (!enable)
    {
        titleLabelButton.hidden = true;
    }


    if (navBarSide == NAV_BAR_LEFT)
    {
        UIBarButtonItem *buttonItem = [[UIBarButtonItem alloc] initWithCustomView:titleLabelButton];
        titleLabelButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        singleton.navBar.topItem.leftBarButtonItem = buttonItem;

    }
    else if (navBarSide == NAV_BAR_RIGHT)
    {
        UIBarButtonItem *buttonItem = [[UIBarButtonItem alloc] initWithCustomView:titleLabelButton];
        titleLabelButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
        singleton.navBar.topItem.rightBarButtonItem = buttonItem;
    }
    else
    {
        singleton.navBar.topItem.titleView = titleLabelButton;
    }

}

+(void)changeNavBarTitle:(UIViewController *)viewController
        title:(NSString*) titleText
{
    [MainViewController changeNavBar:viewController title:titleText side:NAV_BAR_CENTER button:false enable:true action:nil fromObject:nil];
}

+(void)changeNavBarTitleWithButton:(UIViewController *)viewController title:(NSString*) titleText action:(SEL)func fromObject:(id) object;
{
    [MainViewController changeNavBar:viewController title:titleText side:NAV_BAR_CENTER button:true enable:true action:func fromObject:object];
}

-(void)launchViewControllerBasedOnAppMode
{
    if (_txDetailsController)
        [self TransactionDetailsViewControllerDone:_txDetailsController];

	switch(_appMode)
	{
		case APP_MODE_DIRECTORY:
		{
			if (_selectedViewController != _directoryViewController)
			{
                [MainViewController animateSwapViewControllers:_directoryViewController out:_selectedViewController];

            }
			break;
		}
		case APP_MODE_REQUEST:
		{
			if (_selectedViewController != _requestViewController)
			{
				if([User isLoggedIn] || (DIRECTORY_ONLY == 1))
				{
                    [MainViewController animateSwapViewControllers:_requestViewController out:_selectedViewController];
				}
				else
				{
                    [self showFastestLogin];
				}
			}
			break;
		}
		case APP_MODE_SEND:
		{
			if (_selectedViewController != _sendViewController)
			{
				if([User isLoggedIn] || (DIRECTORY_ONLY == 1))
				{
                    _sendViewController.bImportMode = NO;
                    [MainViewController animateSwapViewControllers:_sendViewController out:_selectedViewController];
				}
				else
				{
                    [self showFastestLogin];
				}
			}
			break;
		}
		case APP_MODE_WALLETS:
		{
			if (_selectedViewController != _transactionsViewController)
			{
				if ([User isLoggedIn] || (DIRECTORY_ONLY == 1))
				{
                    [MainViewController animateSwapViewControllers:_transactionsViewController out:_selectedViewController];
				}
				else
				{
                    [self showFastestLogin];
				}
			}
			break;
		}
		case APP_MODE_MORE:
            if ([User isLoggedIn] || (DIRECTORY_ONLY == 1))
            {
                if ([slideoutView isOpen]) {
                    [slideoutView showSlideout:NO];
                } else {
                    [slideoutView showSlideout:YES];
                }
            }
            else
            {
                [self showFastestLogin];
            }
			break;
	}
}

- (void)displayNextNotification
{
    if (!_notificationInfoView && [[UIApplication sharedApplication] applicationState] == UIApplicationStateActive)
    {
        NSDictionary *notif = [NotificationChecker firstNotification];
        if (notif)
        {
            // Hide the keyboard if a notification is shown
            [self.view endEditing:NO];
            NSString *notifHTML = [NSString stringWithFormat:@"<!DOCTYPE html>\
            <html>\
                <style>* { font-family: Helvetica; }</style>\
                <body>\
                    <div><strong><center>%@</center></strong><BR />\
                    %@\
                    </div>\
                </body>\
            </html>",
                                   [notif objectForKey:@"title"],
                                   [notif objectForKey:@"message"]];
            _notificationInfoView = [InfoView CreateWithDelegate:self];
            [_notificationInfoView enableScrolling:YES];
            CGRect frame = self.view.bounds;
            frame.size.height = frame.size.height - self.tabBar.frame.size.height;
            [_notificationInfoView setFrame:frame];
            [_notificationInfoView setHtmlInfoToDisplay:notifHTML];
            [self.view addSubview:_notificationInfoView];
        }
    }
}

- (void)lockTabbar
{
    UITabBarItem *item = self.tabBar.items[APP_MODE_SEND];
    item.enabled = NO;
    item = self.tabBar.items[APP_MODE_REQUEST];
    item.enabled = NO;
}

- (void)unlockTabbar
{
    UITabBarItem *item = self.tabBar.items[APP_MODE_SEND];
    item.enabled = YES;
    item = self.tabBar.items[APP_MODE_REQUEST];
    item.enabled = YES;
}

#pragma mark - SettingsViewControllerDelegates

-(void)SettingsViewControllerDone:(SettingsViewController *)controller
{
    [self loadUserViews];

	_appMode = APP_MODE_WALLETS;
    self.tabBar.selectedItem = self.tabBar.items[_appMode];
}

#pragma mark - LoginViewControllerDelegates

- (void)loginViewControllerDidAbort
{
	_appMode = APP_MODE_DIRECTORY;
    self.tabBar.selectedItem = self.tabBar.items[_appMode];
	[MainViewController showTabBarAnimated:YES];
    [MainViewController showNavBarAnimated:YES];
	[_loginViewController.view removeFromSuperview];
}

- (void)loginViewControllerDidLogin:(BOOL)bNewAccount
{
//    self.backgroundView.image = [Theme Singleton].backgroundApp;
    if (bNewAccount) {
        [FadingAlertView create:self.view
                        message:[Theme Singleton].creatingWalletText
                       holdTime:FADING_ALERT_HOLD_TIME_FOREVER_WITH_SPINNER];
        [CoreBridge setupNewAccount];
    }

    // After login, reset all the main views
    [self loadUserViews];

    _appMode = APP_MODE_WALLETS;
    self.tabBar.selectedItem = self.tabBar.items[_appMode];
    [MainViewController animateFadeOut:_loginViewController.view remove:YES];
	[MainViewController showTabBarAnimated:YES];
    [MainViewController showNavBarAnimated:YES];

    [self launchViewControllerBasedOnAppMode];
    [MainViewController changeNavBarTitle:_selectedViewController title:@""];

    if (_uri)
    {
        [self processBitcoinURI:_uri];
        _uri = nil;
    } else {
        [self checkUserReview];
    }
    
    // add right to left swipe detection for slideout
    [self installRightToLeftSwipeDetection];
}

- (void)LoginViewControllerDidPINLogin
{
//    self.backgroundView.image = [Theme Singleton].backgroundApp;

    _appMode = APP_MODE_WALLETS;
    self.tabBar.selectedItem = self.tabBar.items[_appMode];
    [MainViewController showTabBarAnimated:YES];
    [MainViewController showNavBarAnimated:YES];


    // After login, reset all the main views
    [self loadUserViews];

    [MainViewController animateFadeOut:_loginViewController.view remove:YES];
    [MainViewController showTabBarAnimated:YES];
    [MainViewController showNavBarAnimated:YES];

    [self launchViewControllerBasedOnAppMode];
    [MainViewController changeNavBarTitle:_selectedViewController title:@""];

    // if the user has a password, increment PIN login count
    if ([CoreBridge passwordExists]) {
        [[User Singleton] incPinLogin];
    }

    if (_uri) {
        [self processBitcoinURI:_uri];
        _uri = nil;
    } else if (![CoreBridge passwordExists]) {
        [self showPasswordSetAlert];
    } else if ([User Singleton].needsPasswordCheck) {
        [self showPasswordCheckAlert];
    } else {
        [self checkUserReview];
    }

    // add right to left swipe detection for slideout
    [self installRightToLeftSwipeDetection];
}



- (void)showPasswordCheckAlert
{
    NSString *title = [Theme Singleton].RememberYourPasswordTitle;
    NSString *message = [Theme Singleton].RememberYourPasswordMessage;
    // show password reminder test
    _passwordCheckAlert = [[UIAlertView alloc] initWithTitle:title
                                                     message:message
                                                    delegate:self
                                           cancelButtonTitle:[Theme Singleton].LaterText
                                           otherButtonTitles:[Theme Singleton].CheckPasswordText];
    _passwordCheckAlert.alertViewStyle = UIAlertViewStyleSecureTextInput;
    [_passwordCheckAlert show];
    [User Singleton].needsPasswordCheck = NO;
}

- (void)showPasswordChange
{
    //TODO - show the sreen for password change without needing old password
    UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"Main_iPhone" bundle: nil];
    _signUpController = [mainStoryboard instantiateViewControllerWithIdentifier:@"SignUpViewController"];
    
    _signUpController.mode = SignUpMode_ChangePasswordNoVerify;
    _signUpController.delegate = self;

    NSArray *constraints = [Util addSubviewWithConstraints:self.view child:_signUpController.view];
    _signUpController.leftConstraint = [constraints objectAtIndex:0];
    _signUpController.leftConstraint.constant = _signUpController.view.frame.size.width;

    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
    [UIView animateWithDuration:0.35
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^
     {
         _signUpController.leftConstraint.constant = 0;
         [self.view layoutIfNeeded];
     }
                     completion:^(BOOL finished)
     {
         [[UIApplication sharedApplication] endIgnoringInteractionEvents];
     }];
}

- (void)showPasswordCheckSkip
{
    [MainViewController fadingAlertHelpPopup:[Theme Singleton].createAccountAndTransferFundsText];
}

- (void)showPasswordSetAlert
{
    NSString *title = [Theme Singleton].NoPasswordSetText;
    NSString *message = [Theme Singleton].createPasswordForAccountText;
    // show password reminder test
    _passwordSetAlert = [[UIAlertView alloc]
            initWithTitle:title
                  message:message
                 delegate:self
        cancelButtonTitle:[Theme Singleton].SkipText
        otherButtonTitles:[Theme Singleton].OkCancelButtonTitle];
    [_passwordSetAlert show];
}

- (void)handlePasswordResults:(NSNumber *)authenticated
{
    BOOL bAuthenticated = [authenticated boolValue];
    if (bAuthenticated) {
        [MainViewController fadingAlert:[Theme Singleton].GreatJobRememberingText];
    } else {
        _passwordIncorrectAlert = [[UIAlertView alloc]
                initWithTitle:[Theme Singleton].IncorrectCurrentPassword
                      message:[Theme Singleton].IncorrectPasswordTryAgain
                     delegate:self
            cancelButtonTitle:[Theme Singleton].NoDescriptionText
            otherButtonTitles:[Theme Singleton].YesDescriptionText, [Theme Singleton].ChangeText, nil];
        [_passwordIncorrectAlert show];
    }
}

- (void)checkUserReview
{
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void) {
        if([User offerUserReview]) {
            _userReviewAlert = [[UIAlertView alloc]
                                    initWithTitle:[Theme Singleton].AirbitzCheckUserReview
                                    message:[Theme Singleton].MessageCheckUserReview
                                    delegate:self
                                    cancelButtonTitle:[Theme Singleton].CheckUserReviewCancelButtonTitle
                                    otherButtonTitles:[Theme Singleton].CheckUserReviewOtherButtonTitle, nil];
            [_userReviewAlert show];
        }
    });
}

- (void)fadingAlertDismissed:(FadingAlertView *)view
{
}


- (void)launchReceiving:(NSNotification *)notification
{
    NSDictionary *data = [notification userInfo];
    _strWalletUUID = [data objectForKey:KEY_TX_DETAILS_EXITED_WALLET_UUID];
    _strTxID = [data objectForKey:KEY_TX_DETAILS_EXITED_TX_ID];

    Transaction *transaction = [CoreBridge getTransaction:_strWalletUUID withTx:_strTxID];

    /* If showing QR code, launch receiving screen*/
    if (_selectedViewController == _requestViewController 
            && [_requestViewController showingQRCode:_strWalletUUID withTx:_strTxID])
    {
        RequestState state;

        //
        // Let the RequestViewController know a Tx came in for the QR code it's currently scanning.
        // If it returns kDone as the state. Transition to Tx Details.
        //
        state = [_requestViewController updateQRCode:transaction.amountSatoshi];

        if (state == kDone)
        {
            [self handleReceiveFromQR:_strWalletUUID withTx:_strTxID];
        }

    }
    // Prevent displaying multiple alerts
    else if (_receivedAlert == nil)
    {
        NSString *title = [Theme Singleton].ReceivedFundsAlert;
        NSString *msg = [Theme Singleton].BitcoinReceivedAlert;
        if (transaction && transaction.amountSatoshi < 0) {
            title = [Theme Singleton].SendFundsAlert;
            msg =[Theme Singleton].BitcoinSentAlertMessage;
        }
        [[AudioController controller] playReceived];
        _receivedAlert = [[UIAlertView alloc]
                                initWithTitle:title
                                message:msg
                                delegate:self
                                cancelButtonTitle:[Theme Singleton].cancelButtonText
                                otherButtonTitles:[Theme Singleton].OkCancelButtonTitle, nil];
        [_receivedAlert show];
        // Wait 5 seconds and dimiss
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC);
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void) {
            if (_receivedAlert)
            {
                [_receivedAlert dismissWithClickedButtonIndex:0 animated:YES];
            }
        });
    }
}

- (void)handleReceiveFromQR:(NSString *)walletUUID withTx:(NSString *)txId
{
    NSString *message;
    
    NSInteger receiveCount = LocalSettings.controller.receiveBitcoinCount + 1; //TODO find RECEIVES_COUNT
    [LocalSettings controller].receiveBitcoinCount = receiveCount;
    [LocalSettings saveAll];
    
    NSString *coin;
    NSString *fiat;
    
    tABC_Error error;
    Wallet *wallet = [CoreBridge getWallet:walletUUID];
    Transaction *transaction = [CoreBridge getTransaction:walletUUID withTx:txId];
    
    double currency;
    int64_t satoshi = transaction.amountSatoshi;
    if (ABC_SatoshiToCurrency([[User Singleton].name UTF8String], [[User Singleton].password UTF8String],
                              satoshi, &currency, wallet.currencyNum, &error) == ABC_CC_Ok)
        fiat = [CoreBridge formatCurrency:currency withCurrencyNum:wallet.currencyNum withSymbol:true];
    
    currency = fabs(transaction.amountFiat);
    if (ABC_CurrencyToSatoshi([[User Singleton].name UTF8String], [[User Singleton].password UTF8String],
                                  currency, wallet.currencyNum, &satoshi, &error) == ABC_CC_Ok)
        coin = [CoreBridge formatSatoshi:satoshi withSymbol:false cropDecimals:[CoreBridge currencyDecimalPlaces]];


    if (receiveCount <= 2 && ([LocalSettings controller].bMerchantMode == false))
    {
        message = [NSString stringWithFormat:[Theme Singleton].YouReceivedBitcoinText, coin, fiat];
    }
    else
    {
        message = [NSString stringWithFormat:[Theme Singleton].YouReceivedBitcoinReceivedCount, coin, fiat];
    }

    if([LocalSettings controller].bMerchantMode)
    {
        [MainViewController showTabBarAnimated:NO];
    }
    else
    {
        [self launchTransactionDetails:_strWalletUUID withTx:_strTxID];
    }

    [_requestViewController resetViews];

    [MainViewController fadingAlert:message];
}

- (void)launchViewSweep:(NSNotification *)notification
{
    NSDictionary *data = [notification userInfo];
    _strWalletUUID = [data objectForKey:KEY_TX_DETAILS_EXITED_WALLET_UUID];
    _strTxID = [data objectForKey:KEY_TX_DETAILS_EXITED_TX_ID];
    [self launchTransactionDetails:_strWalletUUID withTx:_strTxID];
}

- (void)launchTransactionDetails:(NSString *)walletUUID withTx:(NSString *)txId
{
    Wallet *wallet = [CoreBridge getWallet:walletUUID];
    Transaction *transaction = [CoreBridge getTransaction:walletUUID withTx:txId];

    UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"Main_iPhone" bundle:nil];
    _txDetailsController = [mainStoryboard instantiateViewControllerWithIdentifier:@"TransactionDetailsViewController"];
    _txDetailsController.wallet = wallet;
    _txDetailsController.transaction = transaction;
    _txDetailsController.delegate = self;
    _txDetailsController.bOldTransaction = NO;
    _txDetailsController.transactionDetailsMode = TD_MODE_RECEIVED;

    [Util addSubviewControllerWithConstraints:singleton.view child:_txDetailsController];
    [MainViewController animateSlideIn:_txDetailsController];
}

-(void)TransactionDetailsViewControllerDone:(TransactionDetailsViewController *)controller
{

    [MainViewController animateOut:controller withBlur:NO complete:^
    {
        [_txDetailsController.view removeFromSuperview];
        _txDetailsController = nil;
        [MainViewController showNavBarAnimated:YES];
        [MainViewController showTabBarAnimated:YES];
    }];
}

#pragma mark - ABC Alert delegate

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
	if (_receivedAlert == alertView && buttonIndex == 1)
	{
        [self launchTransactionDetails:_strWalletUUID withTx:_strTxID];
        _receivedAlert = nil;
	}
    else if (_passwordChangeAlert == alertView)
    {
        _passwordChangeAlert = nil;
    }
    else if (_otpRequiredAlert == alertView && buttonIndex == 1)
    {
        [self launchTwoFactorScan];
    }
    else if (_passwordCheckAlert == alertView)
    {
        _passwordCheckAlert = nil;
        if (buttonIndex == 0) {
            [self showPasswordCheckSkip];
        } else {
            [Util checkPasswordAsync:[[alertView textFieldAtIndex:0] text]
                        withSelector:@selector(handlePasswordResults:)
                          controller:self];
            [FadingAlertView create:self.view message:[Theme Singleton].CheckingPasswordText holdTime:FADING_ALERT_HOLD_TIME_FOREVER_WITH_SPINNER];
        }
    }
    else if (_passwordIncorrectAlert == alertView)
    {
        if (buttonIndex == 0) {
            [self showPasswordCheckSkip];
        } else if (buttonIndex == 1) {
            [self showPasswordCheckAlert];
        } else {
            [self showPasswordChange];
        }
    }
    else if (_passwordSetAlert == alertView)
    {
        _passwordSetAlert = nil;
        if (buttonIndex == 0) {
        } else {
            [self launchChangePassword];
        }
    }
    else if (_userReviewAlert == alertView)
    {
        if(buttonIndex == 0) // No, send an email to support
        {
            _userReviewNOAlert = [[UIAlertView alloc]
                                  initWithTitle:[Theme Singleton].AirbitzCheckUserReview
                                  message:[Theme Singleton].UserReviewNoAlertMessage
                                  delegate:self
                                  cancelButtonTitle:[Theme Singleton].NoThanksUserReview
                                  otherButtonTitles:[Theme Singleton].OkCancelButtonTitle, nil];
            [_userReviewNOAlert show];
        }
        else if (buttonIndex == 1) // Yes, launch userReviewOKAlert
        {
            _userReviewOKAlert = [[UIAlertView alloc]
                                initWithTitle:[Theme Singleton].AirbitzCheckUserReview
                                message:[Theme Singleton].WriteUserReviewAppStore
                                delegate:self
                                cancelButtonTitle:[Theme Singleton].NoThanksUserReview
                                otherButtonTitles:[Theme Singleton].OkCancelButtonTitle, nil];
            [_userReviewOKAlert show];
        }
    }
    else if (_userReviewNOAlert == alertView)
    {
        if(buttonIndex == 1)
        {
            [self sendSupportEmail];
        }
    }
    else if (_userReviewOKAlert == alertView)
    {
        if(buttonIndex == 1)
        {
            NSString *iTunesLink = @"https://itunes.apple.com/us/app/bitcoin-wallet-map-directory/id843536046?mt=8";
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:iTunesLink]];
        }
    }
}

- (void)alertViewCancel:(UIAlertView *)alertView
{
    if (_receivedAlert == alertView)
    {
        _strWalletUUID = @"";
        _strTxID = @"";
        _receivedAlert = nil;
    }
}

- (void)sendSupportEmail
{
    // if mail is available
    if ([MFMailComposeViewController canSendMail])
    {
        MFMailComposeViewController *mailComposer = [[MFMailComposeViewController alloc] init];
        [mailComposer setToRecipients:[NSArray arrayWithObjects:[Theme Singleton].SendSupportEmail]];
        NSString *subject = [NSString stringWithFormat:[Theme Singleton].AirbitzFeedback];
        [mailComposer setSubject:NSLocalizedString(subject, nil)];
        mailComposer.mailComposeDelegate = self;
        [self presentViewController:mailComposer animated:YES completion:nil];
    }
    else
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil
                                                        message:[Theme Singleton].CantSendemailText
                                                       delegate:nil
                                              cancelButtonTitle:[Theme Singleton].OkCancelButtonTitle
                                              otherButtonTitles:nil];
        [alert show];
    }
}

#pragma mark - Mail Compose Delegate Methods

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    NSString *strTitle = [Theme Singleton].AirbitzCheckUserReview;
    NSString *strMsg = nil;
    
    switch (result)
    {
        case MFMailComposeResultCancelled:
            strMsg = [Theme Singleton].EmailCancelledText;
            break;
            
        case MFMailComposeResultSaved:
            strMsg = [Theme Singleton].EmailSavedToLaterText;
            break;
            
        case MFMailComposeResultSent:
            strMsg = [Theme Singleton].EmailSentText;
            break;
            
        case MFMailComposeResultFailed:
        {
            strTitle =[Theme Singleton].ErrorSendingEmailText;
            strMsg = [error localizedDescription];
            break;
        }
        default:
            break;
    }
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:strTitle
                                                    message:strMsg
                                                   delegate:nil
                                          cancelButtonTitle:[Theme Singleton].OkCancelButtonTitle
                                          otherButtonTitles:nil];
    [alert show];
    
    [[controller presentingViewController] dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Custom Notification Handlers

- (void)notifyRemotePasswordChange:(NSArray *)params
{
    if (_passwordChangeAlert == nil && [User isLoggedIn])
    {
        [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
        [[User Singleton] clear];
        [self resetViews:nil];
        _passwordChangeAlert = [[UIAlertView alloc]
                                initWithTitle:[Theme Singleton].PasswordChangeText
                                message:[Theme Singleton].PasswordChangeAlertMessage
                                delegate:self
                    cancelButtonTitle:nil
                    otherButtonTitles:[Theme Singleton].OkCancelButtonTitle];
        [_passwordChangeAlert show];
        [[UIApplication sharedApplication] endIgnoringInteractionEvents];
    }
}

- (void)notifyOtpRequired:(NSArray *)params
{
    if (_otpRequiredAlert == nil) {
        _otpRequiredAlert = [[UIAlertView alloc]
                                initWithTitle:[Theme Singleton].TwoFactorAuthenticationText
                                message:[Theme Singleton].TwoFactorAuthenticationMessage
                                delegate:self
                                cancelButtonTitle:[Theme Singleton].RemindMeLaterText
                                otherButtonTitles:[Theme Singleton].EnableText, nil];
        [_otpRequiredAlert show];
    }
}

- (void)notifyOtpSkew:(NSArray *)params
{
    if (_otpSkewAlert == nil) {
        _otpSkewAlert = [[UIAlertView alloc]
            initWithTitle:[Theme Singleton].TwoFactorsInvalidText
            message:[Theme Singleton].TwoFactorsInvalidMessage
            delegate:self
            cancelButtonTitle:[Theme Singleton].OkCancelButtonTitle
            otherButtonTitles:nil, nil];
        [_otpSkewAlert show];
    }
}

// called when the stats have been updated
- (void)transactionDetailsExit:(NSNotification *)notification
{
    // if the wallet tab is not already open, bring it up with this wallet
    if (APP_MODE_WALLETS != _appMode)
    {
        NSDictionary *dictData = [notification userInfo];
        _strWalletUUID = [dictData objectForKey:KEY_TX_DETAILS_EXITED_WALLET_UUID];
        [CoreBridge makeCurrentWalletWithUUID:_strWalletUUID];

//        [_transactionsViewController resetViews];
        self.tabBar.selectedItem = self.tabBar.items[APP_MODE_WALLETS];
        _appMode = APP_MODE_WALLETS;
        [self launchViewControllerBasedOnAppMode];
    }
}

- (void)launchSend:(NSNotification *)notification
{
    if (APP_MODE_SEND != _appMode)
    {
        NSDictionary *dictData = [notification userInfo];
        _strWalletUUID = [dictData objectForKey:KEY_TX_DETAILS_EXITED_WALLET_UUID];
        [_sendViewController resetViews];
        self.tabBar.selectedItem = self.tabBar.items[APP_MODE_SEND];
        _appMode = APP_MODE_SEND;
        [self launchViewControllerBasedOnAppMode];
    }
}

- (void)launchRequest:(NSNotification *)notification
{
    if (APP_MODE_REQUEST != _appMode)
    {
        NSDictionary *dictData = [notification userInfo];
        _strWalletUUID = [dictData objectForKey:KEY_TX_DETAILS_EXITED_WALLET_UUID];
        [_requestViewController resetViews];
        self.tabBar.selectedItem = self.tabBar.items[APP_MODE_REQUEST];
        _appMode = APP_MODE_REQUEST;
        [self launchViewControllerBasedOnAppMode];

    }
}

- (void)switchToSettingsView:(UIViewController *)controller
{
    [MainViewController animateSwapViewControllers:_settingsViewController out:_selectedViewController];
    self.tabBar.selectedItem = self.tabBar.items[APP_MODE_MORE];
    _appMode = APP_MODE_MORE;
}

- (void)launchChangePassword
{
    [self switchToSettingsView:_settingsViewController];
    [_settingsViewController resetViews];
    [_settingsViewController bringUpSignUpViewInMode:SignUpMode_ChangePassword];
}

- (void)launchRecoveryQuestions:(NSNotification *)notification
{
    [self switchToSettingsView:_settingsViewController];
    [_settingsViewController resetViews];
    [_settingsViewController bringUpRecoveryQuestionsView];
}

- (void)launchBuySell:(NSString *)country provider:(NSString *)provider
{
    if ([_buySellViewController launchPluginByCountry:country provider:provider]) {
        [self switchToSettingsView:_buySellViewController];
    } else {
        // Notify user no match!
    }
}

- (void)launchTwoFactorScan
{
    _tfaScanViewController = (TwoFactorScanViewController *)[Util animateIn:@"TwoFactorScanViewController" storyboard:@"Settings" parentController:self];
    _tfaScanViewController.delegate = self;
    _tfaScanViewController.bStoreSecret = YES;
    _tfaScanViewController.bTestSecret = YES;
}

- (void)twoFactorScanViewControllerDone:(TwoFactorScanViewController *)controller withBackButton:(BOOL)bBack
{
    [Util animateOut:controller parentController:self complete:^(void) {
        _tfaScanViewController = nil;
    }];
}

- (void)handleBitcoinUri:(NSNotification *)notification
{
    NSDictionary *dictData = [notification userInfo];
    NSURL *uri = [dictData objectForKey:KEY_URL];
    [self processBitcoinURI:uri];
}

- (void)processBitcoinURI:(NSURL *)uri
{
    if ([uri.scheme isEqualToString:@"airbitz"] && [uri.host isEqualToString:@"plugin"]) {
        NSArray *cs = [uri.path pathComponents];
        if ([cs count] == 3) {
            [self launchBuySell:cs[2] provider:cs[1]];
        }
    } else if ([uri.scheme isEqualToString:@"bitcoin"] || [uri.scheme isEqualToString:@"airbitz"]) {
        if ([User isLoggedIn]) {
            self.tabBar.selectedItem = self.tabBar.items[APP_MODE_SEND];
            _appMode = APP_MODE_SEND;
            [self launchViewControllerBasedOnAppMode];

            [_sendViewController resetViews];
            _sendViewController.addressTextField.text = [uri absoluteString];
            [_sendViewController processURI];
        } else {
            _uri = uri;
        }
    } else if ([uri.scheme isEqualToString:@"bitcoin-ret"]  || [uri.scheme isEqualToString:@"airbitz-ret"]
               || [uri.host isEqualToString:@"x-callback-url"]) {
        if ([User isLoggedIn]) {
            UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"Main_iPhone" bundle: nil];
            _addressRequestController = [mainStoryboard instantiateViewControllerWithIdentifier:@"AddressRequestController"];
            _addressRequestController.url = uri;
            _addressRequestController.delegate = self;
            [Util animateController:_addressRequestController parentController:self];
            [MainViewController showTabBarAnimated:YES];
            [MainViewController showNavBarAnimated:YES];

            _uri = nil;
        } else {
            _uri = uri;
        }
    }
}

-(void)AddressRequestControllerDone:(AddressRequestController *)vc
{
    [Util animateOut:_addressRequestController parentController:self complete:^(void) {
        _addressRequestController = nil;
    }];
    _uri = nil;
    [MainViewController showTabBarAnimated:NO];
    [MainViewController showNavBarAnimated:NO];

}

- (void)loggedOffRedirect:(NSNotification *)notification
{
    [slideoutView showSlideout:NO withAnimation:NO];

    self.tabBar.selectedItem = self.tabBar.items[APP_MODE_DIRECTORY];
    self.tabBar.selectedItem = self.tabBar.items[APP_MODE_WALLETS];
    _appMode = APP_MODE_WALLETS;
    self.tabBar.selectedItem = self.tabBar.items[_appMode];
    [self resetViews:notification];
    [MainViewController hideTabBarAnimated:NO];
    [MainViewController hideNavBarAnimated:NO];

}

- (void)resetViews:(NSNotification *)notification
{
    // Hide the keyboard
    [self.view endEditing:NO];

    // Force the tabs to redraw the selected view
    if (_selectedViewController != nil)
    {
        [_selectedViewController.view removeFromSuperview];
        _selectedViewController = nil;
    }
    [self launchViewControllerBasedOnAppMode];
}

#pragma mark infoView Delegates

- (void)InfoViewFinished:(InfoView *)infoView
{
    [_notificationInfoView removeFromSuperview];
    _notificationInfoView = nil;
    [self displayNextNotification];
}

#pragma mark slideoutView Delegates

- (void)slideoutViewClosed:(SlideoutView *)slideoutView
{
    
}

- (void)slideoutAccount
{
    NSLog(@"MainViewController.slideoutAccount");
}

- (void)slideoutSettings
{
    [slideoutView showSlideout:NO];
    if (_selectedViewController != _settingsViewController)
    {
        if ([User isLoggedIn] || (DIRECTORY_ONLY == 1)) {
            [MainViewController animateSwapViewControllers:_settingsViewController out:_selectedViewController];
            self.tabBar.selectedItem = self.tabBar.items[APP_MODE_MORE];
            [slideoutView showSlideout:NO];
        }
    }

}

- (void)slideoutLogout
{
    [slideoutView showSlideout:NO withAnimation:NO];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [[User Singleton] clear];
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            [self SettingsViewControllerDone:nil];
            [self launchViewControllerBasedOnAppMode];
        });
    });
}

- (void)slideoutBuySell
{
    [_selectedViewController.view removeFromSuperview];
    _selectedViewController = _buySellViewController;
    [Util insertSubviewControllerWithConstraints:self.view child:_selectedViewController belowSubView:self.tabBar];
//    [self.view insertSubview:_selectedViewController.view belowSubview:self.tabBar];
    self.tabBar.selectedItem = self.tabBar.items[APP_MODE_MORE];
    [slideoutView showSlideout:NO];
}

- (void)slideoutImport
{
    if (_selectedViewController != _importViewController)
    {
        if ([User isLoggedIn] || (DIRECTORY_ONLY == 1)) {
            _importViewController.bImportMode = YES;
            [MainViewController animateSwapViewControllers:_importViewController out:_selectedViewController];
            self.tabBar.selectedItem = self.tabBar.items[APP_MODE_MORE];
            [slideoutView showSlideout:NO];
        }
    }
}

#pragma mark - Slideout Methods

- (void)installRightToLeftSwipeDetection
{
    UIScreenEdgePanGestureRecognizer *gesture = [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [gesture setEdges:UIRectEdgeRight];
    [self.view addGestureRecognizer:gesture];
}

// used by the guesture recognizer to ignore exit
- (BOOL)haveSubViewsShowing
{
    return NO;
}

- (void)handlePan:(UIPanGestureRecognizer *) recognizer {
    if ([User isLoggedIn]) {
        if (![slideoutView isOpen]) {
            [slideoutView handleRecognizer:recognizer fromBlock:NO];
        }
    }
}

#pragma mark - SignUpViewControllerDelegates

-(void)signupViewControllerDidFinish:(SignUpViewController *)controller withBackButton:(BOOL)bBack
{
    [controller.view removeFromSuperview];
    _signUpController = nil;
}

#pragma mark - UITabBarDelegate

- (void)tabBar:(UITabBar *)tabBar didSelectItem:(UITabBarItem *)item
{
    tAppMode newAppMode;

    if (item == [self.tabBar.items objectAtIndex:APP_MODE_DIRECTORY])
    {
        newAppMode = APP_MODE_DIRECTORY;
    }
    else if (item == [self.tabBar.items objectAtIndex:APP_MODE_REQUEST])
    {
        newAppMode = APP_MODE_REQUEST;
    }
    else if (item == [self.tabBar.items objectAtIndex:APP_MODE_SEND])
    {
        newAppMode = APP_MODE_SEND;
    }
    else if (item == [self.tabBar.items objectAtIndex:APP_MODE_WALLETS])
    {
        newAppMode = APP_MODE_WALLETS;
    }
    else if (item == [self.tabBar.items objectAtIndex:APP_MODE_MORE])
    {
        newAppMode = APP_MODE_MORE;
    }

    if (newAppMode == _appMode && (newAppMode != APP_MODE_MORE))
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_TAB_BAR_BUTTON_RESELECT object:self userInfo:nil];
    }
    else
    {
        _appMode = newAppMode;
        [self launchViewControllerBasedOnAppMode];
    }


}

+ (CGFloat)getFooterHeight
{
    return singleton.tabBar.frame.size.height;
}

+ (CGFloat)getHeaderHeight
{
    return singleton.navBar.frame.size.height;
}

+ (CGFloat)getWidth
{
    return singleton.navBar.frame.size.width;
}

+ (CGFloat)getHeight
{
    return singleton.view.frame.size.height;
}

+(CGFloat)getLargestDimension
{
    CGRect frame = singleton.view.frame;
    return frame.size.height > frame.size.width ? frame.size.height : frame.size.width;
}

+(CGFloat)getSmallestDimension
{
    CGRect frame = singleton.view.frame;
    return frame.size.height < frame.size.width ? frame.size.height : frame.size.width;
}

+(CGFloat)getSafeOffscreenOffset:(CGFloat) widthOrHeight
{
    return widthOrHeight + [MainViewController getLargestDimension] - [MainViewController getSmallestDimension];
}


+ (void)animateSlideIn:(AirbitzViewController *)viewController
{
    viewController.leftConstraint.constant = [MainViewController getLargestDimension];
    [viewController.view layoutIfNeeded];

    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
    [UIView animateWithDuration:0.35
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^ {
                         viewController.leftConstraint.constant = 0;
                         [viewController.view layoutIfNeeded];
                     }
                     completion:^(BOOL finished) {
                         [[UIApplication sharedApplication] endIgnoringInteractionEvents];
//                         cb();
                     }];
}



+ (void)animateFadeIn:(UIView *)view
{
    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
    [view setAlpha:0.0];
    [UIView animateWithDuration:0.35
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^ {
                         [view setAlpha:1.0];
                     }
                     completion:^(BOOL finished) {
                         [[UIApplication sharedApplication] endIgnoringInteractionEvents];
//                         cb();
                     }];
}

+ (void)animateFadeOut:(UIView *)view
{
    [MainViewController animateFadeOut:view remove:NO];
}

+ (void)animateFadeOut:(UIView *)view remove:(BOOL)removeFromView
{
    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
    [view setAlpha:1.0];
    [view setOpaque:NO];
    [UIView animateWithDuration:0.35
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^ {
                         [view setAlpha:0.0];
                     }
                     completion:^(BOOL finished) {
                         [[UIApplication sharedApplication] endIgnoringInteractionEvents];
                         if (removeFromView)
                             [view removeFromSuperview];
//                         cb();
                     }];
}

+ (NSArray *)animateSwapViewControllers:(AirbitzViewController *)in out:(AirbitzViewController *)out
{
    NSArray *constraints = [Util insertSubviewControllerWithConstraints:singleton.view child:in belowSubView:singleton.tabBar];

    singleton.selectedViewController = in;

    [out.view setAlpha:1.0];
    [in.view setAlpha:0.0];
    singleton.blurViewLeft.constant = 0;
    [singleton.view layoutIfNeeded];

    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
    [UIView animateWithDuration:0.20
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^
                     {
                         in.leftConstraint.constant = 0;
                         singleton.blurViewLeft.constant = 0;
                         [singleton.blurViewContainer setAlpha:1];
                         [out.view setAlpha:0.0];
                         [in.view setAlpha:1.0];

                         [singleton.view layoutIfNeeded];
                     }
                     completion:^(BOOL finished)
                     {
                         [out.view removeFromSuperview];
                         [[UIApplication sharedApplication] endIgnoringInteractionEvents];
                     }];
    return constraints;
}

+ (void)animateView:(AirbitzViewController *)viewController withBlur:(BOOL)withBlur
{
    [MainViewController animateView:viewController withBlur:withBlur animate:YES];
}

+ (void)animateView:(AirbitzViewController *)viewController withBlur:(BOOL)withBlur animate:(BOOL)animated
{


    [Util insertSubviewControllerWithConstraints:singleton.view child:viewController belowSubView:singleton.tabBar];

    viewController.leftConstraint.constant = viewController.view.frame.size.width;
    [singleton.view layoutIfNeeded];

    if (withBlur)
    {
        singleton.blurViewLeft.constant = [MainViewController getLargestDimension];
        [singleton.view layoutIfNeeded];
    }

    if (animated)
    {
        [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
        [UIView animateWithDuration:0.35
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^
                         {
                             viewController.leftConstraint.constant = 0;
                             if (withBlur)
                             {
                                 singleton.blurViewLeft.constant = 0;
                             }
                             [singleton.view layoutIfNeeded];
                         }
                         completion:^(BOOL finished)
                         {
                             [[UIApplication sharedApplication] endIgnoringInteractionEvents];
                         }];
    }
//    else
//    {
//        viewController.leftConstraint.constant = 0;
//        [singleton.view layoutIfNeeded];
//    }
}

+ (void)animateOut:(AirbitzViewController *)viewController withBlur:(BOOL)withBlur complete:(void(^)(void))cb
{
    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];

    if (withBlur)
        singleton.blurViewLeft.constant = 0;

    [UIView animateWithDuration:0.35
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^ {
                         viewController.leftConstraint.constant = [MainViewController getLargestDimension];
                         if (withBlur)
                             singleton.blurViewLeft.constant = [MainViewController getLargestDimension];
                         [singleton.view layoutIfNeeded];

                     }
                     completion:^(BOOL finished) {
                         [viewController.view removeFromSuperview];
                         [[UIApplication sharedApplication] endIgnoringInteractionEvents];
                         if(cb != nil)
                             cb();
                     }];
}

- (void)showSelectedViewController
{
    if (_selectedViewController == nil)
    {
        NSLog(@"_selectedViewController == nil");
    }
    else if (_selectedViewController == _directoryViewController)
    {
        NSLog(@"_selectedViewController == _directoryViewController");
    }
    else if (_selectedViewController == _transactionsViewController)
    {
        NSLog(@"_selectedViewController == _transactionsViewController");
    }
    else if (_selectedViewController == _loginViewController)
    {
        NSLog(@"_selectedViewController == _loginViewController");
    }
    else if (_selectedViewController == _sendViewController)
    {
        NSLog(@"_selectedViewController == _sendViewController");
    }
    else if (_selectedViewController == _requestViewController)
    {
        NSLog(@"_selectedViewController == _requestViewController");
    }
}

#pragma RequestViewController delegate
-(void)pleaseRestartRequestViewBecauseAppleSucksWithPresentController
{
    NSLog(@"pleaseRestartRequestViewBecauseAppleSucksWithPresentController called");

    NSString *requestID = _requestViewController.requestID;
    AirbitzViewController *fakeViewController;
    UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"Main_iPhone" bundle:nil];
    fakeViewController = [mainStoryboard instantiateViewControllerWithIdentifier:@"AirbitzViewController"];

    [MainViewController animateSwapViewControllers:fakeViewController out:_requestViewController];
    _requestViewController = nil;
    _requestViewController = [mainStoryboard instantiateViewControllerWithIdentifier:@"RequestViewController"];

    _requestViewController.delegate = self;
    _requestViewController.requestID = requestID;
    _requestViewController.bDoFinalizeTx = YES;
    [MainViewController animateSwapViewControllers:_requestViewController out:fakeViewController];
}


#pragma SendViewController delegate
-(void)pleaseRestartSendViewBecauseAppleSucksWithPresentController
{
    SendViewController *tempSend;
    NSLog(@"pleaseRestartSendViewBecauseAppleSucksWithPresentController called");
    NSAssert((_selectedViewController == _sendViewController) || (_selectedViewController == _importViewController), @"Must be Import or Send View Controllers");
    tempSend = _selectedViewController;
    ZBarSymbolSet *zBarSymbolSet = tempSend.zBarSymbolSet;
    BOOL bImportMode = tempSend.bImportMode;
    tLoopbackState loopbackState = tempSend.loopbackState;
    tempSend = nil;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [NSThread sleepForTimeInterval:0.5f];
        dispatch_async(dispatch_get_main_queue(), ^{
            AirbitzViewController *fakeViewController;
            UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"Main_iPhone" bundle:nil];

            fakeViewController = [mainStoryboard instantiateViewControllerWithIdentifier:@"AirbitzViewController"];

            if (bImportMode)
            {
                NSAssert(_selectedViewController == _importViewController, [Theme Singleton].MustBeImportText);
                [MainViewController animateSwapViewControllers:fakeViewController out:_importViewController];
                _importViewController = nil;
                _importViewController = [mainStoryboard instantiateViewControllerWithIdentifier:@"SendViewController"];

                _importViewController.zBarSymbolSet = zBarSymbolSet;
                _importViewController.bImportMode = bImportMode;
                _importViewController.delegate = self;
                _importViewController.loopbackState = loopbackState;
                [MainViewController animateSwapViewControllers:_importViewController out:fakeViewController];

            }
            else
            {
                NSAssert(_selectedViewController == _sendViewController, [Theme Singleton].MustBeSendText);
                [MainViewController animateSwapViewControllers:fakeViewController out:_sendViewController];
                _sendViewController = nil;
                _sendViewController = [mainStoryboard instantiateViewControllerWithIdentifier:@"SendViewController"];

                _sendViewController.zBarSymbolSet = zBarSymbolSet;
                _sendViewController.bImportMode = bImportMode;
                _sendViewController.delegate = self;
                _sendViewController.loopbackState = loopbackState;
                [MainViewController animateSwapViewControllers:_sendViewController out:fakeViewController];

            }
        });
    });
}


+ (void)fadingAlertHelpPopup:(NSString *)message
{
    [MainViewController fadingAlert:message holdTime:[Theme Singleton].alertHoldTimeHelpPopups];
}

+ (void)fadingAlert:(NSString *)message
{
    [MainViewController fadingAlert:message holdTime:FADING_ALERT_HOLD_TIME_DEFAULT];
}

+ (void)fadingAlert:(NSString *)message holdTime:(CGFloat)holdTime
{
    [FadingAlertView create:singleton.view message:message holdTime:holdTime];
}

+ (void)fadingAlertDismiss
{
    [FadingAlertView dismiss:YES];
}

@end
