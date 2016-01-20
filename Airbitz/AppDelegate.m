//
//  AppDelegate.m
//  AirBitz
//
//  Created by Carson Whitsett on 2/4/14.
//  Copyright (c) 2014 AirBitz. All rights reserved.
//

#import "AppDelegate.h"
#import "ABC.h"
#import "User.h"
#import "CoreBridge.h"
#import "CommonTypes.h"
#import "PopupPickerView.h"
#import "Plugin.h"
#import "LocalSettings.h"
#import "AudioController.h"
#import "Config.h"
#import <HockeySDK/HockeySDK.h>
#import <SDWebImage/SDImageCache.h>
#import "NotificationChecker.h"
#import "NSString+StripHTML.h"
#import "Reachability.h"
#import "Util.h"
#import "Keychain.h"

UIBackgroundTaskIdentifier bgLogoutTask;
UIBackgroundTaskIdentifier bgNotificationTask;

@implementation AppDelegate

static CoreBridge *airbitzCore;

+ (CoreBridge *) abc;
{
    return airbitzCore;
}


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
    [application setStatusBarHidden:NO];
    [application setStatusBarStyle:UIStatusBarStyleDefault];

    [[SDImageCache sharedImageCache] clearDisk];
    [[SDImageCache sharedImageCache] cleanDisk];
    [[SDImageCache sharedImageCache] clearMemory];

    [LocalSettings initAll];

    [PopupPickerView initAll];

    [AudioController initAll];

    airbitzCore = [[CoreBridge alloc] init];
    [airbitzCore initAll];

    // Reset badges to 0
    application.applicationIconBadgeNumber = 0;

    // Set background fetch in seconds
    [application setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalMinimum];


    Reachability *reachability = [Reachability reachabilityWithHostname:@"www.google.com"];
    [reachability startNotifier];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                            selector:@selector(reachabilityDidChange:)
                                                name:kReachabilityChangedNotification
                                            object:nil];
    
    [application registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert|UIUserNotificationTypeBadge|UIUserNotificationTypeSound categories:nil]];
    
#if (!AIRBITZ_IOS_DEBUG) || (0 == AIRBITZ_IOS_DEBUG)
    [[BITHockeyManager sharedHockeyManager] configureWithIdentifier:HOCKEY_MANAGER_ID];
    [[BITHockeyManager sharedHockeyManager] startManager];
    [[BITHockeyManager sharedHockeyManager].authenticator authenticateInstallation];
#endif

    return YES;
}

- (void)application:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings
{
    if (notificationSettings.types & UIUserNotificationTypeAlert)
    {
        [LocalSettings controller].bLocalNotificationsAllowed = YES;
        ABLog(1, @"Local notifications allowed");
    }
    else
    {
        [LocalSettings controller].bLocalNotificationsAllowed = NO;
        ABLog(1, @"Local notifications not allowed");
    }
    
}

- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification
{
    // Reset badges to 0
    application.applicationIconBadgeNumber = 0;
}

//  sourceApplication:(NSString *)sourceApplication annotation:(id)annotation

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url
{
    NSDictionary *d = @{ KEY_URL: url };
    [[NSNotificationCenter defaultCenter] postNotificationName:ABC_NOTIFICATION_HANDLE_BITCOIN_URI object:self userInfo:d];
    return YES;
}

- (void)application:(UIApplication *)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler
{
    ABLog(2,@"ENTER performFetch...\n");

    bool bDidNotification = [self showNotifications];

    if (bDidNotification)
    {
        ABLog(2,@"EXIT performFetch() NewData...\n");
        completionHandler(UIBackgroundFetchResultNewData);
    }
    else
    {
        ABLog(2,@"EXIT performFetch() NoData...\n");
        completionHandler(UIBackgroundFetchResultNoData);
    }
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    [[SDImageCache sharedImageCache] clearDisk];
    [[SDImageCache sharedImageCache] cleanDisk];
    [[SDImageCache sharedImageCache] clearMemory];

    if ([User isLoggedIn])
    {
        [airbitzCore saveLogoutDate];
    }
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    [LocalSettings saveAll];

    bgNotificationTask = [application beginBackgroundTaskWithExpirationHandler:^{
        [self bgNotificationCleanup];
    }];

    if ([User isLoggedIn])
    {
        [airbitzCore stopQueues];
        bgLogoutTask = [application beginBackgroundTaskWithExpirationHandler:^{
            [self bgLogoutCleanup];
        }];
        if ([airbitzCore allWatchersReady])
        {
            [airbitzCore disconnectWatchers];
        }
        else
        {
            // If the watchers aren't finished, let them finish
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
                while (![airbitzCore allWatchersReady])
                {
                    // if app is active, break out of loop
                    if ([self isAppActive])
                    {
                        break;
                    }
                    sleep(5);
                }
                // if the app *is not* active, stop watchers
                if (![self isAppActive])
                {
                    [airbitzCore disconnectWatchers];
                }
            });
        }
    }
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    [self bgNotificationCleanup];
    [self bgLogoutCleanup];
    [self checkLoginExpired];
    if ([User isLoggedIn])
    {
        [airbitzCore connectWatchers];
        [airbitzCore startQueues];
    }
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    [self bringNotificationsToForeground];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    [airbitzCore stopQueues];
    [LocalSettings freeAll];

    int wait = 0;
    int maxWait = 200; // ~10 seconds
    while ([airbitzCore dataOperationCount] > 0 && wait < maxWait) {
        [NSThread sleepForTimeInterval:.2];
        wait++;
    }
    
    [[User Singleton] clear];
    ABC_Terminate();
}

- (void)watchStatus
{
}

- (void)bgLogoutCleanup
{
    [[UIApplication sharedApplication] endBackgroundTask:bgLogoutTask];
    bgLogoutTask = UIBackgroundTaskInvalid;
}

- (void)bgNotificationCleanup
{
    [[UIApplication sharedApplication] endBackgroundTask:bgNotificationTask];
    bgNotificationTask = UIBackgroundTaskInvalid;
}

// This is a fallback for auto logout. It is better to have the background task
// or network fetch log the user out
- (void)checkLoginExpired
{
    BOOL bLoginExpired;

    NSString *username;
    if ([User isLoggedIn])
        username = [User Singleton].name;
    else
        username = [LocalSettings controller].cachedUsername;

    bLoginExpired = [airbitzCore didLoginExpire:username];

    if (bLoginExpired)
    {
        // App will not auto login but we will retain login credentials
        // inside iOS Keychain so we can use TouchID
        [Keychain disableRelogin:username];
    }

    if (!bLoginExpired || ![User isLoggedIn])
    {
        return;
    }

    [self autoLogout];
}


// If the app is *not* active, log the user out
- (void)autoLogout
{

    if (![self isAppActive])
    {
        [[User Singleton] clear];
        [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_MAIN_RESET object:self];
    }
    [self bgLogoutCleanup];

}

- (BOOL)isAppActive
{
    return [UIApplication sharedApplication].applicationState == UIApplicationStateActive;
}

- (BOOL)showNotifications
{
    ABLog(2,@"ENTER showNotifications\n");

    bool bDidNotification = false;

    if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground)
    {
        [NotificationChecker requestNotifications];

        NSDictionary *notif = [NotificationChecker unseenNotification];
        while (notif)
        {
            ABLog(2,@"IN showNotifications: while loop\n");

            UILocalNotification *localNotif = [[UILocalNotification alloc] init];
            
            NSString *title = [notif objectForKey:@"title"];
            NSString *strippedTitle = [title stringByStrippingHTML];
            [localNotif setAlertTitle:strippedTitle];
            
            NSString *message = [notif objectForKey:@"message"];
            NSString *strippedMessage = [message stringByStrippingHTML];
            [localNotif setAlertBody:strippedMessage];
            
            // fire the notification now
            [localNotif setFireDate:[NSDate date]];
            [[UIApplication sharedApplication] scheduleLocalNotification:localNotif];

            // Mark seen
            [NotificationChecker setNotificationSeen:notif];

            // get the next one
            notif = [NotificationChecker unseenNotification];

            bDidNotification = true;
        };
        
        const NSTimeInterval MinTimeBetweenNoPasswordNotifications = (60 * 60 * 24); // One day
        
        //
        // Popup notification if user has accounts with no passwords
        //
        NSArray *arrayAccounts = [airbitzCore getLocalAccounts:nil];
        BOOL bDidNoPasswordNotification = false;

        [LocalSettings loadAll];
        NSTimeInterval intervalNow = [[NSDate date] timeIntervalSince1970];
        NSTimeInterval intervalLast = [LocalSettings controller].noPasswordNotificationTime;

        if (arrayAccounts)
        {
            if ((intervalNow - intervalLast) > MinTimeBetweenNoPasswordNotifications)
            {
                for (NSString *acct in arrayAccounts)
                {
                    if (![airbitzCore passwordExists:acct])
                    {
                        UILocalNotification *localNotif = [[UILocalNotification alloc] init];
                        
                        NSString *title = accountsNeedsPasswordNotificationTitle;
                        [localNotif setAlertTitle:title];
                        
                        NSString *message = [NSString stringWithFormat:accountsNeedsPasswordNotificationMessage, acct];
                        [localNotif setAlertBody:message];
                        
                        // fire the notification now
                        [localNotif setFireDate:[NSDate date]];
                        [[UIApplication sharedApplication] scheduleLocalNotification:localNotif];
                        bDidNotification = true;
                        bDidNoPasswordNotification = true;
                        
                    }
                }
            }
            
        }
        
        if (bDidNoPasswordNotification)
        {
            [LocalSettings controller].noPasswordNotificationTime = intervalNow;
            [LocalSettings saveAll];
        }
        
    }

    ABLog(2,@"EXIT showNotifications\n");

    return bDidNotification;
}

- (void)bringNotificationsToForeground
{
    if ([NotificationChecker haveNotifications])
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_NOTIFICATION_RECEIVED object:self];
    }
}

#pragma mark - Notification handlers

- (void)reachabilityDidChange:(NSNotification *)notification
{
    Reachability *reachability = (Reachability *)[notification object];
    if ([reachability isReachable]) {
        [airbitzCore restoreConnectivity];
    }
}

@end
