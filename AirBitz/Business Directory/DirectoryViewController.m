
//
//  DirectoryViewController.m
//  AirBitz
//
//  Created by Carson Whitsett on 2/4/14.
//  Copyright (c) 2014 AirBitz. All rights reserved.
//

#import "DirectoryViewController.h"
#import "MainViewController.h"
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
#import "CommonTypes.h"
#import "Config.h"
#import "Theme.h"
#import "Util.h"
#import "User.h"

//server defines (uncomment one)
#define SERVER_MESSAGES_TO_SHOW		VERBOSE_MESSAGES_OFF
//#define SERVER_MESSAGES_TO_SHOW		VERBOSE_MESSAGES_ERRORS | VERBOSE_MESSAGES_STATS
//#define SERVER_MESSAGES_TO_SHOW		VERBOSE_MESSAGES_ALL

#define MAX_SEARCH_CACHE_SIZE	2 /* each cache can hold this many items */

#define CURRENT_LOCATION_STRING	NSLocalizedString(@"Current Location", nil)
#define ON_THE_WEB_STRING	NSLocalizedString(@"On The Web", nil)
#define NUM_PROGRAMMATIC_RESULTS 2

//#define DEFAULT_SEARCH_RADIUS_MILES	50

#define SHOW_SERVER_PAGE		0		/* set to 1 to replace bitcoin discount label with server page count (should be 0 for deployment) */

#define AGE_ACCEPT_CACHE_SECS	60.0 /* seconds */
#define DEFAULT_RESULTS_PER_PAGE	50 /* how many results to request from the server at a time */



#define MILES_TO_METERS(a)	(a * 1609.34)

//geometry
#define EXTRA_SEARCH_BAR_HEIGHT	44.0
#define DIVIDER_BAR_TRANSPARENT_AREA_HEIGHT	9.0	/* the divider bar image has some transparency above the actual bar */
#define DIVIDER_DOWN_MARGIN		12.0			/* Limit how far off bottom of screen divider bar can be dragged to */
#define LOCATE_ME_BUTTON_OFFSET_FROM_MAP_BOTTOM	58.0
#define MINIMUM_LOCATE_ME_BUTTON_OFFSET_Y	120.0

#define TAG_BUSINESS_SEARCH	0
#define TAG_LOCATION_SEARCH 1

#define TAG_CATEGORY_RESTAURANTS	0
#define TAG_CATEGORY_COFFEE			1
#define TAG_CATEGORY_ATM			2
#define TAG_CATEGORY_MORE			3
#define TAG_CATEGORY_GIFTCARDS      4
#define TAG_CATEGORY_ELECTRONICS    5
#define TAG_CATEGORY_SHOPPING       6

#define LOCATION_WAIT_SECONDS       8.0

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
    MAP_DISPLAY_RESIZE  /* set when user moves divider bar */
} tMapDisplayState;

@interface DirectoryViewController () <UIScrollViewDelegate, UITableViewDataSource, UITableViewDelegate, DL_URLRequestDelegate, UISearchBarDelegate, DividerViewDelegate, MKMapViewDelegate, SMCalloutViewDelegate, BackgroundImageManagerDelegate, LocationDelegate, BusinessDetailsViewControllerDelegate, MoreCategoriesViewControllerDelegate, UIGestureRecognizerDelegate, InfoViewDelegate, CommonOverviewCellDelegate>
{
    int totalResultsCount;          //total number of items in business listings search results (could be more than number of items actually returned due to pages)
    int currentPage;
    NSMutableArray *businessAutoCorrectArray;
    NSMutableArray *locationAutoCorrectArray;
    int mostRecentSearchTag;
    CGPoint dividerBarStartTouchPoint;
    UIView *listingHeaderView; //view that's the table's headerView
    NSMutableDictionary *businessSearchResults;
    BackgroundImageManager *backgroundImages;
    NSDictionary *selectedBusinessInfo;     //cw we might be able to pass this to -launchBusinessDetails and remove it from here
    tDirectoryMode previousDirectoryMode;
    tDirectoryMode directoryMode;
    tMapDisplayState mapDisplayState; //keeps track of current map state so we can decide if we can zoom automatically or load data after region changes.
    SMCalloutView *singleCalloutView;
    BOOL receivedInitialLocation;
    BOOL searchOnTheWeb;
    BusinessDetailsViewController *businessDetailsController;
    MoreCategoriesViewController *moreCategoriesController;
    float locateMeButtonDesiredAlpha;   /* used for fading in/out button when divider bar gets dragged too high */
    NSMutableArray *searchTermCache;
    NSMutableArray *searchLocationCache;
    CLLocationCoordinate2D mostRecentLatLong;
    UISearchBar *activeSearchBar;
    CGFloat originalCategoryViewHeight;
    BOOL bShowBackButton;

}

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *tableViewListingsTop;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *dividerViewTop;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *mapViewHeight;
@property (weak, nonatomic) IBOutlet UIView *tableListingsCategoriesHeader;
@property (weak, nonatomic) IBOutlet UISearchBar *searchBarLocation;
@property (weak, nonatomic) IBOutlet UISearchBar *searchBarSearch;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *headerHeight;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *footerHeight;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *searchCluesTop;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *searchCluesBottom;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *locationSearchViewHeight;
@property (nonatomic, weak) IBOutlet DividerView *dividerView;
@property (nonatomic, weak) IBOutlet UIView *spinnerView;
@property (nonatomic, weak) IBOutlet UITableView *tableView;
@property (nonatomic, weak) IBOutlet UIView *searchView;
@property (nonatomic, weak) IBOutlet UITableView *searchCluesTableView;
@property (nonatomic, weak) IBOutlet MapView *mapView;
@property (nonatomic, weak) IBOutlet UIButton *btn_locateMe;
@property (nonatomic, weak) IBOutlet UIView *contentView;
@property (nonatomic, weak) IBOutlet UIActivityIndicatorView *searchIndicator;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *categoryViewHeight;
@end

static bool bInitialized = false;

@implementation DirectoryViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    directoryMode = previousDirectoryMode = DIRECTORY_MODE_LISTING;
    receivedInitialLocation = NO;

    originalCategoryViewHeight = _categoryViewHeight.constant;

    businessSearchResults = [[NSMutableDictionary alloc] init];
    backgroundImages = [[BackgroundImageManager alloc] init];
    backgroundImages.delegate = self;

    [Location initAllWithDelegate: self];

    searchTermCache = [[NSMutableArray alloc] init];
    searchLocationCache = [[NSMutableArray alloc] init];

    self.dividerView.delegate = self;

    self.searchBarLocation.placeholder = NSLocalizedString(@"City, State/Province, or Country", @"City, State/Province, or Country placeholder");

    //
    // Add a footer so the last listing is visible above tabbar
    //
    UIView *footerView = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, self.dividerView.frame.size.width, [MainViewController getFooterHeight])];
    self.tableView.tableFooterView = footerView;

    currentPage = 0;
    bShowBackButton = NO;

    self.spinnerView.hidden = NO;
    self.mapView.delegate = self;
    self.mapView.showsUserLocation = YES;

    _searchBarSearch.enablesReturnKeyAutomatically = NO;
    _searchBarLocation.enablesReturnKeyAutomatically = NO;

    [self createSingleCalloutView];

    locateMeButtonDesiredAlpha = 1.0;

    UIPanGestureRecognizer *panRec = [[UIPanGestureRecognizer alloc] initWithTarget: self action: @selector(didDragMap:)];
    [panRec setDelegate: self];
    [self.mapView addGestureRecognizer: panRec];

    // If location services aren't enabled, just make a query
    if (NO == [CLLocationManager locationServicesEnabled]) {
        [self businessListingQueryForPage:0];
    } else {
        // If we haven't receive a location after LOCATION_WAIT_SECONDS seconds, just make a query
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, LOCATION_WAIT_SECONDS * NSEC_PER_SEC);
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            if (receivedInitialLocation == NO) {
                [self businessListingQueryForPage:0];
            }
        });
    }
}

- (void) setupNavBar
{
//    [MainViewController changeNavBarTitleWithImage:[UIImage imageWithContentsOfFile:@"logo.png"]];
    [MainViewController changeNavBarOwner:self];
    [MainViewController changeNavBarTitle:self title:NSLocalizedString(@"Directory", @"Directory title bar text")];
    [MainViewController changeNavBar:self title:[Theme Singleton].backButtonText side:NAV_BAR_LEFT button:true enable:bShowBackButton action:@selector(Back:) fromObject:self];
    [MainViewController changeNavBar:self title:[Theme Singleton].infoButtonText side:NAV_BAR_RIGHT button:true enable:true action:@selector(info:) fromObject:self];
}

- (void)resetTableHideSearch
{
    _tableViewListingsTop.constant = 0;

    CGPoint pt;
    pt.x = 0.0;
    pt.y = [MainViewController getHeaderHeight];
    [self.tableView setContentInset:UIEdgeInsetsMake(pt.y,0,0,0)];

    pt.x = 0.0;
    pt.y = -[MainViewController getHeaderHeight] + self.searchBarSearch.frame.size.height;
    [self.tableView setContentOffset:pt animated:true];
    _locationSearchViewHeight.constant = 0;
}

- (BOOL)gestureRecognizer: (UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer: (UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}

- (void)disclosureTapped
{
    //ABLog(2,@"BUTTON TAPPED");
    //selectedBusinessInfo = businessInfo;
    //[self performSegueWithIdentifier:@"BusinessDetailsSegue" sender:self];
    CLLocation *location = [Location controller].curLocation;
    [self launchBusinessDetailsWithBizID: [selectedBusinessInfo objectForKey: @"bizId"] andLocation: location.coordinate animated: YES];
}

- (void)viewDidUnload
{
    backgroundImages = nil;
    [Location freeAll];
}

- (void)viewDidAppear: (BOOL)animated
{
//XXX    if (homeTableViewFrame.size.width == 0)
//    {
//        //only set it once
//        homeTableViewFrame = self.tableListingsView.frame;
//        //ABLog(2,@"Home TableView Frame: %f, %f, %f, %f", homeTableViewFrame.origin.x, homeTableViewFrame.origin.y, homeTableViewFrame.size.width, homeTableViewFrame.size.height);
//    }
}

- (void)viewWillAppear: (BOOL)animated
{
    [Location startLocatingWithPeriod: LOCATION_UPDATE_PERIOD];

    [self hideBackButton];
    [self setupNavBar];

    //ABLog(2,@"Adding keyboard notification");
    [self receiveKeyboardNotifications: YES];

    if (bInitialized == false)
    {
        //
        // Calculate the header size of tableview and set it's frame to that height. Hack because Apple can't
        // figure it out for us automatically -paulvp
        //
        CGFloat height = _dividerView.frame.origin.y + _dividerView.frame.size.height - [MainViewController getHeaderHeight];
        CGRect headerFrame = _tableListingsCategoriesHeader.frame;
        ABLog(2,@"BizDirView viewWillAppear %f %f %f %f\n",_dividerView.frame.origin.y, _dividerView.frame.size.height, _tableListingsCategoriesHeader.frame.origin.y, _tableListingsCategoriesHeader.frame.size.height);
        headerFrame.size.height = height;
        _tableListingsCategoriesHeader.frame = headerFrame;
        self.tableView.tableHeaderView = _tableListingsCategoriesHeader;

        bInitialized = true;

    }

    if (![Theme Singleton].bTranslucencyEnable || [User isLoggedIn])
    {
        [self.view.layer setBackgroundColor:[UIColorFromARGB(0xF8F0F0F0) CGColor]];
    }

    [self transitionMode:DIRECTORY_MODE_LISTING];
}

- (void)receiveKeyboardNotifications: (BOOL)on
{
    if (on)
    {
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver: self selector: @selector(keyboardWillShow:) name: UIKeyboardWillShowNotification object: nil];
        [center addObserver: self selector: @selector(keyboardWillHide:) name: UIKeyboardWillHideNotification object: nil];
    } else
    {
        [[NSNotificationCenter defaultCenter] removeObserver: self];
    }
}

- (void)viewWillDisappear: (BOOL)animated
{
    //ABLog(2,@"%s", __FUNCTION__);

    // cancel all our outstanding requests
    [[DL_URLServer controller] cancelAllRequestsForDelegate: self];

    //ABLog(2,@"Removing keyboard notification");
    [self receiveKeyboardNotifications: NO];
    [Location stopLocating];
    [super viewWillDisappear: animated];
}

- (void)viewWillLayoutSubviews {
    // Your adjustments accd to
    // viewController.bounds
    
    self.footerHeight.constant = [MainViewController getFooterHeight];
    
    [super viewWillLayoutSubviews];
}

- (void)keyboardWillShow: (NSNotification *)notification
{
    if (activeSearchBar)
    {
        NSDictionary *userInfo = [notification userInfo];
        CGRect keyboardFrame = [[userInfo objectForKey: UIKeyboardFrameEndUserInfoKey] CGRectValue];

        [UIView animateWithDuration: 0.35
                              delay: 0.0
                            options: UIViewAnimationOptionCurveEaseInOut
                         animations: ^
        {
            self.searchCluesBottom.constant = keyboardFrame.size.height;
            [self.view layoutIfNeeded];
        }
                         completion: ^(BOOL finished)
        {
        }];
    }
}

- (void)keyboardWillHide: (NSNotification *)notification
{
    if (activeSearchBar)
    //if(notification.object == self)
    {
        self.searchBarSearch.placeholder = @"Search";
        //ABLog(2,@"Keyboard will hide for DirectoryViewController");
        //make searchCluesTableView go away
        //bring back divider bar
        [UIView animateWithDuration: 0.35
                              delay: 0.0
                            options: UIViewAnimationOptionCurveEaseInOut
                         animations: ^
        {
            [self hideSearchBarsAndClues];
            [self.view layoutIfNeeded];
        }
                         completion: ^(BOOL finished)
        {
            activeSearchBar = nil;
        }];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewBottom: (CGFloat)bottomCoord
{
    //sets the height of the main view.  Used to accommodate tab bar
    CGRect frame = self.view.frame;
    frame.size.height = bottomCoord;
    self.view.frame = frame;
}

- (IBAction)info: (UIButton *)sender
{
    //spawn infoView
    InfoView *iv = [InfoView CreateWithDelegate: self];
    CGRect frame;

    frame = self.view.bounds;
    frame.origin.y += [MainViewController getHeaderHeight];
    frame.size.height -= [MainViewController getFooterHeight] + [MainViewController getHeaderHeight];

    iv.frame = frame;
    [iv enableScrolling: NO];
    [self.view addSubview: iv];

    NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    NSString *build = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];

    NSString *versionbuild = [NSString stringWithFormat:@"%@ %@", version, build];

    NSString *path = [[NSBundle mainBundle] pathForResource: @"info" ofType: @"html"];
    NSString *content = [NSString stringWithContentsOfFile: path encoding: NSUTF8StringEncoding error: NULL];
    iv.htmlInfoToDisplay = [content stringByReplacingOccurrencesOfString: @"*" withString: versionbuild];;
}

#pragma mark Back Button

- (IBAction)Back: (UIButton *)sender
{
    switch (directoryMode)
    {
        case DIRECTORY_MODE_LISTING:
            // Can't go back any more
            // There shouldn't even be a back button
            break;
        case DIRECTORY_MODE_SEARCH:
            [self transitionMode:DIRECTORY_MODE_LISTING];
            break;
        case DIRECTORY_MODE_MAP:
            [self transitionMode:DIRECTORY_MODE_SEARCH];
            break;
        case DIRECTORY_MODE_ON_THE_WEB_LISTING:
            [self transitionMode:DIRECTORY_MODE_SEARCH];
            break;
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

- (IBAction)CategoryButton: (UIButton *)sender
{
    //ABLog(2,@"Category %li", (long)sender.tag);
    switch (sender.tag)
    {
        case TAG_CATEGORY_RESTAURANTS:
            self.searchBarSearch.text = NSLocalizedString(@"Restaurants & Food Trucks", nil);
            self.searchBarLocation.text = NSLocalizedString(@"", nil);
            [self transitionMode:DIRECTORY_MODE_MAP];
            break;
        case TAG_CATEGORY_COFFEE:
            self.searchBarSearch.text = NSLocalizedString(@"Coffee & Tea", nil);
            self.searchBarLocation.text = NSLocalizedString(@"", nil);
            [self transitionMode:DIRECTORY_MODE_MAP];
            break;
        case TAG_CATEGORY_ATM:
            self.searchBarSearch.text = NSLocalizedString(@"ATM", nil);
            self.searchBarLocation.text = NSLocalizedString(@"", nil);
            [self transitionMode:DIRECTORY_MODE_MAP];
            break;
        case TAG_CATEGORY_GIFTCARDS:
            self.searchBarSearch.text = NSLocalizedString(@"Gift Cards", nil);
            self.searchBarLocation.text = NSLocalizedString(@"On the Web", nil);
            [self transitionMode:DIRECTORY_MODE_ON_THE_WEB_LISTING];
            break;
        case TAG_CATEGORY_ELECTRONICS:
            self.searchBarSearch.text = NSLocalizedString(@"Electronics", nil);
            self.searchBarLocation.text = NSLocalizedString(@"On the Web", nil);
            [self transitionMode:DIRECTORY_MODE_ON_THE_WEB_LISTING];
            break;
        case TAG_CATEGORY_SHOPPING:
            self.searchBarSearch.text = NSLocalizedString(@"Shopping", nil);
            self.searchBarLocation.text = NSLocalizedString(@"On the Web", nil);
            [self transitionMode:DIRECTORY_MODE_ON_THE_WEB_LISTING];
            break;
        case TAG_CATEGORY_MORE:
            [self launchMoreCategories];
            break;


    }

}

#pragma mark Search

- (void)businessListingQueryForPage: (int)page northEastCoordinate: (CLLocationCoordinate2D)ne southWestCoordinate: (CLLocationCoordinate2D)sw
{
    NSString *boundingBox = [NSString stringWithFormat: @"%f,%f|%f,%f", sw.latitude, sw.longitude, ne.latitude, ne.longitude];
    NSString *myLatLong = [NSString stringWithFormat: @"%f,%f", self.mapView.userLocation.location.coordinate.latitude, self.mapView.userLocation.location.coordinate.longitude];
    NSMutableString *query = [[NSMutableString alloc] initWithFormat: @"%@/search/?ll=%@&sort=%i&page=%i&page_size=%i&bounds=%@", SERVER_API, myLatLong, SORT_RESULT_DISTANCE, page + 1, DEFAULT_RESULTS_PER_PAGE, boundingBox];

    [self businessListingQuery: query];
}
/* cw no longer used but keep around just in case...
-(void)businessListingQueryForPage:(int)page centerCoordinate:(CLLocationCoordinate2D)center radius:(float)radiusInMeters
{
    NSString *latLong = [NSString stringWithFormat:@"%f,%f", center.latitude, center.longitude];
    NSMutableString *query = [[NSMutableString alloc] initWithFormat:@"%@/search/?radius=%.0f&ll=%@&sort=%i&page=%i&page_size=%i", SERVER_API, radiusInMeters, latLong, SORT_RESULT_DISTANCE, page + 1, DEFAULT_RESULTS_PER_PAGE];
    
    [self businessListingQuery:query];
}*/

- (void)businessListingQueryForPage: (int)page
{
    NSMutableString *query = [[NSMutableString alloc] initWithFormat: @"%@/search/?sort=%i&page=%i&page_size=%i", SERVER_API, SORT_RESULT_DISTANCE, page + 1, DEFAULT_RESULTS_PER_PAGE];

    [self businessListingQuery: query];
}

- (void)addLocationToQuery: (NSMutableString *)query
{
    if ([query rangeOfString: @"&ll="].location == NSNotFound)
    {
        CLLocation *location = [Location controller].curLocation;
        if (location) //can be nil if user has locationServices turned off
        {
            NSString *locationString = [NSString stringWithFormat: @"%f,%f", location.coordinate.latitude, location.coordinate.longitude];
            [query appendFormat: @"&ll=%@", locationString];

            if ([self.searchBarLocation.text length])
            {
                if ([[self.searchBarLocation.text uppercaseString] isEqualToString: [CURRENT_LOCATION_STRING uppercaseString]])
                {
                    //NSString *locationString = [NSString stringWithFormat:@"%f,%f", location.coordinate.latitude, location.coordinate.longitude];
                    //[query appendFormat:@"&ll=%@", locationString];
                } else
                {
                    [query appendFormat: @"&location=%@", self.searchBarLocation.text];
                }
            }
        } else {
            [query appendFormat: @"&location=%@", self.searchBarLocation.text];
        }
    } else {
        //ABLog(2,@"string already contains ll");
    }
}

- (void)businessListingQuery: (NSMutableString *)query
{
    //load business listing based on user's search criteria
    if ([self.searchBarSearch.text length])
    {
        [query appendFormat: @"&term=%@", self.searchBarSearch.text];
    }
    [self addLocationToQuery: query];

    NSString *serverQuery = [query stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding];
    //ABLog(2,@"Query to server: %@", serverQuery);

    [[DL_URLServer controller] issueRequestURL: serverQuery
                                    withParams: nil
                                    withObject: nil
                                  withDelegate: self
                            acceptableCacheAge: AGE_ACCEPT_CACHE_SECS
                                   cacheResult: YES];
}

- (void)pruneCachedLocationItemsFromSearchResults
{
    for (NSString *string in searchLocationCache)
    {
        BOOL foundMatch = NO;
        int index = 0;
        for (NSString *result in locationAutoCorrectArray)
        {
            if ([string isEqualToString: result])
            {
                foundMatch = YES;
                break;
            }
            index++;
        }
        if (foundMatch)
        {
            [locationAutoCorrectArray removeObjectAtIndex: index];
        }
    }
}

- (void)pruneCachedSearchItemsFromSearchResults
{
    for (int i = 0; i < searchTermCache.count; i++)
    {
        BOOL foundMatch = NO;
        NSString *string;

        string = [self stringForObjectInCache: searchTermCache atIndex: i];

        int j;
        for (j = 0; j < businessAutoCorrectArray.count; j++)
        {
            NSString *result = [self stringForObjectInCache: businessAutoCorrectArray atIndex: j];

            if ([string isEqualToString: result])
            {
                foundMatch = YES;
                break;
            }
        }
        if (foundMatch)
        {
            //ABLog(2,@"Pruning From Results: %@", [searchResultsArray objectAtIndex:j]);
            [businessAutoCorrectArray removeObjectAtIndex: j];
        }
    }
}

- (NSString *)stringForObjectInCache: (NSArray *)cache atIndex: (NSInteger)index
{
    //if object is dictionary, string is its "text" object
    //otherwise object will already be a string

    NSObject *object = [cache objectAtIndex: index];
    NSString *string;
    if ([object isKindOfClass: [NSDictionary class]])
    {
        string = [(NSDictionary *)object objectForKey: @"text"];
    } else
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

- (void) transitionMode: (tDirectoryMode) mode
{

    switch (mode)
    {
        case DIRECTORY_MODE_LISTING:
        case DIRECTORY_MODE_MAP:
        case DIRECTORY_MODE_ON_THE_WEB_LISTING:
            [self.searchBarSearch resignFirstResponder];
            [self.searchBarLocation resignFirstResponder];
            break;

        case DIRECTORY_MODE_SEARCH:
            [self showSearchBarsAndClues];
            break;
    }

    [UIView animateWithDuration: 0.35
                          delay: 0.0
                        options: UIViewAnimationOptionCurveEaseInOut
                     animations: ^
                     {
                         switch (mode)
                         {
                             case DIRECTORY_MODE_LISTING:

//                                 [businessSearchResults removeAllObjects];
                                 [self hideBackButton];
                                 [self addBusinessListingHeader];
                                 self.dividerView.userControllable = NO;
                                 [self showDividerView];
                                 [self hideMapView];
                                 [self showCategoryView];
                                 //XXX Hide fake searchBar
                                 [self resetTableHideSearch];
                                 break;

                             case DIRECTORY_MODE_SEARCH:
                                 [self hideMapView];
                                 [self hideDividerView];
                                 [self showBackButton];
                                 [self addBusinessListingHeader];
                                 break;

                             case DIRECTORY_MODE_MAP:
                                 mapDisplayState = MAP_DISPLAY_INIT;

                                 [self showBackButton];
                                 [self removeBusinessListingHeader];
                                 self.dividerView.userControllable = YES;
                                 [self hideCategoryView];
                                 [self setDefaultMapDividerPosition];
                                 [self showDividerView];
                                 [self showMapView];
                                 //XXX Show fake searchBar
                                 [self businessListingQueryForPage: 0];
                                 break;

                             case DIRECTORY_MODE_ON_THE_WEB_LISTING:
                                 [self showBackButton];
                                 [self addBusinessListingHeader];
                                 [self hideCategoryView];
                                 [self hideDividerView];
                                 [self hideMapView];
                                 //XXX Hide fake searchBar
                                 [self resetTableHideSearch];
                                 [self businessListingQueryForPage: 0];
                                 break;
                         }
                         [self.view layoutIfNeeded];

                     }
                     completion: ^(BOOL finished)
                     {
                         switch (mode)
                         {
                             case DIRECTORY_MODE_SEARCH:
                                 [self.searchBarSearch becomeFirstResponder];
                                 break;
                             default:
                                 break;
                         }
                         ABLog(2,@"Directory Mode Transition %d -> %d\n", directoryMode, mode);
                         previousDirectoryMode = directoryMode;
                         directoryMode = mode;
                     }];

}


- (void)setDefaultMapDividerPosition
{
    // Remove top offset and inset of the listings tableview to prevent gap
    [self.tableView setContentOffset:CGPointZero animated:NO];
    [self.tableView setContentInset:UIEdgeInsetsMake(0.0, 0.0, 0.0, 0.0)];

    //put divider in ~ middle of screen.  Adjust map and tableView to divider position
    _dividerViewTop.constant = (self.contentView.frame.size.height) / 2;

    //set map frame
    _mapViewHeight.constant = _dividerViewTop.constant + DIVIDER_BAR_TRANSPARENT_AREA_HEIGHT;

    //set tableView frame right under divider bar
    _tableViewListingsTop.constant = _mapViewHeight.constant;

}

- (void) showSearchBarsAndClues
{


    //
    // Set tableView listings to top of screen
    //
    _tableViewListingsTop.constant = 0;

    //
    // Set placeholder text
    //
    self.searchBarSearch.placeholder = NSLocalizedString(@"Business Name or Category", @"Business Name or Category placeholder");
    self.searchCluesTableView.hidden = NO;

    //
    // Reset the inset/offset to show the search bar below the header (navbar)
    //
    CGPoint pt;
    pt.x = 0.0;
    pt.y = [MainViewController getHeaderHeight];
    [self.tableView setContentInset:UIEdgeInsetsMake(pt.y,0,0,0)];

    pt.x = 0.0;
    pt.y = -[MainViewController getHeaderHeight];
    [self.tableView setContentOffset:pt animated:true];

    //
    // Open up location searchBar
    //
    _locationSearchViewHeight.constant = EXTRA_SEARCH_BAR_HEIGHT;
    [self.view layoutIfNeeded];

    //
    // Open up the autocomplete clues tableview. Line up top of autocomplete table with bottom of searchBarLocation
    //
//    CGRect frame = [_searchBarLocation convertRect:_searchBarLocation.bounds toView:self.view];
//    _searchCluesTop.constant = frame.origin.y + frame.size.height;
    _searchCluesTop.constant = [MainViewController getHeaderHeight] + (2 * EXTRA_SEARCH_BAR_HEIGHT);
    [self.view layoutIfNeeded];

    //
    // The last part of this is taken care of in keyboardWillShow
    // The searchCluesBottom is tied to the top of the keyboard height
    //

}

- (void) hideSearchBarsAndClues
{
    // Put bottom of searchCluesTable to top of screen.
    self.searchCluesBottom.constant = self.view.frame.size.height;
    self.searchCluesTableView.hidden = YES;
    self.searchBarSearch.placeholder = NSLocalizedString(@"Search", @"SearchBarSearch placeholder");

    _locationSearchViewHeight.constant = 0;
}



- (void)hideBackButton
{
    [MainViewController changeNavBar:self title:[Theme Singleton].backButtonText side:NAV_BAR_LEFT button:true enable:false action:@selector(Back:) fromObject:self];
    bShowBackButton = NO;

}

- (void)showBackButton
{
    [MainViewController changeNavBar:self title:[Theme Singleton].backButtonText side:NAV_BAR_LEFT button:true enable:true action:@selector(Back:) fromObject:self];
    bShowBackButton = YES;
}

//
// Removes header which includes both double search bars AND categories buttons
//
- (void)removeBusinessListingHeader
{
    if (self.tableView.tableHeaderView)
    {
        listingHeaderView = self.tableView.tableHeaderView;
        self.tableView.tableHeaderView = nil;
    }
}

//
// Add header which includes both double search bars AND categories buttons
//
- (void)addBusinessListingHeader
{
    if (listingHeaderView)
    {
        self.tableView.tableHeaderView = listingHeaderView;
        listingHeaderView = nil;
    }
}

- (void)showCategoryView
{
    _categoryViewHeight.constant = originalCategoryViewHeight;
}

- (void)hideCategoryView
{
//    _categoryViewHeight.constant = 0;
}


//- (void)transitionSearchToMap
//{
//    //ABLog(2,@"Transition Search To Map");
//    directoryMode = DIRECTORY_MODE_MAP;
//    //ABLog(2,@"Setting map state to INIT");
//    mapDisplayState = MAP_DISPLAY_INIT;
//    //subtly show mapView
//    [self showMapView];
//    self.dividerView.userControllable = YES;
//    [self removeBusinessListingHeader];
//    [self.searchBarSearch resignFirstResponder];
//    [self.searchBarLocation resignFirstResponder];
//    self.mapView.showsUserLocation = YES;
//    [self.tableView setContentOffset:CGPointZero animated:NO];
//    [self.tableView setContentInset:UIEdgeInsetsMake(0.0, 0.0, 0.0, 0.0)];
//
//    [self setDefaultMapDividerPosition];
//
//    [self businessListingQueryForPage: 0];
//
//    [UIView animateWithDuration: 0.35
//                          delay: 0.0
//                        options: UIViewAnimationOptionCurveEaseInOut
//                     animations: ^
//    {
//        _locationSearchViewHeight.constant = 0;
//
//        [self.view layoutIfNeeded];
//
//    }
//                     completion: ^(BOOL finished)
//    {
//
//
//    }];
//}
//
//- (void)transitionSearchToListing
//{
//    //directoryMode = DIRECTORY_MODE_ON_THE_WEB_LISTING;
//    [businessSearchResults removeAllObjects];
//    [self.searchBarSearch resignFirstResponder];
//    [self.searchBarLocation resignFirstResponder];
//
//    if (directoryMode == DIRECTORY_MODE_ON_THE_WEB_LISTING)
//    {
//        [self removeBusinessListingHeader];
//        [self hideDividerView];
//    } else
//    {
//        directoryMode = DIRECTORY_MODE_LISTING;
//        [self hideBackButtonAnimated: YES];
//    }
//
//    [self resetTableHideSearch];
//    [self businessListingQueryForPage: 0];
//    [UIView animateWithDuration: 0.5
//                          delay: 0.0
//                        options: UIViewAnimationOptionCurveEaseInOut
//                     animations: ^
//    {
////        _locationSearchViewHeight.constant -= EXTRA_SEARCH_BAR_HEIGHT;
//
//        [self.view layoutIfNeeded];
//    }
//                     completion: ^(BOOL finished)
//    {
//
//
//    }];
//}
//
//- (void)transitionMapToSearch
//{
//    directoryMode = DIRECTORY_MODE_SEARCH;
//
//    [UIView animateWithDuration: 0.35
//                          delay: 0.0
//                        options: UIViewAnimationOptionCurveEaseInOut
//                     animations: ^
//    {
//        [self hideMapView];
//        self.mapView.showsUserLocation = NO;
//        self.dividerView.userControllable = NO;
//        [self addBusinessListingHeader];
//        [self hideBackButtonAnimated: YES];
//        [self.mapView removeAllAnnotations];
//    }
//                     completion: ^(BOOL finished)
//    {
//
//        //subtly hide mapView
//        [UIView animateWithDuration: 0.5
//                              delay: 0.0
//                            options: UIViewAnimationOptionCurveLinear
//                         animations: ^
//        {
//            [self hideMapView];
//        }
//                         completion: ^(BOOL finished)
//        {
//
//            [self resetTableHideSearch];
//            [self positionDividerView];
//
//            //
//            // Open up location searchBar
//            //
//            _locationSearchViewHeight.constant = EXTRA_SEARCH_BAR_HEIGHT;
//            [self.view layoutIfNeeded];
//
//            //
//            // Open up the autocomplete clues tableview. Line up top of autocomplete table with bottom of searchBarLocation
//            //
//            CGRect frame = [_searchBarLocation convertRect:_searchBarLocation.bounds toView:self.view];
//            _searchCluesTop.constant = frame.origin.y + frame.size.height;
//            [self.view layoutIfNeeded];
//
//        }];
//
//    }];
//}
//
//- (void)transitionListingToMap
//{
//    directoryMode = DIRECTORY_MODE_MAP;
//    //ABLog(2,@"Setting map state to INIT");
//    mapDisplayState = MAP_DISPLAY_INIT;
//
//    self.mapView.showsUserLocation = YES;
//    self.dividerView.userControllable = YES;
//    [self removeBusinessListingHeader];
//    [self showBackButtonAnimated: YES];
//
//    [self setDefaultMapDividerPosition];
//
//    [self businessListingQueryForPage: 0];
//    [UIView animateWithDuration: 0.35
//                          delay: 0.0
//                        options: UIViewAnimationOptionCurveLinear
//                     animations: ^
//    {
//
//        [self showMapView];
//    }
//                     completion: ^(BOOL finished)
//    {
//
//    }];
//}
//
//- (void)transitionMapToListing
//{
//    directoryMode = DIRECTORY_MODE_LISTING;
//
//    [self hideMapView];
//    self.mapView.showsUserLocation = NO;
//    self.dividerView.userControllable = NO;
//    [self addBusinessListingHeader];
//    [self hideBackButtonAnimated: YES];
//    [self.mapView removeAllAnnotations];
//    [self resetTableHideSearch];
//    [self positionDividerView];
//
//}


#pragma mark MapView

- (void)didDragMap: (UIGestureRecognizer *)gestureRecognizer
{
    static BOOL dragProcessingComplete = NO;

    if (!dragProcessingComplete)
    {
        dragProcessingComplete = YES;
        //ABLog(2,@"Processing drag operation");
        if (singleCalloutView)
        {
            [singleCalloutView dismissCalloutAnimated: YES];
        }
    }
    if (gestureRecognizer.state == UIGestureRecognizerStateEnded)
    {
        //ABLog(2,@"drag ended");
        dragProcessingComplete = NO;
    }
}

- (IBAction)LocateMe: (UIButton *)sender
{
    [self.mapView setCenterCoordinate: self.mapView.userLocation.location.coordinate animated: YES];
}

//- (void)TackLocateMeButtonToMapBottomCorner
//{
//    CGRect locateMeFrame = self.btn_locateMe.frame;
//    locateMeFrame.origin.y = self.mapView.frame.origin.y + self.mapView.frame.size.height - LOCATE_ME_BUTTON_OFFSET_FROM_MAP_BOTTOM;
//    self.btn_locateMe.frame = locateMeFrame;
//
//    if (locateMeFrame.origin.y < MINIMUM_LOCATE_ME_BUTTON_OFFSET_Y)
//    {
//        if (locateMeButtonDesiredAlpha != 0.0)
//        {
//            locateMeButtonDesiredAlpha = 0.0;
//            //hide locateMe button
//            [UIView animateWithDuration: 0.1
//                                  delay: 0.0
//                                options: UIViewAnimationOptionCurveLinear
//                             animations: ^
//            {
//                self.btn_locateMe.alpha = locateMeButtonDesiredAlpha;
//            }
//                             completion: ^(BOOL finished)
//            {
//            }];
//        }
//    } else
//    {
//        if (locateMeButtonDesiredAlpha != 1.0)
//        {
//            locateMeButtonDesiredAlpha = 1.0;
//            //hide locateMe button
//            [UIView animateWithDuration: 0.1
//                                  delay: 0.0
//                                options: UIViewAnimationOptionCurveLinear
//                             animations: ^
//            {
//                self.btn_locateMe.alpha = locateMeButtonDesiredAlpha;
//            }
//                             completion: ^(BOOL finished)
//            {
//            }];
//        }
//    }
//}

- (void)hideMapView
{
    self.mapView.alpha = 0.0;
    self.btn_locateMe.alpha = 0.0;
}

- (void)showMapView
{
    self.mapView.alpha = 1.0;
    self.btn_locateMe.alpha = 1.0 * locateMeButtonDesiredAlpha;
}

- (MKAnnotationView *)mapView: (MKMapView *)map viewForAnnotation: (id<MKAnnotation>)annotation
{
    //returns a view for the map "pin"
    if (annotation == map.userLocation)
    {
        // We can return nil to let the MapView handle the default annotation view (blue dot):
        return nil;
    } else
    {
        static NSString *AnnotationViewID = @"annotationViewID";

        CustomAnnotationView *customAnnotationView = (CustomAnnotationView *)[map dequeueReusableAnnotationViewWithIdentifier: AnnotationViewID];

        if (customAnnotationView == nil)
        {
            customAnnotationView = [[CustomAnnotationView alloc] initWithAnnotation: annotation reuseIdentifier: AnnotationViewID];
            [customAnnotationView addGestureRecognizer: [[UITapGestureRecognizer alloc] initWithTarget: self action: @selector(AnnotationTapped:)]];
            customAnnotationView.image = [UIImage imageNamed: @"bitCoinAnnotation"];
        } else
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

- (void)mapView: (MKMapView *)mapView didDeselectAnnotationView: (MKAnnotationView *)view
{
    //ABLog(2,@"Did deselect annotation view");

    if ([view isKindOfClass: [CustomAnnotationView class]])
    {
        if (view == singleCalloutView.superview)
        {
            //ABLog(2,@"Dismissing callout due to annotation deselected");
            [singleCalloutView dismissCalloutAnimated: YES];
        }
    }
}

- (void)mapViewDidFinishLoadingMap: (MKMapView *)mapView
{
    //ABLog(2,@"Did finish loading map");
    UITapGestureRecognizer *tap =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(removePopupView)];
    [mapView addGestureRecognizer:tap];
}

- (void)mapView: (MKMapView *)mapView regionDidChangeAnimated: (BOOL)animated
{
    //ABLog(2,@"Map Region Changed");

    if (mapDisplayState == MAP_DISPLAY_NORMAL)
    {
        MKMapRect mRect = self.mapView.visibleMapRect;
        MKMapPoint neMapPoint = MKMapPointMake(MKMapRectGetMaxX(mRect), mRect.origin.y);
        MKMapPoint swMapPoint = MKMapPointMake(mRect.origin.x, MKMapRectGetMaxY(mRect));
        CLLocationCoordinate2D neCoord = MKCoordinateForMapPoint(neMapPoint);
        CLLocationCoordinate2D swCoord = MKCoordinateForMapPoint(swMapPoint);

        [[DL_URLServer controller] cancelAllRequestsForDelegate: self];
        [self businessListingQueryForPage: 0 northEastCoordinate: neCoord southWestCoordinate: swCoord];
    }
    if (mapDisplayState == MAP_DISPLAY_ZOOM)
    {
        //ABLog(2,@"Setting map state to NORMAL");
        mapDisplayState = MAP_DISPLAY_NORMAL;
    }
}

- (void)createSingleCalloutView
{
    singleCalloutView = [SMCalloutView new];
    singleCalloutView.delegate = self;
    UIButton *disclosure = [UIButton buttonWithType: UIButtonTypeCustom];
    [disclosure addGestureRecognizer: [[UITapGestureRecognizer alloc] initWithTarget: self action: @selector(disclosureTapped)]];
    singleCalloutView.rightAccessoryView = disclosure;
}

- (void)AnnotationTapped: (UITapGestureRecognizer *)recognizer
{
    //ABLog(2,@"Tapped annotation");
    //to prevent callout from disappearing right after it appeared because user scrolled map then quickly tapped on an annotation.
    [[DL_URLServer controller] cancelAllRequestsForDelegate: self];
    //calloutViewTapCount++;
    // dismiss our callout if it's already shown but on a different parent view
    //[bottomMapView deselectAnnotation:bottomPin.annotation animated:NO];
    //if (calloutView.window) [calloutView dismissCalloutAnimated:NO];
    // now in this example we're going to introduce an artificial delay in order to make our popup feel identical to MKMapView.
    // MKMapView has a delay after tapping so that it can intercept a double-tap for zooming. We don't need that delay but we'll
    // add it just so things feel the same.
    [recognizer.view.superview bringSubviewToFront: recognizer.view];
    if (singleCalloutView.superview != recognizer.view) //keeps callout from re-popping up if user repeatedly taps on same annotation
    {
        [singleCalloutView removeFromSuperview];
        [self popupCalloutView: recognizer.view];
    }
    //[self performSelector:@selector(popupCalloutView:) withObject:recognizer.view afterDelay:1.0/3.0];
    //[self.mapView popupCalloutForAnnotationView:(CustomAnnotationView *)recognizer.view];
}

- (void)popupCalloutView: (UIView *)parentView;
{
    //ABLog(2,@"Popping up callout");
    // custom view to be used in our callout
    AnnotationContentView *av = [AnnotationContentView Create];
    av.backgroundColor = [UIColor colorWithWhite: 1 alpha: 0.5];
    // av.layer.borderColor = [UIColor redColor].CGColor ;//[UIColor colorWithWhite:0 alpha:0.6].CGColor;
    av.layer.borderColor = [UIColor colorWithRed: 0 green: 80.0 / 255.0 blue: 132.0 / 255.0 alpha: 0.5].CGColor;
    av.layer.borderWidth = 1;
    av.layer.cornerRadius = 4;

    CustomAnnotationView *customAnnotationView = (CustomAnnotationView *)parentView;

    Annotation *annotation = customAnnotationView.annotation;
    av.titleLabel.text = annotation.title;
    av.subtitleLabel.text = annotation.subtitle;
    av.bkg_image.image = [backgroundImages imageForBusiness: annotation.business];
    selectedBusinessInfo = annotation.business;

    av.userInteractionEnabled = YES;

    if (!singleCalloutView)
    {
        [self createSingleCalloutView];
    }
    singleCalloutView.contentView = av;



    singleCalloutView.calloutOffset = customAnnotationView.calloutOffset;

    customAnnotationView.calloutView = singleCalloutView;

    [singleCalloutView presentCalloutFromRect: parentView.bounds
                                       inView: parentView
                            constrainedToView: self.mapView
                     permittedArrowDirections: SMCalloutArrowDirectionAny
                                     animated: YES];
}

- (void)removePopupView
{
    if (singleCalloutView) {
        [UIView animateWithDuration:0.35
                              delay:0
                            options:UIViewAnimationOptionCurveLinear
                        animations:^
        {
            singleCalloutView.alpha = 0.0;
        }
        completion:^(BOOL finished)
        {
            [singleCalloutView removeFromSuperview];
            singleCalloutView.alpha = 1.0; // reset alpha
        }];
    }
}


#pragma mark Segue

- (void)launchBusinessDetailsWithBizID: (NSString *)bizId andLocation: (CLLocationCoordinate2D)location animated: (BOOL)animated
{
    if (businessDetailsController)
    {
        return;
    }

    UIStoryboard *directoryStoryboard = [UIStoryboard storyboardWithName: @"BusinessDirectory" bundle: nil];
    businessDetailsController = [directoryStoryboard instantiateViewControllerWithIdentifier: @"BusinessDetailsViewController"];

    businessDetailsController.bizId = bizId;
    businessDetailsController.latLong = location;
    businessDetailsController.delegate = self;

//    [MainViewController animateView:businessDetailsController withBlur:NO animate:animated];

    CGRect frame = self.view.bounds;
    frame.origin.x = frame.size.width;
    businessDetailsController.view.frame = frame;
    [self.view addSubview: businessDetailsController.view];

    if (animated)
    {
        [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
        [UIView animateWithDuration: 0.35
                              delay: 0.0
                            options: UIViewAnimationOptionCurveEaseInOut
                         animations: ^
        {
            businessDetailsController.view.frame = self.view.bounds;
        }
                         completion: ^(BOOL finished)
        {
            [[UIApplication sharedApplication] endIgnoringInteractionEvents];
            //self.dividerView.alpha = 0.0;
        }];
    }
}

//- (void)animateBusinessDetailsOnScreen
//{
//    if (businessDetailsController)
//    {
//        return;
//    }
//
//    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
//    [UIView animateWithDuration: 0.35
//                          delay: 0.0
//                        options: UIViewAnimationOptionCurveEaseInOut
//                     animations: ^
//    {
//        businessDetailsController.view.frame = self.view.bounds;
//    }
//                     completion: ^(BOOL finished)
//    {
//        [[UIApplication sharedApplication] endIgnoringInteractionEvents];
//    }];
//}

- (void)dismissBusinessDetails
{
    [MainViewController animateOut:businessDetailsController withBlur:NO complete:^(void)
    {
        businessDetailsController = nil;
        [self setupNavBar];
    }];
}

- (void)launchMoreCategories
{
    // prevent >1 instances
    if (moreCategoriesController) {
        return;
    }

    UIStoryboard *directoryStoryboard = [UIStoryboard storyboardWithName: @"BusinessDirectory" bundle: nil];
    moreCategoriesController = [directoryStoryboard instantiateViewControllerWithIdentifier: @"MoreCategoriesViewController"];

    moreCategoriesController.delegate = self;
    [Util addSubviewControllerWithConstraints:self child:moreCategoriesController];
    [MainViewController animateSlideIn:moreCategoriesController];
}

- (void)dismissMoreCategories
{
    [MainViewController animateOut:moreCategoriesController withBlur:NO complete:^(void)
    {
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

- (void)bufferBusinessResults: (NSArray *)arrayResults forPage: (int)page
{
    //adds a block of business search results to the businessSearchResults dictionary

    int row = page * DEFAULT_RESULTS_PER_PAGE;
    [businessSearchResults removeAllObjects];
    [self.mapView removeAllAnnotations];
    [backgroundImages removeAllImages];

    //ABLog(2,@"Populate map annotations");
    for (NSDictionary *dict in arrayResults)
    {
        //printf("%i, ", row);
        [businessSearchResults setObject: dict forKey: [NSNumber numberWithInt: row]];
        [backgroundImages loadImageForBusiness: dict];
        Annotation *ann = [self.mapView addAnnotationForBusiness: dict];
        if (ann)
        {
            //ann.thumbnailImage = [backgroundImages imageForBusiness:ann.business];
        }
        row++;
    }
    //ABLog(2,@"Loaded page %i.  Buffer size: %lu", page, (unsigned long)businessSearchResults.count);
    if (mapDisplayState == MAP_DISPLAY_INIT)
    {
        //ABLog(2,@"Setting map state to ZOOM");
        mapDisplayState = MAP_DISPLAY_ZOOM;
        //ABLog(2,@"Zooming map");
        [self.mapView zoomToFitMapAnnotations];
    }
}

- (void)removeSearchResultsPage: (int)page
{
    if (page >= 0)
    {
        for (int row = page * DEFAULT_RESULTS_PER_PAGE; row < ((page + 1) * DEFAULT_RESULTS_PER_PAGE); row++)
        {
            NSDictionary *business = [businessSearchResults objectForKey: [NSNumber numberWithInt: row]];
            [backgroundImages removeImageForBusiness: business];
            [businessSearchResults removeObjectForKey: [NSNumber numberWithInt: row]];
        }
        //ABLog(2,@"Removed page: %i.  Buffer size: %lu", page, (unsigned long)[businessSearchResults count]);
    }
}

- (void)manageBusinessListingsResultsBufferForPage: (int)page
{
    if (page != currentPage)
    {
        //time to manage the buffer
        //load new page
        if (page > currentPage)
        {
            if (page < (totalResultsCount + (DEFAULT_RESULTS_PER_PAGE - 1) / DEFAULT_RESULTS_PER_PAGE))
            {
                //[self loadSearchResultsPage:page + 1];
                [self businessListingQueryForPage: page + 1];
                [self removeSearchResultsPage: page - 2];
            }
        } else
        {
            if (page > 0)
            {
                //[self loadSearchResultsPage:page - 1];
                [self businessListingQueryForPage: page - 1];
                [self removeSearchResultsPage: page + 2];
            }
        }
        //ABLog(2,@"Setting current page to: %i", page);
        currentPage = page;
    }
}

#pragma mark UISearchBar delegates
-(void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar
{
    //called when user taps on either search textField or location textField

    activeSearchBar = searchBar;

    //ABLog(2,@"TextField began editing");
    if (directoryMode != DIRECTORY_MODE_SEARCH)
    {
        [self transitionMode:DIRECTORY_MODE_SEARCH];

    }
    if (searchBar == self.searchBarLocation)
    {
        mostRecentSearchTag = TAG_LOCATION_SEARCH;
        [self pruneCachedSearchItemsFromSearchResults];
        [self.searchCluesTableView reloadData];
        //ABLog(2,@"Most Recent Search Tag: TAG_LOCATION_SEARCH");
        [self searchBarLocationChanged:searchBar textDidChange:searchBar.text];
    }
    if (searchBar == self.searchBarSearch)
    {
        mostRecentSearchTag = TAG_BUSINESS_SEARCH;
        [self pruneCachedLocationItemsFromSearchResults];
        [self.searchCluesTableView reloadData];
        //ABLog(2,@"Most Recent Search Tag: TAG_BUSINESS_SEARCH");
        [self searchBarSearchChanged:searchBar textDidChange:searchBar.text];
    }
}

-(void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)text
{
    if (searchBar == self.searchBarLocation)
    {
        [self searchBarLocationChanged:searchBar textDidChange:text];

    }
    else if(searchBar == self.searchBarSearch)
    {
        [self searchBarSearchChanged:searchBar textDidChange:text];

    }
}

- (void)searchBarSearchChanged: (UISearchBar *)searchBar textDidChange:(NSString *)text
{
    //ABLog(2, @"search text changed: %@", textField.text);
    //mostRecentSearchTag = TAG_BUSINESS_SEARCH;

    [[DL_URLServer controller] cancelAllRequestsForDelegate: self];
    NSMutableString *urlString = [[NSMutableString alloc] init];

    NSString *searchTerm = [text stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding];
    if (searchTerm == nil)
    {
        //there are non ascii characters in the string
        searchTerm = @" ";

    } else
    {
        searchTerm = text;
    }
    [urlString appendString: [NSString stringWithFormat: @"%@/autocomplete-business/?term=%@", SERVER_API, searchTerm]];

    [self addLocationToQuery: urlString];
    //ABLog(2,@"Autocomplete Query: %@", [urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]);
    if (urlString != (id)[NSNull null])
    {
        self.searchIndicator.hidden = NO;
        
        [[DL_URLServer controller] issueRequestURL: [urlString stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding]
                                        withParams: nil
                                        withObject: searchBar
                                      withDelegate: self
                                acceptableCacheAge: AGE_ACCEPT_CACHE_SECS
                                       cacheResult: YES];
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

- (void)searchBarLocationChanged: (UISearchBar *)searchBar textDidChange:(NSString *)text
{
    [[DL_URLServer controller] cancelAllRequestsForDelegate: self];
    //http://107.170.22.83:80/api/v1/autocomplete-location/?term=sa
    //ABLog(2, @"location text changed: %@", textField.text);
    NSMutableString *query = [[NSMutableString alloc] initWithString: [NSString stringWithFormat: @"%@/autocomplete-location?term=%@", SERVER_API, text]];
    [self addLocationToQuery: query];
    //ABLog(2,@"Location Query: %@", query);
    [[DL_URLServer controller] issueRequestURL: [query stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding]
                                    withParams: nil
                                    withObject: searchBar
                                  withDelegate: self
                            acceptableCacheAge: AGE_ACCEPT_CACHE_SECS
                                   cacheResult: YES];
    
    self.searchIndicator.hidden = NO;
}

-(void) searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    if (searchBar == self.searchBarSearch)
    {
        [self.searchBarLocation becomeFirstResponder];
    }
    if (searchBar == self.searchBarLocation)
    {
        if (directoryMode == DIRECTORY_MODE_SEARCH)
        {
            if ([[self.searchBarLocation.text uppercaseString] isEqualToString: [ON_THE_WEB_STRING uppercaseString]])
            {
                [self transitionMode:DIRECTORY_MODE_ON_THE_WEB_LISTING];
            }
            else
            {
                [self transitionMode:DIRECTORY_MODE_MAP];
            }
        }
    }

}
#pragma mark UIScrollView delegates


- (void)scrollViewDidScroll: (UIScrollView *)scrollView
{
    if (scrollView.tag == 0)
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
        
        //ABLog(2,@"Setting selected business info");
        selectedBusinessInfo = businessInfo;
        //[self performSegueWithIdentifier:@"BusinessDetailsSegue" sender:self];
        [self launchBusinessDetailsWithBizID:[businessInfo objectForKey:@"bizId"] andDistance:[[businessInfo objectForKey:@"distance"] floatValue] animated:YES];
    }
}*/

- (NSInteger)tableView: (UITableView *)tableView numberOfRowsInSection: (NSInteger)section
{
    if (tableView.tag == 0)
    {
        //business listings table
        return [businessSearchResults count];
    } else
    {
        //search clues table
        if (mostRecentSearchTag == TAG_BUSINESS_SEARCH)
        {
            if (self.searchBarSearch.text.length == 0)
            {
                return [businessAutoCorrectArray count] + [searchTermCache count];
            } else
            {
                return [businessAutoCorrectArray count];
            }
        } else //(mostRecentSearchTag == TAG_LOCATION_SEARCH)
        {
            if (self.searchBarLocation.text.length == 0)
            {
                return [locationAutoCorrectArray count] + 2 + [searchLocationCache count];
            } else
            {
                return [locationAutoCorrectArray count] + 2;
            }
        }
    }
}

- (topOverviewCell *)getTopOverviewCellForTableView: (UITableView *)tableView
{
    topOverviewCell *cell;
    static NSString *cellIdentifier = @"topOverviewCell";

    cell = [tableView dequeueReusableCellWithIdentifier: cellIdentifier];
    if (nil == cell)
    {
        cell = [[topOverviewCell alloc] initWithStyle: UITableViewCellStyleDefault reuseIdentifier: cellIdentifier];

    }
    cell.delegate = self;
    return cell;
}

- (overviewCell *)getOverviewCellForTableView: (UITableView *)tableView
{
    overviewCell *cell;
    static NSString *cellIdentifier = @"overviewCell";

    cell = [tableView dequeueReusableCellWithIdentifier: cellIdentifier];
    if (nil == cell)
    {
        cell = [[overviewCell alloc] initWithStyle: UITableViewCellStyleDefault reuseIdentifier: cellIdentifier];

    }
    cell.delegate = self;
    return cell;
}

- (UITableViewCell *)tableView: (UITableView *)tableView cellForRowAtIndexPath: (NSIndexPath *)indexPath
{
    NSInteger row = [indexPath row];
    //[self manageBusinessListingsResultsBufferForRow:row];
    if (tableView.tag == 0)
    {
        //business listings
        CommonOverviewCell *cell;

        NSDictionary *businessInfo = [businessSearchResults objectForKey: [NSNumber numberWithInteger: row]];
        /*Annotation *ann = [self.mapView addAnnotationForBusiness:businessInfo];
        if(ann)
        {
            ann.thumbnailImage = [backgroundImages imageForRow:row];
        }*/
        //[self.mapView zoomToFitMapAnnotations];
        cell = [self getTopOverviewCellForTableView: tableView];
        if (businessInfo)
        {

            NSString *distance = [businessInfo objectForKey: @"distance"];
            if (distance && (distance != (id)[NSNull null]))
            {
                cell.ribbon = [RibbonView metersToDistance: [[businessInfo objectForKey: @"distance"] floatValue]];
            }
            else
            {
                cell.ribbon = nil;
                //ABLog(2,@"Unknown");
            }
            cell.businessNameLabel.text = [businessInfo objectForKey: @"name"];
            cell.businessNameLabel.textColor = [UIColor whiteColor];
            cell.addressLabel.text = [businessInfo objectForKey: @"address"];

            //ABLog(2,@"Requesting background image");
            UIImageView *imageView = cell.backgroundImageView;
            imageView.clipsToBounds = YES;
            imageView.image = [backgroundImages imageForBusiness: businessInfo];
//			ABLog(2,@"SelectedBackgroundView: %@", cell.selectedBackgroundView);
//ABLog(2,@"ImageView: %@, image: %@", cell.backgroundView, imageView.image);

            if (imageView.image)
            {
//                if (!cell.bInitialized)
                {
                    UIImageView *imageView = cell.backgroundImageView;


                    CAGradientLayer *layer = [imageView.layer valueForKey:@"GradientLayer"];
                    if (layer)
                    {
                        // Remove gradient and re-add below
                        [layer removeFromSuperlayer];
                        [imageView.layer setValue:nil forKey:@"GradientLayer"];
                        layer = nil;
                    }
                    CGRect frame = imageView.frame;
                    frame.size.width = [MainViewController getWidth];
                    frame.size.height = [Theme Singleton].heightListings;

                    imageView.frame = frame;

//                    ABLog(2,@"row=%d imagewidth=%f width=%f boundswidth=%f", row, imageView.frame.size.width, [MainViewController getWidth], cell.bounds.size.width);
                    // Set black gradient image over layer
                    CAGradientLayer *gradient = [CAGradientLayer layer];
                    gradient.frame = imageView.frame;

                    // Add colors to layer
                    UIColor *topColor = UIColorFromARGB(0x00000000);
                    UIColor *centerColor = UIColorFromARGB(0x48000000);
                    UIColor *endColor = UIColorFromARGB(0xa0000000);

                    gradient.colors = @[(id) topColor.CGColor,
                            (id) centerColor.CGColor,
                            (id) endColor.CGColor];

                    [imageView.layer insertSublayer:gradient atIndex:0];
                    [imageView.layer setValue:gradient forKey:@"GradientLayer"];
                    cell.bInitialized = YES;
                }
                imageView.hidden = NO;
            }
            else
            {
                imageView.hidden = YES;
            }

            cell.bitCoinLabel.hidden = NO;
#if SHOW_SERVER_PAGE
            cell.bitCoinLabel.text = [NSString stringWithFormat: @"Page %i", row / DEFAULT_RESULTS_PER_PAGE];
#else
            NSString *bitCoinDiscount = [businessInfo objectForKey: @"has_bitcoin_discount"];
            if (bitCoinDiscount)
            {
                float discount = [bitCoinDiscount floatValue] * 100.0;
                if (discount)
                {
                    cell.bitCoinLabel.text = [NSString stringWithFormat: @"BTC Discount: %.0f%%", [bitCoinDiscount floatValue] * 100.0];
                } else
                {
                    cell.bitCoinLabel.text = @" ";
                }
            } else
            {
                cell.bitCoinLabel.text = @" ";
            }
#endif

        } else
        {
            //in case server returns fewer objects than it says (so we don't crash)
            cell.businessNameLabel.text = @"Loading...";
            cell.businessNameLabel.textColor = [UIColor whiteColor];
            cell.addressLabel.text = @" ";
            cell.bitCoinLabel.hidden = YES;
            //[cell loadBackgroundImageForBusiness:nil];
        }
        return cell;
    } else
    {
        //search clues
        static NSString *cellIdentifier = @"searchClueCell";

        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: cellIdentifier];
        if (nil == cell)
        {
            cell = [[UITableViewCell alloc] initWithStyle: UITableViewCellStyleDefault reuseIdentifier: cellIdentifier];
        }
        if (mostRecentSearchTag == TAG_LOCATION_SEARCH)
        {
            //show results for location textfield
            // Reset the font first.
            UIFont *myFont = [UIFont systemFontOfSize: 18.0f];
            cell.textLabel.font = myFont;

            unsigned long cacheSize = 0;
            if (self.searchBarLocation.text.length == 0)
            {
                cacheSize = searchLocationCache.count;
            }
            if (indexPath.row < cacheSize)
            {
                cell.textLabel.text = [searchLocationCache objectAtIndex: indexPath.row];
                //
                cell.textLabel.textColor = [UIColor colorWithRed: 0.5020 green: 0.7647 blue: 0.2549 alpha: 1.0];
                cell.textLabel.backgroundColor = [UIColor clearColor];
            } else if (indexPath.row == cacheSize)
            {
                cell.textLabel.text = CURRENT_LOCATION_STRING;
                cell.textLabel.textColor = [UIColor blueColor];
                cell.textLabel.backgroundColor = [UIColor clearColor];
            } else if (indexPath.row == cacheSize + 1)
            {
                cell.textLabel.text = ON_THE_WEB_STRING;
                cell.textLabel.textColor = [UIColor blueColor];
                cell.textLabel.backgroundColor = [UIColor clearColor];
            } else if (locationAutoCorrectArray != nil)
            {
                unsigned long index = indexPath.row - (NUM_PROGRAMMATIC_RESULTS + cacheSize);
                if (index < [locationAutoCorrectArray count] && [[locationAutoCorrectArray objectAtIndex:index] isKindOfClass:[NSString class]])
                {
                    cell.textLabel.text = [locationAutoCorrectArray objectAtIndex:index];
                    cell.textLabel.textColor = [UIColor darkGrayColor];
                }
            }
        } else if (mostRecentSearchTag == TAG_BUSINESS_SEARCH)
        {
            unsigned long cacheSize = 0;

            // Reset the font first.
            UIFont *myFont = [UIFont systemFontOfSize: 18.0f];
            cell.textLabel.font = myFont;

            if (self.searchBarSearch.text.length == 0)
            {
                cacheSize = searchTermCache.count;
            }
            //show results for business search field
            //ABLog(2,@"Row: %li", (long)indexPath.row);
            //ABLog(2,@"Results array: %@", businessAutoCorrectArray);
            if (indexPath.row < cacheSize)
            {
                cell.textLabel.text = [self stringForObjectInCache: searchTermCache atIndex: indexPath.row]; //[searchTermCache objectAtIndex:indexPath.row];
                cell.textLabel.textColor = [UIColor colorWithRed: 0.5020 green: 0.7647 blue: 0.2549 alpha: 1.0];
                cell.textLabel.backgroundColor = [UIColor clearColor];
            } else if (businessAutoCorrectArray.count && businessAutoCorrectArray.count > indexPath.row)
            {
                NSObject *object = [businessAutoCorrectArray objectAtIndex: indexPath.row - cacheSize];
                if ([object isKindOfClass: [NSDictionary class]])
                {
                    cell.textLabel.text = [(NSDictionary *)object objectForKey: @"text"];
                    NSString *type = [(NSDictionary *)object objectForKey: @"type"];

                    if ([type isEqualToString: @"category"])
                    {
                        UIFont *myFont = [UIFont italicSystemFontOfSize: 18.0f];
                        cell.textLabel.font = myFont;
                    } else
                    {
                        UIFont *myFont = [UIFont boldSystemFontOfSize: 18.0f];
                        cell.textLabel.font = myFont;

                    }
                } else
                {
                    cell.textLabel.text = (NSString *)object;
                }

                cell.textLabel.textColor = [UIColor darkGrayColor];
            }
        }
        return cell;
    }
}

- (CGFloat)tableView: (UITableView *)tableView heightForRowAtIndexPath: (NSIndexPath *)indexPath
{
    if (tableView.tag == 0)
    {
        return [Theme Singleton].heightListings;
    } else
    {
        return [Theme Singleton].heightSearchClues;
    }
}

- (void)tableView: (UITableView *)tableView didSelectRowAtIndexPath: (NSIndexPath *)indexPath
{
    if (tableView == self.searchCluesTableView)
    {
        self.searchIndicator.hidden = YES;
        //ABLog(2,@"Row: %i", indexPath.row);
        UITableViewCell *cell = [tableView cellForRowAtIndexPath: indexPath];
        if (mostRecentSearchTag == TAG_BUSINESS_SEARCH)
        {
            NSDictionary *dict;

            NSUInteger cacheSize = 0;
            if (self.searchBarSearch.text.length == 0)
            {
                cacheSize = searchTermCache.count;
            }
            if (indexPath.row < cacheSize)
            {
                dict = [searchTermCache objectAtIndex: indexPath.row];
            } else if (0 < [businessAutoCorrectArray count])
            {
                dict = [businessAutoCorrectArray objectAtIndex: indexPath.row - cacheSize];
                //add to search cache
                if ([searchTermCache containsObject: dict] == NO)
                {
                    [searchTermCache addObject: dict];
                    if (searchTermCache.count > MAX_SEARCH_CACHE_SIZE)
                    {
                        [searchTermCache removeObjectAtIndex: 0];
                    }
                }
            }
            NSString *type = [dict objectForKey: @"type"];


            if ([type isEqualToString: @"business"])
            {
                self.searchBarSearch.text = cell.textLabel.text;
                [self.searchBarSearch resignFirstResponder];
                //ABLog(2,@"Go to business");
                //[self transitionSearchToMap];
                /*NSDictionary *businessInfo = [businessSearchResults objectForKey:[NSNumber numberWithInteger:indexPath.row]];
                if(businessInfo)
                {
                    ABLog(2,@"Setting selected business info");
                    selectedBusinessInfo = businessInfo;
                    //[self performSegueWithIdentifier:@"BusinessDetailsSegue" sender:self];
                    [self launchBusinessDetails];
                }
                else*/
                //{
                //find this business's bizID in businessSearchResults.  If found, we can grab the distance and pass it to Biz Details
                float distance = 0;
                for (NSString *key in businessSearchResults)
                {
                    NSDictionary *business = [businessSearchResults objectForKey: key];
                    //ABLog(2,@"%@ = %@", [dict objectForKey:@"bizId"], [business objectForKey:@"bizId"]);
                    NSString *firstBizID = [dict objectForKey: @"bizId"];
                    NSString *secondBizID = [[business objectForKey: @"bizId"] stringValue];
                    if ([firstBizID isEqualToString: secondBizID])
                    {
                        //found it
                        NSNumber *distanceNum = [business objectForKey: @"distance"];
                        if (distanceNum && (distanceNum != (id)[NSNull null]))
                        {
                            distance = [distanceNum floatValue];
                            break;
                        }
                    }
                }
                CLLocation *location = [Location controller].curLocation;
                [self launchBusinessDetailsWithBizID: [dict objectForKey: @"bizId"] andLocation: location.coordinate animated: YES];
//                [self transitionSearchToListing];
                [self transitionMode:DIRECTORY_MODE_LISTING];
                //}
            } else
            {
                self.searchBarSearch.text = cell.textLabel.text;

                [self.searchBarLocation becomeFirstResponder];

                businessAutoCorrectArray = nil;
                [self.searchCluesTableView reloadData];
                //[self transitionSearchToMap];
            }
        }
        else if (mostRecentSearchTag == TAG_LOCATION_SEARCH)
        {
            self.searchBarLocation.text = cell.textLabel.text;
            //add to search cache
            if ([searchLocationCache containsObject: cell.textLabel.text] == NO)
            {
                if (([cell.textLabel.text isEqualToString: ON_THE_WEB_STRING] == NO) && ([cell.textLabel.text isEqualToString: CURRENT_LOCATION_STRING] == NO)) //don't cache the default items
                {
                    [searchLocationCache addObject: cell.textLabel.text];
                    if (searchLocationCache.count > MAX_SEARCH_CACHE_SIZE)
                    {
                        [searchLocationCache removeObjectAtIndex: 0];
                    }
                }
            }

            if ([cell.textLabel.text isEqualToString: ON_THE_WEB_STRING])
            {
                [self transitionMode:DIRECTORY_MODE_ON_THE_WEB_LISTING];
            }
            else
            {
                [self transitionMode:DIRECTORY_MODE_MAP];
            }
//            [self.searchBarSearch becomeFirstResponder];
//
//            locationAutoCorrectArray = nil;
//            [self.searchCluesTableView reloadData];
        }
    }
    else
    {
        //business listings table
        NSDictionary *businessInfo = [businessSearchResults objectForKey: [NSNumber numberWithInteger: indexPath.row]];

        //ABLog(2,@"Setting selected business info");
        selectedBusinessInfo = businessInfo;
        //[self performSegueWithIdentifier:@"BusinessDetailsSegue" sender:self];
        float distance = 0.0;
        NSNumber *number = [businessInfo objectForKey: @"distance"];
        if (number != (id)[NSNull null])
        {
            distance = [number floatValue];
        }
        CLLocation *location = [Location controller].curLocation;
        [self launchBusinessDetailsWithBizID: [businessInfo objectForKey: @"bizId"] andLocation: location.coordinate animated: YES];
    }
}

- (void)tableView: (UITableView *)tableView didEndDisplayingCell: (UITableViewCell *)cell forRowAtIndexPath: (NSIndexPath *)indexPath
{
    NSDictionary *businessInfo = [businessSearchResults objectForKey: [NSNumber numberWithInteger: indexPath.row]];
    if (businessInfo)
    {
        //[self.mapView removeAnnotationForBusiness:businessInfo];
        //[self.mapView zoomToFitMapAnnotations];
    }
}

#pragma mark - DLURLServer Callbacks

- (void)onDL_URLRequestCompleteWithStatus: (tDL_URLRequestStatus)status resultData: (NSData *)data resultObj: (id)object
{
    NSString *jsonString = [[NSString alloc] initWithBytes: [data bytes] length: [data length] encoding: NSUTF8StringEncoding];

    //ABLog(2,@"Results download returned: %@", jsonString );

    NSData *jsonData = [jsonString dataUsingEncoding: NSUTF32BigEndianStringEncoding];
    NSError *myError;
    NSDictionary *dictFromServer = [[CJSONDeserializer deserializer] deserializeAsDictionary: jsonData error: &myError];

    if ([dictFromServer objectForKey: @"results"] != (id)[NSNull null])
    {
        if (object == self.searchBarLocation)
        {
            //ABLog(2,@"Got search results: %@", [dictFromServer objectForKey:@"results"]);
            locationAutoCorrectArray = [[dictFromServer objectForKey: @"results"] mutableCopy];
            [self pruneCachedLocationItemsFromSearchResults];
            [self.searchCluesTableView reloadData];

        } else if (object == self.searchBarSearch)
        {
            //ABLog(2,@"Got search results: %@", [dictFromServer objectForKey:@"results"]);
            businessAutoCorrectArray = [[dictFromServer objectForKey: @"results"] mutableCopy];
            [self pruneCachedSearchItemsFromSearchResults];
            [self.searchCluesTableView reloadData];
            if (businessAutoCorrectArray.count)
            {

            } else
            {
                ABLog(2,@"SEARCH RESULTS ARRAY IS EMPTY!");
            }
        } else
        {
            //object is a page number (NSNumber)
            if (DL_URLRequestStatus_Success == status)
            {
                //ABLog(2,@"Error: %@", myError);
                //ABLog(2,@"Dictionary from server: %@", [dictFromServer allKeys]);

                //total number of results (in all pages)
                totalResultsCount = [[dictFromServer objectForKey: @"count"] intValue];

                [self bufferBusinessResults: [dictFromServer objectForKey: @"results"] forPage: [object intValue]];
                //ABLog(2,@"Businesses: %@", businessesArray);
                //ABLog(2,@"Total results: %i", totalResultsCount);
            } else
            {
                ABLog(2,@"*** SERVER REQUEST STATUS FAILURE ***");
                NSString *msg = NSLocalizedString(@"Can't connect to server.  Check your internet connection", nil);
                UIAlertView *alert = [[UIAlertView alloc]
                                          initWithTitle: NSLocalizedString(@"No Connection", @"Alert title that warns user couldn't connect to server")
                                                message: msg
                                               delegate: nil
                                      cancelButtonTitle: @"OK"
                                      otherButtonTitles: nil];
                [alert show];

            }
            [self.tableView reloadData];
        }
    }
    self.spinnerView.hidden = YES;
    self.searchIndicator.hidden = YES;
}

#pragma mark DividerView

- (void)positionDividerView
{
    if (self.dividerView.userControllable == NO)
    {
        float offset = self.tableView.contentOffset.y;
        if (offset > self.tableView.tableHeaderView.frame.size.height - [MainViewController getHeaderHeight])
        {
            offset = self.tableView.tableHeaderView.frame.size.height - [MainViewController getHeaderHeight];
        }
        self.dividerViewTop.constant = self.tableView.frame.origin.y + self.tableView.tableHeaderView.frame.size.height - DIVIDER_BAR_TRANSPARENT_AREA_HEIGHT - offset;
//        ABLog(2,@"position non-control divider coords: %f <- %f %f %f\n", self.dividerViewTop.constant, offset, self.tableView.frame.origin.y, self.tableView.tableHeaderView.frame.size.height);

    }
    else
    {
        self.dividerViewTop.constant = self.mapView.frame.origin.y + self.mapView.frame.size.height - DIVIDER_BAR_TRANSPARENT_AREA_HEIGHT;
//        ABLog(2,@"position control divider coords: %f <- %f %f %f\n", self.dividerViewTop.constant, self.tableView.frame.origin.y, self.tableView.tableHeaderView.frame.size.height);
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

- (void)hideDividerView
{
    self.dividerView.alpha = 0.0;
}

- (void)showDividerView
{
    self.dividerView.alpha = 1.0;
}

- (void)DividerViewTouchesBegan: (NSSet *)touches withEvent: (UIEvent *)event
{
    //ABLog(2,@"Divider touches began");
    //ABLog(2,@"Setting map state to RESIZE");
    mapDisplayState = MAP_DISPLAY_RESIZE;
    dividerBarStartTouchPoint = [[touches anyObject] locationInView: self.contentView];
}

- (void)DividerViewTouchesMoved: (NSSet *)touches withEvent: (UIEvent *)event
{
    CGPoint newLocation = [[touches anyObject] locationInView: self.contentView];

    _dividerViewTop.constant += newLocation.y - dividerBarStartTouchPoint.y;
    //don't allow divider bar to be dragged beyond searchbar
    if (_dividerViewTop.constant < [MainViewController getHeaderHeight]) //(self.searchView.frame.origin.y + self.searchView.frame.size.height - DIVIDER_BAR_TRANSPARENT_AREA_HEIGHT))
    {
        _dividerViewTop.constant = [MainViewController getHeaderHeight]; //self.searchView.frame.origin.y + self.searchView.frame.size.height - DIVIDER_BAR_TRANSPARENT_AREA_HEIGHT;
    }

    //don't allow divider bar to be dragged to far down
    if (_dividerViewTop.constant > self.contentView.bounds.size.height - _dividerView.frame.size.height - [MainViewController getFooterHeight] - DIVIDER_DOWN_MARGIN)
    {
        _dividerViewTop.constant = self.contentView.bounds.size.height - _dividerView.frame.size.height - [MainViewController getFooterHeight] - DIVIDER_DOWN_MARGIN;
    }
    dividerBarStartTouchPoint = newLocation;

    [self updateMapAndTableToTrackDividerBar];
}

- (void)updateMapAndTableToTrackDividerBar
{
    //updates mapView and tableView heights to conincide with divider bar position
    CGRect frame = self.dividerView.frame;

    CGRect mapFrame = self.mapView.frame;
    _mapViewHeight.constant = frame.origin.y - mapFrame.origin.y + DIVIDER_BAR_TRANSPARENT_AREA_HEIGHT;

    CGRect tableFrame = self.tableView.frame;
    _tableViewListingsTop.constant = frame.origin.y + DIVIDER_BAR_TRANSPARENT_AREA_HEIGHT;
    self.tableView.frame = tableFrame;

}


- (void)DividerViewTouchesEnded: (NSSet *)touches withEvent: (UIEvent *)event
{
    //ABLog(2,@"Setting map state to NORMAL");
    mapDisplayState = MAP_DISPLAY_NORMAL;
}

- (void)DividerViewTouchesCancelled: (NSSet *)touches withEvent: (UIEvent *)event
{
    //ABLog(2,@"Setting map state to NORMAL");
    mapDisplayState = MAP_DISPLAY_NORMAL;
}

#pragma mark BackgroundImageManager delegates

- (void)BackgroundImageManagerImageLoadedForBizID: (NSNumber *)bizID
{
    NSArray *visiblePaths = [self.tableView indexPathsForVisibleRows];

    int imageBizID = [bizID intValue];
    BOOL reloadTable = NO;
    for (NSIndexPath *path in visiblePaths)
    {
        NSDictionary *business = [businessSearchResults objectForKey: [NSNumber numberWithInteger: path.row]];
        int otherBizID = [[business objectForKey: @"bizId"] intValue];
        if (imageBizID == otherBizID)
        {
            reloadTable = YES;
            break;
        }
    }
    if (reloadTable)
    {
        //ABLog(2,@"Reloading table because image for visible cell just got loaded");
        [self.tableView reloadData];
    }
}

#pragma mark LocationDelegates

- (void)DidReceiveLocation
{
    //ABLog(2,@"Location Received!");
    if (receivedInitialLocation == NO)
    {
        receivedInitialLocation = YES;
        [self businessListingQueryForPage: 0];
    }
}

#pragma mark BusinessDetailsViewControllerDelegates

- (void)businessDetailsViewControllerDone: (BusinessDetailsViewController *)controller
{
    if (NO == [CommonOverviewCell dismissSelectedCell])
    {
        [self dismissBusinessDetails];
    }
    [self setupNavBar];
}

#pragma mark MoreCategoriesViewControllerDelegates

- (void)moreCategoriesViewControllerDone: (MoreCategoriesViewController *)controller withCategory: (NSString *)category
{
    [self dismissMoreCategories];
    if (category)
    {
        [self transitionMode:DIRECTORY_MODE_SEARCH];
        [self setupNavBar];
        [self.searchBarLocation becomeFirstResponder];
        self.searchBarSearch.text = category;
    }
}

#pragma mark CalloutView delegates

- (void)calloutViewDidDisappear: (SMCalloutView *)calloutView
{
    singleCalloutView = nil;
}

#pragma mark infoView Delegates

- (void)InfoViewFinished: (InfoView *)infoView
{
    [infoView removeFromSuperview];
}

#pragma mark Overview Cell delegates

- (void)OverviewCell: (CommonOverviewCell *)cell didStartDraggingFromPointInCell: (CGPoint)point
{
    //tapTimer = CACurrentMediaTime();
    self.tableView.canCancelContentTouches = NO;
    self.tableView.delaysContentTouches = NO;
    CGPoint swipeLocation = [cell convertPoint:point toView:self.tableView]; //[gestureRecognizer locationInView:self.tableView];
    NSIndexPath *swipedIndexPath = [self.tableView indexPathForRowAtPoint:swipeLocation];
    //UITableViewCell* swipedCell = [self.tableView cellForRowAtIndexPath:swipedIndexPath];

    NSDictionary *businessInfo = [businessSearchResults objectForKey: [NSNumber numberWithInteger: swipedIndexPath.row]];

    // ABLog(2,@"Setting selected business info");
    selectedBusinessInfo = businessInfo;
    //[self performSegueWithIdentifier:@"BusinessDetailsSegue" sender:self];
    float distance = 0.0;
    NSNumber *distanceNum = [businessInfo objectForKey: @"distance"];
    if (distanceNum && (distanceNum != (id)[NSNull null]))
    {
        distance = [distanceNum floatValue];
    }
    CLLocation *location = [Location controller].curLocation;
    [self launchBusinessDetailsWithBizID: [businessInfo objectForKey: @"bizId"] andLocation: location.coordinate animated: NO];
    cell.viewConnectedToMe = businessDetailsController.view;
    //self.tableView.scrollEnabled = NO;
}

- (void)OverviewCellDidEndDraggingReturnedToStart: (BOOL)returned
{
    //self.tableView.scrollEnabled = YES;

    if (returned)
    {
        [businessDetailsController.view removeFromSuperview];
        [businessDetailsController removeFromParentViewController];
        businessDetailsController = nil;
        [self setupNavBar];
    }
}

- (void)OverviewCellDraggedWithOffset: (float)xOffset
{
    //ABLog(2,@"Drag offset: %f", xOffset);
    //CGRect frame = businessDetailsController.view.frame;
    //frame.origin.x = self.view.bounds.size.width + xOffset;
    //businessDetailsController.view.frame = frame;

}

- (void)OverviewCellDidDismissSelectedCell: (CommonOverviewCell *)cell
{
    //ABLog(2,@"Removing business details controller");
    [businessDetailsController.view removeFromSuperview];
    [businessDetailsController removeFromParentViewController];
    businessDetailsController = nil;
    [self setupNavBar];
}

@end
