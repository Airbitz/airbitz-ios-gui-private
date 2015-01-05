//
//  BusinessDetailsViewController.m
//  AirBitz
//
//  Created by Carson Whitsett on 2/17/14.
//  Copyright (c) 2014 AirBitz. All rights reserved.
//

#import "BusinessDetailsViewController.h"
#import "DL_URLServer.h"
#import "Server.h"
#import "Util.h"
#import "BD_Address_Cell.h"
#import "BD_Phone_Cell.h"
#import "BD_Website_Cell.h"
#import "BD_Hours_Cell.h"
#import "BD_Details_Cell.h"
#import "BD_Social_Cell.h"
#import "BD_Share_Cell.h"
#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>
#import "RibbonView.h"
#import "CommonTypes.h"
#import "UIPhotoGalleryView.h"
#import "UIPhotoGalleryViewController.h"
#import "UIPhotoGallerySliderView.h"
#import "UIPhotoGalleryViewController+Slider.h"

#import "CJSONDeserializer.h"

#define SHOW_PHONE_CALL_ARE_YOU_SURE_ALERT 0	/* set to 1 to show are you sure alert before dialing */

typedef NS_ENUM(NSUInteger, CellType) {
    kAddress,
    kPhone,
    kWebsite,
    kShare,
    kHours,
    kDetails,
    kSocial
};

#define SINGLE_ROW_CELL_HEIGHT	44

#define CLOSED_STRING	@"closed"

@interface BusinessDetailsViewController () <DL_URLRequestDelegate, UITableViewDataSource, UITableViewDelegate,
                                             UIAlertViewDelegate, UIPhotoGalleryDataSource, UIPhotoGalleryDelegate>
{
	CGFloat hoursCellHeight;
	CGFloat detailsCellHeight;
	CGFloat detailsLabelWidth;
	BOOL needToLoadImageInfo;
    NSArray *details;
    UIPhotoGalleryViewController *galleryController;
    UIActivityIndicatorView *gallerySpinner;
	NSMutableArray *imageURLs;
    NSMutableArray *rowTypes;
    NSMutableArray *socialRows;
}

@property (nonatomic, weak) IBOutlet UIImageView *darkenImageView;
@property (nonatomic, weak) IBOutlet UIPhotoGalleryView *galleryView;
@property (nonatomic, weak) IBOutlet UITableView *tableView;
@property (nonatomic, weak) IBOutlet UIActivityIndicatorView *activityView;
@property (nonatomic, weak) IBOutlet UIActivityIndicatorView *imageLoadActivityView;
@property (nonatomic, weak) IBOutlet UILabel *businessTitleLabel;
@property (nonatomic, weak) IBOutlet UIView *imageArea;
@property (nonatomic, weak) IBOutlet UILabel *categoriesLabel;
@property (nonatomic, weak) IBOutlet UILabel *BTC_DiscountLabel;

@property (nonatomic, strong) NSDictionary *businessDetails;

@end

@implementation BusinessDetailsViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.galleryView.dataSource = self;
    self.galleryView.delegate = self;
    self.galleryView.galleryMode = UIPhotoGalleryModeCustomView;
    self.galleryView.subviewGap = 0;
    self.galleryView.photoItemContentMode = UIViewContentModeScaleAspectFill;

    details = nil;
	imageURLs = [[NSMutableArray alloc] init];
    rowTypes = [[NSMutableArray alloc] init];
    socialRows = [[NSMutableArray alloc] init];
	hoursCellHeight = SINGLE_ROW_CELL_HEIGHT;
	detailsCellHeight = SINGLE_ROW_CELL_HEIGHT;
	
	self.darkenImageView.hidden = YES; //hide until business image gets loaded
	
	//get business details
	NSString *requestURL = [NSString stringWithFormat:@"%@/business/%@/?ll=%f,%f", SERVER_API, self.bizId, self.latLong.latitude, self.latLong.longitude];
	//NSLog(@"Requesting: %@", requestURL);
	[[DL_URLServer controller] issueRequestURL:requestURL
									withParams:nil
									withObject:nil
								  withDelegate:self
							acceptableCacheAge:CACHE_24_HOURS
								   cacheResult:YES];
	
	self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
	[self.activityView startAnimating];
	
	UISwipeGestureRecognizer *gesture = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(didSwipe:)];
	gesture.direction = UISwipeGestureRecognizerDirectionRight;
	[self.view addGestureRecognizer:gesture];
}

-(void)didSwipe:(UIGestureRecognizer *)gestureRecognizer
{
    if (!galleryController)
    {
        [self Back:nil];
    }
}

-(void)dealloc
{
	[[DL_URLServer controller] cancelAllRequestsForDelegate:self];
}

-(void)setCategories
{
	NSMutableString *categoriesString = [[NSMutableString alloc] init];
	NSArray *categoriesArray = [self.businessDetails objectForKey:@"categories"];
	BOOL firstObject = YES;
	for(NSDictionary *dict in categoriesArray)
	{
		if(firstObject == NO)
		{
			[categoriesString appendString:@" | "];
		}
		[categoriesString appendString:[dict objectForKey:@"name"]];
		firstObject = NO;
	}
	self.categoriesLabel.text = categoriesString;
}

-(void)setRibbon:(NSString *)ribbon
{
	RibbonView *ribbonView;
	
	ribbonView = (RibbonView *)[self.imageArea viewWithTag:TAG_RIBBON_VIEW];
	if(ribbonView)
	{
		[ribbonView flyIntoPosition];
		if(ribbon.length)
		{
			ribbonView.hidden = NO;
			ribbonView.string = ribbon;
		}
		else
		{
			ribbonView.hidden = YES;
		}
	}
	else
	{
		if(ribbon.length)
		{
			ribbonView = [[RibbonView alloc] initAtLocation:CGPointMake(self.imageArea.bounds.origin.x + self.imageArea.bounds.size.width, 0.0) WithString:ribbon];
			[self.imageArea addSubview:ribbonView];
		}
	}
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(IBAction)Back:(id)sender
{
	[self.delegate businessDetailsViewControllerDone:self];
}

-(NSString *)time12Hr:(NSString *)time24Hr
{
	NSString *pmamDateString;
	
	if(time24Hr != (id)[NSNull null])
	{
		NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
		dateFormatter.dateFormat = @"HH:mm:ss";
		NSDate *date = [dateFormatter dateFromString:time24Hr];
		
		dateFormatter.dateFormat = @"h:mm a";
		pmamDateString = [dateFormatter stringFromDate:date];
	}
	else
	{
		pmamDateString = CLOSED_STRING;
	}
	return [pmamDateString lowercaseString];
}

-(void)launchMapApp
{
	NSDictionary *locationDict = [self.businessDetails objectForKey:@"location"];
	if(locationDict.count == 2)
	{
		//launch with specific coordinate
		CLLocationCoordinate2D coordinate;
		coordinate.latitude = [[locationDict objectForKey:@"latitude"] floatValue];
		coordinate.longitude = [[locationDict objectForKey:@"longitude"] floatValue];
		
		NSMutableDictionary *addressDict = [[NSMutableDictionary alloc] init];
		[addressDict setObject:[self.businessDetails objectForKey:@"city"] forKey:@"City"];
		[addressDict setObject:[self.businessDetails objectForKey:@"address"] forKey:@"Street"];
		[addressDict setObject:[self.businessDetails objectForKey:@"state"] forKey:@"State"];
		[addressDict setObject:[self.businessDetails objectForKey:@"postalcode"] forKey:@"ZIP"];
		
		MKPlacemark *placemark = [[MKPlacemark alloc] initWithCoordinate:coordinate addressDictionary:addressDict];
		
		// Create a map item for the geocoded address to pass to Maps app
		MKMapItem *mapItem = [[MKMapItem alloc] initWithPlacemark:placemark];
		[mapItem setName:[self.businessDetails objectForKey:@"name"]];
		
		// Set the directions mode to "Driving"
		// Can use MKLaunchOptionsDirectionsModeWalking instead
		NSDictionary *launchOptions = @{MKLaunchOptionsDirectionsModeKey : MKLaunchOptionsDirectionsModeDriving};
		
		// Get the "Current User Location" MKMapItem
		MKMapItem *currentLocationMapItem = [MKMapItem mapItemForCurrentLocation];
		
		// Pass the current location and destination map items to the Maps app
		// Set the direction mode in the launchOptions dictionary
		[MKMapItem openMapsWithItems:@[currentLocationMapItem, mapItem] launchOptions:launchOptions];
		
	}
	else
	{
		//no coordinate so launch with address instead
		NSString *address = [NSString stringWithFormat:@"%@ %@, %@  %@", [self.businessDetails objectForKey:@"address"], [self.businessDetails objectForKey:@"city"], [self.businessDetails objectForKey:@"state"], [self.businessDetails objectForKey:@"postalcode"]];
		CLGeocoder *geocoder = [[CLGeocoder alloc] init];
		[geocoder geocodeAddressString:address completionHandler:^(NSArray *placemarks, NSError *error)
		 {
			 NSLog(@"error: %li", (long)error.code);
			 
			 // Convert the CLPlacemark to an MKPlacemark
			 // Note: There's no error checking for a failed geocode
			 CLPlacemark *geocodedPlacemark = [placemarks objectAtIndex:0];
			 MKPlacemark *placemark = [[MKPlacemark alloc]
									   initWithCoordinate:geocodedPlacemark.location.coordinate
									   addressDictionary:geocodedPlacemark.addressDictionary];
			 
			 // Create a map item for the geocoded address to pass to Maps app
			 MKMapItem *mapItem = [[MKMapItem alloc] initWithPlacemark:placemark];
			 [mapItem setName:geocodedPlacemark.name];
			 
			 // Set the directions mode to "Driving"
			 // Can use MKLaunchOptionsDirectionsModeWalking instead
			 NSDictionary *launchOptions = @{MKLaunchOptionsDirectionsModeKey : MKLaunchOptionsDirectionsModeDriving};
			 
			 // Get the "Current User Location" MKMapItem
			 MKMapItem *currentLocationMapItem = [MKMapItem mapItemForCurrentLocation];
			 
			 // Pass the current location and destination map items to the Maps app
			 // Set the direction mode in the launchOptions dictionary
			 [MKMapItem openMapsWithItems:@[currentLocationMapItem, mapItem] launchOptions:launchOptions];
			 
		 }];
	}
}

-(void)callBusinessNumber
{
	NSString *telNum = [NSString stringWithFormat:@"tel://%@", [self.businessDetails objectForKey:@"phone"]];
    [Util callTelephoneNumber:telNum];
}

-(void)hideDiscountLabel
{
	//hide BTC discount label
	//Make categories label longer to fill space previously occupied by BTC discount label
	CGRect categoryFrame = self.categoriesLabel.frame;
	CGRect discountFrame = self.BTC_DiscountLabel.frame;
	
	categoryFrame.size.width = discountFrame.origin.x + discountFrame.size.width - categoryFrame.origin.x;
	self.categoriesLabel.frame = categoryFrame;
	self.BTC_DiscountLabel.hidden = YES;
}

-(void)determineVisibleRows
{
    [rowTypes removeAllObjects];

    // If business detail data is available for row type, increment count
    
    //Address (must have at least city and state)
    NSString *city = [self.businessDetails objectForKey:@"city"];
    NSString *state = [self.businessDetails objectForKey:@"state"];
    
    if((city != nil) && (city != (id)[NSNull null]) && city.length)
    {
        if((state != nil) && (state != (id)[NSNull null]) && state.length)
        {
            [rowTypes addObject:[NSNumber numberWithInt:kAddress]];
        }
    }
    
    //phone (must have length)
    NSString *phone = [self.businessDetails objectForKey:@"phone"];
    if((phone != nil) && (phone != (id)[NSNull null]) && phone.length)
    {
        [rowTypes addObject:[NSNumber numberWithInt:kPhone]];
    }
    
    //web (must have length)
    NSString *web = [self.businessDetails objectForKey:@"website"];
    if((web != nil) && (web != (id)[NSNull null]) && web.length)
    {
        [rowTypes addObject:[NSNumber numberWithInt:kWebsite]];
    }
    
    //share always visible
    [rowTypes addObject:[NSNumber numberWithInt:kShare]];

    //hours (must have at least one item)
    NSArray *daysOfOperation = [self.businessDetails objectForKey:@"hours"];
    if((daysOfOperation != nil) && (daysOfOperation != (id)[NSNull null]) && daysOfOperation.count)
    {
        [rowTypes addObject:[NSNumber numberWithInt:kHours]];
    }
    
    //details always visible
    [rowTypes addObject:[NSNumber numberWithInt:kDetails]];

    //social
    NSArray *social = [self.businessDetails objectForKey:@"social"];
    if((social != nil) && (social != (id)[NSNull null]))
    {
        for (NSDictionary *data in social)
        {
            // store row index and social type for later retrieval
            NSString *type = [data objectForKey:@"social_type"];
            NSNumber *typeEnum = [BD_Social_Cell getSocialTypeAsEnum:type];
            if (typeEnum != [NSNumber numberWithInt:kNull])
            {
                NSDictionary *rowData = @{[NSNumber numberWithInt:[rowTypes count]] : typeEnum};
                [socialRows addObject:rowData];

                [rowTypes addObject:[NSNumber numberWithInt:kSocial]];
            }
        }
    }
}

-(NSUInteger)primaryImage:(NSArray *)arrayImageResults
{
	NSUInteger primaryImage = 0;
	NSUInteger count = 0;
	for(NSDictionary *dict in arrayImageResults)
	{
		NSArray *tags = [dict objectForKey:@"tags"];
		if(tags && (tags != (id)[NSNull null]))
		{
			for(NSString *tag in tags)
			{
				if([tag isEqualToString:@"Primary"])
				{
					//found primary image
					//NSLog(@"Found primary tag at object index: %i", count);
					primaryImage = count;
					break;
				}
			}
			if(primaryImage)
			{
				break;
			}
		}
		count++;
	}
	return primaryImage;
}

#pragma mark - DLURLServer Callbacks

- (void)onDL_URLRequestCompleteWithStatus:(tDL_URLRequestStatus)status resultData:(NSData *)data resultObj:(id)object
{
	if(data)
	{
        if (DL_URLRequestStatus_Success == status)
        {
			if(object == imageURLs)
			{
				NSString *jsonString = [[NSString alloc] initWithBytes:[data bytes] length:[data length] encoding:NSUTF8StringEncoding];
				
				//NSLog(@"Results download returned: %@", jsonString );
				
				NSError *myError;
				NSData *jsonData = [jsonString dataUsingEncoding:NSUTF32BigEndianStringEncoding];
				NSDictionary *dict = [[CJSONDeserializer deserializer] deserializeAsDictionary:jsonData error:&myError];
				
				details = [dict objectForKey:@"results"];
                self.galleryView.galleryMode = UIPhotoGalleryModeImageRemote;
                self.galleryView.photoItemContentMode = UIViewContentModeScaleAspectFill;
                [self.galleryView layoutSubviews];

				self.darkenImageView.hidden = NO;
                [gallerySpinner stopAnimating];
				
				//create the distance ribbon
				NSNumber *distance = [self.businessDetails objectForKey:@"distance"];
				if(distance && distance != (id)[NSNull null])
				{
					[self setRibbon:[RibbonView metersToDistance:[distance floatValue]]];
				}
				
				NSString *bitCoinDiscount = [self.businessDetails objectForKey:@"has_bitcoin_discount"];
				if(bitCoinDiscount)
				{
					float discount = [bitCoinDiscount floatValue] * 100.0;
					if(discount)
					{
						self.BTC_DiscountLabel.text = [NSString stringWithFormat:@"BTC Discount: %.0f%%", [bitCoinDiscount floatValue] * 100.0];
					}
					else
					{
						[self hideDiscountLabel];
					}
				}
				else
				{
					[self hideDiscountLabel];
				}
				[self setCategories];
			}
			else
			{
				if(object)
				{
				
					if([object isKindOfClass:[UIImageView class]])
					{
						((UIImageView *)object).image = [UIImage imageWithData:data];
						self.darkenImageView.hidden = NO;
					}
                    [gallerySpinner stopAnimating];
					
					//create the distance ribbon
					NSString *distance = [self.businessDetails objectForKey:@"distance"];
					if(distance && (distance != (id)[NSNull null]))
					{
						[self setRibbon:[RibbonView metersToDistance:[distance floatValue]]];
					}
					
					NSString *bitCoinDiscount = [self.businessDetails objectForKey:@"has_bitcoin_discount"];
					if(bitCoinDiscount)
					{
						float discount = [bitCoinDiscount floatValue] * 100.0;
						if(discount)
						{
							self.BTC_DiscountLabel.text = [NSString stringWithFormat:@"BTC Discount: %.0f%%", [bitCoinDiscount floatValue] * 100.0];
						}
						else
						{
							[self hideDiscountLabel];
						}
					}
					else
					{
						[self hideDiscountLabel];
					}
					[self setCategories];
				}
				else
				{
					NSString *jsonString = [[NSString alloc] initWithBytes:[data bytes] length:[data length] encoding:NSUTF8StringEncoding];
					
					//NSLog(@"Results download returned: %@", jsonString );
					
					NSData *jsonData = [jsonString dataUsingEncoding:NSUTF32BigEndianStringEncoding];
					NSError *myError;
					self.businessDetails = [[CJSONDeserializer deserializer] deserializeAsDictionary:jsonData error:&myError];
					
					[self determineVisibleRows];
					
					self.businessTitleLabel.text = [self.businessDetails objectForKey:@"name"];
					
					NSArray *daysOfOperation = [self.businessDetails objectForKey:@"hours"];
					
					if(daysOfOperation.count)
					{
						hoursCellHeight = SINGLE_ROW_CELL_HEIGHT + 16 * [daysOfOperation count] - 16;
					}
					else
					{
						hoursCellHeight = SINGLE_ROW_CELL_HEIGHT;
					}
					
					BD_Details_Cell *detailsCell = [self getDetailsCellForTableView:self.tableView];
					
					//calculate height of details cell
					CGSize size = [ [self.businessDetails objectForKey:@"description"] sizeWithFont:detailsCell.detailsLabel.font constrainedToSize:CGSizeMake(detailsLabelWidth, 9999) lineBreakMode:NSLineBreakByWordWrapping];
					detailsCellHeight = size.height + 28.0;

					[self.tableView reloadData];
					
					//Get image URLs
					NSString *requestURL = [NSString stringWithFormat:@"%@/business/%@/photos/", SERVER_API, self.bizId];
					//NSLog(@"Requesting: %@ for row: %i", requestURL, row);
					[[DL_URLServer controller] issueRequestURL:requestURL
													withParams:nil
													withObject:imageURLs
												  withDelegate:self
											acceptableCacheAge:CACHE_24_HOURS
												   cacheResult:YES];
					
				}
			}
		}
    }
	[self.activityView stopAnimating];
}

#pragma mark Table View delegates

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [rowTypes count];
}

-(BD_Address_Cell *)getAddressCellForTableView:(UITableView *)tableView
{
	BD_Address_Cell *cell;
	static NSString *cellIdentifier = @"BD_Address_Cell";
	
	cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	if (nil == cell)
	{
		cell = [[BD_Address_Cell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
	}
	return cell;
}

-(BD_Phone_Cell *)getPhoneCellForTableView:(UITableView *)tableView
{
	BD_Phone_Cell *cell;
	static NSString *cellIdentifier = @"BD_Phone_Cell";
	
	cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	if (nil == cell)
	{
		cell = [[BD_Phone_Cell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
	}
	return cell;
}

-(BD_Website_Cell *)getWebsiteCellForTableView:(UITableView *)tableView
{
	BD_Website_Cell *cell;
	static NSString *cellIdentifier = @"BD_Website_Cell";
	
	cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	if (nil == cell)
	{
		cell = [[BD_Website_Cell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
	}
	return cell;
}

-(BD_Social_Cell *)getSocialCellForTableView:(UITableView *)tableView
{
	BD_Social_Cell *cell;
	static NSString *cellIdentifier = @"BD_Social_Cell";
	
	cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	if (nil == cell)
	{
		cell = [[BD_Social_Cell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
	}
	return cell;
}

-(BD_Share_Cell *)getShareCellForTableView:(UITableView *)tableView
{
	BD_Share_Cell *cell;
	static NSString *cellIdentifier = @"BD_Share_Cell";
	
	cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	if (nil == cell)
	{
		cell = [[BD_Share_Cell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
	}
	return cell;
}

-(BD_Hours_Cell *)getHoursCellForTableView:(UITableView *)tableView
{
	BD_Hours_Cell *cell;
	static NSString *cellIdentifier = @"BD_Hours_Cell";
	
	cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	if (nil == cell)
	{
		cell = [[BD_Hours_Cell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
	}
	return cell;
}

-(BD_Details_Cell *)getDetailsCellForTableView:(UITableView *)tableView
{
	BD_Details_Cell *cell;
	static NSString *cellIdentifier = @"BD_Details_Cell";
	
	cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	if (nil == cell)
	{
		cell = [[BD_Details_Cell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
	}
	detailsLabelWidth = cell.detailsLabel.frame.size.width;
	return cell;
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	NSInteger row = [indexPath row];
	UITableViewCell *cell;
	
	
	int cellType = [self cellTypeForRow:indexPath.row];
	
	UIImage *cellImage;
	if ([tableView numberOfRowsInSection:indexPath.section] == 1)
	{
		cellImage = [UIImage imageNamed:@"bd_cell_single"];
	}
	else
	{
		if (row == 0)
		{
			cellImage = [UIImage imageNamed:@"bd_cell_top"];
		}
		else if (row == [tableView numberOfRowsInSection:indexPath.section] - 1)
        {
            if (cellType == kHours | cellType == kDetails)
            {
                cellImage = [UIImage imageNamed:@"bd_cell_bottom_white"];
            }
            else
            {
                cellImage = [UIImage imageNamed:@"bd_cell_bottom"];
            }
        }
        else
        {
            if (cellType == kHours | cellType == kDetails)
            {
                cellImage = [UIImage imageNamed:@"bd_cell_middle_white"];
            }
            else
            {
                cellImage = [UIImage imageNamed:@"bd_cell_middle"];
            }
        }
	}
	
	if (cellType == kAddress)
	{
		//address cell
		BD_Address_Cell *addressCell = [self getAddressCellForTableView:tableView];
		if(self.businessDetails)
		{
			addressCell.topAddress.text = [self.businessDetails objectForKey:@"address"];
			addressCell.botAddress.text = [NSString stringWithFormat:@"%@, %@  %@", [self.businessDetails objectForKey:@"city"], [self.businessDetails objectForKey:@"state"], [self.businessDetails objectForKey:@"postalcode"]];
			addressCell.bkg_image.image = cellImage;
		}
		cell = addressCell;
	}
	else if(cellType == kPhone)
	{
		//phone cell
		BD_Phone_Cell *phoneCell = [self getPhoneCellForTableView:tableView];
		phoneCell.phoneLabel.text = [self.businessDetails objectForKey:@"phone"];
		phoneCell.bkg_image.image = cellImage;
		cell = phoneCell;
	}
	else if(cellType == kWebsite)
	{
		//website cell
		BD_Website_Cell *websiteCell = [self getWebsiteCellForTableView:tableView];
		websiteCell.websiteLabel.text = [self.businessDetails objectForKey:@"website"];
		websiteCell.bkg_image.image = cellImage;
		cell = websiteCell;
	}
	else if(cellType == kShare)
	{
		//phone cell
		BD_Share_Cell *shareCell = [self getShareCellForTableView:tableView];
//		shareCell.shareLabel.text = [self.businessDetails objectForKey:@"share"];
		shareCell.bkg_image.image = cellImage;
		cell = shareCell;
	}
	else if(cellType == kHours)
	{
		BD_Hours_Cell *hoursCell = [self getHoursCellForTableView:tableView];
		hoursCell.bkg_image.image = cellImage;
		if(self.businessDetails)
		{
			[hoursCell.activityView stopAnimating];
			NSArray *operatingDays = [self.businessDetails objectForKey:@"hours"];
			NSMutableString *dayString = [[NSMutableString alloc] init];
			NSMutableString *hoursString = [[NSMutableString alloc] init];
			if(operatingDays.count)
			{
				NSString *lastDayString = @" ";
				for(NSDictionary *day in operatingDays)
				{
					NSString *weekday = [day objectForKey:@"dayOfWeek"];
					if([weekday isEqualToString:lastDayString])
					{
						[dayString appendString:@"\n"];
					}
					else
					{
						[dayString appendFormat:@"%@\n", weekday];
					}
					lastDayString = [weekday copy];
					NSString *openTime = [self time12Hr:[day objectForKey:@"hourStart"]];
					NSString *closedTime = [self time12Hr:[day objectForKey:@"hourEnd"]];
					if([openTime isEqualToString:closedTime])
					{
						[hoursString appendFormat:@"%@\n", closedTime];
					}
					else if(![openTime isEqualToString:CLOSED_STRING] && [closedTime isEqualToString:CLOSED_STRING])
					{
						[hoursString appendString:@"Open 24 hours\n"];
					}
					else
					{
						[hoursString appendFormat:@"%@ - %@\n", [self time12Hr:[day objectForKey:@"hourStart"]], [self time12Hr:[day objectForKey:@"hourEnd"]]];
					}
				}
				//remove last CR
				[dayString deleteCharactersInRange:NSMakeRange([dayString length]-1, 1)];
				[hoursString deleteCharactersInRange:NSMakeRange([hoursString length]-1, 1)];
			}
			else
			{
				[dayString appendString:@"Open 24"];
				[hoursString appendString:@"hours\n"];
			}
			
			//apply new strings to text labels
			hoursCell.dayLabel.text = [dayString copy];
			[hoursCell.dayLabel sizeToFit];
			hoursCell.timeLabel.text = [hoursString copy];
			[hoursCell.timeLabel sizeToFit];
		}
		cell = hoursCell;
	}
	else if(cellType == kDetails)
	{
		//details cell
		BD_Details_Cell *detailsCell = [self getDetailsCellForTableView:tableView];
		detailsCell.bkg_image.image = cellImage;
		if(self.businessDetails)
		{
			[detailsCell.activityView stopAnimating];
			detailsCell.detailsLabel.text = [self.businessDetails objectForKey:@"description"];
			[detailsCell.detailsLabel sizeToFit];
		}
		cell = detailsCell;
	}
	else if(cellType == kSocial)
	{
		BD_Social_Cell *socialCell = [self getSocialCellForTableView:tableView];
        for (NSDictionary *pair in socialRows)
        {
            NSNumber *socialType = [pair objectForKey:[NSNumber numberWithInt:row]];
            if (socialType)
            {
                socialCell.socialLabel.text = [BD_Social_Cell getSocialTypeAsString:socialType];
                socialCell.socialIcon.image = [BD_Social_Cell getSocialTypeImage:socialType];
                break;
            }
        }
		socialCell.bkg_image.image = cellImage;
		cell = socialCell;
	}
	
	return cell;
}

-(int)cellTypeForRow:(NSInteger)row
{
    if (row < [rowTypes count])
        return [((NSNumber*)[rowTypes objectAtIndex:row]) intValue];
	return kSocial;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	int cellType = [self cellTypeForRow:indexPath.row];
	
	if(cellType == kHours)
	{
		return hoursCellHeight;
	}
	else if(cellType == kDetails)
	{
		//NSLog(@"returning details cell height of %f", detailsCellHeight);
		return detailsCellHeight;
	}
	else if(cellType == kWebsite)
	{
		NSString *website = [self.businessDetails objectForKey:@"website"];
		if(website.length)
		{
			return SINGLE_ROW_CELL_HEIGHT;
		}
		else
		{
			return 0;
		}
	}
	else if(cellType == kPhone)
	{
		NSString *phone = [self.businessDetails objectForKey:@"phone"];
		if(phone.length)
		{
			return SINGLE_ROW_CELL_HEIGHT;
		}
		else
		{
			return 0;
		}
	}
	else
	{
		return SINGLE_ROW_CELL_HEIGHT;
	}
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
//    NSURL *url = [[NSURL alloc] initWithString:[self.businessDetails objectForKey:@"website"] ];
//    [[UIApplication sharedApplication] openURL:url];

    switch ([self cellTypeForRow:indexPath.row]) {
        case kAddress:
        {
            [self launchMapApp];
            break;
        }
        case kPhone:
        {
#if SHOW_PHONE_CALL_ARE_YOU_SURE_ALERT
            NSString *msg = NSLocalizedString(@"Are you sure you want to call", nil);
            
            UIAlertView *alert = [[UIAlertView alloc]
                                  initWithTitle:NSLocalizedString(@"Place Call", nil)
                                  message:[NSString stringWithFormat:@"%@ %@?", msg, [self.businessGeneralInfo objectForKey:@"phone"]]
                                  delegate:self
                                  cancelButtonTitle:@"No"
                                  otherButtonTitles:@"Yes", nil];
            [alert show];
#else
            [self callBusinessNumber];
#endif
            break;
        }
        case kWebsite:
        {
            NSURL *url = [[NSURL alloc] initWithString:[self.businessDetails objectForKey:@"website"] ];
            [[UIApplication sharedApplication] openURL:url];
            break;
        }
        case kShare:
        {
            NSString *subject = [NSString stringWithFormat:@"%@ - %@ %@",
                             [self.businessDetails objectForKey:@"name"],
                             [self.businessDetails objectForKey:@"city"],
                             NSLocalizedString(@"Bitcoin | Airbitz", nil)
                             ];
            NSString *msg = [NSString stringWithFormat:@"%@ https://airbitz.co/biz/%@",
                                subject, [self.businessDetails objectForKey:@"bizId"]
            ];
            NSArray *activityItems = [NSArray arrayWithObjects: msg, nil, nil];
            UIActivityViewController *activityController = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:nil];
            [activityController setValue:subject forKey:@"subject"];
            [self presentViewController:activityController animated:YES completion:nil];
            break;
        }
        case kSocial:
        {
            NSArray *social = [self.businessDetails objectForKey:@"social"];
            if((social != nil) && (social != (id)[NSNull null]))
            {
                // TODO : refactor, possibly by including the URL into socialRows
                for (NSDictionary *data in social)
                {
                    NSString *type = [data objectForKey:@"social_type"];
                    NSNumber *typeEnum = [BD_Social_Cell getSocialTypeAsEnum:type];
                    for (NSDictionary *pair in socialRows)
                    {
                        NSNumber *socialType = [pair objectForKey:[NSNumber numberWithInt:indexPath.row]];
                        if (typeEnum == socialType)
                        {
                            NSString *urlStr = [data objectForKey:@"social_url"];
                            NSURL *url = [[NSURL alloc] initWithString:urlStr];
                            [[UIApplication sharedApplication] openURL:url];
                        }
                    }
                }
            }
            break;
        }
        default:
            break;
    }
}

#pragma mark UIAlertView delegates

-(void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
	//NSLog(@"Clicked button %li", (long)buttonIndex);
	if(buttonIndex == 1)
	{
		[self callBusinessNumber];
	}
}

#pragma mark UIPhotoGalleryDataSource methods
- (NSInteger)numberOfViewsInPhotoGallery:(UIPhotoGalleryView *)photoGallery
{
    if (details)
    {
        return [details count];
    }
    return 1;
}

- (NSURL*)photoGallery:(UIPhotoGalleryView *)photoGallery remoteImageURLAtIndex:(NSInteger)index
{
    NSString *imageKey;
    if (details)
    {
        imageKey = galleryController ? @"image" : @"thumbnail";
        NSDictionary *bizData = [details objectAtIndex:index % [details count]];
        NSString *imageRequest = [NSString stringWithFormat:@"%@%@", SERVER_URL, [bizData objectForKey:imageKey]];
        return [NSURL URLWithString:imageRequest];
    }
    return nil;
}

- (UIView*)photoGallery:(UIPhotoGalleryView *)photoGallery customViewAtIndex:(NSInteger)index
{
    if (!gallerySpinner)
    {
        CGRect frame = CGRectMake(0, 0, photoGallery.frame.size.width, photoGallery.frame.size.height);
        gallerySpinner = [[UIActivityIndicatorView alloc] initWithFrame:frame];
        [gallerySpinner setActivityIndicatorViewStyle:UIActivityIndicatorViewStyleWhiteLarge];
    }
    [gallerySpinner startAnimating];
    return gallerySpinner;
}

- (UIView*)customTopViewForGalleryViewController:(UIPhotoGalleryViewController *)galleryViewController
{
    CGFloat statusBarHeight = [[UIApplication sharedApplication] statusBarFrame].size.height;
    CGRect topFrame = CGRectMake(0, 0,
                                 self.view.frame.size.width, statusBarHeight + MINIMUM_BUTTON_SIZE);
    UIView *topView = [[UIView alloc] initWithFrame:topFrame];
    topView.backgroundColor = [UIColor clearColor];
    
    UIButton *btnDone = [UIButton buttonWithType:UIButtonTypeCustom];
    CGRect btnFrame = CGRectMake(self.view.frame.size.width - MINIMUM_BUTTON_SIZE, statusBarHeight,
                                 MINIMUM_BUTTON_SIZE, MINIMUM_BUTTON_SIZE);
    btnDone.frame = btnFrame;
    [btnDone setBackgroundImage:[UIImage imageNamed:@"btn_close"] forState:UIControlStateNormal];
    [btnDone addTarget:self
                action:@selector(returnFromGallery)
      forControlEvents:UIControlEventTouchUpInside];
    [topView addSubview:btnDone];
    return topView;
}

- (void)returnFromGallery
{
    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
	[UIView animateWithDuration:0.35
						  delay:0.0
						options:UIViewAnimationOptionCurveEaseInOut
					 animations:^
	 {
		 CGRect frame = self.view.bounds;
		 frame.origin.x = frame.size.width;
		 galleryController.view.frame = frame;
	 }
					 completion:^(BOOL finished)
	 {
		 [galleryController.view removeFromSuperview];
		 galleryController = nil;
         [[UIApplication sharedApplication] endIgnoringInteractionEvents];
	 }];
}

- (UIView*)customBottomViewForGalleryViewController:(UIPhotoGalleryViewController *)galleryViewController
{
    UIPhotoGallerySliderView *bottomView = [UIPhotoGallerySliderView CreateWithPhotoCount:[details count]
                                                                          andCurrentIndex:[galleryViewController initialIndex]];
    bottomView.delegate = galleryViewController;
    return bottomView;
}

#pragma mark UIPhotoGalleryDelegate methods

- (void)photoGallery:(UIPhotoGalleryView *)photoGallery didTapAtIndex:(NSInteger)index
{
    if (details && !galleryController)
    {
        galleryController = [[UIPhotoGalleryViewController alloc] init];
        [galleryController setScrollIndicator:NO];
        galleryController.galleryMode = UIPhotoGalleryModeImageRemote;
        galleryController.initialIndex = index;
        galleryController.showStatusBar = YES;
        galleryController.dataSource = self;
        
        CGRect frame = self.view.bounds;
        frame.origin.x = frame.size.width;
        galleryController.view.frame = frame;
        [self.view addSubview:galleryController.view];
        
        [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
        [UIView animateWithDuration:0.35
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^
         {
             galleryController.view.frame = self.view.bounds;
         }
                         completion:^(BOOL finished)
         {
             [[UIApplication sharedApplication] endIgnoringInteractionEvents];
         }];
    }
}

- (UIPhotoGalleryDoubleTapHandler)photoGallery:(UIPhotoGalleryView *)photoGallery doubleTapHandlerAtIndex:(NSInteger)index
{
    return UIPhotoGalleryDoubleTapHandlerNone;
}

#pragma mark - Rotation Methods

- (BOOL)shouldAutorotate
{
    return NO;
}

@end

