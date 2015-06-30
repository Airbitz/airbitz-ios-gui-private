//
//  PasswordVerifyView.m
//  AirBitz
//
//  Created by Carson Whitsett on 3/21/14.
//  Copyright (c) 2014 AirBitz. All rights reserved.
//

#import "PasswordVerifyView.h"
#import "ABC.h"
#import "Util.h"
#import "Theme.h"

@interface PasswordVerifyView ()

@property (nonatomic, weak) IBOutlet UILabel *crackMessageLabel;

@end

@implementation PasswordVerifyView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

+ (PasswordVerifyView *)CreateInsideView:(UIView *)parentView withDelegate:(id<PasswordVerifyViewDelegate>)delegate
{
	PasswordVerifyView *pv;
	
    pv = [[[NSBundle mainBundle] loadNibNamed:@"PasswordVerifyView" owner:nil options:nil] objectAtIndex:0];

	[parentView addSubview:pv];
	CGRect frame = pv.frame;
//	frame.origin.x = (parentView.frame.size.width - frame.size.width) / 2;
    frame.origin.x = 0;
	frame.origin.y = -frame.size.height;
	pv.frame = frame;
	pv.delegate = delegate;
//	pv.layer.cornerRadius = 5;
//    pv.layer.shadowColor = [[UIColor blackColor] CGColor];
//    pv.layer.shadowRadius = 5.0f;
//    pv.layer.shadowOpacity = 1.0f;
//    pv.layer.shadowOffset = CGSizeMake(0.0, 0.0);
//    pv.layer.masksToBounds = NO;
	
	[UIView animateWithDuration:0.35
						  delay:0.0
						options:UIViewAnimationOptionCurveEaseInOut
					 animations:^
	 {
		 CGRect frame = pv.frame;
		 frame.origin.y = 0.0;
		 pv.frame = frame;
		 
		 
	 }
					 completion:^(BOOL finished)
	 {
		 //self.dividerView.alpha = 0.0;
	 }];
	return pv;
}

-(void)dismiss
{
	[UIView animateWithDuration:0.35
						  delay:0.0
						options:UIViewAnimationOptionCurveEaseInOut
					 animations:^
	 {
		 CGRect frame = self.frame;
		 frame.origin.y = -frame.size.height;
		 self.frame = frame;
		 
		 
	 }
	 completion:^(BOOL finished)
	 {
		 [self.delegate PasswordVerifyViewDismissed:self];
	 }];
}

-(void)setPassword:(NSString *)password
{
	_password = password;
	
	tABC_Error Error;
	tABC_PasswordRule **aRules = NULL;
    unsigned int count = 0;
    double secondsToCrack;
	
    ABC_CheckPassword([self.password UTF8String],
                      &secondsToCrack,
                      &aRules,
                      &count,
                      &Error);
    [Util printABC_Error:&Error];
	
    printf("Password results:\n");
    printf("Time to crack: %lf seconds\n", secondsToCrack);
    NSMutableString *crackString = [[NSMutableString alloc] initWithString:[Theme Singleton].TimeToCrackPassword];
    
    if(secondsToCrack < 60.0)
	{
		[crackString appendFormat:@"%.2lf seconds", secondsToCrack];
	}
	else if(secondsToCrack < 3600)
	{
		[crackString appendFormat:@"%.2lf minutes", secondsToCrack / 60.0];
	}
	else if(secondsToCrack < 86400)
	{
		[crackString appendFormat:@"%.2lf hours", secondsToCrack / 3600.0];
	}
	else if(secondsToCrack < 604800)
	{
		[crackString appendFormat:@"%.2lf days", secondsToCrack / 86400.0];
	}
	else if(secondsToCrack < 604800)
	{
		[crackString appendFormat:@"%.2lf days", secondsToCrack / 86400.0];
	}
	else if(secondsToCrack < 2419200)
	{
		[crackString appendFormat:@"%.2lf weeks", secondsToCrack / 604800.0];
	}
	else if(secondsToCrack < 29030400)
	{
		[crackString appendFormat:@"%.2lf months", secondsToCrack / 2419200.0];
	}
	else
	{
		[crackString appendFormat:@"%.2lf years", secondsToCrack / 29030400.0];
	}
	self.crackMessageLabel.text = crackString;
    for (int i = 0; i < count; i++)
    {
        tABC_PasswordRule *pRule = aRules[i];
        printf("%s - %s\n", pRule->bPassed ? "pass" : "fail", pRule->szDescription);
		UIImageView *imageView = (UIImageView *)[self viewWithTag:i + 10];
		if(imageView)
		{
			if(pRule->bPassed)
			{
				imageView.image = [UIImage imageNamed:@"Green-check"];
			}
			else
			{
				imageView.image = [UIImage imageNamed:@"White-Dot"];
			}
		}
		
		UILabel* label = (UILabel *)[self viewWithTag:i + 20];
		//NSLog(@"curent tag: %i for view: %@", i, label);
		if(label)
		{
			label.text = [NSString stringWithFormat:@"%s", pRule->szDescription];
		}
    }
	
    ABC_FreePasswordRuleArray(aRules, count);
	
}

@end
