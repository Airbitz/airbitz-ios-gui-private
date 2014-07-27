//
//  AnnotationContentView.m
//  AirBitz
//
//  Created by Carson Whitsett on 2/23/14.
//  Copyright (c) 2014 AirBitz. All rights reserved.
//

#import "AnnotationContentView.h"
#import <QuartzCore/QuartzCore.h>

@implementation AnnotationContentView

+ (AnnotationContentView *)Create
{
	AnnotationContentView *av = nil;
	
	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
	{
		av = [[[NSBundle mainBundle] loadNibNamed:@"AnnotationContentView" owner:nil options:nil] objectAtIndex:0];
	}
	/*else
	{
		av = [[[NSBundle mainBundle] loadNibNamed:@"HowToPlayView~ipad" owner:nil options:nil] objectAtIndex:0];
		
	}*/
	av.bkg_image.layer.cornerRadius = 4.0;
	[av addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:av action:@selector(AnnotationContentTapped:)]];
	return av;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}


- (void)AnnotationContentTapped:(UITapGestureRecognizer *)recognizer
{
	//NSLog(@"Content Tapped!");
}

-(UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
	UIView *hitView = [super hitTest:point withEvent:event];
	
	//NSLog(@"Content HitView: %@", hitView);
	return hitView;
}

@end
