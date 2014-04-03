//
//  DirectoryViewController.m
//  AirBitz
//
//  Created by Carson Whitsett on 2/4/14.
//  Copyright (c) 2014 AirBitz. All rights reserved.
//

#import "DirectoryViewController.h"
#import "RibbonView.h"
#import "topOverviewCell.h"
#import "overviewCell.h"
#import "DL_URLServer.h"
#import "Location.h"
#import "CJSONDeserializer.h"
#import "Server.h"
#import <MapKit/MapKit.h>
#import "DividerView.h"
#import "BackgroundImageManager.h"
#import "BusinessDetailsViewController.h"
#import "MapView.h"
#import "SMCalloutView.h"
#import "AnnotationContentView.h"
#import "CustomAnnotationView.h"
#import "MoreCategoriesViewController.h"
#import "InfoView.h"

//server defines (uncomment one)
#define SERVER_MESSAGES_TO_SHOW		VERBOSE_MESSAGES_OFF
//#define SERVER_MESSAGES_TO_SHOW		VERBOSE_MESSAGES_ERRORS | VERBOSE_MESSAGES_STATS
//#define SERVER_MESSAGES_TO_SHOW		VERBOSE_MESSAGES_ALL

#define MAX_SEARCH_CACHE_SIZE	2 /* each cache can hold this many items */

#define LOCATION_UPDATE_PERIOD	60 /* seconds */

#define CURRENT_LOCATION_STRING	NSLocalizedString(@"Current Location", nil)
#define ON_THE_WEB_STRING	NSLocalizedString(@"On The Web", nil)

#define DEFAULT_SEARCH_RADIUS_MILES	50

#define SHOW_SERVER_PAGE		0		/* set to 1 to replace bitcoin discount label with server page count (should be 0 for deployment) */

#define AGE_ACCEPT_CACHE_SECS	60.0 /* seconds */
#define DEFAULT_RESULTS_PER_PAGE	50 /* how many results to request from the server at a time */

//business search sort parameter can be one of these
#define SORT_RESULT_BEST_MATCH	0
#define SORT_RESULT_DISTANCE	1

#define MILES_TO_METERS(a)	(a * 1609.34)

//Business results table cell heights
#define HEIGHT_FOR_TOP_BUSINESS_RESULT	130.0
#define HEIGHT_FOR_TYPICAL_BUSINESS_RESULT	110.0

//geometry
#define EXTRA_SEARCH_BAR_HEIGHT	37.0
#define DIVIDER_BAR_TRANSPARENT_AREA_HEIGHT	9.0	/* the divider bar image has some transparency above the actual bar */
#define DIVIDER_DOWN_MARGIN		12.0			/* Limit how far off bottom of screen divider bar can be dragged to */
#define LOCATE_ME_BUTTON_OFFSET_FROM_MAP_BOTTOM	58.0
#define MINIMUM_LOCATE_ME_BUTTON_OFFSET_Y	120.0

#define TAG_BUSINESS_SEARCH	0
#define TAG_LOCATION_SEARCH 1

#define TAG_CATEGORY_RESTAURANTS	0
#define TAG_CATEGORY_BARS			1
#define TAG_CATEGORY_COFFEE			2
#define TAG_CATEGORY_MORE			3

//modes
/*

Listing mode
	single search bar
	single tableView
	
Search mode
	dual search bar
	search clues table
	keyboard
	
Map mode
	single search bar
	map view
	listing table
*/

typedef enum eDirectoryMode
{
	DIRECTORY_MODE_LISTING,
	DIRECTORY_MODE_ON_THE_WEB_LISTING,
	DIRECTORY_MODE_SEARCH,
	DIRECTORY_MODE_MAP
} tDirectoryMode;

typedef enum eMapDisplayState
{
	MAP_DISPLAY_INIT,
	MAP_DISPLAY_ZOOM,
	MAP_DISPLAY_NORMAL,
	MAP_DISPLAY_RESIZE	/* set when user moves divider bar */
} tMapDisplayState;

@interface DirectoryViewController () <UIScrollViewDelegate, UITableViewDataSource, UITableViewDelegate, DL_URLRequestDelegate, UITextFieldDelegate, DividerViewDelegate, MKMapViewDelegate, SMCalloutViewDelegate, BackgroundImageManagerDelegate, LocationDelegate, BusinessDetailsViewControllerDelegate, MoreCategoriesViewControllerDelegate, UIGestureRecognizerDelegate, InfoViewDelegate, CommonOverviewCellDelegate>
{
	int totalResultsCount;			//total number of items in business listings search results (could be more than number of items actually returned due to pages)
	int currentPage;
	NSMutableArray *searchResultsArray;
	int mostRecentSearchTag;
	CGPoint dividerBarStartTouchPoint;
	float dividerBarPositionWithMap;
	float dividerBarPositionWithoutMap;
	UIView *categoryView; //view that's the table's headerView
	NSMutableDictionary *businessSearchResults;
	BackgroundImageManager *backgroundImages;
	CGRect homeTableViewFrame;
	NSDictionary *selectedBusinessInfo;		//cw we might be able to pass this to -launchBusinessDetails and remove it from here
	tDirectoryMode directoryMode;
	tMapDisplayState mapDisplayState; //keeps track of current map state so we can decide if we can zoom automatically or load data after region changes.
	SMCalloutView *singleCalloutView;
	BOOL receivedInitialLocation;
	BOOL searchOnTheWeb;
	BusinessDetailsViewController *businessDetailsController;
	MoreCategoriesViewController *moreCategoriesController;
	float locateMeButtonDesiredAlpha;	/* used for fading in/out button when divider bar gets dragged too high */
	NSMutableArray *searchTermCache;
	NSMutableArray *searchLocationCache;
	CLLocationCoordinate2D mostRecentLatLong;
	UITextField *activeTextField;
}

@property (nonatomic, weak) IBOutlet DividerView *dividerView;
@property (nonatomic, weak) IBOutlet UITableView *tableView;
@property (nonatomic, weak) IBOutlet UITextField *searchTextfield;
@property (nonatomic, weak) IBOutlet UITextField *locationTextfield;
@property (nonatomic, weak) IBOutlet UIView *searchView;
@property (nonatomic, weak) IBOutlet UITableView *searchCluesTableView;
@property (nonatomic, weak) IBOutlet MapView *mapView;
@property (nonatomic, weak) IBOutlet UIButton *btn_back;
@property (nonatomic, weak) IBOutlet UIButton *btn_locateMe;
@property (nonatomic, weak) IBOutlet UIButton *btn_info;
@property (nonatomic, weak) IBOutlet UIView *contentView;
@end

@implementation DirectoryViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

	directoryMode = DIRECTORY_MODE_LISTING;
	receivedInitialLocation = NO;
	
	businessSearchResults = [[NSMutableDictionary alloc] init];
	backgroundImages = [[BackgroundImageManager alloc] init];
	backgroundImages.delegate = self;
	
	[DL_URLServer initAll];
	//set API key
	[[DL_URLServer controller] setHeaderRequestValue:@"Token bae1c3d6e3dc3357b71ad998151b985d93b6ab56" forKey:@"Authorization"];
	
	[Location initAllWithDelegate:self];
	
	searchTermCache = [[NSMutableArray alloc] init];
	searchLocationCache = [[NSMutableArray alloc] init];
	
	self.dividerView.delegate = self;
	[self positionDividerView];
	
	dividerBarPositionWithMap = dividerBarPositionWithoutMap = self.dividerView.frame.origin.y;
	
	/*for (NSString* family in [UIFont familyNames])
	{
		NSLog(@"%@", family);
        
		for (NSString* name in [UIFont fontNamesForFamilyName: family])
		{
			NSLog(@"  %@", name);
		}
	}*/
	self.searchTextfield.font = [UIFont fontWithName:@"Montserrat-Regular" size:self.searchTextfield.font.pointSize];
	self.locationTextfield.font = [UIFont fontWithName:@"Montserrat-Regular" size:self.locationTextfield.font.pointSize];
	
	
	//NSString *paramDataString = [self createSearchParamString];
	
	[[DL_URLServer controller] verbose:SERVER_MESSAGES_TO_SHOW];
	
	currentPage = 0;
	//[self loadSearchResultsPage:currentPage];
	//[self loadSearchResultsPage:currentPage + 1];
	//[self businessListingQueryForPage:currentPage];
	//[self businessListingQueryForPage:currentPage + 1];
	
	
	self.searchCluesTableView.hidden = YES;
	[self hideMapView];
	self.mapView.delegate = self;
	
	[self hideBackButtonAnimated:NO];
	
	[self createSingleCalloutView];
	
	/*UISwipeGestureRecognizer *gesture = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(didSwipe:)];
	gesture.direction = UISwipeGestureRecognizerDirectionLeft;
	[self.tableView addGestureRecognizer:gesture];*/
	
	locateMeButtonDesiredAlpha = 1.0;
	
	UIPanGestureRecognizer* panRec = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(didDragMap:)];
    [panRec setDelegate:self];
    [self.mapView addGestureRecognizer:panRec];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}

-(void)disclosureTapped
{
	//NSLog(@"BUTTON TAPPED");
	//selectedBusinessInfo = businessInfo;
	//[self performSegueWithIdentifier:@"BusinessDetailsSegue" sender:self];
	CLLocation *location = [Location controller].curLocation;
	[self launchBusinessDetailsWithBizID:[selectedBusinessInfo objectForKey:@"bizId"] andLocation:location.coordinate animated:YES];
}

-(void)viewDidUnload
{
	backgroundImages = nil;
	[Location freeAll];
}

-(void)viewDidAppear:(BOOL)animated
{
	if(homeTableViewFrame.origin.y == 0)
	{
		//only set it once
		homeTableViewFrame = self.tableView.frame;
	}
}

-(void)viewWillAppear:(BOOL)animated
{
	[Location startLocatingWithPeriod:LOCATION_UPDATE_PERIOD];
	[self.searchTextfield addTarget:self action:@selector(searchTextFieldChanged:) forControlEvents:UIControlEventEditingChanged];
	[self.locationTextfield addTarget:self action:@selector(locationTextFieldChanged:) forControlEvents:UIControlEventEditingChanged];
	
	//NSLog(@"Adding keyboard notification");
	[self receiveKeyboardNotifications:YES];
}

-(void)receiveKeyboardNotifications:(BOOL)on
{
	if(on)
	{
		NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
		[center addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
		[center addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
	}
	else
	{
		[[NSNotificationCenter defaultCenter] removeObserver:self];
	}
}

- (void)viewWillDisappear:(BOOL)animated
{
    //NSLog(@"%s", __FUNCTION__);
    
    // cancel all our outstanding requests
    [[DL_URLServer controller] cancelAllRequestsForDelegate:self];
    
	//NSLog(@"Removing keyboard notification");
	[self receiveKeyboardNotifications:NO];
	[Location stopLocating];
    [super viewWillDisappear:animated];
}

- (void)keyboardWillShow:(NSNotification *)notification
{
	//show searchCluesTableView
	//hide divider bar
	
	//Get KeyboardFrame (in Window coordinates)
	//if(notification.object == self)
	if(activeTextField)
	{
		//NSLog(@"keyboard will show for directoryViewController");
		NSDictionary *userInfo = [notification userInfo];
		CGRect keyboardFrame = [[userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
		
		CGRect ownFrame = [self.view.window convertRect:keyboardFrame toView:self.contentView];
		
		CGRect searchCluesFrame = self.searchCluesTableView.frame;
		searchCluesFrame.size.height = 0.0;
		self.searchCluesTableView.frame = searchCluesFrame;
		
		self.searchCluesTableView.hidden = NO;
		
		[UIView animateWithDuration:0.35
							  delay:0.0
							options:UIViewAnimationOptionCurveEaseInOut
						 animations:^
		 {
			 CGRect frame = self.searchCluesTableView.frame;
			 frame.size.height = ownFrame.origin.y - frame.origin.y;
			 self.searchCluesTableView.frame = frame;
			 
		 }
		 completion:^(BOOL finished)
		 {
			 //self.dividerView.alpha = 0.0;
		 }];
	}
}

- (void)keyboardWillHide:(NSNotification *)notification
{
	if(activeTextField)
	//if(notification.object == self)
	{
		//NSLog(@"Keyboard will hide for DirectoryViewController");
		//make searchCluesTableView go away
		//bring back divider bar
		[UIView animateWithDuration:0.35
							  delay:0.0
							options:UIViewAnimationOptionCurveEaseInOut
						 animations:^
		 {
			 CGRect frame = self.searchCluesTableView.frame;
			 frame.size.height = 0.0;
			 self.searchCluesTableView.frame = frame;
		 }
		completion:^(BOOL finished)
		 {
			 self.searchCluesTableView.hidden = YES;
			 activeTextField = nil;
		 }];
	}
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)viewBottom:(CGFloat)bottomCoord
{
	//sets the height of the main view.  Used to accommodate tab bar
	CGRect frame = self.view.frame;
	frame.size.height = bottomCoord;
	self.view.frame = frame;
}

-(IBAction)info
{
	//spawn infoView
	InfoView *iv = [InfoView CreateWithDelegate:self];
	iv.frame = self.view.bounds;
	[self.view addSubview:iv];
}

#pragma mark Back Button

-(IBAction)Back:(UIButton *)sender
{
	
	if(directoryMode == DIRECTORY_MODE_SEARCH)
	{
		[self transitionSearchToListing];
	}
	else if(directoryMode == DIRECTORY_MODE_MAP)
	{
		[self transitionMapToListing];
	}
	else if(directoryMode == DIRECTORY_MODE_ON_THE_WEB_LISTING)
	{
		directoryMode = DIRECTORY_MODE_LISTING;
		//[self.tableView beginUpdates];
		[self addBusinessListingHeader];
		//[self.tableView endUpdates];
		[self showDividerView];
		[self positionDividerView];
		[self hideBackButtonAnimated:YES];

	}
}

-(void)hideBackButtonAnimated:(BOOL)animated
{
	//NSLog(@"Hiding back button");
	if(animated)
	{
		[UIView animateWithDuration:0.5
							  delay:0.0
							options:UIViewAnimationOptionCurveLinear | UIViewAnimationOptionBeginFromCurrentState
						 animations:^
		 {
			 self.btn_back.alpha = 0.0;
		 }
		 completion:^(BOOL finished)
		 {
			 
		 }];
	}
	else
	{
		self.btn_back.alpha = 0.0;
	}
}

-(void)showBackButtonAnimated:(BOOL)animated
{
	//NSLog(@"Showing back button");
	if(animated)
	{
		[UIView animateWithDuration:0.5
							  delay:0.0
							options:UIViewAnimationOptionCurveLinear | UIViewAnimationOptionBeginFromCurrentState
						 animations:^
		 {
			 self.btn_back.alpha = 1.0;
		 }
						 completion:^(BOOL finished)
		 {
			 
		 }];
	}
	else
	{
		self.btn_back.alpha = 1.0;
	}
}

-(void)removeBusinessListingHeader
{
	if(self.tableView.tableHeaderView)
	{
		categoryView = self.tableView.tableHeaderView;
		self.tableView.tableHeaderView = nil;
	}
}

-(void)addBusinessListingHeader
{
	if(categoryView)
	{
		self.tableView.tableHeaderView = categoryView;
		categoryView = nil;
	}
}
/*
-(NSString *)metersToDistance:(float)meters
{
	//used to generate string that is displayed in distance ribbon
	float feet = meters * 3.28084;
	NSString *resultString = nil;
	
	if(feet < 1000.0)
	{
		//give result in feet
		if((int)feet == 1)
		{
			resultString = @"1 foot";
		}
		else
		{
			resultString = [NSString stringWithFormat:@"%.0f feet", feet];
		}
	}
	else
	{
		//give result in miles
		if((int)feet == 5280)
		{
			resultString = @"1 mile";
		}
		else
		{
			resultString = [NSString stringWithFormat:@"%.2f miles", feet / 5280.0];
		}
	}
	return resultString;
}*/

#pragma mark category buttons

-(IBAction)CategoryButton:(UIButton *)sender
{
	//NSLog(@"Category %li", (long)sender.tag);
	switch(sender.tag)
	{
		case TAG_CATEGORY_RESTAURANTS:
			self.searchTextfield.text = NSLocalizedString(@"Restaurants", nil);
			[self transitionListingToMap];
			break;
		case TAG_CATEGORY_BARS:
			self.searchTextfield.text = NSLocalizedString(@"Bars", nil);
			[self transitionListingToMap];
			break;
		case TAG_CATEGORY_COFFEE:
			self.searchTextfield.text = NSLocalizedString(@"Coffee & Tea", nil);
			[self transitionListingToMap];
			break;
		case TAG_CATEGORY_MORE:
			[self launchMoreCategories];
			break;
			

	}
	
}

#pragma mark Search

-(void)businessListingQueryForPage:(int)page northEastCoordinate:(CLLocationCoordinate2D)ne southWestCoordinate:(CLLocationCoordinate2D)sw
{
	NSString *boundingBox = [NSString stringWithFormat:@"%f,%f|%f,%f", sw.latitude, sw.longitude, ne.latitude, ne.longitude];
	NSString *myLatLong = [NSString stringWithFormat:@"%f,%f", self.mapView.userLocation.location.coordinate.latitude, self.mapView.userLocation.location.coordinate.longitude];
	NSMutableString *query = [[NSMutableString alloc] initWithFormat:@"%@/search/?ll=%@&sort=%i&page=%i&page_size=%i&bounds=%@", SERVER_API, myLatLong, SORT_RESULT_DISTANCE, page + 1, DEFAULT_RESULTS_PER_PAGE, boundingBox];
	
	[self businessListingQuery:query];
}
/* cw no longer used but keep around just in case...
-(void)businessListingQueryForPage:(int)page centerCoordinate:(CLLocationCoordinate2D)center radius:(float)radiusInMeters
{
	NSString *latLong = [NSString stringWithFormat:@"%f,%f", center.latitude, center.longitude];
	NSMutableString *query = [[NSMutableString alloc] initWithFormat:@"%@/search/?radius=%.0f&ll=%@&sort=%i&page=%i&page_size=%i", SERVER_API, radiusInMeters, latLong, SORT_RESULT_DISTANCE, page + 1, DEFAULT_RESULTS_PER_PAGE];
	
	[self businessListingQuery:query];
}*/

-(void)businessListingQueryForPage:(int)page
{
	NSMutableString *query = [[NSMutableString alloc] initWithFormat:@"%@/search/?sort=%i&page=%i&page_size=%i", SERVER_API, SORT_RESULT_DISTANCE, page + 1, DEFAULT_RESULTS_PER_PAGE];
	
	[self businessListingQuery:query];
}

-(void)addLocationToQuery:(NSMutableString *)query
{
	if ([query rangeOfString:@"&ll="].location == NSNotFound)
	{
		CLLocation *location = [Location controller].curLocation;
		if(location) //can be nil if user has locationServices turned off
		{
			NSString *locationString = [NSString stringWithFormat:@"%f,%f", location.coordinate.latitude, location.coordinate.longitude];
			[query appendFormat:@"&ll=%@", locationString];
			
			if([self.locationTextfield.text length])
			{
				if([[self.locationTextfield.text uppercaseString] isEqualToString:[CURRENT_LOCATION_STRING uppercaseString]])
				{
					//CLLocation *location = [Location controller].curLocation;
					//NSString *locationString = [NSString stringWithFormat:@"%f,%f", location.coordinate.latitude, location.coordinate.longitude];
					//[query appendFormat:@"&ll=%@", locationString];
				}
				else
				{
					[query appendFormat:@"&location=%@", self.locationTextfield.text];
				}
			}
		}
	}
	else
	{
		//NSLog(@"string already contains ll");
	}
}

-(void)businessListingQuery:(NSMutableString *)query
{
	//load business listing based on user's search criteria
	if([self.searchTextfield.text length])
	{
		[query appendFormat:@"&term=%@", self.searchTextfield.text];
	}
	[self addLocationToQuery:query];
	
	NSString *serverQuery = [query stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding];
	//NSLog(@"Query to server: %@", serverQuery);
	
	[[DL_URLServer controller] issueRequestURL:serverQuery
									withParams:nil
									withObject:nil
								  withDelegate:self
							acceptableCacheAge:AGE_ACCEPT_CACHE_SECS
								   cacheResult:YES];
}

-(void)pruneCachedLocationItemsFromSearchResults
{
	for(NSString *string in searchLocationCache)
	{
		BOOL foundMatch = NO;
		int index = 0;
		for(NSString *result in searchResultsArray)
		{
			if([string isEqualToString:result])
			{
				foundMatch = YES;
				break;
			}
			index++;
		}
		if(foundMatch)
		{
			[searchResultsArray removeObjectAtIndex:index];
		}
	}
}

-(void)pruneCachedSearchItemsFromSearchResults
{
	for(int i = 0; i<searchTermCache.count; i++)
	{
		BOOL foundMatch = NO;
		NSString *string;
		
		string = [self stringForObjectInCache:searchTermCache atIndex:i];

		int j;
		for(j=0; j<searchResultsArray.count; j++)
		{
			NSString *result = [self stringForObjectInCache:searchResultsArray atIndex:j];

			if([string isEqualToString:result])
			{
				foundMatch = YES;
				break;
			}
		}
		if(foundMatch)
		{
			//NSLog(@"Pruning From Results: %@", [searchResultsArray objectAtIndex:j]);
			[searchResultsArray removeObjectAtIndex:j];
		}
	}
}

-(NSString *)stringForObjectInCache:(NSArray *)cache atIndex:(NSInteger)index
{
	//if object is dictionary, string is its "text" object
	//otherwise object will already be a string
	
	NSObject *object = [cache objectAtIndex:index];
	NSString *string;
	if([object isKindOfClass:[NSDictionary class]])
	{
		string = [(NSDictionary*)object objectForKey:@"text"];
	}
	else
	{
		string = (NSString *)object;
	}
	return string;
}

#pragma mark transitions

/* Possible transitions: 

 LM -> SM - when user taps in search bar
 SM -> MM - when user taps item in search table
 SM -> LM - when user taps back button on search table
 MM -> SM - when user taps search bar while in map mode
 MM -> LM - when user taps back button while in map mode

 */

-(void)transitionListingToSearch
{
	//NSLog(@"Transition Listing TO Search");
	directoryMode = DIRECTORY_MODE_SEARCH;
	[UIView animateWithDuration:0.35
						  delay:0.0
						options:UIViewAnimationOptionCurveEaseInOut
					 animations:^
	 {
		 CGRect frame = self.searchView.frame;
		 frame.size.height += EXTRA_SEARCH_BAR_HEIGHT;
		 self.searchView.frame = frame;
		 
		 //push top of content area down by EXTRA SEARCH BAR HEIGHT
		 CGRect contentFrame = self.contentView.frame;
		 contentFrame.origin.y += EXTRA_SEARCH_BAR_HEIGHT;
		 contentFrame.size.height -= EXTRA_SEARCH_BAR_HEIGHT;
		 self.contentView.frame = contentFrame;
	 }
	 completion:^(BOOL finished)
	 {
		 //NSLog(@"Listing To Search COMPLETION");
		 [self showBackButtonAnimated:YES];
		 [self showDividerView]; //in case it was previously hidden by an on the web search
	 }];
}

-(void)setDefaultMapDividerPosition
{
	//put divider in ~ middle of screen.  Adjust map and tableView to divider position
	CGRect dividerFrame = self.dividerView.frame;
	dividerFrame.origin.y = (self.contentView.frame.size.height) / 2;
	self.dividerView.frame = dividerFrame;
	
	//set map frame
	CGRect mapFrame = self.mapView.frame;
	mapFrame.size.height = dividerFrame.origin.y + DIVIDER_BAR_TRANSPARENT_AREA_HEIGHT;
	self.mapView.frame = mapFrame;
	
	[self TackLocateMeButtonToMapBottomCorner];
	
	//set tableView frame right under divider bar
	CGRect tableFrame = self.tableView.frame;
	tableFrame.origin.y = self.mapView.frame.origin.y + self.mapView.frame.size.height;
	tableFrame.size.height = self.contentView.bounds.size.height - tableFrame.origin.y;
	self.tableView.frame = tableFrame;
}

-(void)transitionSearchToMap
{
	//NSLog(@"Transition Search To Map");
	directoryMode = DIRECTORY_MODE_MAP;
	//NSLog(@"Setting map state to INIT");
	mapDisplayState = MAP_DISPLAY_INIT;
	//subtly show mapView
	[self showMapView];
	self.dividerView.userControllable = YES;
	[self removeBusinessListingHeader];
	[self.searchTextfield resignFirstResponder];
	[self.locationTextfield resignFirstResponder];
	self.mapView.showsUserLocation = YES;
	[self.tableView setContentOffset:CGPointZero animated:NO];
	
	[self setDefaultMapDividerPosition];
	
	[self businessListingQueryForPage:0];
	
	[UIView animateWithDuration:0.35
						  delay:0.0
						options:UIViewAnimationOptionCurveEaseInOut
					 animations:^
	 {
		 CGRect contentFrame = self.contentView.frame;
		 contentFrame.origin.y -= EXTRA_SEARCH_BAR_HEIGHT;
		 contentFrame.size.height += EXTRA_SEARCH_BAR_HEIGHT;
		 self.contentView.frame = contentFrame;
		 
		 CGRect frame = self.searchView.frame;
		 frame.size.height -= EXTRA_SEARCH_BAR_HEIGHT;
		 self.searchView.frame = frame;
	 }
	 completion:^(BOOL finished)
	 {
		 
		 
		/* CGRect dividerFrame = self.dividerView.frame;
		 dividerFrame.origin.y = contentFrame.size.height / 2;
		 self.dividerView.frame = dividerFrame;
	 
		 //set map frame
		 CGRect mapFrame = self.mapView.frame;
		 mapFrame.size.height = dividerFrame.origin.y + DIVIDER_BAR_TRANSPARENT_AREA_HEIGHT;
		 self.mapView.frame = mapFrame;
		
		 [self TackLocateMeButtonToMapBottomCorner];
		 
		 self.dividerView.userControllable = YES;
		 [self removeBusinessListingHeader];
		
		 //position divider bar under map
		 //CGRect dividerFrame = self.dividerView.frame;
		 //dividerFrame.origin.y = self.mapView.frame.origin.y + self.mapView.frame.size.height - DIVIDER_BAR_TRANSPARENT_AREA_HEIGHT;
		 //self.dividerView.frame = dividerFrame;

		 //set tableView frame right under divider bar
		 CGRect tableFrame = self.tableView.frame;
		 tableFrame.origin.y = self.mapView.frame.origin.y + self.mapView.frame.size.height;
		 tableFrame.size.height = self.view.bounds.size.height - tableFrame.origin.y;
		 self.tableView.frame = tableFrame;

		 
		 
		 [UIView animateWithDuration:0.35
							  delay:0.0
							options:UIViewAnimationOptionCurveEaseInOut
						 animations:^
		 {
			 
			 
			 //[self showMapView];
			 
			 //frame = self.mapView.frame;
			 //frame.origin.y -= EXTRA_SEARCH_BAR_HEIGHT;
			 //frame.size.height += EXTRA_SEARCH_BAR_HEIGHT;
			 //self.mapView.frame = frame;
			 
			 [self TackLocateMeButtonToMapBottomCorner];
		 }
		 completion:^(BOOL finished)
		 {
			 
			 [self businessListingQueryForPage:0];
		 }];*/
	}];
}

-(void)transitionSearchToListing
{
	//directoryMode = DIRECTORY_MODE_ON_THE_WEB_LISTING;
	[businessSearchResults removeAllObjects];
	[self.searchTextfield resignFirstResponder];
	[self.locationTextfield resignFirstResponder];
	if(directoryMode == DIRECTORY_MODE_ON_THE_WEB_LISTING)
	{
		[self removeBusinessListingHeader];
		[self hideDividerView];
	}
	else
	{
		directoryMode = DIRECTORY_MODE_LISTING;
		[self hideBackButtonAnimated:YES];
	}
	[self.tableView setContentOffset:CGPointZero animated:NO];
	[self businessListingQueryForPage:0];
	[UIView animateWithDuration:0.5
						  delay:0.0
						options:UIViewAnimationOptionCurveEaseInOut
					 animations:^
	 {
		 CGRect frame = self.searchView.frame;
		 frame.size.height -= EXTRA_SEARCH_BAR_HEIGHT;
		 self.searchView.frame = frame;
		 
		 /*frame = self.tableView.frame;
		 frame.origin.y -= EXTRA_SEARCH_BAR_HEIGHT;
		 self.tableView.frame = frame;
		 
		 frame = self.dividerView.frame;
		 frame.origin.y -= EXTRA_SEARCH_BAR_HEIGHT;
		 self.dividerView.frame = frame;*/
		 CGRect contentFrame = self.contentView.frame;
		 contentFrame.origin.y -= EXTRA_SEARCH_BAR_HEIGHT;
		 contentFrame.size.height += EXTRA_SEARCH_BAR_HEIGHT;
		 self.contentView.frame = contentFrame;
		 
	 }
	 completion:^(BOOL finished)
	 {
		 
		 
	 }];
}

-(void)transitionMapToSearch
{
	directoryMode = DIRECTORY_MODE_SEARCH;
	
	[UIView animateWithDuration:0.35
						  delay:0.0
						options:UIViewAnimationOptionCurveEaseInOut
					 animations:^
	 {
		 CGRect frame = self.searchView.frame;
		 frame.size.height += EXTRA_SEARCH_BAR_HEIGHT;
		 self.searchView.frame = frame;
		 

		 CGRect contentFrame = self.contentView.frame;
		 contentFrame.origin.y += EXTRA_SEARCH_BAR_HEIGHT;
		 contentFrame.size.height -= EXTRA_SEARCH_BAR_HEIGHT;
		 self.contentView.frame = contentFrame;
	 }
	 completion:^(BOOL finished)
	 {
		 //
		 self.dividerView.userControllable = NO;
		 [self addBusinessListingHeader];
		 [self positionDividerView];
		 
		 //subtly hide mapView
		 [UIView animateWithDuration:0.5
							   delay:0.0
							 options:UIViewAnimationOptionCurveLinear
						  animations:^
		  {
			  [self hideMapView];
		  }
		  completion:^(BOOL finished)
		  {
			  self.mapView.showsUserLocation = NO;
			  [self.mapView removeAllAnnotations];
			  self.tableView.frame = homeTableViewFrame;
		  }];

	 }];
}

-(void)transitionListingToMap
{
	directoryMode = DIRECTORY_MODE_MAP;
	//NSLog(@"Setting map state to INIT");
	mapDisplayState = MAP_DISPLAY_INIT;
	
	self.dividerView.userControllable = YES;
	[self removeBusinessListingHeader];
	[self showBackButtonAnimated:YES];

	[self setDefaultMapDividerPosition];
	
	[self businessListingQueryForPage:0];
	[UIView animateWithDuration:0.35
						  delay:0.0
						options:UIViewAnimationOptionCurveLinear
					 animations:^
	 {
		 
		 [self showMapView];
	 }
	 completion:^(BOOL finished)
	 {
		 
	 }];
}

-(void)transitionMapToListing
{
	directoryMode = DIRECTORY_MODE_LISTING;

	[self hideMapView];
	self.mapView.showsUserLocation = NO;
	self.dividerView.userControllable = NO;
	[self addBusinessListingHeader];
	self.tableView.frame = homeTableViewFrame;
	[self positionDividerView];
	[self hideBackButtonAnimated:YES];
	[self.mapView removeAllAnnotations];
	[self.tableView setContentOffset:CGPointZero animated:YES];
}
#pragma mark MapView

- (void)didDragMap:(UIGestureRecognizer*)gestureRecognizer
{
	static BOOL dragProcessingComplete = NO;
	
	if(!dragProcessingComplete)
	{
		dragProcessingComplete = YES;
		//NSLog(@"Processing drag operation");
		if(singleCalloutView)
		{
			[singleCalloutView dismissCalloutAnimated:YES];
		}
	}
    if (gestureRecognizer.state == UIGestureRecognizerStateEnded)
	{
        //NSLog(@"drag ended");
		dragProcessingComplete = NO;
    }
}

-(IBAction)LocateMe:(UIButton *)sender
{
	[self.mapView setCenterCoordinate:self.mapView.userLocation.location.coordinate animated:YES];
}

-(void)TackLocateMeButtonToMapBottomCorner
{
	CGRect locateMeFrame = self.btn_locateMe.frame;
	locateMeFrame.origin.y = self.mapView.frame.origin.y + self.mapView.frame.size.height - LOCATE_ME_BUTTON_OFFSET_FROM_MAP_BOTTOM;
	self.btn_locateMe.frame = locateMeFrame;
	
	if(locateMeFrame.origin.y < MINIMUM_LOCATE_ME_BUTTON_OFFSET_Y)
	{
		if(locateMeButtonDesiredAlpha != 0.0)
		{
			locateMeButtonDesiredAlpha = 0.0;
			//hide locateMe button
			[UIView animateWithDuration:0.1
								  delay:0.0
								options:UIViewAnimationOptionCurveLinear
							 animations:^
			 {
				 self.btn_locateMe.alpha = locateMeButtonDesiredAlpha;
			 }
			completion:^(BOOL finished)
			 {
			 }];
		}
	}
	else
	{
		if(locateMeButtonDesiredAlpha != 1.0)
		{
			locateMeButtonDesiredAlpha = 1.0;
			//hide locateMe button
			[UIView animateWithDuration:0.1
								  delay:0.0
								options:UIViewAnimationOptionCurveLinear
							 animations:^
			 {
				 self.btn_locateMe.alpha = locateMeButtonDesiredAlpha;
			 }
			completion:^(BOOL finished)
			 {
			 }];
		}
	}
}

-(void)hideMapView
{
	self.mapView.alpha = 0.0;
	self.btn_locateMe.alpha = 0.0;
}

-(void)showMapView
{
	self.mapView.alpha = 1.0;
	self.btn_locateMe.alpha = 1.0 * locateMeButtonDesiredAlpha;
}

- (MKAnnotationView *)mapView:(MKMapView *)map viewForAnnotation:(id <MKAnnotation>)annotation
{
	//returns a view for the map "pin"
	if (annotation == map.userLocation)
	{
		// We can return nil to let the MapView handle the default annotation view (blue dot):
		return nil;
	}
	else
	{
		static NSString *AnnotationViewID = @"annotationViewID";
		
		CustomAnnotationView *customAnnotationView = (CustomAnnotationView *)[map dequeueReusableAnnotationViewWithIdentifier:AnnotationViewID];
		
		if (customAnnotationView == nil)
		{
			customAnnotationView = [[CustomAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:AnnotationViewID];
			[customAnnotationView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(AnnotationTapped:)]];
			customAnnotationView.image = [UIImage imageNamed:@"bitCoinAnnotation"];
		}
		else
		{
			if (customAnnotationView.calloutView)
			{
				[customAnnotationView.calloutView removeFromSuperview];
				customAnnotationView.calloutView = nil;
			}
		}
		customAnnotationView.annotation = annotation;
		customAnnotationView.enabled = NO; //keeps callout from disappearing when user taps on an annotation that's partially overlapping another annotation
		return customAnnotationView;
	}
}

- (void)mapView:(MKMapView *)mapView didDeselectAnnotationView:(MKAnnotationView *)view
{
	//NSLog(@"Did deselect annotation view");

	if([view isKindOfClass:[CustomAnnotationView class]])
	{
		if(view == singleCalloutView.superview)
		{
			//NSLog(@"Dismissing callout due to annotation deselected");
			[singleCalloutView dismissCalloutAnimated:YES];
		}
	}
}

-(void)mapViewDidFinishLoadingMap:(MKMapView *)mapView
{
	//NSLog(@"Did finish loading map");
}

-(void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated
{
	//NSLog(@"Map Region Changed");

	if(mapDisplayState == MAP_DISPLAY_NORMAL)
	{
		MKMapRect mRect = self.mapView.visibleMapRect;
		MKMapPoint neMapPoint = MKMapPointMake(MKMapRectGetMaxX(mRect), mRect.origin.y);
		MKMapPoint swMapPoint = MKMapPointMake(mRect.origin.x, MKMapRectGetMaxY(mRect));
		CLLocationCoordinate2D neCoord = MKCoordinateForMapPoint(neMapPoint);
		CLLocationCoordinate2D swCoord = MKCoordinateForMapPoint(swMapPoint);
		
		[[DL_URLServer controller] cancelAllRequestsForDelegate:self];
		[self businessListingQueryForPage:0 northEastCoordinate:neCoord southWestCoordinate:swCoord];
	}
	if(mapDisplayState == MAP_DISPLAY_ZOOM)
	{
		//NSLog(@"Setting map state to NORMAL");
		mapDisplayState = MAP_DISPLAY_NORMAL;
	}
}

-(void)createSingleCalloutView
{
	singleCalloutView = [SMCalloutView new];
	singleCalloutView.delegate = self;
	UIButton *disclosure = [UIButton buttonWithType:UIButtonTypeCustom];
	[disclosure addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(disclosureTapped)]];
	singleCalloutView.rightAccessoryView = disclosure;
}

- (void)AnnotationTapped:(UITapGestureRecognizer *)recognizer
{
    //NSLog(@"Tapped annotation");
	//to prevent callout from disappearing right after it appeared because user scrolled map then quickly tapped on an annotation.
	[[DL_URLServer controller] cancelAllRequestsForDelegate:self];
	//calloutViewTapCount++;
    // dismiss our callout if it's already shown but on a different parent view
    //[bottomMapView deselectAnnotation:bottomPin.annotation animated:NO];
	//if (calloutView.window) [calloutView dismissCalloutAnimated:NO];
    // now in this example we're going to introduce an artificial delay in order to make our popup feel identical to MKMapView.
    // MKMapView has a delay after tapping so that it can intercept a double-tap for zooming. We don't need that delay but we'll
    // add it just so things feel the same.
	[recognizer.view.superview bringSubviewToFront:recognizer.view];
	if(singleCalloutView.superview != recognizer.view) //keeps callout from re-popping up if user repeatedly taps on same annotation
	{
		[singleCalloutView removeFromSuperview];
		[self popupCalloutView:recognizer.view];
	}
    //[self performSelector:@selector(popupCalloutView:) withObject:recognizer.view afterDelay:1.0/3.0];
	//[self.mapView popupCalloutForAnnotationView:(CustomAnnotationView *)recognizer.view];
}

- (void)popupCalloutView:(UIView *)parentView;
{
	//NSLog(@"Popping up callout");
	// custom view to be used in our callout
	AnnotationContentView *av = [AnnotationContentView Create];
	av.backgroundColor = [UIColor colorWithWhite:1 alpha:0.5];
   // av.layer.borderColor = [UIColor redColor].CGColor ;//[UIColor colorWithWhite:0 alpha:0.6].CGColor;
    av.layer.borderColor = [UIColor colorWithRed:0 green:80.0 / 255.0 blue:132.0 / 255.0 alpha:0.5].CGColor;
    av.layer.borderWidth = 1;
    av.layer.cornerRadius = 4;
	
	CustomAnnotationView *customAnnotationView = (CustomAnnotationView *)parentView;
	
	Annotation *annotation = customAnnotationView.annotation;
	av.titleLabel.text = annotation.title;
	av.subtitleLabel.text = annotation.subtitle;
	av.bkg_image.image = [backgroundImages imageForBusiness:annotation.business];
	selectedBusinessInfo = annotation.business;
	
	av.userInteractionEnabled = YES;
	
	if(!singleCalloutView)
	{
		[self createSingleCalloutView];
	}
	singleCalloutView.contentView = av;
	
	
	
	singleCalloutView.calloutOffset = customAnnotationView.calloutOffset;
	
	customAnnotationView.calloutView = singleCalloutView;
	
    [singleCalloutView presentCalloutFromRect:parentView.bounds
                                 inView:parentView
                      constrainedToView:self.mapView
               permittedArrowDirections:SMCalloutArrowDirectionAny
                               animated:YES];
}

#pragma mark Segue

-(void)launchBusinessDetailsWithBizID:(NSString *)bizId andLocation:(CLLocationCoordinate2D)location animated:(BOOL)animated
{
	UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"Main_iPhone" bundle: nil];
	businessDetailsController = [mainStoryboard instantiateViewControllerWithIdentifier:@"BusinessDetailsViewController"];
	
	businessDetailsController.bizId = bizId;
	businessDetailsController.latLong = location;
	businessDetailsController.delegate = self;
	
	CGRect frame = self.view.bounds;
	frame.origin.x = frame.size.width;
	businessDetailsController.view.frame = frame;
	[self.view addSubview:businessDetailsController.view];
	
	if(animated)
	{
		[UIView animateWithDuration:0.35
						  delay:0.0
						options:UIViewAnimationOptionCurveEaseInOut
					 animations:^
		 {
			 businessDetailsController.view.frame = self.view.bounds;
		 }
		 completion:^(BOOL finished)
		 {
		 //self.dividerView.alpha = 0.0;
		 }];
	}
}

-(void)animateBusinessDetailsOnScreen
{
	[UIView animateWithDuration:0.35
						  delay:0.0
						options:UIViewAnimationOptionCurveEaseInOut
					 animations:^
	 {
		 businessDetailsController.view.frame = self.view.bounds;
	 }
					 completion:^(BOOL finished)
	 {
	 }];
}

/*
-(void)launchBusinessDetails
{
	UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"Main_iPhone" bundle: nil];
	businessDetailsController = [mainStoryboard instantiateViewControllerWithIdentifier:@"BusinessDetailsViewController"];
	
	
	//businessDetailsController.businessGeneralInfo = selectedBusinessInfo;
	businessDetailsController.bizId = [selectedBusinessInfo objectForKey:@"bizId"];
	businessDetailsController.delegate = self;
	
	CGRect frame = self.view.bounds;
	frame.origin.x = frame.size.width;
	businessDetailsController.view.frame = frame;
	[self.view addSubview:businessDetailsController.view];
	
	
	[UIView animateWithDuration:0.35
						  delay:0.0
						options:UIViewAnimationOptionCurveEaseInOut
					 animations:^
	 {
		 businessDetailsController.view.frame = self.view.bounds;
	 }
	 completion:^(BOOL finished)
	 {
		 //self.dividerView.alpha = 0.0;
	 }];
	 
}
*/

-(void)dismissBusinessDetails
{
	[UIView animateWithDuration:0.35
						  delay:0.0
						options:UIViewAnimationOptionCurveEaseInOut
					 animations:^
	 {
		 CGRect frame = self.view.bounds;
		 frame.origin.x = frame.size.width;
		 businessDetailsController.view.frame = frame;
	 }
	completion:^(BOOL finished)
	 {
		 [businessDetailsController.view removeFromSuperview];
		 businessDetailsController = nil;
	 }];
}

-(void)launchMoreCategories
{
	UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"Main_iPhone" bundle: nil];
	moreCategoriesController = [mainStoryboard instantiateViewControllerWithIdentifier:@"MoreCategoriesViewController"];
	
	moreCategoriesController.delegate = self;
	
	CGRect frame = self.view.bounds;
	frame.origin.x = frame.size.width;
	moreCategoriesController.view.frame = frame;
	[self.view addSubview:moreCategoriesController.view];
	
	
	[UIView animateWithDuration:0.35
						  delay:0.0
						options:UIViewAnimationOptionCurveEaseInOut
					 animations:^
	 {
		 moreCategoriesController.view.frame = self.view.bounds;
	 }
	 completion:^(BOOL finished)
	 {
	 }];
}

-(void)dismissMoreCategories
{
	[UIView animateWithDuration:0.35
						  delay:0.0
						options:UIViewAnimationOptionCurveEaseInOut
					 animations:^
	 {
		 CGRect frame = self.view.bounds;
		 frame.origin.x = frame.size.width;
		 moreCategoriesController.view.frame = frame;
	 }
	 completion:^(BOOL finished)
	 {
		 [moreCategoriesController.view removeFromSuperview];
		 moreCategoriesController = nil;
	 }];
}
/*
-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
	if([segue.identifier isEqualToString:@"BusinessDetailsSegue"])
	{
		BusinessDetailsViewController *vc = [segue destinationViewController];
		
		vc.businessGeneralInfo = selectedBusinessInfo;
	}
}*/

#pragma mark Business Listing buffer management

-(void)bufferBusinessResults:(NSArray *)arrayResults forPage:(int)page
{
	//adds a block of business search results to the businessSearchResults dictionary
	
	int row = page * DEFAULT_RESULTS_PER_PAGE;
	[businessSearchResults removeAllObjects];
	[self.mapView removeAllAnnotations];
	[backgroundImages removeAllImages];
	
	//NSLog(@"Populate map annotations");
	for(NSDictionary *dict in arrayResults)
	{
		//printf("%i, ", row);
		[businessSearchResults setObject:dict forKey:[NSNumber numberWithInt:row]];
		[backgroundImages loadImageForBusiness:dict];
		Annotation *ann = [self.mapView addAnnotationForBusiness:dict];
		if(ann)
		{
			//ann.thumbnailImage = [backgroundImages imageForBusiness:ann.business];
		}
		row++;
	}
	//NSLog(@"Loaded page %i.  Buffer size: %lu", page, (unsigned long)businessSearchResults.count);
	if(mapDisplayState == MAP_DISPLAY_INIT)
	{
		//NSLog(@"Setting map state to ZOOM");
		mapDisplayState = MAP_DISPLAY_ZOOM;
		//NSLog(@"Zooming map");
		[self.mapView zoomToFitMapAnnotations];
	}
}

-(void)removeSearchResultsPage:(int)page
{
	if(page >= 0)
	{
		for (int row = page * DEFAULT_RESULTS_PER_PAGE; row < ((page + 1) * DEFAULT_RESULTS_PER_PAGE); row++)
		{
			NSDictionary *business = [businessSearchResults objectForKey:[NSNumber numberWithInt:row]];
			[backgroundImages removeImageForBusiness:business];
			[businessSearchResults removeObjectForKey:[NSNumber numberWithInt:row]];
		}
		//NSLog(@"Removed page: %i.  Buffer size: %lu", page, (unsigned long)[businessSearchResults count]);
	}
}

-(void)manageBusinessListingsResultsBufferForPage:(int)page
{
	if(page != currentPage)
	{
		//time to manage the buffer
		//load new page
		if(page > currentPage)
		{
			if(page < (totalResultsCount + (DEFAULT_RESULTS_PER_PAGE - 1) / DEFAULT_RESULTS_PER_PAGE))
			{
				//[self loadSearchResultsPage:page + 1];
				[self businessListingQueryForPage:page + 1];
				[self removeSearchResultsPage:page - 2];
			}
		}
		else
		{
			if(page > 0)
			{
				//[self loadSearchResultsPage:page - 1];
				[self businessListingQueryForPage:page - 1];
				[self removeSearchResultsPage:page + 2];
			}
		}
		//NSLog(@"Setting current page to: %i", page);
		currentPage = page;
	}
}

#pragma mark UITextField delegates

-(void)textFieldDidBeginEditing:(UITextField *)textField
{
	//called when user taps on either search textField or location textField
	
	activeTextField = textField;
	
	//NSLog(@"TextField began editing");
	if(directoryMode != DIRECTORY_MODE_SEARCH)
	{
		if((directoryMode == DIRECTORY_MODE_LISTING) || (directoryMode == DIRECTORY_MODE_ON_THE_WEB_LISTING))
		{
			//NSLog(@"APP MODE MAP.  Transition Listing to Search");
			[self transitionListingToSearch];
		}
		if(directoryMode == DIRECTORY_MODE_MAP)
		{
			//NSLog(@"APP MODE MAP.  Transition MAP to Search");
			[self transitionMapToSearch];
		}
	}
	if(textField == self.locationTextfield)
	{
		mostRecentSearchTag = TAG_LOCATION_SEARCH;
		//NSLog(@"Most Recent Search Tag: TAG_LOCATION_SEARCH");
		[self locationTextFieldChanged:textField];
	}
	if(textField == self.searchTextfield)
	{
		mostRecentSearchTag = TAG_BUSINESS_SEARCH;
		//NSLog(@"Most Recent Search Tag: TAG_BUSINESS_SEARCH");
		[self searchTextFieldChanged:textField];
	}
}

//http://107.170.22.83:80/api/v1/autocomplete-business/?term=den&location=san
-(void)searchTextFieldChanged:(UITextField *)textField
{
	//NSLog( @"search text changed: %@", textField.text);
	//mostRecentSearchTag = TAG_BUSINESS_SEARCH;
	
	[[DL_URLServer controller] cancelAllRequestsForDelegate:self];
	NSMutableString *urlString = [[NSMutableString alloc] init];

	NSString *searchTerm = [textField.text stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding];
	if(searchTerm == nil)
	{
		//there are non ascii characters in the string
		searchTerm = @" ";
		
	}
	else
	{
		searchTerm = textField.text;
	}
	[urlString appendString:[NSString stringWithFormat:@"%@/autocomplete-business/?term=%@", SERVER_API, searchTerm]];

	[self addLocationToQuery:urlString];
	//NSLog(@"Autocomplete Query: %@", [urlString stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding]);
	if(urlString != (id)[NSNull null])
	{
		[[DL_URLServer controller] issueRequestURL:[urlString stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding]
										withParams:nil
										withObject:textField
									  withDelegate:self
								acceptableCacheAge:AGE_ACCEPT_CACHE_SECS
									   cacheResult:YES];
	}
	
}

/*
 Rules:
 Tap on current location
 Top two rows are:
 Current Location
 On The Web (these two highlighted different color like Yelp!)
 cached recent searches for the next up to 10 slots
 Recommendation from server (remainder of slots).  Don’t duplicate what is already cached.
 */

-(void)locationTextFieldChanged:(UITextField *)textField
{
	[[DL_URLServer controller] cancelAllRequestsForDelegate:self];
	//http://107.170.22.83:80/api/v1/autocomplete-location/?term=sa
	//NSLog( @"location text changed: %@", textField.text);
	NSMutableString *query = [[NSMutableString alloc] initWithString:[NSString stringWithFormat:@"%@/autocomplete-location?term=%@", SERVER_API, textField.text]];
	[self addLocationToQuery:query];
	//NSLog(@"Location Query: %@", query);
	[[DL_URLServer controller] issueRequestURL:[query stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding]
									withParams:nil
									withObject:textField
								  withDelegate:self
							acceptableCacheAge:AGE_ACCEPT_CACHE_SECS
								   cacheResult:YES];
}

-(BOOL)textFieldShouldReturn:(UITextField *)textField
{
	if(directoryMode == DIRECTORY_MODE_SEARCH)
	{
		if([[self.locationTextfield.text uppercaseString] isEqualToString:[ON_THE_WEB_STRING uppercaseString]])
		{
			directoryMode = DIRECTORY_MODE_ON_THE_WEB_LISTING;
			[self transitionSearchToListing];
		}
		else
		{
			[self transitionSearchToMap];
		}
	}
	 
	return YES;
}

#pragma mark UIScrollView delegates


-(void)scrollViewDidScroll:(UIScrollView *)scrollView
{
	if(scrollView.tag == 0)
	{
		//this is the business listings table
		[self positionDividerView];
		/*
		//manage the buffer of business listings
		//first find the average row number we're on.
		NSArray *paths = [self.tableView indexPathsForVisibleRows];
		int averageRowNumber = 0;
		for(NSIndexPath *path in paths)
		{
			averageRowNumber += path.row;
		}
		averageRowNumber /= paths.count;
		//now find the page that this row belongs to
		int page = averageRowNumber / DEFAULT_RESULTS_PER_PAGE;
		[self manageBusinessListingsResultsBufferForPage:page];
		*/
	}
}

#pragma mark Table View delegates
/*
-(void)didSwipe:(UIGestureRecognizer *)gestureRecognizer
{
	
	if (gestureRecognizer.state == UIGestureRecognizerStateEnded)
	{
        CGPoint swipeLocation = [gestureRecognizer locationInView:self.tableView];
        NSIndexPath *swipedIndexPath = [self.tableView indexPathForRowAtPoint:swipeLocation];
        //UITableViewCell* swipedCell = [self.tableView cellForRowAtIndexPath:swipedIndexPath];
        
		NSDictionary *businessInfo = [businessSearchResults objectForKey:[NSNumber numberWithInteger:swipedIndexPath.row]];
		
		//NSLog(@"Setting selected business info");
		selectedBusinessInfo = businessInfo;
		//[self performSegueWithIdentifier:@"BusinessDetailsSegue" sender:self];
		[self launchBusinessDetailsWithBizID:[businessInfo objectForKey:@"bizId"] andDistance:[[businessInfo objectForKey:@"distance"] floatValue] animated:YES];
	}
}*/

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if(tableView.tag == 0)
	{
		//business listings table
		return [businessSearchResults count];
	}
	else
	{
		//search clues table
		if(mostRecentSearchTag == TAG_BUSINESS_SEARCH)
		{
			if(self.searchTextfield.text.length == 0)
			{
				return [searchResultsArray count] + [searchTermCache count];
			}
			else
			{
				return [searchResultsArray count];
			}
		}
		else //(mostRecentSearchTag == TAG_LOCATION_SEARCH)
		{
			if(self.locationTextfield.text.length == 0)
			{
				return [searchResultsArray count] + 2 + [searchLocationCache count];
			}
			else
			{
				return [searchResultsArray count] + 2;
			}
		}
	}
}

-(topOverviewCell *)getTopOverviewCellForTableView:(UITableView *)tableView
{
	topOverviewCell *cell;
	static NSString *cellIdentifier = @"topOverviewCell";
	
	cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	if (nil == cell)
	{
		cell = [[topOverviewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
		
	}
	cell.delegate = self;
	return cell;
}

-(overviewCell *)getOverviewCellForTableView:(UITableView *)tableView
{
	overviewCell *cell;
	static NSString *cellIdentifier = @"overviewCell";
	
	cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	if (nil == cell)
	{
		cell = [[overviewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
		
	}
	cell.delegate = self;
	return cell;
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	NSInteger row = [indexPath row];
	//[self manageBusinessListingsResultsBufferForRow:row];
	if(tableView.tag == 0)
	{
		//business listings
		CommonOverviewCell *cell;
		
		NSDictionary *businessInfo = [businessSearchResults objectForKey:[NSNumber numberWithInteger:row]];
		/*Annotation *ann = [self.mapView addAnnotationForBusiness:businessInfo];
		if(ann)
		{
			ann.thumbnailImage = [backgroundImages imageForRow:row];
		}*/
		//[self.mapView zoomToFitMapAnnotations];
		if (row == 0)
		{
			//top cell
			cell = [self getTopOverviewCellForTableView:tableView];
		}
		else
		{
			cell = [self getOverviewCellForTableView:tableView];
		}
	
		if(businessInfo)
		{
			
			NSString *distance = [businessInfo objectForKey:@"distance"];
			if(distance && (distance != (id)[NSNull null]))
			{
				cell.ribbon = [RibbonView metersToDistance:[[businessInfo objectForKey:@"distance"] floatValue]];
			}
			else
			{
				cell.ribbon = nil;
				//NSLog(@"Unknown");
			}
			cell.businessNameLabel.text = [businessInfo objectForKey:@"name"];
			cell.businessNameLabel.textColor = [UIColor whiteColor];
			cell.addressLabel.text = [businessInfo objectForKey:@"address"];
	
			//NSLog(@"Requesting background image");
			UIImageView *imageView = cell.backgroundImageView;
			imageView.clipsToBounds = YES;
			imageView.image = [backgroundImages imageForBusiness:businessInfo];
			//((UIImageView *)cell.selectedBackgroundView).image = [backgroundImages darkImageForBusiness:businessInfo];
//			NSLog(@"SelectedBackgroundView: %@", cell.selectedBackgroundView);
			//cell.selectedBackgroundView.backgroundColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.5];
			//NSLog(@"ImageView: %@, image: %@", cell.backgroundView, imageView.image);
			
			cell.bitCoinLabel.hidden = NO;
			#if SHOW_SERVER_PAGE
			cell.bitCoinLabel.text = [NSString stringWithFormat:@"Page %i", row / DEFAULT_RESULTS_PER_PAGE];
			#else
			NSString *bitCoinDiscount = [businessInfo objectForKey:@"has_bitcoin_discount"];
			if(bitCoinDiscount)
			{
				float discount = [bitCoinDiscount floatValue] * 100.0;
				if(discount)
				{
					cell.bitCoinLabel.text = [NSString stringWithFormat:@"BTC Discount: %.0f%%", [bitCoinDiscount floatValue] * 100.0];
				}
				else
				{
					cell.bitCoinLabel.text = @" ";
				}
			}
			else
			{
				cell.bitCoinLabel.text = @" ";
			}
			#endif
			
		}
		else
		{
			//in case server returns fewer objects than it says (so we don't crash)
			cell.businessNameLabel.text = @"NO LISTING";
			cell.businessNameLabel.textColor = [UIColor yellowColor];
			cell.addressLabel.text = @" ";
			cell.bitCoinLabel.hidden = YES;
			//[cell loadBackgroundImageForBusiness:nil];
		}
		return cell;
	}
	else
	{
		//search clues
		static NSString *cellIdentifier = @"searchClueCell";
		
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
		if (nil == cell)
		{
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
		}
		if(mostRecentSearchTag == TAG_LOCATION_SEARCH)
		{
			//show results for location textfield
			
			unsigned long cacheSize = 0;
			if(self.locationTextfield.text.length == 0)
			{
				cacheSize = searchLocationCache.count;
			}
			if(indexPath.row < cacheSize)
			{
				cell.textLabel.text = [searchLocationCache objectAtIndex:indexPath.row];
				//
				cell.textLabel.textColor = [UIColor colorWithRed:0.5020 green:0.7647 blue:0.2549 alpha:1.0];
				cell.textLabel.backgroundColor = [UIColor clearColor];
			}
			else if(indexPath.row == cacheSize)
			{
				cell.textLabel.text = CURRENT_LOCATION_STRING;
				cell.textLabel.textColor = [UIColor blueColor];
				cell.textLabel.backgroundColor = [UIColor clearColor];
			}
			else if(indexPath.row == cacheSize + 1)
			{
				cell.textLabel.text = ON_THE_WEB_STRING;
				cell.textLabel.textColor = [UIColor purpleColor];
				cell.textLabel.backgroundColor = [UIColor clearColor];
			}
			else
			{
				//NSLog(@"Row: %li", (long)indexPath.row);
				//NSLog(@"Results array: %@", searchResultsArray);
				cell.textLabel.text = [searchResultsArray objectAtIndex:indexPath.row - (2 + cacheSize)];
				cell.textLabel.textColor = [UIColor darkGrayColor];
			}
		}
		else if(mostRecentSearchTag == TAG_BUSINESS_SEARCH)
		{
			unsigned long cacheSize = 0;
			if(self.searchTextfield.text.length == 0)
			{
				cacheSize = searchTermCache.count;
			}
			//show results for business search field
			//NSLog(@"Row: %li", (long)indexPath.row);
			//NSLog(@"Results array: %@", searchResultsArray);
			if(indexPath.row < cacheSize)
			{
				cell.textLabel.text = [self stringForObjectInCache:searchTermCache atIndex:indexPath.row];//[searchTermCache objectAtIndex:indexPath.row];
				cell.textLabel.textColor = [UIColor colorWithRed:0.5020 green:0.7647 blue:0.2549 alpha:1.0];
				cell.textLabel.backgroundColor = [UIColor clearColor];
			}
			else if(searchResultsArray.count)
			{
				NSObject *object = [searchResultsArray objectAtIndex:indexPath.row - cacheSize];
				if([object isKindOfClass:[NSDictionary class]])
				{
					cell.textLabel.text = [(NSDictionary*)object objectForKey:@"text"];
				}
				else
				{
					cell.textLabel.text = (NSString *)object;
				}
				
				cell.textLabel.textColor = [UIColor darkGrayColor];
			}
		}
		return cell;
	}
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	if(tableView.tag == 0)
	{
		if(indexPath.row == 0)
		{
			return HEIGHT_FOR_TOP_BUSINESS_RESULT;
		}
		else
		{
			return HEIGHT_FOR_TYPICAL_BUSINESS_RESULT;
		}
	}
	else
	{
		return 35.0;
	}
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	if(tableView == self.searchCluesTableView)
	{
		//NSLog(@"Row: %i", indexPath.row);
		UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
		if(mostRecentSearchTag == TAG_BUSINESS_SEARCH)
		{
			NSDictionary *dict;
			
			NSUInteger cacheSize = 0;
			if(self.searchTextfield.text.length == 0)
			{
				cacheSize = searchTermCache.count;
			}
			if(indexPath.row < cacheSize)
			{
				dict = [searchTermCache objectAtIndex:indexPath.row];
			}
			else
			{
				dict = [searchResultsArray objectAtIndex:indexPath.row - cacheSize];
				//add to search cache
				if([searchTermCache containsObject:dict] == NO)
				{
					[searchTermCache addObject:dict];
					if(searchTermCache.count > MAX_SEARCH_CACHE_SIZE)
					{
						[searchTermCache removeObjectAtIndex:0];
					}
				}
			}
			NSString *type = [dict objectForKey:@"type"];
			
						
			if([type isEqualToString:@"business"])
			{
				self.searchTextfield.text = cell.textLabel.text;
				[self.searchTextfield resignFirstResponder];
				//NSLog(@"Go to business");
				//[self transitionSearchToMap];
				/*NSDictionary *businessInfo = [businessSearchResults objectForKey:[NSNumber numberWithInteger:indexPath.row]];
				if(businessInfo)
				{
					NSLog(@"Setting selected business info");
					selectedBusinessInfo = businessInfo;
					//[self performSegueWithIdentifier:@"BusinessDetailsSegue" sender:self];
					[self launchBusinessDetails];
				}
				else*/
				//{
					//find this business's bizID in businessSearchResults.  If found, we can grab the distance and pass it to Biz Details
				float distance = 0;
				for(NSString *key in businessSearchResults)
				{
					NSDictionary *business = [businessSearchResults objectForKey:key];
					//NSLog(@"%@ = %@", [dict objectForKey:@"bizId"], [business objectForKey:@"bizId"]);
					NSString *firstBizID = [dict objectForKey:@"bizId"];
					NSString *secondBizID = [[business objectForKey:@"bizId"] stringValue];
					if([firstBizID isEqualToString:secondBizID])
					{
						//found it
						NSNumber *distanceNum = [business objectForKey:@"distance"];
						if(distanceNum && (distanceNum != (id)[NSNull null]))
						{
							distance = [distanceNum floatValue];
							break;
						}
					}
				}
				CLLocation *location = [Location controller].curLocation;
				[self launchBusinessDetailsWithBizID:[dict objectForKey:@"bizId"] andLocation:location.coordinate animated:YES];
				[self transitionSearchToListing];
				//}
			}
			else
			{
				self.searchTextfield.text = cell.textLabel.text;
				
				[self.locationTextfield becomeFirstResponder];
				
				searchResultsArray = nil;
				[self.searchCluesTableView reloadData];
				//[self transitionSearchToMap];
			}
		}
		else if(mostRecentSearchTag == TAG_LOCATION_SEARCH)
		{
			self.locationTextfield.text = cell.textLabel.text;
			//add to search cache
			if([searchLocationCache containsObject:cell.textLabel.text] == NO)
			{
				if(([cell.textLabel.text isEqualToString:ON_THE_WEB_STRING] == NO) && ([cell.textLabel.text isEqualToString:CURRENT_LOCATION_STRING] == NO)) //don't cache the default items
				{
					[searchLocationCache addObject:cell.textLabel.text];
					if(searchLocationCache.count > MAX_SEARCH_CACHE_SIZE)
					{
						[searchLocationCache removeObjectAtIndex:0];
					}
				}
			}
			[self.searchTextfield becomeFirstResponder];
			
			searchResultsArray = nil;
			[self.searchCluesTableView reloadData];
		}
	}
	else
	{
		//business listings table
		NSDictionary *businessInfo = [businessSearchResults objectForKey:[NSNumber numberWithInteger:indexPath.row]];
		
		//NSLog(@"Setting selected business info");
		selectedBusinessInfo = businessInfo;
		//[self performSegueWithIdentifier:@"BusinessDetailsSegue" sender:self];
		float distance = 0.0;
		NSNumber *number = [businessInfo objectForKey:@"distance"];
		if(number != (id)[NSNull null])
		{
			distance = [number floatValue];
		}
		CLLocation *location = [Location controller].curLocation;
		[self launchBusinessDetailsWithBizID:[businessInfo objectForKey:@"bizId"] andLocation:location.coordinate animated:YES];
	}
}

-(void)tableView:(UITableView *)tableView didEndDisplayingCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
	NSDictionary *businessInfo = [businessSearchResults objectForKey:[NSNumber numberWithInteger:indexPath.row]];
	if(businessInfo)
	{
		//[self.mapView removeAnnotationForBusiness:businessInfo];
		//[self.mapView zoomToFitMapAnnotations];
	}
}

#pragma mark - DLURLServer Callbacks

- (void)onDL_URLRequestCompleteWithStatus:(tDL_URLRequestStatus)status resultData:(NSData *)data resultObj:(id)object
{
	NSString *jsonString = [[NSString alloc] initWithBytes:[data bytes] length:[data length] encoding:NSUTF8StringEncoding];
	
	//NSLog(@"Results download returned: %@", jsonString );
	
	NSData *jsonData = [jsonString dataUsingEncoding:NSUTF32BigEndianStringEncoding];
	NSError *myError;
	NSDictionary *dictFromServer = [[CJSONDeserializer deserializer] deserializeAsDictionary:jsonData error:&myError];
	
	if(object == self.locationTextfield)
	{
		//NSLog(@"Got search results: %@", [dictFromServer objectForKey:@"results"]);
		searchResultsArray = [[dictFromServer objectForKey:@"results"] mutableCopy];
		[self pruneCachedLocationItemsFromSearchResults];
		[self.searchCluesTableView reloadData];
		
	}
	else if(object == self.searchTextfield)
	{
		//NSLog(@"Got search results: %@", [dictFromServer objectForKey:@"results"]);
		searchResultsArray = [[dictFromServer objectForKey:@"results"] mutableCopy];
		[self pruneCachedSearchItemsFromSearchResults];
		[self.searchCluesTableView reloadData];
		if(searchResultsArray.count)
		{
			
		}
		else
		{
			NSLog(@"SEARCH RESULTS ARRAY IS EMPTY!");
		}
	}
	else
	{
		//object is a page number (NSNumber)
		if (DL_URLRequestStatus_Success == status)
		{
			//NSLog(@"Error: %@", myError);
			//NSLog(@"Dictionary from server: %@", [dictFromServer allKeys]);
			
			//total number of results (in all pages)
			totalResultsCount = [[dictFromServer objectForKey:@"count"] intValue];
			
			[self bufferBusinessResults:[dictFromServer objectForKey:@"results"] forPage:[object intValue]];
			//NSLog(@"Businesses: %@", businessesArray);
			//NSLog(@"Total results: %i", totalResultsCount);
		}
		else
		{
			NSLog(@"*** SERVER REQUEST STATUS FAILURE ***");
			NSString *msg = NSLocalizedString(@"Can't connect to server.  Check your internet connection", nil);
			UIAlertView *alert = [[UIAlertView alloc]
								  initWithTitle:NSLocalizedString(@"No Connection", @"Alert title that warns user couldn't connect to server")
								  message:msg
								  delegate:nil
								  cancelButtonTitle:@"OK"
								  otherButtonTitles:nil];
			[alert show];
			
		}
		[self.tableView reloadData];
	}
}

#pragma mark DividerView

-(void)positionDividerView
{
	CGRect frame = self.dividerView.frame;
	if(self.dividerView.userControllable == NO)
	{
		//NSLog(@"offset: %f", scrollView.contentOffset.y);
		float offset = self.tableView.contentOffset.y;
		if (offset > self.tableView.tableHeaderView.frame.size.height)
		{
			offset = self.tableView.tableHeaderView.frame.size.height;
		}
		frame.origin.y = self.tableView.frame.origin.y + self.tableView.tableHeaderView.frame.size.height - DIVIDER_BAR_TRANSPARENT_AREA_HEIGHT - offset;
		self.dividerView.frame = frame;
	}
	else
	{
		//frame.origin.y -= EXTRA_SEARCH_BAR_HEIGHT;
		frame.origin.y = self.mapView.frame.origin.y + self.mapView.frame.size.height - DIVIDER_BAR_TRANSPARENT_AREA_HEIGHT;
		self.dividerView.frame = frame;
	}
}
/*
-(void)tieViewsToDividerBar
{
	//MapView height adjusted to go down to divider bar
	//tableView origin and height adjusted so that top of table is at divider bar
	CGRect frame = self.dividerView.frame;
	
	
	CGRect mapFrame = self.mapView.frame;
	mapFrame.size.height = frame.origin.y - mapFrame.origin.y + DIVIDER_BAR_TRANSPARENT_AREA_HEIGHT;
	self.mapView.frame = mapFrame;
	
	[self TackLocateMeButtonToMapBottomCorner];
	
	CGRect tableFrame = self.tableView.frame;
	tableFrame.origin.y = frame.origin.y + DIVIDER_BAR_TRANSPARENT_AREA_HEIGHT;
	tableFrame.size.height = self.view.bounds.size.height - tableFrame.origin.y;
	self.tableView.frame = tableFrame;
}*/

-(void)hideDividerView
{
	self.dividerView.alpha = 0.0;
}

-(void)showDividerView
{
	self.dividerView.alpha = 1.0;
}

-(void)DividerViewTouchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	//NSLog(@"Divider touches began");
	//NSLog(@"Setting map state to RESIZE");
	mapDisplayState = MAP_DISPLAY_RESIZE;
	dividerBarStartTouchPoint = [[touches anyObject] locationInView:self.contentView];
}

-(void)DividerViewTouchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	CGPoint newLocation = [[touches anyObject] locationInView:self.contentView];
	CGRect frame = self.dividerView.frame;
	frame.origin.y += newLocation.y - dividerBarStartTouchPoint.y;
	//don't allow divider bar to be dragged beyond searchbar
	if(frame.origin.y < 0) //(self.searchView.frame.origin.y + self.searchView.frame.size.height - DIVIDER_BAR_TRANSPARENT_AREA_HEIGHT))
	{
		frame.origin.y = 0; //self.searchView.frame.origin.y + self.searchView.frame.size.height - DIVIDER_BAR_TRANSPARENT_AREA_HEIGHT;
	}
	
	//don't allow divider bar to be dragged to far down
	if(frame.origin.y > self.contentView.bounds.size.height - frame.size.height - DIVIDER_DOWN_MARGIN)
	{
		frame.origin.y = self.contentView.bounds.size.height - frame.size.height - DIVIDER_DOWN_MARGIN;
	}
	self.dividerView.frame = frame;
	dividerBarStartTouchPoint = newLocation;
	
	[self updateMapAndTableToTrackDividerBar];
}

-(void)updateMapAndTableToTrackDividerBar
{
	//updates mapView and tableView heights to conincide with divider bar position
	CGRect frame = self.dividerView.frame;
	
	CGRect mapFrame = self.mapView.frame;
	mapFrame.size.height = frame.origin.y - mapFrame.origin.y + DIVIDER_BAR_TRANSPARENT_AREA_HEIGHT;
	self.mapView.frame = mapFrame;
	
	[self TackLocateMeButtonToMapBottomCorner];
	
	CGRect tableFrame = self.tableView.frame;
	tableFrame.origin.y = frame.origin.y + DIVIDER_BAR_TRANSPARENT_AREA_HEIGHT;
	tableFrame.size.height = self.contentView.bounds.size.height - tableFrame.origin.y;
	self.tableView.frame = tableFrame;
}


-(void)DividerViewTouchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	//NSLog(@"Setting map state to NORMAL");
	mapDisplayState = MAP_DISPLAY_NORMAL;
}

-(void)DividerViewTouchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
	//NSLog(@"Setting map state to NORMAL");
	mapDisplayState = MAP_DISPLAY_NORMAL;
}

#pragma mark BackgroundImageManager delegates

-(void)BackgroundImageManagerImageLoadedForBizID:(NSNumber *)bizID
{
	NSArray *visiblePaths = [self.tableView indexPathsForVisibleRows];
	
	int imageBizID = [bizID intValue];
	BOOL reloadTable = NO;
	for(NSIndexPath *path in visiblePaths)
	{
		NSDictionary *business = [businessSearchResults objectForKey:[NSNumber numberWithInteger:path.row]];
		int otherBizID = [[business objectForKey:@"bizId"] intValue];
		if(imageBizID == otherBizID)
		{
			reloadTable = YES;
			break;
		}
	}
	if(reloadTable)
	{
		//NSLog(@"Reloading table because image for visible cell just got loaded");
		[self.tableView reloadData];
	}
}

#pragma mark LocationDelegates

-(void)DidReceiveLocation
{
	//NSLog(@"Location Received!");
	if(receivedInitialLocation == NO)
	{
		receivedInitialLocation = YES;
		[self businessListingQueryForPage:0];
	}
}

#pragma mark BusinessDetailsViewControllerDelegates

-(void)businessDetailsViewControllerDone:(BusinessDetailsViewController *)controller
{
	if(NO == [CommonOverviewCell dismissSelectedCell])
	{
		[self dismissBusinessDetails];
	}
}

#pragma mark MoreCategoriesViewControllerDelegates

-(void)moreCategoriesViewControllerDone:(MoreCategoriesViewController *)controller withCategory:(NSString *)category
{
	[self dismissMoreCategories];
	if(category)
	{
		[self transitionListingToSearch];
		[self.locationTextfield becomeFirstResponder];
		self.searchTextfield.text = category;
	}
}

#pragma mark CalloutView delegates

-(void)calloutViewDidDisappear:(SMCalloutView *)calloutView
{
	singleCalloutView = nil;
}

#pragma mark infoView Delegates

-(void)InfoViewFinished:(InfoView *)infoView
{
	[infoView removeFromSuperview];
}

#pragma mark Overview Cell delegates

-(void)OverviewCell:(CommonOverviewCell *)cell didStartDraggingFromPointInCell:(CGPoint)point
{
	//tapTimer = CACurrentMediaTime();
	self.tableView.canCancelContentTouches = NO;
	self.tableView.delaysContentTouches = NO;
	 CGPoint swipeLocation = [cell convertPoint:point toView:self.tableView]; //[gestureRecognizer locationInView:self.tableView];
	 NSIndexPath *swipedIndexPath = [self.tableView indexPathForRowAtPoint:swipeLocation];
	 //UITableViewCell* swipedCell = [self.tableView cellForRowAtIndexPath:swipedIndexPath];
	 
	 NSDictionary *businessInfo = [businessSearchResults objectForKey:[NSNumber numberWithInteger:swipedIndexPath.row]];
	 
	// NSLog(@"Setting selected business info");
	 selectedBusinessInfo = businessInfo;
	 //[self performSegueWithIdentifier:@"BusinessDetailsSegue" sender:self];
	 float distance = 0.0;
	 NSNumber *distanceNum = [businessInfo objectForKey:@"distance"];
	 if(distanceNum && (distanceNum != (id)[NSNull null]))
	 {
		 distance = [distanceNum floatValue];
	 }
	 CLLocation *location = [Location controller].curLocation;
	 [self launchBusinessDetailsWithBizID:[businessInfo objectForKey:@"bizId"] andLocation:location.coordinate animated:NO];
	 cell.viewConnectedToMe = businessDetailsController.view;
	//self.tableView.scrollEnabled = NO;
}

-(void)OverviewCellDidEndDraggingReturnedToStart:(BOOL)returned
{
	//self.tableView.scrollEnabled = YES;
	
	if(returned)
	{
		/*if((CACurrentMediaTime() - tapTimer) < TAP_TIME_THRESHOLD)
		{
			//cw here:  probably handle the animation onscreen from within CommonOverviewCell
			[self animateBusinessDetailsOnScreen];
		}
		else*/
		{
			[businessDetailsController.view removeFromSuperview];
			businessDetailsController = nil;
		}
	}
	//self.tableView.canCancelContentTouches = YES;
	//self.tableView.delaysContentTouches = YES;
}

-(void)OverviewCellDraggedWithOffset:(float)xOffset
{
	//NSLog(@"Drag offset: %f", xOffset);
	//CGRect frame = businessDetailsController.view.frame;
	//frame.origin.x = self.view.bounds.size.width + xOffset;
	//businessDetailsController.view.frame = frame;
	
}

-(void)OverviewCellDidDismissSelectedCell:(CommonOverviewCell *)cell
{
	//NSLog(@"Removing business details controller");
	[businessDetailsController.view removeFromSuperview];
	businessDetailsController = nil;
}

@end
