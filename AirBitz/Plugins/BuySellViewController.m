//
//  BuySellViewController.m
//  AirBitz
//

#import "BuySellCell.h"
#import "BuySellViewController.h"
#import "MainViewController.h"
#import "Plugin.h"
#import "PluginViewController.h"
#import "Theme.h"
#import "Util.h"
#import "WalletHeaderView.h"

@interface BuySellViewController () <UIWebViewDelegate, UITableViewDataSource, UITableViewDelegate, PluginViewControllerDelegate>
{
    PluginViewController *_pluginViewController;
}

@property (nonatomic, strong) WalletHeaderView    *activePluginsView;
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
    _backButton.hidden = YES;

    _activePluginsView = [WalletHeaderView CreateWithTitle:NSLocalizedString(@"", nil) collapse:NO];
    _activePluginsView.btn_expandCollapse.hidden = YES;
    _activePluginsView.btn_addWallet.hidden = YES;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    _pluginTable.editing = NO;
    [self setupNavBar];
}

- (void)setupNavBar
{
    [MainViewController changeNavBarOwner:self];
    [MainViewController changeNavBar:self title:[Theme Singleton].buySellText
                                side:NAV_BAR_CENTER
                              button:NO
                              enable:true
                              action:nil
                          fromObject:self];
    // Clear back button
    [MainViewController changeNavBar:self
                               title:nil
                                side:NAV_BAR_LEFT
                              button:YES
                              enable:NO
                              action:nil
                          fromObject:self];
}

#pragma mark - UITableView

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return nil;
}

-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 0.0;
}

-(UIView *) tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    return _activePluginsView;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [[Plugin getPlugins] count];
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return UITableViewCellEditingStyleNone;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"BuySellCell";
    NSInteger row = [indexPath row];
 
    BuySellCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[BuySellCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    Plugin *plugin = [[Plugin getPlugins] objectAtIndex:row];
    [cell setInfo:row tableHeight:[tableView numberOfRowsInSection:indexPath.section]];
    cell.text.text = plugin.name;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
 
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger row = [indexPath row];
    Plugin *plugin = [[Plugin getPlugins] objectAtIndex:row];
    [self launchPlugin:plugin];
}

- (BOOL)launchPluginByCountry:(NSString *)country provider:(NSString *)provider
{
    Plugin *plugin = nil;
    for (Plugin *p in [Plugin getPlugins]) {
        if ([provider isEqualToString:p.provider]
          && [country isEqualToString:p.country]) {
            plugin = p;
        }
    }
    if (plugin != nil) {
        [self launchPlugin:plugin];
        return YES;
    }
    return NO;
}

- (void)launchPlugin:(Plugin *)plugin
{
    if (_pluginViewController != nil) {
        [_pluginViewController.view removeFromSuperview];
        [_pluginViewController removeFromParentViewController];

    }
    UIStoryboard *pluginStoryboard = [UIStoryboard storyboardWithName:@"Plugins" bundle: nil];
    _pluginViewController = [pluginStoryboard instantiateViewControllerWithIdentifier:@"PluginViewController"];
    _pluginViewController.delegate = self;
    _pluginViewController.plugin = plugin;

    [Util animateController:_pluginViewController parentController:self];
}

#pragma mark - PluginViewControllerDelegate

- (void)PluginViewControllerDone:(PluginViewController *)controller
{
    [self setupNavBar];
    [Util animateOut:controller parentController:self complete:^(void) {
        _pluginViewController = nil;
    }];
}

@end
