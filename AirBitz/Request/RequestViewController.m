//
//  RequestViewController.m
//  AirBitz
//
//  Created by Carson Whitsett on 2/28/14.
//  Copyright (c) 2014 AirBitz. All rights reserved.
//

#import <AddressBookUI/AddressBookUI.h>
#import <MessageUI/MessageUI.h>
#import <MobileCoreServices/UTCoreTypes.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "DDData.h"
#import "RequestViewController.h"
#import "Notifications.h"
#import "Transaction.h"
#import "TxOutput.h"
#import "CalculatorView.h"
#import "ButtonSelectorView2.h"
#import "ABC.h"
#import "User.h"
#import "ShowWalletQRViewController.h"
#import "CoreBridge.h"
#import "Util.h"
#import "ImportWalletViewController.h"
#import "InfoView.h"
#import "LocalSettings.h"
#import "MainViewController.h"
#import "Theme.h"
#import "Contact.h"
#import "TransferService.h"
#import "AudioController.h"
#import "RecipientViewController.h"
#import "DropDownAlertView.h"


#define QR_CODE_TEMP_FILENAME @"qr_request.png"
#define QR_CODE_SIZE          200.0
#define QR_ATTACHMENT_WIDTH 100



#define WALLET_REQUEST_BUTTON_WIDTH  200

#define OPERATION_CLEAR		0
#define OPERATION_BACK		1
#define OPERATION_DONE		2
#define OPERATION_DIVIDE	3
#define OPERATION_EQUAL		4
#define OPERATION_MINUS		5
#define OPERATION_MULTIPLY	6
#define OPERATION_PLUS		7
#define OPERATION_PERCENT	8

typedef enum eAddressPickerType
{
    AddressPickerType_SMS,
    AddressPickerType_EMail
} tAddressPickerType;

static NSTimeInterval		lastPeripheralBLEPowerOffNotificationTime = 0;

@interface RequestViewController () <UITextFieldDelegate, CalculatorViewDelegate, ButtonSelector2Delegate,FadingAlertViewDelegate,CBPeripheralManagerDelegate,
                                     ImportWalletViewControllerDelegate,RecipientViewControllerDelegate>
{
	UITextField                 *_selectedTextField;
	int                         _selectedWalletIndex;
    ImportWalletViewController  *_importWalletViewController;
    tABC_TxDetails              _details;
    CGRect                      topFrame;
    CGRect                      bottomFrame;
    BOOL                        bInitialized;
    CGFloat                     topTextSize;
    CGFloat                     bottomTextSize;
    BOOL                        bWalletListDropped;
    NSString                    *statusString;
    NSString                    *addressString;
    NSString                    *_uriString;
    NSMutableString                    *previousWalletUUID;
    BOOL                        bLastCalculatorState;
    tAddressPickerType          _addressPickerType;



}
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *btcWidth;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *btcHeight;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *fiatTop;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *btcTop;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *fiatWidth;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *fiatHeight;
@property (weak, nonatomic) IBOutlet UILabel            *statusLine1;
@property (weak, nonatomic) IBOutlet UILabel            *statusLine2;
@property (weak, nonatomic) IBOutlet UILabel            *statusLine3;
@property (nonatomic, weak) IBOutlet UIImageView	    *BLE_LogoImageView;
@property (strong, nonatomic) CBPeripheralManager       *peripheralManager;
@property (strong, nonatomic) CBMutableCharacteristic   *bitcoinURICharacteristic;
@property (nonatomic, strong) NSArray                   *arrayContacts;
@property (nonatomic, strong) NSString			        *connectedName;
@property (nonatomic, assign) int64_t                   amountSatoshiRequested;
@property (nonatomic, assign) int64_t                   previousAmountSatoshiRequested;
@property (nonatomic, assign) int64_t                   amountSatoshiReceived;
@property (nonatomic, assign) RequestState              state;

@property (assign) tABC_TxDetails txDetails;
@property (nonatomic, strong) NSString *requestType;
@property (nonatomic, strong) RecipientViewController   *recipientViewController;
@property (weak, nonatomic) IBOutlet UILabel *btcLabel;
@property (weak, nonatomic) IBOutlet UILabel *fiatLabel;
@property (nonatomic, weak) IBOutlet UIImageView    *qrCodeImageView;
@property (weak, nonatomic) IBOutlet UIView         *viewQRCodeFrame;
@property (weak, nonatomic) IBOutlet UISegmentedControl *segmentedControlBTCUSD;
@property (weak, nonatomic) IBOutlet UISegmentedControl *segmentedControlCopyEmailSMS;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *calculatorBottom;
@property (nonatomic, weak) IBOutlet CalculatorView     *keypadView;
@property (nonatomic, weak) IBOutlet UITextField        *currentTopField;
@property (nonatomic, weak) IBOutlet UITextField        *BTC_TextField;
@property (nonatomic, weak) IBOutlet UITextField        *USD_TextField;
@property (nonatomic, weak) IBOutlet ButtonSelectorView2 *buttonSelector; //wallet dropdown
@property (nonatomic, weak) IBOutlet UILabel            *exchangeRateLabel;
@property (nonatomic, weak) IBOutlet UIButton                *refreshButton;
@property (nonatomic, weak) IBOutlet UIActivityIndicatorView *refreshSpinner;

@property (nonatomic, copy)   NSString *strFullName;
@property (nonatomic, copy)   NSString *strPhoneNumber;
@property (nonatomic, copy)   NSString *strEMail;

@end

@implementation RequestViewController
@synthesize segmentedControlBTCUSD;
@synthesize segmentedControlCopyEmailSMS;

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

	self.keypadView.delegate = self;
    self.currentTopField = nil;
    bInitialized = false;
    bWalletListDropped = false;
    previousWalletUUID = nil;

	self.buttonSelector.delegate = self;
    [self.buttonSelector disableButton];

    self.qrCodeImageView.layer.magnificationFilter = kCAFilterNearest;
    self.viewQRCodeFrame.layer.cornerRadius = 8;
    self.viewQRCodeFrame.layer.masksToBounds = YES;
    self.amountSatoshiReceived = 0;
    self.amountSatoshiRequested = 0;
    self.state = kRequest;

    _selectedTextField = self.USD_TextField;
    self.keypadView.calcMode = CALC_MODE_FIAT;

    self.arrayContacts = @[];
    // load all the names from the address book
    [self generateListOfContactNames];
}

-(void)awakeFromNib
{
	
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.previousAmountSatoshiRequested = -1;

    // create a dummy view to replace the keyboard if we are on a 4.5" screen
    UIView *dummyView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];
    [self.segmentedControlBTCUSD setTitle:[User Singleton].denominationLabel forSegmentAtIndex:1];
    _btcLabel.text = [User Singleton].denominationLabel;

    self.BTC_TextField.inputView = dummyView;
    self.USD_TextField.inputView = dummyView;
	self.BTC_TextField.delegate = self;
	self.USD_TextField.delegate = self;

    // if they are on a 4" screen then move the calculator below the bottom of the screen
    if ([LocalSettings controller].bMerchantMode)
    {
        [self changeCalculator:false show:true];
    }
    else
    {
        [self changeCalculator:false show:false];
    }

    [MainViewController changeNavBarOwner:self];

    if (!bInitialized) {
        topFrame = self.USD_TextField.frame;
        bottomFrame = self.BTC_TextField.frame;
        topTextSize = self.USD_TextField.font.pointSize;
        bottomTextSize = self.BTC_TextField.font.pointSize;
        bInitialized = true;
    }
    [self changeTopField:true animate:false];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateViews:) name:NOTIFICATION_WALLETS_CHANGED object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(exchangeRateUpdate:) name:NOTIFICATION_EXCHANGE_RATE_CHANGE object:nil];

    if ([[User Singleton] offerRequestHelp]) {
        [MainViewController fadingAlertHelpPopup:[Theme Singleton].PresentQRcodeText];
    }

    [self updateViews:nil];

    if (_bDoFinalizeTx)
    {
        [self finalizeRequest];
        _bDoFinalizeTx = NO;
    }

}

- (void)updateViews:(NSNotification *)notification
{
    if ([CoreBridge Singleton].arrayWallets && [CoreBridge Singleton].currentWallet)
    {
        self.buttonSelector.arrayItemsToSelect = [CoreBridge Singleton].arrayWalletNames;
        [self.buttonSelector.button setTitle:[CoreBridge Singleton].currentWallet.strName forState:UIControlStateNormal];
        self.buttonSelector.selectedItemIndex = [CoreBridge Singleton].currentWalletID;

        NSString *walletName = [NSString stringWithFormat:@"To: %@ ↓", [CoreBridge Singleton].currentWallet.strName];
        [MainViewController changeNavBarTitleWithButton:self title:walletName action:@selector(didTapTitle:) fromObject:self];

        self.keypadView.currencyNum = [CoreBridge Singleton].currentWallet.currencyNum;

        [self updateTextFieldContents:YES];

        if (!([[CoreBridge Singleton].arrayWallets containsObject:[CoreBridge Singleton].currentWallet]))
        {
            [FadingAlertView create:self.view
                            message:[Theme Singleton].walletHasBeenArchivedText
                           holdTime:FADING_ALERT_HOLD_TIME_FOREVER];
        }
    }
    [MainViewController changeNavBar:self title:[Theme Singleton].backButtonText side:NAV_BAR_LEFT button:true enable:false action:@selector(Back:) fromObject:self];
    [MainViewController changeNavBar:self title:[Theme Singleton].helpButtonText side:NAV_BAR_RIGHT button:true enable:true action:@selector(info:) fromObject:self];

}

    -(void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];

    [self setFirstResponder];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    if(self.peripheralManager.isAdvertising) {
        NSLog(@"Removing all BLE services and stopping advertising");
        [self.peripheralManager removeAllServices];
        [self.peripheralManager stopAdvertising];
        _peripheralManager = nil;
    }
    [CoreBridge prioritizeAddress:nil inWallet:[CoreBridge Singleton].currentWallet.strUUID];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (BOOL)showingQRCode:(NSString *)walletUUID withTx:(NSString *)txId
{
//    if (_qrViewController == nil || _qrViewController.addressString == nil)
    if (addressString == nil)
    {
        return NO;
    }
    Transaction *transaction = [CoreBridge getTransaction:walletUUID withTx:txId];
    for (TxOutput *output in transaction.outputs)
    {
        if (!output.bInput 
            && [addressString isEqualToString:output.strAddress])
        {
            return YES;
        }
    }
    return NO;
}

- (void)changeCalculator:(BOOL)animate show:(BOOL)bShow
{
    if (animate) {
        [UIView animateWithDuration:0.35
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^
                         {
                             [self upCalculator:bShow];
                             [self.view layoutIfNeeded];
                         }
                         completion:^(BOOL finished)
                         {
                         }];

    }
    else
    {
        [self upCalculator:bShow];
    }
    bLastCalculatorState = bShow;


}

- (void)upCalculator:(BOOL)up
{
    CGFloat destination;
    if (up)
    {
        destination = [MainViewController getFooterHeight];
        self.keypadView.alpha = 1.0;
        self.keypadView.hidden = false;
    }
    else
    {
        destination = -[MainViewController getLargestDimension];
        self.keypadView.alpha = 0.0;
        self.keypadView.hidden = true;
    }

    self.calculatorBottom.constant = destination;

}

- (void)resetViews
{
    if (_importWalletViewController)
    {
        [_importWalletViewController.view removeFromSuperview];
        _importWalletViewController = nil;
    }
    if (_recipientViewController)
    {
        [_recipientViewController.view removeFromSuperview];
        _recipientViewController = nil;
    }

    self.BTC_TextField.text = @"";
	self.USD_TextField.text = @"";
    self.amountSatoshiReceived = 0;
    self.amountSatoshiRequested = 0;
    self.state = kRequest;
}


#pragma mark - Action Methods

- (IBAction)Refresh
{
    if ([CoreBridge Singleton].arrayWallets && [CoreBridge Singleton].currentWallet)
    {
        _refreshButton.hidden = YES;
        _refreshSpinner.hidden = NO;
        [CoreBridge refreshWallet:[CoreBridge Singleton].currentWallet.strUUID refreshData:NO notify:^{
            [NSThread sleepForTimeInterval:2.0f];
            _refreshSpinner.hidden = YES;
            _refreshButton.hidden = NO;
        }];
    }
}

- (IBAction)didTouchQRCode:(id)sender
{
    if (bLastCalculatorState)
    {
        [self.BTC_TextField resignFirstResponder];
        [self.USD_TextField resignFirstResponder];

        [self changeCalculator:YES show:NO];
    }
    else
    {
        [self changeCalculator:YES show:YES];
        [self.currentTopField becomeFirstResponder];
    }
}

- (IBAction)segmentedControlBTCUSDAction:(id)sender
{
    if(segmentedControlBTCUSD.selectedSegmentIndex == 0)            // Checking which segment is selected using the segment index value
    {
        [self changeTopField:true animate:true];
    }
    else if(segmentedControlBTCUSD.selectedSegmentIndex == 1)
    {
        [self changeTopField:false animate:true];
    }
}

- (IBAction)segmentedControlCopyEmailSMSAction:(id)sender
{
    if(segmentedControlCopyEmailSMS.selectedSegmentIndex == 0)
    {
        UIPasteboard *pb = [UIPasteboard generalPasteboard];
        [pb setString:addressString];

        [MainViewController fadingAlert:[Theme Singleton].CopiedToTheClipboard];
    }
    else if(segmentedControlCopyEmailSMS.selectedSegmentIndex == 1)
    {
        // Do Email
        self.strFullName = @"";
        self.strEMail = @"";

        [self launchRecipientWithMode:RecipientMode_Email];
    }
    else if(segmentedControlCopyEmailSMS.selectedSegmentIndex == 2)
    {
        // Do SMS
        self.strPhoneNumber = @"";
        self.strFullName = @"";

        [self launchRecipientWithMode:RecipientMode_SMS];
    }
}

- (IBAction)info:(id)sender
{
	[self.view endEditing:YES];
    [InfoView CreateWithHTML:@"infoRequest" forView:self.view];
}

- (IBAction)ImportWallet
{
	[self.view endEditing:YES];
    [self bringUpImportWalletView];
}

//
// Implement the state machine of the QR code screen based on Merchant Mode, amount received, amount requested. All of which could change at any time.
// Returns new state

- (RequestState)updateQRCode:(SInt64)incomingSatoshi
{
    NSLog(@"ENTER updateQRCode");

    BOOL bChangeRequest = false;

    BOOL mm = [LocalSettings controller].bMerchantMode;
    self.amountSatoshiReceived += incomingSatoshi;
    self.amountSatoshiRequested = [CoreBridge denominationToSatoshi:self.BTC_TextField.text];
    SInt64 remaining = self.amountSatoshiRequested;

    if (self.previousAmountSatoshiRequested != self.amountSatoshiRequested)
    {
        self.previousAmountSatoshiRequested = self.amountSatoshiRequested;
        bChangeRequest = true;
    }
    if (previousWalletUUID != [CoreBridge Singleton].currentWallet.strUUID)
    {
        previousWalletUUID = [CoreBridge Singleton].currentWallet.strUUID;
        bChangeRequest = true;
    }
    if (incomingSatoshi)
    {
        bChangeRequest = true;
    }

    if (!bChangeRequest) // Nothing's changed so save some work. Especially BLE start/stop
        return self.state;

    if (self.amountSatoshiRequested == 0)
    {
        if (mm)
        {
            self.state = kDonation;
        }
        else
        {
            if (self.amountSatoshiReceived == 0)
                self.state = kRequest;
            else
                self.state = kDone;

        }
    }
    else
    {
        if (self.amountSatoshiReceived == 0)
        {
            self.state = kRequest;
        }
        else if (self.amountSatoshiReceived < self.amountSatoshiRequested)
        {
            self.state = kPartial;
        }
        else // if (self.amountSatoshiReceived >= self.amountSatoshiRequested)
        {
            self.state = kDone;
        }
    }

    if (self.state == kDone)
    {
        self.amountSatoshiReceived = 0;
        self.amountSatoshiRequested = 0;
    }

    //
    // Done with validation. Now to change the GUI
    //

    NSString *strName = @"";
    NSString *strCategory = @"";
    NSString *strNotes = @"";

    // get the QR Code image
    NSMutableString *strRequestID = [[NSMutableString alloc] init];
    NSMutableString *strRequestAddress = [[NSMutableString alloc] init];
    NSMutableString *strRequestURI = [[NSMutableString alloc] init];

    self.statusLine1.text = @"";
    self.statusLine2.text = @"";
    self.statusLine3.text = @"";

    switch (self.state) {
        case kRequest:
        case kDone:
        {
            self.statusLine2.text = [Theme Singleton].WaitingForPaymentText;
            break;
        }
        case kPartial:
        {
            remaining = self.amountSatoshiRequested - self.amountSatoshiReceived;
            NSString *string = [Theme Singleton].RequestedText;
            self.statusLine1.text = [NSString stringWithFormat:@"%@ %@",[CoreBridge formatSatoshi:self.amountSatoshiRequested],string];

            string = [Theme Singleton].RemainingText;
            self.statusLine2.text = [NSString stringWithFormat:@"%@ %@",[CoreBridge formatSatoshi:remaining],string];
            break;
        }
        case kDonation:
        {

            if (self.amountSatoshiReceived > 0)
            {
                NSString *string =[Theme Singleton].ReceivedText;
                self.statusLine2.text = [NSString stringWithFormat:@"%@ %@",[CoreBridge formatSatoshi:self.amountSatoshiReceived],string];
            }
            else
            {
                self.statusLine2.text = [Theme Singleton].WaitingForPaymentText;
            }
            break;
        }
    }

    //
    // Change the QR code. This is a slow call so put it in a queue
    //
    [CoreBridge postToWalletsQueue:^(void) {

        UIImage *qrImage = [self createRequestQRImageFor:strName withNotes:strNotes withCategory:strCategory
                                        storeRequestIDIn:strRequestID storeRequestURI:strRequestURI storeRequestAddressIn:strRequestAddress
                                            scaleAndSave:NO withAmount:remaining];


        addressString = strRequestAddress;
        _uriString = strRequestURI;

        dispatch_async(dispatch_get_main_queue(),^{
            [CoreBridge prioritizeAddress:addressString inWallet:[CoreBridge Singleton].currentWallet.strUUID];
            self.statusLine3.text = addressString;
            self.qrCodeImageView.image = qrImage;
        });
    }];

    if (incomingSatoshi)
    {
        [self showPaymentPopup:self.state amount:incomingSatoshi];
    }

    if([LocalSettings controller].bDisableBLE)
    {
        self.BLE_LogoImageView.hidden = YES;
    }

    //
    // If request has changed or is brand new, startup the BLE manager and start broadcasting
    //
    [CoreBridge postToWalletsQueue:^(void) {
        if(self.peripheralManager.isAdvertising) {
            NSLog(@"Removing all BLE services and stopping advertising");
            [self.peripheralManager removeAllServices];
            [self.peripheralManager stopAdvertising];
            _peripheralManager = nil;
        }

        if(![LocalSettings controller].bDisableBLE)
        {
            // Start up the CBPeripheralManager.  Warn if settings BLE is on but device BLE is off (but only once every 24 hours)
            NSTimeInterval curTime = CACurrentMediaTime();
            if((curTime - lastPeripheralBLEPowerOffNotificationTime) > 86400.0) //24 hours
            {
                _peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil options:@{CBPeripheralManagerOptionShowPowerAlertKey: @(YES)}];
            }
            else
            {
                _peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil options:@{CBPeripheralManagerOptionShowPowerAlertKey: @(NO)}];
            }
            lastPeripheralBLEPowerOffNotificationTime = curTime;
        }
    }];

    return self.state;
    NSLog(@"EXIT updateQRCode");

}

#pragma mark - Notification Handlers

- (void)exchangeRateUpdate: (NSNotification *)notification
{
    NSLog(@"Updating exchangeRateUpdate");
	[self updateTextFieldContents:NO];
}

#pragma mark - Misc Methods

- (void)setFirstResponder
{
    if ([LocalSettings controller].bMerchantMode)
    {
        // make the USD the first responder
        [self.USD_TextField becomeFirstResponder];
    }
    else
    {
        [self.BTC_TextField resignFirstResponder];
        [self.USD_TextField resignFirstResponder];
    }
}

- (void)changeTopField:(BOOL)bFiat animate:(BOOL)animate
{
    if (animate) {
        [UIView animateWithDuration:0.35
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^
                         {
                             [self changeTopFieldRaw:bFiat];
                             [self.view layoutIfNeeded];
                         }
                         completion:^(BOOL finished)
                         {
                         }];

    }
    else
    {
        [self changeTopFieldRaw:bFiat];
    }
}

- (void)changeTopFieldRaw:(BOOL)bFiat
{

    UITextField *bottomField;
    UILabel *bottomLabel;
    UILabel *topLabel;
    CGRect fiatFrame, btcFrame;
    Wallet *wallet = [self getCurrentWallet];

    if (bFiat)
    {
        if (self.currentTopField == self.USD_TextField)
        {
            return;
        }
        else
        {
            self.currentTopField = self.USD_TextField;
            bottomField = self.BTC_TextField;

            fiatFrame = topFrame;
            btcFrame = bottomFrame;
            topLabel = _fiatLabel;
            bottomLabel = _btcLabel;
            segmentedControlBTCUSD.selectedSegmentIndex = 0;
            


        }
    }
    else
    {
        if (self.currentTopField == self.BTC_TextField)
        {
            return;
        }
        else
        {
            self.currentTopField = self.BTC_TextField;
            bottomField = self.USD_TextField;

            fiatFrame = bottomFrame;
            btcFrame = topFrame;
            topLabel = _btcLabel;
            bottomLabel = _fiatLabel;
            segmentedControlBTCUSD.selectedSegmentIndex = 1;

        }
    }

    self.fiatTop.constant = fiatFrame.origin.y;
    self.fiatWidth.constant = fiatFrame.size.width;
    self.fiatHeight.constant = fiatFrame.size.height;

    self.btcTop.constant = btcFrame.origin.y;
    self.btcWidth.constant = btcFrame.size.width;
    self.btcHeight.constant = btcFrame.size.height;

    UIColor *color = [UIColor lightGrayColor];
    NSString *string = NSLocalizedString(@"Enter Amount (optional)", "Placeholder text for Receive screen amount");
    self.currentTopField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:string attributes:@{NSForegroundColorAttributeName: [Theme Singleton].colorRequestTopTextFieldPlaceholder}];

    [topLabel setFont:[UIFont fontWithName:@"Lato-Regular" size:topTextSize]];
    [topLabel setTextColor:[Theme Singleton].colorRequestTopTextField];
    [self.currentTopField setFont:[UIFont fontWithName:@"Lato-Regular" size:topTextSize]];
    [self.currentTopField setTextColor:[Theme Singleton].colorRequestTopTextField];
    [self.currentTopField setTintColor:[UIColor lightGrayColor]];
    [self.currentTopField setEnabled:true];
    if (bLastCalculatorState)
    {
        [self.currentTopField becomeFirstResponder];
    }


    self.keypadView.textField = self.currentTopField;

    bottomField.placeholder = @"";
    [bottomLabel setFont:[UIFont fontWithName:@"Lato-Regular" size:bottomTextSize]];
    [bottomLabel setTextColor:[Theme Singleton].colorRequestBottomTextField];
    [bottomField setFont:[UIFont fontWithName:@"Lato-Regular" size:bottomTextSize]];
    [bottomField setTextColor:[Theme Singleton].colorRequestBottomTextField];
    [bottomField setTintColor:[UIColor lightGrayColor]];
    [bottomField setEnabled:false];

}

- (const char *)createReceiveRequestFor:(NSString *)strName withNotes:(NSString *)strNotes 
    withCategory:(NSString *)strCategory withAmount:(SInt64)amountSatoshi
{
	//creates a receive request.  Returns a requestID.  Caller must free this ID when done with it
	tABC_CC result;
	double currency;
	tABC_Error error;

    Wallet *wallet = [self getCurrentWallet];

	//first need to create a transaction details struct
    memset(&_details, 0, sizeof(tABC_TxDetails));

    _details.amountSatoshi = amountSatoshi;

	//the true fee values will be set by the core
	_details.amountFeesAirbitzSatoshi = 0;
	_details.amountFeesMinersSatoshi = 0;
	
	result = ABC_SatoshiToCurrency([[User Singleton].name UTF8String], [[User Singleton].password UTF8String],
                                   _details.amountSatoshi, &currency, wallet.currencyNum, &error);
	if (result == ABC_CC_Ok)
	{
		_details.amountCurrency = currency;
	}

    _details.szName = (char *) [strName UTF8String];
    _details.szNotes = (char *) [strNotes UTF8String];
	_details.szCategory = (char *) [strCategory UTF8String];
	_details.attributes = 0x0; //for our own use (not used by the core)
    _details.bizId = 0;

	char *pRequestID;

    // create the request
	result = ABC_CreateReceiveRequest([[User Singleton].name UTF8String],
                                      [[User Singleton].password UTF8String],
                                      [wallet.strUUID UTF8String],
                                      &_details,
                                      &pRequestID,
                                      &error);

	if (result == ABC_CC_Ok)
	{
		return pRequestID;
	}
	else
	{
		return 0;
	}
}


// generates and returns a request qr image, stores request id in the given mutable string
- (UIImage *)createRequestQRImageFor:(NSString *)strName withNotes:(NSString *)strNotes withCategory:(NSString *)strCategory 
    storeRequestIDIn:(NSMutableString *)strRequestID storeRequestURI:(NSMutableString *)strRequestURI 
    storeRequestAddressIn:(NSMutableString *)strRequestAddress scaleAndSave:(BOOL)bScaleAndSave 
    withAmount:(SInt64)amountSatoshi
{
    NSLog(@"ENTER createRequestQRImageFor");

    UIImage *qrImage = nil;
    [strRequestID setString:@""];
    [strRequestAddress setString:@""];
    [strRequestURI setString:@""];

    unsigned int width = 0;
    unsigned char *pData = NULL;
    char *pszURI = NULL;
    tABC_Error error;

    const char *szRequestID = [self createReceiveRequestFor:strName withNotes:strNotes
        withCategory:strCategory withAmount:amountSatoshi];
    self.requestID = [NSString stringWithUTF8String:szRequestID];

    if (szRequestID)
    {
        Wallet *wallet = [self getCurrentWallet];
        tABC_CC result = ABC_GenerateRequestQRCode([[User Singleton].name UTF8String],
                                           [[User Singleton].password UTF8String],
                                           [wallet.strUUID UTF8String],
                                                   szRequestID,
                                                   &pszURI,
                                                   &pData,
                                                   &width,
                                                   &error);

        if (result == ABC_CC_Ok)
        {
                qrImage = [Util dataToImage:pData withWidth:width andHeight:width];

            if (pszURI && strRequestURI)
            {
                [strRequestURI appendFormat:@"%s", pszURI];
                free(pszURI);
            }
            
        }
        else
        {
                [Util printABC_Error:&error];
        }
    }

    if (szRequestID)
    {
        if (strRequestID)
        {
            [strRequestID appendFormat:@"%s", szRequestID];
        }
        char *szRequestAddress = NULL;

        Wallet *wallet = [self getCurrentWallet];
        tABC_CC result = ABC_GetRequestAddress([[User Singleton].name UTF8String],
                                               [[User Singleton].password UTF8String],
                                               [wallet.strUUID UTF8String],
                                               szRequestID,
                                               &szRequestAddress,
                                               &error);

        if (result == ABC_CC_Ok)
        {
            if (szRequestAddress && strRequestAddress)
            {
                [strRequestAddress appendFormat:@"%s", szRequestAddress];
                free(szRequestAddress);
            }
        }
        else
        {
            [Util printABC_Error:&error];
        }

        free((void*)szRequestID);
    }

    if (pData)
    {
        free(pData);
    }
    
    UIImage *qrImageFinal = qrImage;

    if (bScaleAndSave)
    {
        // scale qr image up
        UIGraphicsBeginImageContext(CGSizeMake(QR_CODE_SIZE, QR_CODE_SIZE));
        CGContextRef c = UIGraphicsGetCurrentContext();
        CGContextSetInterpolationQuality(c, kCGInterpolationNone);
        [qrImage drawInRect:CGRectMake(0, 0, QR_CODE_SIZE, QR_CODE_SIZE)];
        qrImageFinal = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();

        // save it to a file
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *filePath = [[paths objectAtIndex:0] stringByAppendingPathComponent:QR_CODE_TEMP_FILENAME];
        [UIImagePNGRepresentation(qrImageFinal) writeToFile:filePath atomically:YES];
    }

    NSLog(@"EXIT createRequestQRImageFor");

    return qrImageFinal;
}



- (void)updateTextFieldContents:(BOOL)allowBTCUpdate
{
    tABC_Error error;
    
    Wallet *wallet = [self getCurrentWallet];
    
    self.exchangeRateLabel.text = [CoreBridge conversionString:wallet];
//XXX    self.USDLabel_TextField.text = wallet.currencyAbbrev;
    [self.segmentedControlBTCUSD setTitle:wallet.currencyAbbrev forSegmentAtIndex:0];
    _fiatLabel.text = wallet.currencyAbbrev;

    if (_selectedTextField == self.BTC_TextField)
	{
		double currency;
        int64_t satoshi = [CoreBridge denominationToSatoshi: self.BTC_TextField.text];

        if (satoshi == 0)
        {
            if ([self.BTC_TextField.text hasPrefix:@"."] == NO)
            {
                self.USD_TextField.text = @"";
                self.BTC_TextField.text = @"";
            }
        }
        else
        {
            if (ABC_SatoshiToCurrency([[User Singleton].name UTF8String], [[User Singleton].password UTF8String],
                    satoshi, &currency, wallet.currencyNum, &error) == ABC_CC_Ok)
                self.USD_TextField.text = [CoreBridge formatCurrency:currency
                                                     withCurrencyNum:wallet.currencyNum
                                                          withSymbol:false];
        }
	}
	else if (allowBTCUpdate && (_selectedTextField == self.USD_TextField))
	{
		int64_t satoshi;
		double currency = [self.USD_TextField.text doubleValue];
        if (currency == 0.0)
        {
            if ([self.USD_TextField.text hasPrefix:@"."] == NO)
            {
                self.USD_TextField.text = @"";
                self.BTC_TextField.text = @"";
            }
        }
        else
        {
            if (ABC_CurrencyToSatoshi([[User Singleton].name UTF8String], [[User Singleton].password UTF8String],
                    currency, wallet.currencyNum, &satoshi, &error) == ABC_CC_Ok)
            {
                self.BTC_TextField.text = [CoreBridge formatSatoshi:satoshi
                                                         withSymbol:false
                                                       cropDecimals:[CoreBridge currencyDecimalPlaces]];
            }
        }
	}

//    NSString *walletName;
//
//    walletName = [NSString stringWithFormat:@"To: %@ ↓", wallet.strName];
//
//    [MainViewController changeNavBarTitleWithButton:self title:walletName action:@selector(didTapTitle:) fromObject:self];
    [self updateQRCode:0];
//
}

- (void)didTapTitle: (UIButton *)sender
{
    if (bWalletListDropped)
    {
        [self.buttonSelector close];
        bWalletListDropped = false;
    }
    else
    {
        [self.buttonSelector open];
        bWalletListDropped = true;
    }

}

- (void)bringUpImportWalletView
{
    if (nil == _importWalletViewController)
    {
        UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"Main_iPhone" bundle: nil];
        _importWalletViewController = [mainStoryboard instantiateViewControllerWithIdentifier:@"ImportWalletViewController"];

        Wallet *wallet = [CoreBridge Singleton].currentWallet;
        _importWalletViewController.walletUUID = wallet.strUUID;
        _importWalletViewController.delegate = self;

        CGRect frame = self.view.bounds;
        frame.origin.x = frame.size.width;
        _importWalletViewController.view.frame = frame;
        [self.view addSubview:_importWalletViewController.view];

        [UIView animateWithDuration:0.35
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^
         {
             _importWalletViewController.view.frame = self.view.bounds;
         }
                         completion:^(BOOL finished)
         {

         }];
    }
}

#pragma mark - Calculator delegates



- (void)CalculatorDone:(CalculatorView *)calculator
{
    [self didTouchQRCode:nil];
}

- (void)CalculatorValueChanged:(CalculatorView *)calculator
{
	[self updateTextFieldContents:YES];
}


#pragma mark - ButtonSelectorView2 delegates

- (void)ButtonSelector2:(ButtonSelectorView2 *)view selectedItem:(int)itemIndex
{
    NSIndexPath *indexPath = [[NSIndexPath alloc]init];
    indexPath = [NSIndexPath indexPathForItem:itemIndex inSection:0];
    [CoreBridge makeCurrentWalletWithIndex:indexPath];

    bWalletListDropped = false;
}

#pragma mark - Textfield delegates

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    if (textField != self.currentTopField)
    {
        if (self.currentTopField == self.USD_TextField)
            [self changeTopField:false animate:YES];
        else
            [self changeTopField:true animate:YES];

    }

    _selectedTextField = textField;
    if (_selectedTextField == self.BTC_TextField)
        self.keypadView.calcMode = CALC_MODE_COIN;
    else if (_selectedTextField == self.USD_TextField)
        self.keypadView.calcMode = CALC_MODE_FIAT;

    // Popup numpad
    [self changeCalculator:YES show:true];

}

#pragma mark - Import Wallet Delegates

- (void)importWalletViewControllerDidFinish:(ImportWalletViewController *)controller
{
	[controller.view removeFromSuperview];
	_importWalletViewController = nil;

    [self setFirstResponder];
}

- (Wallet *) getCurrentWallet
{
    return [CoreBridge Singleton].currentWallet;
}

-(void)showConnectedPopup
{
    NSString *line1;
    NSString *line2;
    NSString *line3;
    UIImage *image;

    line1 = self.connectedName;
    line2 = @"";
    line3 = [Theme Singleton].ConnectedText;

    //see if there is a match between advertised name and name in contacts.  If so, use the photo from contacts
    BOOL imageIsFromContacts = NO;

    NSArray *arrayComponents = [self.connectedName componentsSeparatedByString:@" "];
    if(arrayComponents.count >= 2)
    {
        //filter off the nickname.  We just want first name and last name
        NSString *firstName = [arrayComponents objectAtIndex:0];
        NSString *lastName = [arrayComponents objectAtIndex:1];
        NSString *name = [NSString stringWithFormat:@"%@ %@", firstName, lastName ];
        for (Contact *contact in self.arrayContacts)
        {
            if([[name uppercaseString] isEqualToString:[contact.strName uppercaseString]])
            {
                image = contact.imagePhoto;
                imageIsFromContacts = YES;
                break;
            }
        }
    }


    if(imageIsFromContacts == NO)
    {
        image = [UIImage imageNamed:@"BLE_photo.png"];
    }

    [DropDownAlertView create:self.view
                      message:nil
                        image:image
                        line1:line1
                        line2:line2
                        line3:line3
                     holdTime:DROP_DOWN_HOLD_TIME_DEFAULT
                 withDelegate:nil];

}

-(void)showPaymentPopup:(RequestState)state amount:(SInt64) amountSatoshi
{
    NSString *line1;
    NSString *line2;
    NSString *line3;
    UIImage *image;

    NSTimeInterval delay;
    NSTimeInterval duration;

    Wallet *wallet = [self getCurrentWallet];


    switch (state) {
        case kPartial:
        {
            delay = 4.0;
            duration = 2.0;
            line1 = [Theme Singleton].WarningInitWithTitle;
            line2 = @"";
            line3 = [Theme Singleton].PartialPaymentText;
            image = [UIImage imageNamed:@"Warning_icon.png"];
            [[AudioController controller] playPartialReceived];
            break;
        }
        case kDonation:
        {
            delay = 7.0;
            duration = 2.0;
            image = [UIImage imageNamed:@"bitcoin_symbol.png"];
            line1 = [Theme Singleton].PaymentReceivedText;
            tABC_Error error;
            double currency;
            if (ABC_SatoshiToCurrency([[User Singleton].name UTF8String], [[User Singleton].password UTF8String],
                    amountSatoshi, &currency, wallet.currencyNum, &error) == ABC_CC_Ok)
            {
                NSString *fiatAmount = [CoreBridge currencySymbolLookup:wallet.currencyNum];
                NSString *fiatSymbol = [NSString stringWithFormat:@"%.2f", currency];
                NSString *fiat = [fiatAmount stringByAppendingString:fiatSymbol];
                line2 = [CoreBridge formatSatoshi:amountSatoshi];
                line3 = fiat;
            }
            else
            {
                // failed to look up the wallet's fiat currency
                line2 = [CoreBridge formatSatoshi:amountSatoshi];
                line3  = @"";
            }
            [[AudioController controller] playReceived];
            break;
        }
        default:
        {
            [[AudioController controller] playReceived];
            return;
        }
    }

    [DropDownAlertView create:self.view
                      message:nil
                        image:image
                        line1:line1
                        line2:line2
                        line3:line3
                     holdTime:[Theme Singleton].alertHoldTimePaymentReceived
                 withDelegate:nil];

}

#pragma mark address book

- (void)generateListOfContactNames
{
    NSMutableArray *arrayContacts = [[NSMutableArray alloc] init];

    CFErrorRef error;
    ABAddressBookRef addressBook = ABAddressBookCreateWithOptions(NULL, &error);

    __block BOOL accessGranted = NO;

    if (ABAddressBookRequestAccessWithCompletion != NULL)
    {
        // we're on iOS 6
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);

        ABAddressBookRequestAccessWithCompletion(addressBook, ^(bool granted, CFErrorRef error)
        {
            accessGranted = granted;
            dispatch_semaphore_signal(sema);
        });

        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        //dispatch_release(sema);
    }
    else
    {
        // we're on iOS 5 or older
        accessGranted = YES;
    }

    if (accessGranted)
    {
        CFArrayRef people = ABAddressBookCopyArrayOfAllPeople(addressBook);
        for (CFIndex i = 0; i < CFArrayGetCount(people); i++)
        {
            ABRecordRef person = CFArrayGetValueAtIndex(people, i);

            NSString *strFullName = [Util getNameFromAddressRecord:person];
            if ([strFullName length])
            {
                // add this contact
                [self addContactInfo:person withName:strFullName toArray:arrayContacts];
            }
        }
        CFRelease(people);
    }

    // assign final
    self.arrayContacts = [arrayContacts sortedArrayUsingSelector:@selector(compare:)];
    //NSLog(@"contacts: %@", self.arrayContacts);
}

- (void)addContactInfo:(ABRecordRef)person withName:(NSString *)strName toArray:(NSMutableArray *)arrayContacts
{
    UIImage *imagePhoto = nil;

    // does this contact has an image
    if (ABPersonHasImageData(person))
    {
        NSData *data = (__bridge_transfer NSData*)ABPersonCopyImageData(person);
        imagePhoto = [UIImage imageWithData:data];
    }

    Contact *contact = [[Contact alloc] init];
    contact.strName = strName;
    contact.imagePhoto = imagePhoto;

    [arrayContacts addObject:contact];
}

#pragma mark - CBPeripheral methods

/** Required protocol method.  A full app should take care of all the possible states,
*  but we're just waiting for  to know when the CBPeripheralManager is ready
*/
- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral
{
    if(peripheral.state == CBPeripheralManagerStatePoweredOn && [self isLECapableHardware])
    {
        // We're in CBPeripheralManagerStatePoweredOn state...
        //NSLog(@"self.peripheralManager powered on.");

        // ... so build our service.

        // Start with the CBMutableCharacteristic
        self.bitcoinURICharacteristic = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_UUID]
                                                                           properties:CBCharacteristicPropertyNotify | CBCharacteristicPropertyRead | CBCharacteristicPropertyWrite
                                                                                value:nil
                                                                          permissions:CBAttributePermissionsReadable | CBAttributePermissionsWriteable];


        // Then the service
        CBMutableService *transferService = [[CBMutableService alloc] initWithType:[CBUUID UUIDWithString:TRANSFER_SERVICE_UUID]
                                                                           primary:YES];

        // Add the characteristic to the service
        transferService.characteristics = @[self.bitcoinURICharacteristic];

        // And add it to the peripheral manager
        [self.peripheralManager addService:transferService];

        //now start advertising (UUID and username)

        //make 10-character address
        NSString *address;
        if(addressString.length >= 10)
        {
            address = [addressString substringToIndex:10];
        }
        else
        {
            address = addressString;
        }

        tABC_AccountSettings            *pAccountSettings;
        tABC_Error Error;
        Error.code = ABC_CC_Ok;

        // load the current account settings
        pAccountSettings = NULL;
        ABC_LoadAccountSettings([[User Singleton].name UTF8String],
                [[User Singleton].password UTF8String],
                &pAccountSettings,
                &Error);
        [Util printABC_Error:&Error];

        BOOL sendName = NO;
        if (pAccountSettings)
        {
            if(pAccountSettings->bNameOnPayments)
            {
                sendName = YES;
            }
            ABC_FreeAccountSettings(pAccountSettings);
        }

        NSString *name;
        if(sendName)
        {
            name = [User Singleton].fullName ;
            if ([name isEqualToString:@""])
            {
                name = [[UIDevice currentDevice] name];
            }
        }
        else
        {
            name = [[UIDevice currentDevice] name];
        }
        //broadcast first 10 digits of bitcoin address followed by full name (up to 28 bytes total)
        [self.peripheralManager startAdvertising:@{ CBAdvertisementDataServiceUUIDsKey : @[[CBUUID UUIDWithString:TRANSFER_SERVICE_UUID]], CBAdvertisementDataLocalNameKey : [NSString stringWithFormat:@"%@%@", address, name]}];
        self.BLE_LogoImageView.hidden = NO;
    }
    else
    {
//        [self showFadingAlert:NSLocalizedString(@"Bluetooth disconnected", nil)];
        self.BLE_LogoImageView.hidden = YES;
    }

}

/*
 * Central sends their name - acknowledge it
 */
-(void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveWriteRequests:(NSArray *)requests
{
    //NSLog(@"didReceiveWriteRequests");
    for(CBATTRequest *request in requests)
    {
        if([request.characteristic.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_UUID]])
        {
            NSString *userName = [[NSString alloc] initWithData:request.value encoding:NSUTF8StringEncoding];
            //NSLog(@"Received new string: %@", userName);

            self.connectedName = userName;
        }
    }
    [self showConnectedPopup];
    [self.peripheralManager respondToRequest:[requests objectAtIndex:0] withResult:CBATTErrorSuccess];
}

/*
 * Central requesting full bitcoin URI. Send it in limited packets up to 512 bytes
 */
-(void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveReadRequest:(CBATTRequest *)request
{
    //NSLog(@"didReceiveReadRequests");

    if([request.characteristic.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_UUID]])
    {
        NSString *stringToSend = [NSString stringWithFormat:@"%@", _uriString];
        NSData *data = [stringToSend dataUsingEncoding:NSUTF8StringEncoding];

        if (request.offset > data.length)
        {
            [self.peripheralManager respondToRequest:request withResult:CBATTErrorInvalidOffset];
            return;
        }

        NSRange readRange = NSMakeRange(request.offset, data.length - request.offset);
        request.value = [data subdataWithRange:readRange];
        [peripheral respondToRequest:request withResult:CBATTErrorSuccess];
    }
}

// Use CBPeripheralManager to check whether the current platform/hardware supports Bluetooth LE.
- (BOOL)isLECapableHardware
{
    NSString * state = nil;
    switch ([self.peripheralManager state]) {
        case CBPeripheralManagerStateUnsupported:
            state = [Theme Singleton].HardwareNotSupportedText;
            break;
        case CBPeripheralManagerStateUnauthorized:
            state = [Theme Singleton].NotAuthorizedToUseBluetoothText;
            break;
        case CBPeripheralManagerStatePoweredOff:
            state = [Theme Singleton].BluetoothPoweredOffText;
            break;
        case CBPeripheralManagerStateResetting:
            state =[Theme Singleton].BluetoothCurrentlyResettingText;
            break;
        case CBPeripheralManagerStatePoweredOn:
            NSLog(@"powered on");
            return TRUE;
        case CBPeripheralManagerStateUnknown:
            NSLog(@"state unknown");
            return FALSE;
        default:
            return FALSE;
    }
    NSLog(@"Peripheral manager state: %@", state);
    return FALSE;
}

- (void)replaceRequestTags:(NSString **) strContent
{
    NSString *amountBTC = [CoreBridge formatSatoshi:_amountSatoshiRequested
                                         withSymbol:false
                                      forceDecimals:8];
    NSString *amountBits = [CoreBridge formatSatoshi:_amountSatoshiRequested
                                          withSymbol:false
                                       forceDecimals:2];
    // For sending requests, use 8 decimal places which is a BTC (not mBTC or uBTC amount)

    NSString *iosURL;
    NSString *redirectURL = [NSString stringWithString: _uriString];
    NSString *paramsURI;
    NSString *paramsURIEnc;

    NSRange tempRange = [_uriString rangeOfString:@"bitcoin:"];

    if (*strContent == NULL)
    {
        return;
    }

    if (tempRange.location != NSNotFound)
    {
        iosURL = [_uriString stringByReplacingCharactersInRange:tempRange withString:@"bitcoin://"];
        paramsURI = [_uriString stringByReplacingCharactersInRange:tempRange withString:@""];
        paramsURIEnc = (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(
                NULL,
                (CFStringRef)paramsURI,
                NULL,
                (CFStringRef)@"!*'();:@&=+$,/?%#[]",
                kCFStringEncodingUTF8 ));
        redirectURL = [NSString stringWithFormat:@"%@%@",@"https://airbitz.co/blf/?address=", paramsURIEnc ];

    }
    NSString *name;

    if ([User Singleton].bNameOnPayments && [User Singleton].fullName)
    {
        name = [NSString stringWithString:[User Singleton].fullName];
    }
    else
    {
        name = nil;
    }

    NSMutableArray* searchList  = [[NSMutableArray alloc] initWithObjects:
            @"[[abtag FROM]]",
            @"[[abtag BITCOIN_URL]]",
            @"[[abtag REDIRECT_URL]]",
            @"[[abtag BITCOIN_URI]]",
            @"[[abtag ADDRESS]]",
            @"[[abtag AMOUNT_BTC]]",
            @"[[abtag AMOUNT_BITS]]",
            @"[[abtag QRCODE]]",
                    nil];

    NSMutableArray* replaceList = [[NSMutableArray alloc] initWithObjects:
            name ? name : @"Unknown User",
            iosURL,
            redirectURL,
                    _uriString,
            addressString,
            amountBTC,
            amountBits,
            @"cid:qrcode.jpg",
                    nil];

    for (int i=0; i<[searchList count];i++)
    {
        *strContent = [*strContent stringByReplacingOccurrencesOfString:[searchList objectAtIndex:i]
                                                             withString:[replaceList objectAtIndex:i]];
    }

}


- (void)sendEMail
{

    // if mail is available
    if ([MFMailComposeViewController canSendMail])
    {

        NSError* error = nil;
        NSString *path = [[NSBundle mainBundle] pathForResource:@"emailTemplate" ofType:@"html"];
        NSString* content = [NSString stringWithContentsOfFile:path
                                                      encoding:NSUTF8StringEncoding
                                                         error:&error];
        [self replaceRequestTags:&content];

        MFMailComposeViewController *mailComposer = [[MFMailComposeViewController alloc] init];

        if ([self.strEMail length])
        {
            [mailComposer setToRecipients:[NSArray arrayWithObject:self.strEMail]];
        }

        NSString *subject;

        if ([User Singleton].bNameOnPayments && [User Singleton].fullName)
        {
            subject = [NSString stringWithFormat:@"Airbitz Bitcoin Request from %@", [User Singleton].fullName];
        }
        else
        {
            subject = [NSString stringWithFormat:@"Airbitz Bitcoin Request"];
        }

        [mailComposer setSubject:NSLocalizedString(subject, nil)];

        [mailComposer setMessageBody:content isHTML:YES];

        NSData *imgData;

        UIImage *imageAttachment = [self imageWithImage:self.qrCodeImageView.image scaledToSize:CGSizeMake(QR_ATTACHMENT_WIDTH, QR_ATTACHMENT_WIDTH)];
        imgData = [NSData dataWithData:UIImageJPEGRepresentation(imageAttachment, 1.0)];
        [mailComposer addAttachmentData:imgData mimeType:@"image/jpeg" fileName:@"qrcode.jpg"];

        mailComposer.mailComposeDelegate = self;

        [self presentViewController:mailComposer animated:YES completion:nil];

        [MainViewController animateFadeOut:self.view];
        _requestType = [Theme Singleton].emailText;
    }
    else
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil
                                                        message:@"Can't send e-mail"
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
    }
}



- (void)sendSMS
{
    //NSLog(@"sendSMS to: %@ / %@", self.strFullName, self.strPhoneNumber);

    MFMessageComposeViewController *controller = [[MFMessageComposeViewController alloc] init];
    if ([MFMessageComposeViewController canSendText] && [MFMessageComposeViewController canSendAttachments])
    {

        NSError* error = nil;
        NSString *path = [[NSBundle mainBundle] pathForResource:@"SMSTemplate" ofType:@"txt"];
        NSString* content = [NSString stringWithContentsOfFile:path
                                                      encoding:NSUTF8StringEncoding
                                                         error:&error];
        [self replaceRequestTags:&content];

        // create the attachment
        UIImage *imageAttachment = [self imageWithImage:self.qrCodeImageView.image scaledToSize:CGSizeMake(QR_ATTACHMENT_WIDTH, QR_ATTACHMENT_WIDTH)];
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *filePath = [[paths objectAtIndex:0] stringByAppendingPathComponent:QR_CODE_TEMP_FILENAME];
        BOOL bAttached = [controller addAttachmentData:UIImagePNGRepresentation(imageAttachment) typeIdentifier:(NSString*)kUTTypePNG filename:filePath];
        if (!bAttached)
        {
            NSLog(@"Could not attach qr code");
        }

        controller.body = content;

        if (self.strPhoneNumber)
        {
            if ([self.strPhoneNumber length] != 0)
            {
                controller.recipients = @[self.strPhoneNumber];
            }
        }

        controller.messageComposeDelegate = self;

        [self presentViewController:controller animated:YES completion:nil];
        [MainViewController animateFadeOut:self.view];

        _requestType = [Theme Singleton].smsText;
    }
}

- (UIImage *)imageWithImage:(UIImage *)image scaledToSize:(CGSize)newSize
{
    //UIGraphicsBeginImageContext(newSize);
    // In next line, pass 0.0 to use the current device's pixel scaling factor (and thus account for Retina resolution).
    // Pass 1.0 to force exact pixel size.
    UIGraphicsBeginImageContextWithOptions(newSize, NO, 0.0);
    CGContextSetInterpolationQuality(UIGraphicsGetCurrentContext(), kCGInterpolationNone);
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}


- (void)launchRecipientWithMode:(tRecipientMode)mode
{
    if (self.recipientViewController)
    {
        return;
    }
    UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"Main_iPhone" bundle: nil];
    self.recipientViewController = [mainStoryboard instantiateViewControllerWithIdentifier:@"RecipientViewController"];
    self.recipientViewController.delegate = self;
    self.recipientViewController.mode = mode;

    [Util addSubviewControllerWithConstraints:self.view child:self.recipientViewController];
    [MainViewController animateSlideIn:self.recipientViewController];
}

- (void)dismissRecipient
{
    [MainViewController animateOut:self.recipientViewController withBlur:NO complete:nil];
    self.recipientViewController = nil;
    [MainViewController changeNavBarOwner:self];
    [self updateViews:nil];
}

- (void)installLeftToRightSwipeDetection
{
    UISwipeGestureRecognizer *gesture = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(didSwipeLeftToRight:)];
    gesture.direction = UISwipeGestureRecognizerDirectionRight;
    [self.view addGestureRecognizer:gesture];
}

// used by the guesture recognizer to ignore exit
- (BOOL)haveSubViewsShowing
{
    return (self.recipientViewController != nil);
}


- (void)saveRequest
{
    if (_strFullName) {
        _txDetails.szName = (char *)[_strFullName UTF8String];
    } else if (_strEMail) {
        _txDetails.szName = (char *)[_strEMail UTF8String];
    } else if (_strPhoneNumber) {
        _txDetails.szName = (char *)[_strPhoneNumber UTF8String];
    }
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateStyle:NSDateFormatterMediumStyle];
    NSDate *now = [NSDate date];

    NSMutableString *notes = [[NSMutableString alloc] init];
    [notes appendFormat:[Theme Singleton].RequestedViaText,
                        [CoreBridge formatSatoshi:_txDetails.amountSatoshi],
                        [CoreBridge formatCurrency:_txDetails.amountCurrency withCurrencyNum:[CoreBridge Singleton].currentWallet.currencyNum],
                        _requestType,
                        [dateFormatter stringFromDate:now]];
    _txDetails.szNotes = (char *)[notes UTF8String];
    tABC_Error Error;
    // Update the Details
    if (ABC_CC_Ok != ABC_ModifyReceiveRequest([[User Singleton].name UTF8String],
            [[User Singleton].password UTF8String],
            [[CoreBridge Singleton].currentWallet.strUUID UTF8String],
            [self.requestID UTF8String],
            &_txDetails,
            &Error))
    {
        [Util printABC_Error:&Error];
    }

    [self.delegate pleaseRestartRequestViewBecauseAppleSucksWithPresentController];

}

- (void)finalizeRequest
{
    tABC_Error Error;

    // Finalize this request so it isn't used elsewhere
    if (ABC_CC_Ok != ABC_FinalizeReceiveRequest([[User Singleton].name UTF8String],
            [[User Singleton].password UTF8String],
            [[CoreBridge Singleton].currentWallet.strUUID UTF8String],
            [self.requestID UTF8String],
            &Error))
    {
        [Util printABC_Error:&Error];
    }
}

#pragma mark - MFMessageComposeViewController delegate

- (void)messageComposeViewController:(MFMessageComposeViewController *)controller didFinishWithResult:(MessageComposeResult)result
{
    switch (result)
    {
        case MessageComposeResultCancelled:
        {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:[Theme Singleton].AirbitzCheckUserReview
                                                            message:[Theme Singleton].SMSCancelledText
                                                           delegate:nil
                                                  cancelButtonTitle:[Theme Singleton].OkCancelButtonTitle
                                                  otherButtonTitles: nil];
            [alert show];
        }
            break;

        case MessageComposeResultFailed:
        {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:[Theme Singleton].AirbitzCheckUserReview
                                                            message:[Theme Singleton].ErrorSendingSMSText
                                                           delegate:nil
                                                  cancelButtonTitle:[Theme Singleton].OkCancelButtonTitle
                                                  otherButtonTitles: nil];
            [alert show];
        }
            break;

        case MessageComposeResultSent:
        {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:[Theme Singleton].AirbitzCheckUserReview
                                                            message:[Theme Singleton].SMSSentText
                                                           delegate:nil
                                                  cancelButtonTitle:[Theme Singleton].OkCancelButtonTitle
                                                  otherButtonTitles: nil];
            [alert show];
        }
            break;

        default:
            break;
    }

    [[controller presentingViewController] dismissViewControllerAnimated:YES completion:nil];
    [self saveRequest];

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
            strTitle = [Theme Singleton].ErrorSendingEmailText;
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
    [self saveRequest];
}


#pragma mark - RecipientViewControllerDelegates

- (void)RecipientViewControllerDone:(RecipientViewController *)controller withFullName:(NSString *)strFullName andTarget:(NSString *)strTarget
{
    // if they selected a target
    if ([strTarget length])
    {
        self.strFullName = strFullName;
        self.strEMail = strTarget;
        self.strPhoneNumber = strTarget;

        //NSLog(@"name: %@, target: %@", strFullName, strTarget);

        if (controller.mode == RecipientMode_SMS)
        {
            [self performSelector:@selector(sendSMS) withObject:nil afterDelay:0.0];
        }
        else if (controller.mode == RecipientMode_Email)
        {
            [self performSelector:@selector(sendEMail) withObject:nil afterDelay:0.0];
        }
    }
    else
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:[Theme Singleton].AirbitzCheckUserReview
                                                        message:(controller.mode == RecipientMode_SMS ? [Theme Singleton].SMSCancelledText : [Theme Singleton].EmailCancelledText)
                                                       delegate:nil
                                              cancelButtonTitle:[Theme Singleton].OkCancelButtonTitle
                                              otherButtonTitles:nil];
        [alert show];
    }

    [self dismissRecipient];
}


@end
