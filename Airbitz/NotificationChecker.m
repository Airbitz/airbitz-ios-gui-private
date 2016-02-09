//
//  NotificationChecker.m
//  AirBitz
//
//  Created by Allan on 11/24/14.
//  Copyright (c) 2014 AirBitz. All rights reserved.
//

#import "NotificationChecker.h"
#import "Server.h"
#import "CommonTypes.h"
#import "LocalSettings.h"
#import "CJSONDeserializer.h"
#import "User.h"
#import "AirbitzCore.h"
#import "Util.h"
#import "MainViewController.h"

#define OTP_NOTIFICATION          @"otp_notification"
#define OTP_TIME                  @"otp_time"
#define OTP_REPEAT_PERIOD         60 * 60 * 24
#define NOTIFICATION_SEEN_KEY     @"viewed"
#define NOTIFICATION_SHOWN_IN_APP @"shown_in_app"

static BOOL bInitialized = NO;
static NotificationChecker *singleton = nil;

@interface NotificationChecker ()
{
    NSTimer *_notificationTimer;
}

@property (strong, nonatomic) AFHTTPRequestOperationManager         *afmanager;

@end

@implementation NotificationChecker

#pragma mark Public Methods
+ (void)initAll
{
    if (NO == bInitialized)
    {
        singleton = [[NotificationChecker alloc] init];
        singleton.afmanager = [MainViewController createAFManager];

        bInitialized = YES;
        [singleton start];
    }
}

+ (void)freeAll
{
    if (YES == bInitialized)
    {
//        [[DL_URLServer controller] cancelAllRequestsForDelegate:singleton];
        singleton = nil;
        bInitialized = NO;
    }
}

+ (void)requestNotifications
{
    ABCLog(2,@"ENTER requestNotifications\n");
    [singleton checkOtpResetPending];
    [singleton checkDirectoryNotifications];
    ABCLog(2,@"EXIT requestNotifications\n");
}

+ (NSDictionary *)haveNotifications
{
    return [singleton haveNotifications];
}

+ (NSDictionary *)firstNotification
{
    return [singleton getNextNotification];
}

+ (NSDictionary *)unseenNotification
{
    return [singleton getFirstUnseenNotification];
}

#pragma mark Private Methods

- (NSDictionary *)haveNotifications
{
    return [[LocalSettings controller].notifications firstObject];
}

- (NSDictionary *)getNextNotification
{
    NSDictionary *notif = [[LocalSettings controller].notifications firstObject];
    if (notif) {
        [[LocalSettings controller].notifications removeObject:notif];
        [LocalSettings saveAll];
        return notif;
    }
    int i = 0;
    // Find the first unseen notification
    for (NSDictionary *dict in [LocalSettings controller].otpNotifications) {
        NSNumber *shown = [dict objectForKey:NOTIFICATION_SHOWN_IN_APP];
        if (![shown boolValue]) {
            notif = dict;
            break;
        }
        i++;
    }
    if (notif) {
        NSMutableDictionary *temp = [notif mutableCopy];
        [temp setValue:[NSNumber numberWithBool:YES] 
                forKey:NOTIFICATION_SEEN_KEY];
        [temp setValue:[NSNumber numberWithBool:YES]
                forKey:NOTIFICATION_SHOWN_IN_APP];
        [[LocalSettings controller].otpNotifications
            replaceObjectAtIndex:i withObject:temp];
        [LocalSettings saveAll];
    }
    return notif;
}

- (NSDictionary *)getFirstUnseenNotification
{
    ABCLog(2,@"ENTER getFirstUnseenNotification\n");

    NSArray *arrays = @[[LocalSettings controller].notifications,
                        [LocalSettings controller].otpNotifications];
    for (NSMutableArray *array in arrays) {
        int i = 0;
        for (NSDictionary *notif in array) {
            NSNumber *seen = [notif objectForKey:NOTIFICATION_SEEN_KEY];
            if (nil == seen || ![seen boolValue]) {
                ABCLog(2,@"EXIT getFirstUnseenNotification: %@\n", notif);
                return notif;
            }
            i++;
        }
    }
    ABCLog(2,@"EXIT getFirstUnseenNotification: nil\n");

    return nil;
}

- (void)postNotification
{
    ABCLog(2,@"GO postNotification\n");

    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_NOTIFICATION_RECEIVED object:self];
}
//
// Set a notification as SEEN
//
+ (BOOL)setNotificationSeen:(NSDictionary *)setSeenNotif
{
    ABCLog(2,@"ENTER setNotificationSeen\n");

    NSArray *arrays = @[[LocalSettings controller].notifications,
            [LocalSettings controller].otpNotifications];

    //
    // Verify that this notification is in our notification pool
    //
    for (NSMutableArray *array in arrays) {
        int i = 0;
        for (NSDictionary *notif in array) {
            if (notif == setSeenNotif)
            {
                NSNumber *seen = [notif objectForKey:NOTIFICATION_SEEN_KEY];

                if (nil == seen || ![seen boolValue])
                {
                    // add the seen key to the dictionary
                    NSMutableDictionary *temp = [setSeenNotif mutableCopy];
                    [temp setValue:[NSNumber numberWithBool:YES] forKey:NOTIFICATION_SEEN_KEY];
                    [array replaceObjectAtIndex:i withObject:temp];

                    [LocalSettings saveAll];
                    ABCLog(2,@"EXIT setNotificationSeen: true %@\n",notif);

                    return true;
                }
            }
            i++;
        }
    }
    ABCLog(2,@"EXIT setNotificationSeen: false\n");
    return false;
}


- (void)start
{
    if (nil == [LocalSettings controller].notifications)
    {
        [LocalSettings controller].notifications = [[NSMutableArray alloc] init];
    }
    _notificationTimer = [NSTimer scheduledTimerWithTimeInterval:NOTIF_PULL_REFRESH_INTERVAL_SECONDS
                                                          target:self
                                                        selector:@selector(checkNotifications)
                                                        userInfo:nil
                                                         repeats:YES];

    [_notificationTimer fire];
}

- (void)checkNotifications
{
    ABCLog(2,@"ENTER checkNotifications\n");
    [self checkOtpResetPending];

    [self checkDirectoryNotifications];

    if ([self getFirstUnseenNotification] != nil)
    {
        [self postNotification];
    }
    ABCLog(2,@"EXIT checkNotifications\n");
}

+ (void)resetOtpNotifications
{
    int i = 0;
    while (i < [[LocalSettings controller].otpNotifications count]) {
        NSDictionary *notif = [[LocalSettings controller].otpNotifications firstObject];
        if ([[notif objectForKey:@"id"] isEqualToString:abcUser.name]) {
            [[LocalSettings controller].otpNotifications removeObject:notif];
            break;
        }
        i++;
    }
    [LocalSettings saveAll];
}

- (void)resetOtpNotification:(NSDictionary *)notif
{

    [[LocalSettings controller].otpNotifications removeObject:notif];

    [LocalSettings saveAll];
}

- (void)checkOtpResetPending
{
    NSArray *arrayUsers = [abc getOTPResetUsernames];
    
    if (!arrayUsers) return;

    for (NSString *username in arrayUsers)
    {
        if (!username || ![username length])
        {
            continue;
        }

        bool bHasNotification = false;

        // If there is already an OTP notification, then if it's over a day old, replace it, else ignore it
        for (NSDictionary *d in [LocalSettings controller].otpNotifications)
        {
            if ([[d objectForKey:@"id"] isEqualToString:username])
            {
                //
                // Already a notification for this user
                //
                bHasNotification = true;
                double currentTime = [[NSDate date] timeIntervalSince1970]; // in seconds
                double notifBegan = [[d objectForKey:@"otp_time"] doubleValue];
                double delta = currentTime - notifBegan;

                //
                // If notification is older than the repeat period, then remove this user's notification
                // and re-add it below with new timestamp
                //
                if (delta > OTP_REPEAT_PERIOD)
                {
                    [self resetOtpNotification:d];

                    // Must break out of otpNotifications loop since we have modified the dictionary
                    // during the reset
                }
                break;

            }
        }

        if (!bHasNotification)
        {
            NSMutableDictionary *notif = [[NSMutableDictionary alloc] init];
            [notif setObject:username forKey:@"id"];
            [notif setObject:OTP_NOTIFICATION forKey:@"type"];
            [notif setValue:[NSNumber numberWithBool:NO] forKey:NOTIFICATION_SEEN_KEY];
            [notif setValue:[NSNumber numberWithBool:NO] forKey:NOTIFICATION_SHOWN_IN_APP];
            [notif setValue:[NSNumber numberWithDouble:[[NSDate date] timeIntervalSince1970]] forKey:OTP_TIME];
            [notif setObject:NSLocalizedString(@"Two Factor Reset", nil) forKey:@"title"];
            NSString *message = [NSString stringWithFormat:
                    @"A two factor reset has been requested. Please login as %@ and approve or cancel the request.", username];
            [notif setObject:NSLocalizedString(message, nil) forKey:@"message"];
            [[LocalSettings controller].otpNotifications addObject:notif];
        }

    }
}

- (void)checkDirectoryNotifications
{
    NSInteger prevNotifID = [LocalSettings controller].previousNotificationID;
    NSString *build = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    build = [build stringByReplacingOccurrencesOfString:@"." withString:@""];
    build = [build stringByReplacingOccurrencesOfString:@"-" withString:@""];
    NSString *serverQuery = [NSString stringWithFormat:@"%@/notifications/?since_id=%ld&ios_build=%@",
                             SERVER_API, (long)prevNotifID, build];
    
    [self.afmanager GET:serverQuery parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        NSDictionary *results = (NSDictionary *)responseObject;
        
        if ([results objectForKey: @"results"] != (id)[NSNull null])
        {
            NSArray *notifsArray;
            notifsArray = [[results objectForKey:@"results"] copy];
            
            NSInteger highestNotifID = [LocalSettings controller].previousNotificationID;
            for(NSDictionary *dict in notifsArray)
            {
                NSInteger notifID = [[dict objectForKey:@"id"] intValue];
                if (highestNotifID < notifID)
                {
                    highestNotifID = notifID;
                }
                [[LocalSettings controller].notifications addObject:dict];
            }
            
            [LocalSettings controller].previousNotificationID = highestNotifID;
            [LocalSettings saveAll];
            
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        ABCLog(1, @"*** ERROR Connecting to Network: checkDirectoryNotifications");
    }];
    
}

@end
