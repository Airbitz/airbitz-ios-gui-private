//
//  PickerTextView.h
//  AirBitz
//
//  Created by Adam Harris on 5/8/14.
//  Copyright (c) 2014 Adam Harris. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PopupPickerView.h"

@protocol PickerTextViewDelegate;

@interface PickerTextView : UIView

@property (nonatomic, assign) id<PickerTextViewDelegate>    delegate;
@property (nonatomic, strong) UITextField                   *textField;
@property (nonatomic, strong) PopupPickerView               *popupPicker; //nil until picker actually appears
@property (nonatomic, assign) tPopupPickerPosition          popupPickerPosition;
@property (nonatomic, assign) NSInteger                     pickerMaxChoicesVisible; //can constrain to a certain number of choices
@property (nonatomic, assign) NSInteger                     pickerWidth;
@property (nonatomic, assign) NSInteger                     pickerCellHeight;
@property (nonatomic, assign) UITableViewCellStyle          pickerTableViewCellStyle;
@property (nonatomic, strong) NSArray                       *arrayChoices;


- (void)setTextFieldObject:(UITextField *)newTextField;
- (void)setTopMostView:(UIView *)topMostView; //what view will the drop down selector be added to?
- (void)updateChoices:(NSArray *)arrayChoices;
- (void)dismissPopupPicker;

@end

@protocol PickerTextViewDelegate <NSObject>

@required


@optional

- (BOOL)pickerTextViewFieldShouldChange:(PickerTextView *)pickerTextView charactersInRange:(NSRange)range replacementString:(NSString *)string;
- (void)pickerTextViewFieldDidChange:(PickerTextView *)pickerTextView;
- (void)pickerTextViewFieldDidBeginEditing:(PickerTextView *)pickerTextView;
- (void)pickerTextViewFieldDidEndEditing:(PickerTextView *)pickerTextView;
- (BOOL)pickerTextViewFieldShouldReturn:(PickerTextView *)pickerTextView;
- (void)pickerTextViewPopupSelected:(PickerTextView *)view onRow:(NSInteger)row;
- (BOOL)pickerTextViewPopupFormatCell:(PopupPickerView *)view onRow:(NSInteger)row withCell:(UITableViewCell *)cell;
- (NSInteger)pickerTextViewPopupNumberOfRows:(PopupPickerView *)view;
- (UITableViewCell *)pickerTextViewPopupCellForRow:(PopupPickerView *)view forTableView:(UITableView *)tableView andRow:(NSInteger)row;

@end