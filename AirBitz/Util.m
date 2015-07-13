//
//  Util.m
//  AirBitz
//
//  Created by Adam Harris on 5/19/14.
//  Copyright (c) 2014 AirBitz. All rights reserved.
//

#import "Util.h"
#import "ABC.h"
#import "CommonTypes.h"
#import "AirbitzViewController.h"
#import "Theme.h"

@implementation Util

+ (NSString *)errorMap:(const tABC_Error *)pError
{
    switch (pError->code)
    {
        case ABC_CC_AccountAlreadyExists:
            return [Theme Singleton].AccountAlreadyExistsText;
        case ABC_CC_AccountDoesNotExist:
            return [Theme Singleton].AccountDoesNotExistText;
        case ABC_CC_BadPassword:
            return [Theme Singleton].InvalidPasswordOrUsernameText;
        case ABC_CC_WalletAlreadyExists:
            return [Theme Singleton].WalletAlreadyExistsText;
        case ABC_CC_InvalidWalletID:
            return [Theme Singleton].InvalidWalletIdText;
        case ABC_CC_URLError:
        case ABC_CC_ServerError:
            return [Theme Singleton].ServerErrorForAirbitzText;
        case ABC_CC_NoRecoveryQuestions:
            return [Theme Singleton].NoRecoveryQuestionsText;
        case ABC_CC_NotSupported:
            return [Theme Singleton].NotSupportedText;
        case ABC_CC_InsufficientFunds:
            return [Theme Singleton].InsufficientFundsText;
        case ABC_CC_SpendDust:
            return [Theme Singleton].AmountTooSmallAlert;
        case ABC_CC_Synchronizing:
            return [Theme Singleton].SynchronizingNetworkText;
        case ABC_CC_NonNumericPin:
            return [Theme Singleton].NonNumericPinText;
        case ABC_CC_InvalidPinWait:
        {
            NSString *description = [NSString stringWithUTF8String:pError->szDescription];
            if ([@"0" isEqualToString:description]) {
                return [Theme Singleton].IncorrectPINText;
            } else {
                return [NSString stringWithFormat:
                            NSLocalizedString(@"Too many failed login attempts. Please try again in %@ seconds.", nil),
                            description];
            }
        }
        case ABC_CC_Error:
        case ABC_CC_NULLPtr:
        case ABC_CC_NoAvailAccountSpace:
        case ABC_CC_DirReadError:
        case ABC_CC_FileOpenError:
        case ABC_CC_FileReadError:
        case ABC_CC_FileWriteError:
        case ABC_CC_FileDoesNotExist:
        case ABC_CC_UnknownCryptoType:
        case ABC_CC_InvalidCryptoType:
        case ABC_CC_DecryptError:
        case ABC_CC_DecryptFailure:
        case ABC_CC_EncryptError:
        case ABC_CC_ScryptError:
        case ABC_CC_SysError:
        case ABC_CC_NotInitialized:
        case ABC_CC_Reinitialization:
        case ABC_CC_JSONError:
        case ABC_CC_MutexError:
        case ABC_CC_NoTransaction:
        case ABC_CC_ParseError:
        case ABC_CC_NoRequest:
        case ABC_CC_NoAvailableAddress:
        default:
            return [Theme Singleton].AnErrorOccurredText;
    }
}

+ (void)printABC_Error:(const tABC_Error *)pError
{
    if (pError)
    {
        if (pError->code != ABC_CC_Ok)
        {
            printf("Code: %d, Desc: %s, Func: %s, File: %s, Line: %d\n",
                   pError->code,
                   pError->szDescription,
                   pError->szSourceFunc,
                   pError->szSourceFile,
                   pError->nSourceLine
                   );
        }
        if (pError->code == ABC_CC_DecryptError
                    || pError->code == ABC_CC_DecryptFailure)
        {
            [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_MAIN_RESET object:self];
        }
    }
}

// resizes a view that is one of the tab bar screens to the approriate size to avoid the toolbar
// display view is if the view has a sub-view that also does not include the top 'name of screen' bar
+ (void)resizeView:(UIView *)theView withDisplayView:(UIView *)theDisplayView
{
//    CGRect frame;
//
//    if (theView)
//    {
//        frame = theView.frame;
//        frame.size.height = SUB_SCREEN_HEIGHT;
//        theView.frame = frame;
//    }
//
//    if (theDisplayView)
//    {
//        frame = theDisplayView.frame;
//        frame.size.height = DISPLAY_AREA_HEIGHT;
//        theDisplayView.frame = frame;
//    }
}

+(CGRect)currentScreenBoundsDependOnOrientation
{

    CGRect screenBounds = [UIScreen mainScreen].bounds ;
    CGFloat width = CGRectGetWidth(screenBounds)  ;
    CGFloat height = CGRectGetHeight(screenBounds) ;
    UIInterfaceOrientation interfaceOrientation = [UIApplication sharedApplication].statusBarOrientation;

    if(UIInterfaceOrientationIsPortrait(interfaceOrientation)){
        screenBounds.size = CGSizeMake(width, height);
    }else if(UIInterfaceOrientationIsLandscape(interfaceOrientation)){
        screenBounds.size = CGSizeMake(height, width);
    }
    return screenBounds ;
}


+ (void)freeStringArray:(char **)aszStrings count:(unsigned int)count
{
    if ((aszStrings != NULL) && (count > 0))
    {
        for (int i = 0; i < count; i++)
        {
            free(aszStrings[i]);
        }
        free(aszStrings);
    }
}

// creates the full name from an address book record
+ (NSString *)getNameFromAddressRecord:(ABRecordRef)person
{
    NSString *strFirstName = (__bridge_transfer NSString*)ABRecordCopyValue(person, kABPersonFirstNameProperty);
    NSString *strMiddleName = (__bridge_transfer NSString*)ABRecordCopyValue(person, kABPersonMiddleNameProperty);
    NSString *strLastName  = (__bridge_transfer NSString*)ABRecordCopyValue(person, kABPersonLastNameProperty);

    NSMutableString *strFullName = [[NSMutableString alloc] init];
    if (strFirstName)
    {
        if ([strFirstName length])
        {
            [strFullName appendString:strFirstName];
        }
    }
    if (strMiddleName)
    {
        if ([strMiddleName length])
        {
            if ([strFullName length])
            {
                [strFullName appendString:@" "];
            }
            [strFullName appendString:strMiddleName];
        }
    }
    if (strLastName)
    {
        if ([strLastName length])
        {
            if ([strFullName length])
            {
                [strFullName appendString:@" "];
            }
            [strFullName appendString:strLastName];
        }
    }

    // if we don't have a name yet, try the company
    if ([strFullName length] == 0)
    {
        NSString *strCompanyName  = (__bridge_transfer NSString*)ABRecordCopyValue(person, kABPersonOrganizationProperty);
        if (strCompanyName)
        {
            if ([strCompanyName length])
            {
                [strFullName appendString:strCompanyName];
            }
        }
    }

    return strFullName;
}

+ (void)callTelephoneNumber:(NSString *)telNum
{
    static UIWebView *webView = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        webView = [UIWebView new];
    });
    [webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:telNum]]];
}

+ (UIViewController *)animateIn:(NSString *)identifier parentController:(UIViewController *)parent
{
    return [Util animateIn:identifier storyboard:@"Main_iPhone" parentController:parent];
}

+ (UIViewController *)animateIn:(NSString *)identifier storyboard:(NSString *)storyboardName parentController:(UIViewController *)parent
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:storyboardName bundle: nil];
    UIViewController *controller = [storyboard instantiateViewControllerWithIdentifier:identifier];
    return [Util animateController:controller parentController:parent];
}

+ (UIViewController *)animateController:(UIViewController *)controller parentController:(UIViewController *)parent
{
    CGRect frame = parent.view.bounds;
    frame.origin.x = frame.size.width;
    controller.view.frame = frame;
    [parent.view addSubview:controller.view];

    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
    [UIView animateWithDuration:0.35
                            delay:0.0
                        options:UIViewAnimationOptionCurveEaseInOut
                        animations:^
        {
            controller.view.frame = parent.view.bounds;
        }
                        completion:^(BOOL finished)
        {
            [[UIApplication sharedApplication] endIgnoringInteractionEvents];
        }];
    return controller;
}

+ (void)animateOut:(UIViewController *)controller parentController:(UIViewController *)parent complete:(void(^)(void))cb
{
    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
    [UIView animateWithDuration:0.35
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^ {
        CGRect frame = parent.view.bounds;
        frame.origin.x = frame.size.width;
        controller.view.frame = frame;
    }
    completion:^(BOOL finished) {
        [controller.view removeFromSuperview];
        [[UIApplication sharedApplication] endIgnoringInteractionEvents];
        cb();
    }];
}

+ (UIImage *)dataToImage:(const unsigned char *)data withWidth:(int)width andHeight:(int)height
{
	//converts raw monochrome bitmap data (each byte is a 1 or a 0 representing a pixel) into a UIImage
	char *pixels = malloc(4 * width * width);
	char *buf = pixels;
		
	for (int y = 0; y < height; y++)
	{
		for (int x = 0; x < width; x++)
		{
			if (data[(y * width) + x] & 0x1)
			{
				//printf("%c", '*');
				*buf++ = 0;
				*buf++ = 0;
				*buf++ = 0;
				*buf++ = 255;
			}
			else
			{
				printf(" ");
				*buf++ = 255;
				*buf++ = 255;
				*buf++ = 255;
				*buf++ = 255;
			}
		}
		//printf("\n");
	}
	
	CGContextRef ctx;
	CGImageRef imageRef;
	
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	ctx = CGBitmapContextCreate(pixels,
								(float)width,
								(float)height,
								8,
								width * 4,
								colorSpace,
								(CGBitmapInfo)kCGImageAlphaPremultipliedLast ); //documentation says this is OK
	CGColorSpaceRelease(colorSpace);
	imageRef = CGBitmapContextCreateImage (ctx);
	UIImage* rawImage = [UIImage imageWithCGImage:imageRef];
	
	CGContextRelease(ctx);
	CGImageRelease(imageRef);
	free(pixels);
	return rawImage;
}

+ (void)stylizeTextView:(UITextView *)textField
{
    textField.tintColor = [UIColor whiteColor];
    
    [textField.layer setBackgroundColor:[[[UIColor blackColor] colorWithAlphaComponent:0.3] CGColor]];
    [textField.layer setBorderColor:[[[UIColor colorWithRed:0.8 green:0.8 blue:0.8 alpha:0.5] colorWithAlphaComponent:1.0] CGColor]];
    [textField.layer setBorderWidth:0.7];
    
    //The rounded corner part, where you specify your view's corner radius:
    textField.layer.cornerRadius = 5;
    textField.clipsToBounds = YES;
    
}

+ (void)stylizeTextField:(UITextField *)textField
{
    UIView *paddingView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 20)];
    textField.leftView = paddingView;
    textField.leftViewMode = UITextFieldViewModeAlways;
    textField.tintColor = [UIColor whiteColor];

    [textField.layer setBackgroundColor:[[[UIColor blackColor] colorWithAlphaComponent:0.3] CGColor]];
    [textField.layer setBorderColor:[[[UIColor colorWithRed:0.8 green:0.8 blue:0.8 alpha:0.5] colorWithAlphaComponent:1.0] CGColor]];
    [textField.layer setBorderWidth:1.0];
    
    //The rounded corner part, where you specify your view's corner radius:
    textField.layer.cornerRadius = 5;
    textField.clipsToBounds = YES;

}

+ (void)checkPasswordAsync:(NSString *)password withSelector:(SEL)selector controller:(UIViewController *)controller
{
    if (!password || [password length] == 0) {
        if ([CoreBridge passwordExists]) {
            [controller performSelectorOnMainThread:selector
                withObject:[NSNumber numberWithBool:NO] waitUntilDone:NO];
        } else {
            [controller performSelectorOnMainThread:selector
                withObject:[NSNumber numberWithBool:YES] waitUntilDone:NO];
        }
    } else {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
            BOOL matched = [CoreBridge passwordOk:password];
            [controller performSelectorOnMainThread:selector
                withObject:[NSNumber numberWithBool:matched] waitUntilDone:NO];
        });
    }
}

+ (NSString *)urlencode:(NSString *)url
{
    url = [url stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    url = [url stringByReplacingOccurrencesOfString:@":" withString:@"%3A"];
    url = [url stringByReplacingOccurrencesOfString:@"=" withString:@"%3D"];
    return [url stringByReplacingOccurrencesOfString:@"?" withString:@"%3F"];
}

+ (NSMutableDictionary *)getUrlParameters:(NSURL *)url
{
    NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
    for (NSString *param in [[url query] componentsSeparatedByString:@"&"]) {
        NSArray *split = [param componentsSeparatedByString:@"="];
        if ([split count] > 1) {
            [params setValue:[split[1] stringByRemovingPercentEncoding] forKey:split[0]];
        }
    }
    return params;
}

+ (BOOL)isValidCategory:(NSString *)category
{
    return [category hasPrefix:[Theme Singleton].ExpenseText]
            || [category hasPrefix:[Theme Singleton].IncomeText]
            || [category hasPrefix:[Theme Singleton].TransferText]
            || [category hasPrefix:[Theme Singleton].ExchangeText];
}

+ (NSArray *)insertSubviewControllerWithConstraints:(UIView *)parentView child:(AirbitzViewController *)childViewController belowSubView:(UIView *)belowView
{
    NSArray *constraints = [Util insertSubviewWithConstraints:parentView child:childViewController.view belowSubView:belowView];
    childViewController.leftConstraint = [constraints objectAtIndex:0];
    return constraints;
}
+ (NSArray *)insertSubviewControllerWithConstraints:(UIView *)parentView child:(AirbitzViewController *)childViewController aboveSubView:(UIView *)aboveView
{
    NSArray *constraints = [Util insertSubviewWithConstraints:parentView child:childViewController.view aboveSubView:aboveView];
    childViewController.leftConstraint = [constraints objectAtIndex:0];
    return constraints;
}
+ (NSArray *)addSubviewControllerWithConstraints:(UIView *)parentView child:(AirbitzViewController *)childViewController
{
    NSArray *constraints = [Util addSubviewWithConstraints:parentView child:childViewController.view];
    childViewController.leftConstraint = [constraints objectAtIndex:0];
    return constraints;
}
+ (NSArray *)insertSubviewWithConstraints:(UIView *)parentView child:(UIView *)childView belowSubView:(UIView *)belowView
{
    NSMutableArray *constraints = [[NSMutableArray alloc] init];

    [childView setTranslatesAutoresizingMaskIntoConstraints:NO];
    NSDictionary *viewsDictionary = NSDictionaryOfVariableBindings(childView, parentView);
    [parentView insertSubview:childView belowSubview:belowView];

    [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-0-[childView]" options:0 metrics:nil views:viewsDictionary]];
    [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-0-[childView]" options:0 metrics:nil views:viewsDictionary]];
    [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[parentView(==childView)]" options:0 metrics:nil views:viewsDictionary]];
    [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[parentView(==childView)]" options:0 metrics:nil views:viewsDictionary]];

    [parentView addConstraints:constraints];
    [parentView layoutIfNeeded];

    return constraints;

}
+ (NSArray *)insertSubviewWithConstraints:(UIView *)parentView child:(UIView *)childView aboveSubView:(UIView *)aboveView
{
    NSMutableArray *constraints = [[NSMutableArray alloc] init];

    [childView setTranslatesAutoresizingMaskIntoConstraints:NO];
    NSDictionary *viewsDictionary = NSDictionaryOfVariableBindings(childView, parentView);
    [parentView insertSubview:childView aboveSubview:aboveView];
    [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-0-[childView]" options:0 metrics:nil views:viewsDictionary]];
    [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-0-[childView]" options:0 metrics:nil views:viewsDictionary]];
    [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[parentView(==childView)]" options:0 metrics:nil views:viewsDictionary]];
    [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[parentView(==childView)]" options:0 metrics:nil views:viewsDictionary]];

    [parentView addConstraints:constraints];
    [parentView layoutIfNeeded];

    return constraints;

}
+ (NSArray *)addSubviewWithConstraints:(UIView *)parentView child:(UIView *)childView
{
    NSMutableArray *constraints = [[NSMutableArray alloc] init];

    [childView setTranslatesAutoresizingMaskIntoConstraints:NO];
    NSDictionary *viewsDictionary = NSDictionaryOfVariableBindings(childView, parentView);
    [parentView addSubview:childView];
    [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-0-[childView]" options:0 metrics:nil views:viewsDictionary]];
    [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-0-[childView]" options:0 metrics:nil views:viewsDictionary]];
    [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[parentView(==childView)]" options:0 metrics:nil views:viewsDictionary]];
    [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[parentView(==childView)]" options:0 metrics:nil views:viewsDictionary]];

    [parentView addConstraints:constraints];
    [parentView layoutIfNeeded];

    return constraints;
}


@end

@implementation NSString (reverse)
 
+ (NSString *)safeStringWithUTF8String:(const char *)bytes;
{
    if (bytes) {
        return [NSString stringWithUTF8String:bytes];
    } else {
        return @"";
    }
}
 
@end
