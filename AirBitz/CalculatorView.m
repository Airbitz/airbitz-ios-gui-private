//
//  CalculatorView.m
//  AirBitz
//
//  Created by Carson Whitsett on 4/2/14.
//  Copyright (c) 2014 AirBitz. All rights reserved.
//

#import "CalculatorView.h"
#import "CoreBridge.h"

#define DIGIT_BACK			11

#define OPERATION_CLEAR		0
#define OPERATION_DONE		2
#define OPERATION_DIVIDE	3
#define OPERATION_EQUAL		4
#define OPERATION_MINUS		5
#define OPERATION_MULTIPLY	6
#define OPERATION_PLUS		7
#define OPERATION_PERCENT	8

@interface CalculatorView ()
{
	float accumulator;
	int operation;
	BOOL lastKeyWasOperation;
}

@end

@implementation CalculatorView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
	{
        // Initialization code
        _calcMode = CALC_MODE_COIN;
    }
    return self;
}

-(id)initWithCoder:(NSCoder *)aDecoder
{
    if ((self = [super initWithCoder:aDecoder]))
	{
        _calcMode = CALC_MODE_COIN;
        [self addSubview:[[[NSBundle mainBundle] loadNibNamed:@"CalculatorView~iphone" owner:self options:nil] objectAtIndex:0]];
    }
    return self;
}

-(void)loadAccumulator
{
	accumulator = [self.textField.text floatValue];
}

-(NSString *)formattedAcc: (float) acc
{
    if (_calcMode == CALC_MODE_COIN)
    {
        int64_t satoshi = [CoreBridge denominationToSatoshi:[NSString stringWithFormat:@"%f", acc]];
        return [CoreBridge formatSatoshi:satoshi withSymbol:false];
    }
    else
        return [CoreBridge formatCurrency:acc withSymbol:false];
}

-(void)performLastOperation
{
	switch(operation)
	{
		case OPERATION_CLEAR:
		case OPERATION_DONE:
			//NSLog(@"Performing loadAccumulator");
			[self loadAccumulator];
			break;
		case OPERATION_DIVIDE:
			//NSLog(@"Performing Divide");
			accumulator /= [self.textField.text floatValue];
            self.textField.text = [self formattedAcc:accumulator];
			break;
		case OPERATION_EQUAL:
			//NSLog(@"Performing Equal");
			break;
		case OPERATION_MINUS:
			//NSLog(@"Performing Minus");
			accumulator -= [self.textField.text floatValue];
            self.textField.text = [self formattedAcc:accumulator];
			break;
		case OPERATION_MULTIPLY:
			//NSLog(@"Performing Multiply");
			accumulator *= [self.textField.text floatValue];
            self.textField.text = [self formattedAcc:accumulator];
			break;
		case OPERATION_PLUS:
			//NSLog(@"Performing Plus");
			accumulator += [self.textField.text floatValue];
            self.textField.text = [self formattedAcc:accumulator];
			break;
		case OPERATION_PERCENT:
			//self.textField.text = [NSString stringWithFormat:@"%.2f", [self.textField.text floatValue] / 100.0];
			break;
	}
}

-(IBAction)digit:(UIButton *)sender
{
	//NSLog(@"Digit: %i", (int)sender.tag);
	if(operation == OPERATION_EQUAL)
	{
		//also clear the accumulator
		//NSLog(@"Clearing accumulator");
		accumulator = 0.0;
		operation = OPERATION_CLEAR;
	}
	if(lastKeyWasOperation)
	{
		//NSLog(@"Clearing textfield");
		self.textField.text = @"";
	}
	if(sender.tag < 10)
	{
		if(sender.tag == 0)
		{
			//allow 0 only if current value is non-zero OR there's a decimal point
			if(([self.textField.text intValue] != 0) || ([self.textField.text rangeOfString:@"."].location != NSNotFound))
			{
				self.textField.text = [self.textField.text stringByAppendingFormat:@"%li", (long)sender.tag];
			}
		}
		else
		{
			self.textField.text = [self.textField.text stringByAppendingFormat:@"%li", (long)sender.tag];
		}
	}
	else
	{
		if(sender.tag == DIGIT_BACK)
		{
			self.textField.text = [self.textField.text substringToIndex:self.textField.text.length - (self.textField.text.length > 0)];
		}
		else
		{
			if ([self.textField.text rangeOfString:@"."].location == NSNotFound)
			{
				self.textField.text = [self.textField.text stringByAppendingString:@"."];
			}
		}
	}
	lastKeyWasOperation = NO;
	[self.delegate CalculatorValueChanged:self];
}

-(IBAction)operation:(UIButton *)sender
{
	//NSLog(@"Operation %i", (int)sender.tag);
	switch (sender.tag)
	{
		case OPERATION_CLEAR:
			self.textField.text = @"";
			accumulator = 0.0;
			lastKeyWasOperation = NO;
			break;
		//case OPERATION_BACK:
			//self.textField.text = [self.textField.text substringToIndex:self.textField.text.length - (self.textField.text.length > 0)];
			//lastKeyWasOperation = NO;
			//break;
		case OPERATION_DONE:
			[self.delegate CalculatorDone:self];
			lastKeyWasOperation = NO;
			break;
		case OPERATION_DIVIDE:
			[self performLastOperation];
			lastKeyWasOperation = YES;
			break;
		case OPERATION_EQUAL:
			[self performLastOperation];
			lastKeyWasOperation = YES;
			break;
		case OPERATION_MINUS:
			[self performLastOperation];
			lastKeyWasOperation = YES;
			break;
		case OPERATION_MULTIPLY:
			[self performLastOperation];
			lastKeyWasOperation = YES;
			break;
		case OPERATION_PLUS:
			[self performLastOperation];
			lastKeyWasOperation = YES;
			break;
		case OPERATION_PERCENT:
			//[self performLastOperation];
			if(accumulator)
			{
                self.textField.text = [self formattedAcc:(accumulator * ([self.textField.text floatValue] / 100.0))];
			}
			else
			{
                self.textField.text = [self formattedAcc:[self.textField.text floatValue] / 100.0];
			}
			lastKeyWasOperation = YES;
			break;
			
	}
	if(sender.tag != OPERATION_PERCENT)
	{
		operation = (int)sender.tag;
	}
	
	
	[self.delegate CalculatorValueChanged:self];
}

@end
