//
//  BuySellViewController.m
//  AirBitz
//

#import "BuySellViewController.h"
#import "MainViewController.h"
#import "Theme.h"
#import "BuySellCell.h"
#import "PluginViewController.h"
#import "WalletHeaderView.h"
#import "Plugin.h"
#import "Util.h"

#define SECTION_GIFT_CARDS      0
#define SECTION_BUY_SELL        1
#define SECTIONS_TOTAL          2

#define INDEX_FROM_SECTION_ROW(section, row) [NSNumber numberWithInt:((row * SECTIONS_TOTAL) + section)]

@interface BuySellViewController () <UIWebViewDelegate, UITableViewDataSource, UITableViewDelegate, PluginViewControllerDelegate>
{
    NSMutableDictionary *_pluginViewControllers;
    int numBuySell;
    int numGiftCard;
    int numPlugins;
}

@property (nonatomic, strong) WalletHeaderView    *buySellHeaderView;
@property (nonatomic, strong) WalletHeaderView    *giftCardHeaderView;
@property (nonatomic, weak) IBOutlet UILabel      *titleLabel;
@property (nonatomic, weak) IBOutlet UIButton     *backButton;
@property (nonatomic, weak) IBOutlet UITableView  *pluginTable;

@end

@implementation BuySellViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
    }
    return self;
}

- (void)viewDidLoad
{
    _pluginTable.dataSource = self;
    _pluginTable.delegate = self;
    _pluginTable.separatorStyle = UITableViewCellSeparatorStyleNone;
    [_pluginTable setContentInset:UIEdgeInsetsMake(0,0,
                                                   [MainViewController getFooterHeight],0)];

    _backButton.hidden = YES;

    _buySellHeaderView = [WalletHeaderView CreateWithTitle:NSLocalizedString(@"Buy / Sell Bitcoin", nil) collapse:NO];
    _buySellHeaderView.btn_expandCollapse.hidden = YES;
    _buySellHeaderView.btn_addWallet.hidden = YES;
    _buySellHeaderView.btn_exportWallet.hidden = YES;
    _buySellHeaderView.btn_header.hidden = YES;
    _giftCardHeaderView = [WalletHeaderView CreateWithTitle:NSLocalizedString(@"Discounted Gift Cards", nil) collapse:NO];
    _giftCardHeaderView.btn_expandCollapse.hidden = YES;
    _giftCardHeaderView.btn_addWallet.hidden = YES;
    _giftCardHeaderView.btn_exportWallet.hidden = YES;
    _giftCardHeaderView.btn_header.hidden = YES;

    [Plugin initAll];
    
    numBuySell = (int)[[Plugin getBuySellPlugins] count];
    numGiftCard = (int)[[Plugin getGiftCardPlugins] count];
    numPlugins = (SECTIONS_TOTAL * MAX(numGiftCard, numBuySell));
    
    _pluginViewControllers = [[NSMutableDictionary alloc] initWithCapacity:numPlugins];
    
    // Fill Section 0
    int numRows = numGiftCard;
    
    for (int row = 0; row < numRows; row++)
    {
        PluginViewController *pluginViewController;
        Plugin *plugin = [[Plugin getGiftCardPlugins] objectAtIndex:row];
        
        UIStoryboard *pluginStoryboard = [UIStoryboard storyboardWithName:@"Plugins" bundle: nil];
        pluginViewController = [pluginStoryboard instantiateViewControllerWithIdentifier:@"PluginViewController"];
        pluginViewController.delegate = self;
        pluginViewController.plugin = plugin;
        pluginViewController.uri = nil;
        [pluginViewController.view layoutSubviews];
        _pluginViewControllers[INDEX_FROM_SECTION_ROW(SECTION_GIFT_CARDS, row)] = pluginViewController;
    }

    // Fill Section 1
    numRows = numBuySell;
    
    for (int row = 0; row < numRows; row++)
    {
        PluginViewController *pluginViewController;
        Plugin *plugin = [[Plugin getBuySellPlugins] objectAtIndex:row];
        
        UIStoryboard *pluginStoryboard = [UIStoryboard storyboardWithName:@"Plugins" bundle: nil];
        pluginViewController = [pluginStoryboard instantiateViewControllerWithIdentifier:@"PluginViewController"];
        pluginViewController.delegate = self;
        pluginViewController.plugin = plugin;
        pluginViewController.uri = nil;
        [pluginViewController.view layoutSubviews];
        _pluginViewControllers[INDEX_FROM_SECTION_ROW(SECTION_BUY_SELL, row)] = pluginViewController;
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [MainViewController changeNavBarOwner:self];
    [MainViewController changeNavBar:self title:backButtonText side:NAV_BAR_LEFT button:true enable:false action:nil fromObject:self];
    [MainViewController changeNavBar:self title:backButtonText side:NAV_BAR_RIGHT button:true enable:false action:nil fromObject:self];
    [MainViewController changeNavBarTitle:self title:buySellText];
    _pluginTable.editing = NO;
}

#pragma mark - UITableView

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return nil;
}

-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return [Theme Singleton].heightBLETableCells;
}

-(UIView *) tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    if (SECTION_BUY_SELL == section)
        return  _buySellHeaderView;
    else
        return  _giftCardHeaderView;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return SECTIONS_TOTAL;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (SECTION_BUY_SELL == section)
        return [[Plugin getBuySellPlugins] count];
    else
        return [[Plugin getGiftCardPlugins] count];
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return UITableViewCellEditingStyleNone;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(nonnull NSIndexPath *)indexPath
{
    return [Theme Singleton].heightBLETableCells;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"BuySellCell";
    NSInteger section = [indexPath section];
    NSInteger row = [indexPath row];
    PluginViewController *pluginViewController = _pluginViewControllers[INDEX_FROM_SECTION_ROW(section, row)];
    Plugin *plugin = pluginViewController.plugin;
 
    BuySellCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[BuySellCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }

    [cell setInfo:row tableHeight:[tableView numberOfRowsInSection:indexPath.section]];
    cell.text.text = plugin.name;
    cell.text.textColor = plugin.textColor;
    cell.imageView.image = [UIImage imageNamed:plugin.imageFile];
    
    cell.selectionStyle = UITableViewCellSelectionStyleBlue;
    cell.accessoryType = UITableViewCellAccessoryNone;
 
    UIView *bgColorView = [[UIView alloc] init];
    bgColorView.backgroundColor = [Theme Singleton].colorBackgroundHighlight;
    bgColorView.layer.masksToBounds = YES;
    cell.selectedBackgroundView = bgColorView;
    cell.backgroundColor = plugin.backgroundColor;

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger section = [indexPath section];
    NSInteger row = [indexPath row];
//    Plugin *plugin;
//    
//    if (SECTION_BUY_SELL == section)
//        plugin = [[Plugin getBuySellPlugins] objectAtIndex:row];
//    else if (SECTION_GIFT_CARDS == section)
//        plugin = [[Plugin getGiftCardPlugins] objectAtIndex:row];
    
    [self launchPluginSectionRow:(int)section row:(int)row];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (BOOL)launchPluginByCountry:(NSString *)country provider:(NSString *)provider uri:(NSURL *)uri
{
    Plugin *plugin = nil;
    for (Plugin *p in [Plugin getBuySellPlugins]) {
        if ([provider isEqualToString:p.provider]
          && [country isEqualToString:p.country]) {
            plugin = p;
        }
    }
    if (nil == plugin)
    {
        for (Plugin *p in [Plugin getGiftCardPlugins]) {
            if ([provider isEqualToString:p.provider]
                && [country isEqualToString:p.country]) {
                plugin = p;
            }
        }
    }
    if (plugin != nil) {
        [self launchPlugin:plugin uri:uri];
        return YES;
    }
    return NO;
}

- (void)launchPluginSectionRow:(int)section row:(int)row
{
    [self resetViews];
    PluginViewController *pluginViewController = _pluginViewControllers[INDEX_FROM_SECTION_ROW(section, row)];
    
    [pluginViewController.view layoutSubviews];
    
    [MainViewController animateSwapViewControllers:pluginViewController out:self];
//   [Util animateController:pluginViewController parentController:self];
    
}

- (void)launchPlugin:(Plugin *)plugin uri:(NSURL *)uri
{
    [self resetViews];

    UIStoryboard *pluginStoryboard = [UIStoryboard storyboardWithName:@"Plugins" bundle: nil];
    PluginViewController *pluginViewController;
    pluginViewController = [pluginStoryboard instantiateViewControllerWithIdentifier:@"PluginViewController"];
    pluginViewController.delegate = self;
    pluginViewController.plugin = plugin;
    pluginViewController.uri = uri;
    [Util animateController:pluginViewController parentController:self];
}

- (void)resetViews
{
    for(id key in _pluginViewControllers)
    {
        PluginViewController *pluginViewController = [_pluginViewControllers objectForKey:key];
        if (pluginViewController)
        {
            [pluginViewController.view removeFromSuperview];
            [pluginViewController removeFromParentViewController];
        }
    }
//    [_pluginViewControllers removeAllObjects];
}

#pragma mark - PluginViewControllerDelegate

- (void)PluginViewControllerDone:(PluginViewController *)controller
{
    [MainViewController changeNavBarOwner:self];
    [MainViewController changeNavBar:self title:backButtonText side:NAV_BAR_LEFT button:true enable:false action:nil fromObject:self];
    [MainViewController changeNavBar:self title:backButtonText side:NAV_BAR_RIGHT button:true enable:false action:nil fromObject:self];
    [MainViewController changeNavBarTitle:self title:buySellText];
    [Util animateOut:controller parentController:self complete:^(void) {
        [self resetViews];
        _pluginViewControllers = nil;
    }];
}

@end
