//
//  User.m
//  AirBitz
//
//  Created by Carson Whitsett on 3/27/14.
//  Copyright (c) 2014 AirBitz. All rights reserved.
//

#import "User.h"
#import "ABC.h"
#import "Util.h"
#import "CoreBridge.h"

#define SPENDING_LIMIT_AMOUNT  @"spending_limit_amount"
#define SPENDING_LIMIT_ENABLED @"spending_limit_enabled"

#define REVIEW_NOTIFIED @"review_notified"
#define DISCLAIMER_VIEWED @"disclaimer_viewed"
#define FIRST_LOGIN_TIME @"first_login_time"
#define LOGIN_COUNT @"login_count"
#define REQUEST_VIEW_COUNT @"request_view_count"
#define SEND_VIEW_COUNT @"send_view_count"
#define BLE_VIEW_COUNT @"ble_view_count"
#define WALLETS_VIEW_COUNT @"ble_view_count"

#define REVIEW_ACCOUNT_AGE 14
#define REVIEW_LOGIN_COUNT 7
#define REVIEW_TX_COUNT    7

#define FORCE_HELP_SCREENS 0

static BOOL bInitialized = NO;

@interface User ()
{

}
@property (nonatomic, strong)   AirbitzCore                 *airbitzCore;

@end

@implementation User

static User *singleton = nil;  // this will be the one and only object this static singleton class has

+ (void)initAll
{
    if (NO == bInitialized)
    {
        singleton = [[User alloc] init];
        bInitialized = YES;
    }
}

+ (void)freeAll
{
    if (YES == bInitialized)
    {
        // release our singleton
        singleton = nil;

        bInitialized = NO;
    }
}

+ (User *)Singleton
{
    return singleton;
}

- (id)init
{
    self = [super init];
    if(self)
    {
        [self clear];
    }
//    self.denomination = 100000000;
//    self.denominationType = ABC_DENOMINATION_UBTC;
//    self.denominationLabel = @"bits";
//    self.denominationLabelShort = @"Ƀ ";
    self.sendInvalidEntryCount = 0;
    self.sendState = kNormal;
    self.runLoop = [NSRunLoop currentRunLoop];
    self.reviewNotified = NO;
    self.bDisclaimerViewed = NO;
    self.loginCount = 0;
    self.needsPasswordCheck = NO;
    self.firstLoginTime = nil;
    self.requestViewCount = 0;
    self.sendViewCount = 0;
    self.bleViewCount = 0;

    return self;
}

- (void)login:(AirbitzCore *)airbitzCore
{
    self.airbitzCore = airbitzCore;
    [self loadLocalSettings];
}

//    tABC_Error Error;
//    tABC_AccountSettings *pSettings = NULL;
//    tABC_CC result = ABC_LoadAccountSettings([self.name UTF8String],
//                                             [self.password UTF8String],
//                                             &pSettings,
//                                             &Error);
//    if (ABC_CC_Ok == result)
//    {
//        self.minutesAutoLogout = pSettings->minutesAutoLogout;
//        self.defaultCurrencyNum = pSettings->currencyNum;
//        if (pSettings->bitcoinDenomination.satoshi > 0)
//        {
//            self.denomination = pSettings->bitcoinDenomination.satoshi;
//            self.denominationType = pSettings->bitcoinDenomination.denominationType;
//
//            switch (self.denominationType) {
//                case ABC_DENOMINATION_BTC:
//                    self.denominationLabel = @"BTC";
//                    self.denominationLabelShort = @"Ƀ ";
//                    break;
//                case ABC_DENOMINATION_MBTC:
//                    self.denominationLabel = @"mBTC";
//                    self.denominationLabelShort = @"mɃ ";
//                    break;
//                case ABC_DENOMINATION_UBTC:
//                    self.denominationLabel = @"bits";
//                    self.denominationLabelShort = @"ƀ ";
//                    break;
//
//            }
//        }
//        self.firstName = pSettings->szFirstName ? [NSString stringWithUTF8String:pSettings->szFirstName] : nil;
//        self.lastName = pSettings->szLastName ? [NSString stringWithUTF8String:pSettings->szLastName] : nil;
//        self.nickName = pSettings->szNickname ? [NSString stringWithUTF8String:pSettings->szNickname] : nil;
//        self.fullName = pSettings->szFullName ? [NSString stringWithUTF8String:pSettings->szFullName] : nil;
//        self.strPIN   = pSettings->szPIN ? [NSString stringWithUTF8String:pSettings->szPIN] : nil;
//        self.bNameOnPayments = pSettings->bNameOnPayments;
//
//        [self loadLocalSettings:pSettings];
//
//        self.bSpendRequirePin = pSettings->bSpendRequirePin;
//        self.spendRequirePinSatoshis = pSettings->spendRequirePinSatoshis;
//        self.bDisablePINLogin = pSettings->bDisablePINLogin;
//    }
//    else
//    {
//        [Util printABC_Error:&Error];
//    }
//    ABC_FreeAccountSettings(pSettings);
//}

- (NSString *)userKey:(NSString *)base
{
    return [NSString stringWithFormat:@"%@_%@", self.name, base];
}

- (void)loadLocalSettings
{
    NSUserDefaults *localConfig = [NSUserDefaults standardUserDefaults];
    self.bDisclaimerViewed = [localConfig boolForKey:DISCLAIMER_VIEWED];
    self.reviewNotified = [localConfig boolForKey:REVIEW_NOTIFIED];
    self.firstLoginTime = [localConfig objectForKey:FIRST_LOGIN_TIME];
    self.loginCount = [localConfig integerForKey:LOGIN_COUNT];
    self.requestViewCount = [localConfig integerForKey:REQUEST_VIEW_COUNT];
    self.sendViewCount = [localConfig integerForKey:SEND_VIEW_COUNT];
    self.bleViewCount = [localConfig integerForKey:BLE_VIEW_COUNT];
    self.walletsViewCount = [localConfig integerForKey:WALLETS_VIEW_COUNT];

    self.dailySpendLimitSatoshis = [[localConfig objectForKey:[self userKey:SPENDING_LIMIT_AMOUNT]] unsignedLongLongValue];
    self.bDailySpendLimit = [localConfig boolForKey:[self userKey:SPENDING_LIMIT_ENABLED]];
}

- (void)saveLocalSettings
{
    NSUserDefaults *localConfig = [NSUserDefaults standardUserDefaults];
    [localConfig setObject:@(_dailySpendLimitSatoshis) forKey:[self userKey:SPENDING_LIMIT_AMOUNT]];
    [localConfig setBool:_bDailySpendLimit forKey:[self userKey:SPENDING_LIMIT_ENABLED]];

    [localConfig setBool:self.reviewNotified forKey:REVIEW_NOTIFIED];
    [localConfig setBool:self.bDisclaimerViewed forKey:DISCLAIMER_VIEWED];
    [localConfig setObject:self.firstLoginTime forKey:FIRST_LOGIN_TIME];
    [localConfig setInteger:self.loginCount forKey:LOGIN_COUNT];
    [localConfig setInteger:self.requestViewCount forKey:REQUEST_VIEW_COUNT];
    [localConfig setInteger:self.sendViewCount forKey:SEND_VIEW_COUNT];
    [localConfig setInteger:self.bleViewCount forKey:BLE_VIEW_COUNT];
    [localConfig setInteger:self.walletsViewCount forKey:WALLETS_VIEW_COUNT];

    [localConfig synchronize];
}

- (void)clear
{
    // Delete webview cookies
    NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie *cookie in [storage cookies]) {
        [storage deleteCookie:cookie];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];

    if (self.airbitzCore && [self.airbitzCore isLoggedIn])
    {
        [_airbitzCore logout];
    }
    self.airbitzCore = nil;
}

- (SendViewState)sendInvalidEntry
{
    ++self.sendInvalidEntryCount;
    if (SEND_INVALID_ENTRY_COUNT_MAX <= self.sendInvalidEntryCount)
    {
        [self startInvalidEntryWait];
    }
    return self.sendState;
}

- (void)startInvalidEntryWait
{
    if (kInvalidEntryWait == self.sendState)
    {
        return;
    }
    
    self.sendState = kInvalidEntryWait;
    self.sendInvalidEntryCount = 0;
    self.sendInvalidEntryTimer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:INVALID_ENTRY_WAIT]
                                                  interval:INVALID_ENTRY_WAIT
                                                    target:self
                                                  selector:@selector(endInvalidEntryWait)
                                                  userInfo:@{kTimerStart : [NSDate date]}
                                                   repeats:NO];
    [self.runLoop addTimer:self.sendInvalidEntryTimer forMode:NSDefaultRunLoopMode];
}

- (void)endInvalidEntryWait
{
    if (self)
    {
        self.sendState = kNormal;
    }
}

- (NSTimeInterval)getRemainingInvalidEntryWait
{
    if (!self.sendInvalidEntryTimer || ![self.sendInvalidEntryTimer isValid]) {
        return 0;
    }
    NSDate *start = [[self.sendInvalidEntryTimer userInfo] objectForKey:kTimerStart];
    NSDate *current = [NSDate date];
    return INVALID_ENTRY_WAIT - [current timeIntervalSinceDate:start];
}


// XXX make this a localsetting
- (void)incPINorTouchIDLogin
{
    tABC_Error error;
    tABC_AccountSettings *pSettings;
    ABC_LoadAccountSettings([_name UTF8String], [_password UTF8String], &pSettings, &error);
    if (error.code == ABC_CC_Ok) {
        int pinLoginCount = ++(pSettings->pinLoginCount);
        ABC_UpdateAccountSettings([_name UTF8String], [_password UTF8String], pSettings, &error);

        if (pinLoginCount == 3
                || pinLoginCount == 10
                || pinLoginCount == 40
                || pinLoginCount == 100) {
            _needsPasswordCheck = YES;
        }
    }
}

- (BOOL)offerDisclaimer;
{
    if (self.bDisclaimerViewed)
    {
        return NO;
    }
    else
    {
        return YES;
    }
}

- (void)saveDisclaimerViewed
{
    self.bDisclaimerViewed = YES;
    [self saveLocalSettings];
}

+ (BOOL)offerUserReview
{
    if ([User Singleton].reviewNotified) {
        return NO;
    }
    BOOL ret = NO;
    BOOL timeTrigger = [User Singleton].timeUseTriggered;
    [User Singleton].loginCount++;
    if ([User Singleton].loginCount >= REVIEW_LOGIN_COUNT && timeTrigger
            && [User Singleton].transactionCountTriggered) {
        [User Singleton].reviewNotified = true;
        ret = YES;
    }
    [[User Singleton] saveLocalSettings];
    return ret;
}

- (BOOL)offerRequestHelp
{
    return [self offerHelp:&_requestViewCount
               thisSession:&_notifiedRequest];
}

- (BOOL)offerSendHelp
{
    return [self offerHelp:&_sendViewCount
               thisSession:&_notifiedSend];
}

- (BOOL)offerBleHelp
{
    return [self offerHelp:&_bleViewCount
               thisSession:&_notifiedBle];
}

- (BOOL)offerWalletHelp
{
    return [self offerHelp:&_walletsViewCount
               thisSession:&_notifiedWallet];
}
- (BOOL)offerHelp:(NSInteger *)value thisSession:(BOOL *)session
{
    if (*session) {
        return NO;
    }
    *session = YES;

    if (FORCE_HELP_SCREENS)
        return YES;

    if (*value > 2) {
        return NO;
    }
    (*value)++;
    [self saveLocalSettings];
    return *value <= 2;
}

- (BOOL)transactionCountTriggered
{
    if ([User isLoggedIn] &&
            [AppDelegate abc].arrayWallets != nil &&
            [AppDelegate abc].arrayArchivedWallets != nil)
    {
        int transactionCount = 0;
        for (Wallet *curWallet in [AppDelegate abc].arrayWallets) {
            transactionCount += [curWallet.arrayTransactions count];
        }
        for (Wallet *curWallet in [AppDelegate abc].arrayArchivedWallets) {
            transactionCount += [curWallet.arrayTransactions count];
        }
        return transactionCount >= REVIEW_TX_COUNT;
    } else {
        return NO;
    }
}

- (NSDate *)earliestDate
{
    NSDate *date = [NSDate date];

    if ([AppDelegate abc].arrayWallets != nil &&
            [AppDelegate abc].arrayArchivedWallets != nil)
    {
        for (Wallet *w in [AppDelegate abc].arrayWallets) {
            for (Transaction *t in w.arrayTransactions) {
                if (t.date && [t.date compare:date] == NSOrderedAscending) {
                    date = t.date;
                }
            }
        }
    }
    return date;
}

- (BOOL)timeUseTriggered
{
    NSDate *earliest = [self earliestDate];
    if (self.firstLoginTime == nil) {
        self.firstLoginTime = earliest;
        return NO;
    }
    if ([earliest compare:self.firstLoginTime] == NSOrderedAscending) {
        self.firstLoginTime = earliest;
    }
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *difference = [calendar components:NSCalendarUnitDay
                                                fromDate:self.firstLoginTime
                                                    toDate:[NSDate date]
                                                options:0];
    return [difference day] >= REVIEW_ACCOUNT_AGE;
}

@end
