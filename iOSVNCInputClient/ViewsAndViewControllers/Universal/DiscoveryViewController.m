/*  
 Copyright 2013 V Wong <vwong122013 (at) gmail.com>
 Licensed under the Apache License, Version 2.0 (the "License"); you may not
 use this file except in compliance with the License. You may obtain a copy of
 the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
 WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
 License for the specific language governing permissions and limitations under
 the License.
 */

#import "DiscoveryViewController.h"
#import "MDNSDiscoverer.h"

#import "UIViewController+Spinner.h" //Wait spinning animation

//For pushing to next VC
#import "ServerProfile.h"
#import "ServerProfileViewController.h"

@interface DiscoveryViewController () <MDNSDiscovererDelegateProtocol>
@property (strong,nonatomic) MDNSDiscoverer *discoverer;
@property (strong,nonatomic) NSMutableArray *searchResults;
@end

@implementation DiscoveryViewController

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        _discoverer = [[MDNSDiscoverer alloc] init];
        _searchResults = [NSMutableArray new];
    }
    return self;
}

- (void)viewWillAppear:(BOOL)animated {
    //Setup title
    self.title = NSLocalizedString(@"VNC Servers Found", @"Discovery Navigation Bar Title");
}

- (void)viewDidLoad
{
    [super viewDidLoad];
 
    //Setup refresh button for manual discovery attempts
    UIBarButtonItem *barBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                            target:self
                                                                            action:@selector(startRFBDiscovery)];
    self.navigationItem.rightBarButtonItem = barBtn;
    
    //Start search
    [self startRFBDiscovery];
}

-(void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	
	//Clear selection since it's not getting automatically cleared even though it should.
	[self deselectSelectedCell];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc {
    DLogInf(@"dvc dealloc!");
    [self.discoverer setDelegate:nil];
}

#pragma mark - Orientation view control methods
- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    [self refreshSpinnerPosition]; //Refresh spinner position if present in view
}

#pragma mark - Button Selectors
-(void)startRFBDiscovery {
    //Clear existing data before performing new search
    [self.searchResults removeAllObjects];
    
    [self.discoverer setDelegate:self];
    [self.discoverer startSearch];
}

#pragma mark - Storyboard Scene Transition Methods
//Class method for determining correct SB to reference VC transitions
+(NSString *)interfaceIdiomDependentStoryboardName {
    //Alter macro for reference to SB depending on whether iPad or iPhone
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        return @"MainStoryboard_iPad";
    } else { //"default" SB is iPhone
        return @"MainStoryboard_iPhone";
    }
}

#pragma mark - Table cell manipulation
-(void)deselectSelectedCell {
	NSIndexPath *selectedIndexPath = [self.tableView indexPathForSelectedRow];
	[self.tableView deselectRowAtIndexPath:selectedIndexPath animated:NO];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return self.searchResults.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"discoveredCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    // Configure the cell...
    if (self.searchResults.count > 0) {
        NSDictionary *serviceDetails = [self.searchResults objectAtIndex:indexPath.row];
        cell.textLabel.text = [serviceDetails objectForKey:SERVICE_NAME];
        NSString *address = [serviceDetails objectForKey:SERVICE_ADDRESS];
        NSString *port = [serviceDetails objectForKey:SERVICE_PORT];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ : %@",address,port];
    }
    
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    //Create server profile
    NSDictionary *serviceDetails = [self.searchResults objectAtIndex:indexPath.row];
    ServerProfile *serverProfile = [[ServerProfile alloc] initWithAddress:[serviceDetails objectForKey:SERVICE_ADDRESS]
                                                    Port:[[serviceDetails objectForKey:SERVICE_PORT] intValue]
                                                Username:@""
                                                Password:@""
                                              ServerName:[serviceDetails objectForKey:SERVICE_NAME] ServerVersion:@"" ARD35:NO
                                                 MacAuth:NO];
    
    //Dig out the Server Profile list view controller
    UINavigationController *rootNavCtl = (UINavigationController *)self.view.window.rootViewController;
    
    //Push
    UIStoryboard *sb = [UIStoryboard storyboardWithName:[[self class] interfaceIdiomDependentStoryboardName] bundle:nil];
	ServerProfileViewController *serverProfileVC = [sb instantiateViewControllerWithIdentifier:@"ServerProfileVC"];
	serverProfileVC.serverProfile = serverProfile;
    serverProfileVC.delegate = (id<ServerProfileViewControllerDelegate>)[rootNavCtl.viewControllers objectAtIndex:0]; //0 is root, ie. the profile list VC aka "master" VC
	[self.navigationController pushViewController:serverProfileVC animated:YES];
}

#pragma mark - MDNSDiscovererDelegate protocol methods
-(void)MDNSDiscovererStartedSearch:(MDNSDiscoverer *)discoverer {
    [self startSpinnerWithWaitText:NSLocalizedString(@"Searching...", @"Discovery Spinner Text")];
    self.navigationItem.rightBarButtonItem.enabled = NO;    //Disable button once search initiated
}

-(void)MDNSDiscoverer:(MDNSDiscoverer *)discoverer completedSearch:(NSArray *)searchResults {
    [self stopSpinner];
    self.navigationItem.rightBarButtonItem.enabled = YES;     //Reenable button once search finished
    //Parse results and reload table
    if (searchResults.count > 0) {
        self.searchResults = [searchResults mutableCopy];
        [self.tableView reloadData];
    }
}

-(void)MDNSDiscoverer:(MDNSDiscoverer *)discoverer failedSearch:(NSError *)error {
    DLog(@"Failed search, error: %@", [error localizedDescription]);
    [self stopSpinner];
    self.navigationItem.rightBarButtonItem.enabled = YES;     //Reenable button once search finished
    [self.tableView reloadData];
}

@end
