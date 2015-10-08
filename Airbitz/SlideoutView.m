//
//  SlideoutView.m
//  AirBitz
//
//  Created by Tom on 3/25/15.
//  Copyright (c) 2015 AirBitz. All rights reserved.
//

#import "SlideoutView.h"
#import "PickerTextView.h"
#import "CoreBridge.h"
#import "ABC.h"
#import "User.h"
#import "LocalSettings.h"
#import "Util.h"
#import "CommonTypes.h"
#import "MainViewController.h"

#define SHOW_BUY_SELL 1

@interface SlideoutView () <PickerTextViewDelegate >

{
//    CGRect                      _originalSlideoutFrame;
    BOOL                        _open;
    NSString                    *_account;
    FadingAlertView             *_fadingAlert;
    UIButton                    *_blockingButton;
    UIView                      *_parentView;
}

@property (weak, nonatomic) IBOutlet UILabel                *conversionText;
@property (weak, nonatomic) IBOutlet UILabel                *accountText;
@property (weak, nonatomic) IBOutlet UIView                 *accountArrow;
@property (weak, nonatomic) IBOutlet UIView                 *otherAccountsView;
@property (weak, nonatomic) IBOutlet UIView                 *lowerViews;
@property (weak, nonatomic) IBOutlet UIButton               *buySellButton;
@property (weak, nonatomic) IBOutlet UIButton               *accountButton;
@property (weak, nonatomic) IBOutlet UIButton               *logoutButton;
@property (weak, nonatomic) IBOutlet UIButton               *settingsButton;
@property (weak, nonatomic) IBOutlet UIView                 *buySellDivider;
@property (weak, nonatomic) IBOutlet UIButton               *walletsButton;

@property (nonatomic, strong) NSArray                       *arrayAccounts;
@property (nonatomic, strong) NSArray                       *otherAccounts;
@property (nonatomic, weak) IBOutlet PickerTextView         *accountPicker;

@end

@implementation SlideoutView

+ (SlideoutView *)CreateWithDelegate:(id)del parentView:(UIView *)parentView withTab:(UIView *)tabBar;
{
    SlideoutView *v = [[[NSBundle mainBundle] loadNibNamed:@"SlideoutView~iphone" owner:self options:nil] objectAtIndex:0];
    v.delegate = del;

    v->_parentView = parentView;
    v->_open = NO;

    UIColor *back = [UIColor colorWithRed:0.0 green:0.0 blue:1.0 alpha:0.05];
    [v->_logoutButton setBackgroundImage:[self imageWithColor:back] forState:UIControlStateHighlighted];
    [v->_settingsButton setBackgroundImage:[self imageWithColor:back] forState:UIControlStateHighlighted];
    [v->_buySellButton setBackgroundImage:[self imageWithColor:back] forState:UIControlStateHighlighted];
    return v;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
    }
    return self;
}

+ (UIImage *)imageWithColor:(UIColor *)color {
    CGRect rect = CGRectMake(0.0f, 0.0f, 1.0f, 1.0f);
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextSetFillColorWithColor(context, [color CGColor]);
    CGContextFillRect(context, rect);
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

- (void)showSlideout:(BOOL)show
{
    if ([User isLoggedIn])
    {
        if (show)
        {
            self.accountPicker.delegate = self;

            _buySellButton.hidden = !SHOW_BUY_SELL;
            _buySellDivider.hidden = !SHOW_BUY_SELL;

            // set up the specifics on our picker text view
            [self.accountPicker setTopMostView:self.otherAccountsView];
            CGRect frame = self.accountPicker.frame;
            frame.size.width = self.otherAccountsView.frame.size.width;
            self.accountPicker.frame = frame;
            [self.accountPicker setAccessoryImage:[UIImage imageNamed:@"btn_close.png"]];
            [self.accountPicker setRoundedAndShadowed:NO];

            int num = [User Singleton].defaultCurrencyNum;

            self.conversionText.text = [CoreBridge conversionStringFromNum:num withAbbrev:YES];


            self.accountText.text = [User Singleton].name;
            [self.accountButton setAccessibilityLabel:[User Singleton].name];

            self.lowerViews.hidden = NO;
            self.otherAccountsView.hidden = YES;
            self.otherAccountsView.clipsToBounds = YES;

            CGRect lframe = self.lowerViews.frame;
            CGRect oframe = self.otherAccountsView.frame;
            oframe.size.height = lframe.size.height;
            self.lowerViews.frame = lframe;
            self.otherAccountsView.frame = oframe;

        }

        [self showSlideout:show withAnimation:YES];
    }
    else
    {
        [self showSlideout:NO withAnimation:YES];
    }
}

- (void)showSlideout:(BOOL)show withAnimation:(BOOL)bAnimation
{
    if (!show)
    {
        if(!self.otherAccountsView.hidden)
        {
            [self accountTouched];
        }

        if (self.delegate && [self.delegate respondsToSelector:@selector(slideoutWillClose:)]) {
            [self.delegate slideoutWillClose:self];
        }
        if (bAnimation) {
            [UIView animateWithDuration:0.35
                                delay:0.0
                                options:UIViewAnimationOptionCurveEaseOut
                            animations:^
            {
                self.leftConstraint.constant = -0;
                [self layoutIfNeeded];
            }
                            completion:^(BOOL finished)
            {
                
            }];
            [UIView animateWithDuration:0.35
                                  delay:0.0
                                options:UIViewAnimationOptionCurveEaseOut
                             animations:^
             {
                 _blockingButton.alpha = 0;
             }
                             completion:^(BOOL finished)
             {
                 [self removeBlockingButton:self->_parentView];
             }];
        } else {
            self.leftConstraint.constant = -0;
            [self layoutIfNeeded];
//            self.frame = frame;
            [self removeBlockingButton:self->_parentView];
        }
        [self rotateImage:self.accountArrow duration:0.0
                    curve:UIViewAnimationCurveEaseIn radians:0];
    } else {
        if (self.delegate && [self.delegate respondsToSelector:@selector(slideoutWillOpen:)]) {
            [self.delegate slideoutWillOpen:self];
        }
        if (bAnimation) {
            [UIView animateWithDuration:0.35
                                delay:0.0
                                options:UIViewAnimationOptionCurveEaseOut
                            animations:^
            {
                self.leftConstraint.constant = -self.frame.size.width;
                [self layoutIfNeeded];
            }
                            completion:^(BOOL finished)
            {
                
            }];
            [self addBlockingButton:self->_parentView];
            [UIView animateWithDuration:0.35
                                  delay:0.0
                                options:UIViewAnimationOptionCurveEaseOut
                             animations:^
             {
                 _blockingButton.alpha = 0.5;
             }
                             completion:^(BOOL finished)
             {
                 
             }];
        } else {
            self.leftConstraint.constant = -self.frame.size.width;
            [self layoutIfNeeded];
        }
    }
    _open = show;
}

- (IBAction)buysellTouched
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(slideoutBuySell)]) {
        [self.delegate slideoutBuySell];
    }
}

- (IBAction)importTouched:(id)sender
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(slideoutImport)]) {
        [self.delegate slideoutImport];
    }
}

- (IBAction)walletsTouched:(id)sender
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(slideoutWallets)]) {
        [self.delegate slideoutWallets];
    }
}


- (IBAction)accountTouched
{
    if(self.otherAccountsView.hidden) {
        [self updateOtherAccounts:self.accountText.text];
        if(self.otherAccounts.count > 0)
        {
            [self.accountPicker updateChoices:self.otherAccounts] ;
            self.otherAccountsView.hidden = NO;
            self.lowerViews.hidden = YES;
            self.lowerViews.userInteractionEnabled = NO;
            
            [self rotateImage:self.accountArrow duration:0.2
                        curve:UIViewAnimationCurveEaseIn radians:M_PI-0.0001];
        }
    }
    else
    {
        self.otherAccountsView.hidden = YES;
        self.lowerViews.hidden = NO;
        self.lowerViews.userInteractionEnabled = YES;
        [self rotateImage:self.accountArrow duration:0.2
                    curve:UIViewAnimationCurveEaseIn radians:0];
    }
    if (self.delegate && [self.delegate respondsToSelector:@selector(slideoutAccount)]) {
        [self.delegate slideoutAccount];
    }
}

- (IBAction)settingTouched
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(slideoutSettings)]) {
        [self.delegate slideoutSettings];
    }
}

- (IBAction)logoutTouched
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(slideoutLogout)]) {
        [self.delegate slideoutLogout];
    }
    [self removeBlockingButton:self->_parentView];
}

- (void)rotateImage:(UIView *)image duration:(NSTimeInterval)duration
              curve:(int)curve radians:(CGFloat)radians
{
    // Setup the animation
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:duration];
    [UIView setAnimationCurve:curve];
    [UIView setAnimationBeginsFromCurrentState:YES];
    
    // The transform matrix
    CGAffineTransform transform = CGAffineTransformMakeRotation(radians);
    image.transform = transform;
    
    // Commit the changes
    [UIView commitAnimations];
}

- (BOOL)isOpen
{
    return _open;
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    CGPoint translation = [(UIPanGestureRecognizer *)gestureRecognizer translationInView:gestureRecognizer.view.superview];
    return fabs(translation.x) > fabs(translation.y);
}

- (void)handleRecognizer:(UIPanGestureRecognizer *)recognizer fromBlock:(bool) block
{
    if(![self gestureRecognizerShouldBegin:recognizer])
    {
        return;
    }
    CGPoint translation = [recognizer translationInView:self->_parentView];
    CGPoint location = [recognizer locationInView:self->_parentView];
    int openLeftX = self->_parentView.bounds.size.width - self.bounds.size.width;
    bool halfwayOut = location.x < self->_parentView.bounds.size.width - self.bounds.size.width / 2;
    ABLog(2,@"transX, locX, centerX: %f %f %f", translation.x, location.x, self.center.x);
    
    if(recognizer.state == UIGestureRecognizerStateEnded)
    {
        [self showSlideout:halfwayOut];
        return;
    }
    else if(recognizer.state == UIGestureRecognizerStateBegan)
    {
        [self addBlockingButton:self->_parentView];
    }
    
    if(block)
    {
        //over slideout
        if(location.x >= openLeftX) {
            self.center = CGPointMake(location.x + self.bounds.size.width / 2, self.center.y);
        }
    }
    else
    {
        if(-translation.x > self.bounds.size.width) {
            self.center = CGPointMake(self->_parentView.bounds.size.width - self.bounds.size.width/2, self.center.y);
        }
        else
        {
            self.center = CGPointMake(self->_parentView.bounds.size.width + translation.x + self.bounds.size.width/2, self.center.y);
        }
    }
    
    [self updateBlockingButtonAlpha:self.frame.origin.x];
}

- (void)updateBlockingButtonAlpha:(int) frameOriginX
{
    float alpha = (self->_parentView.bounds.size.width - frameOriginX) / self->_parentView.bounds.size.width;
    if(alpha > 0.5)
    {
        alpha = 0.5;
    }
    _blockingButton.alpha = alpha;
}

- (void)addBlockingButton:(UIView *)view
{
    if(!_blockingButton)
    {
        _blockingButton = [UIButton buttonWithType:UIButtonTypeCustom];
        CGRect frame = view.bounds;
        _blockingButton.frame = frame;
        _blockingButton.backgroundColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.5];
        [self->_parentView insertSubview:_blockingButton belowSubview:self];
        _blockingButton.alpha = 0.0;
    
        [_blockingButton addTarget:self
                        action:@selector(blockingButtonHit:)
              forControlEvents:UIControlEventTouchUpInside];
        [self installPanningDetection];
    }
}

- (void)removeBlockingButton:(UIView *)view
{
    [_blockingButton removeFromSuperview];
    _blockingButton = nil;
}

- (void)blockingButtonHit:(UIButton *)button
{
    [self showSlideout:NO];
}

- (void)installPanningDetection
{
    UIPanGestureRecognizer *gesturePanOnBlocker = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleBlockingButtonPan:)];
    [self->_blockingButton addGestureRecognizer:gesturePanOnBlocker];
    UIPanGestureRecognizer *gesturePanOnSlideout = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleBlockingButtonPan:)];
    [self addGestureRecognizer:gesturePanOnSlideout];
}

// used by the guesture recognizer to ignore exit
- (BOOL)haveSubViewsShowing
{
    return NO;
}

- (void)handleBlockingButtonPan:(UIPanGestureRecognizer *) recognizer {
    [self handleRecognizer:recognizer fromBlock:YES];
}


#pragma mark - PickerTextView delegates

- (void)pickerTextViewPopupSelected:(PickerTextView *)pickerTextView onRow:(NSInteger)row
{
    [self.accountPicker dismissPopupPicker];
    
    // set the text field to the choice
    NSString *account = [self.otherAccounts objectAtIndex:row];
    [LocalSettings controller].cachedUsername = account;
    if (self.delegate && [self.delegate respondsToSelector:@selector(slideoutLogout)]) {
        [self.delegate slideoutLogout];
    }
}

- (void)pickerTextViewDidTouchAccessory:(PickerTextView *)pickerTextView categoryString:(NSString *)string
{
    _account = string;
    NSString *message = [NSString stringWithFormat:@"Delete '%@' on this device? This will disable access via PIN. If 2FA is enabled, this device will not be able to login without a 2FA reset which takes 7 days.",
                         string];
    UIAlertView *alert = [[UIAlertView alloc]
                          initWithTitle:NSLocalizedString(@"Delete Account", nil)
                          message:message
                          delegate:self
                          cancelButtonTitle:@"No"
                          otherButtonTitles:@"Yes", nil];
    [alert show];
    [self.accountPicker dismissPopupPicker];
}

- (void)pickerTextViewFieldDidShowPopup:(PickerTextView *)pickerTextView
{
    CGRect popupWindowFrame = pickerTextView.popupPicker.frame;
    
    popupWindowFrame.size.width = pickerTextView.frame.size.width;
    int height = IS_IPHONE4 ? 250 : 340;
    popupWindowFrame.size.height = height;
    pickerTextView.popupPicker.frame = popupWindowFrame;
}

- (void)removeAccount:(NSString *)account
{
    tABC_Error error;
    tABC_CC cc = ABC_AccountDelete((const char*)[account UTF8String], &error);
    if(cc == ABC_CC_Ok) {
        [self getAllAccounts];
        [self.accountPicker updateChoices:self.arrayAccounts];
    }
    else {
        [MainViewController fadingAlert:[Util errorMap:&error]];
    }
}

- (void)getAllAccounts
{
    char * pszUserNames;
    tABC_Error error;
    __block tABC_CC result = ABC_ListAccounts(&pszUserNames, &error);
    switch (result)
    {
        case ABC_CC_Ok:
        {
            NSString *str = [NSString stringWithCString:pszUserNames encoding:NSUTF8StringEncoding];
            NSArray *arrayAccounts = [str componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
            NSMutableArray *stringArray = [[NSMutableArray alloc] init];
            for(NSString *str in arrayAccounts)
            {
                if(str && str.length!=0)
                {
                    [stringArray addObject:str];
                }
            }
            self.arrayAccounts = [stringArray copy];
            break;
        }
        default:
        {
            tABC_Error temp;
            temp.code = result;
            [MainViewController fadingAlert:[Util errorMap:&temp]];
            break;
        }
    }
}

- (void)updateOtherAccounts:(NSString *)username
{
    [self getAllAccounts];
    NSMutableArray *stringArray = [[NSMutableArray alloc] init];
    for(NSString *str in self.arrayAccounts)
    {
        if(![str isEqualToString:username])
        {
            [stringArray addObject:str];
        }
    }
    self.otherAccounts = [stringArray copy];
}

#pragma mark - UIAlertView Delegate

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    // if they said they wanted to delete the account
    if (buttonIndex == 1)
    {
        [self removeAccount:_account];
    }
    [self accountTouched];
}

@end
