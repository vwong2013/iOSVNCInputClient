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

#import "MasterViewController.h"

//Table data structure for profiles
#import "TableRowDetails.h"

//Scene transitions
#import "ServerProfileViewController.h"
#import "RFBInputViewController.h"

//Loading/Saving
#import "ProfileSaverFetcher.h"
#import "ServerProfile.h"

//Error handling
#import "HandleErrors.h"
#import "ErrorHandlingMacros.h"

//++++++Macros+++++++
#define SAVED_PROFILE_CELL_TEXTS @"profileTexts"
#define SAVED_PROFILE_CELL_URLS @"profileURLs"

#define SEGUE_ADD_PROFILE @"addServerProfile"

@interface MasterViewController () <ServerProfileViewControllerDelegate>
@property (weak, nonatomic) IBOutlet UILabel *errorLabel;

@property (assign,nonatomic) BOOL firstRun;
@property (strong,nonatomic) NSArray *tableSectionTitles, *tableSectionFooters;
@property (strong,nonatomic) NSArray *sectionsRows;
@property (strong,nonatomic) NSArray *editableSections;
@property (assign,nonatomic) BOOL tableNeedsReload;

//Stores table view text and url sub dict (internal objects are mutable though)
@property (strong,nonatomic) NSDictionary *savedServerProfiles;

//Store error handling block
@property (assign,nonatomic) HandleError handleError;
@end

@implementation MasterViewController
#pragma mark - View Controller Method Overrides
//Designated init for VC's in SB's apparently...
- (id)initWithCoder:(NSCoder *)aDecoder	{
    self = [super initWithCoder:aDecoder];
	if (self) {
		_tableNeedsReload = YES;
		_firstRun = YES;
		_handleError = [HandleErrors handleErrorBlock];
	}
	
	return self;
}

-(void)dealloc {
    DLogInf(@"MasterVC dealloc");
}

//Triggers every time view about to re-appear
-(void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	
    //Set navigation bar title
    self.title = NSLocalizedString(@"iOSVNCInputClient",@"MainVC Nav Bar Application Title Text");
    
	//Setup section headers and editability.  These don't change after view is loaded
	if (self.firstRun) {
		self.tableSectionTitles = [self tableSectionTitlesSetup];
		self.editableSections = [self editableSectionsSetup];
		self.firstRun = NO;
	}
	
	//Setup table view.  Reload table data when delegatee indicates new profile added
	[self reloadTableCellsIfRequired];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
	//Allow selection during editing to bring user to Edit view for profile
	self.tableView.allowsSelectionDuringEditing = YES;
	
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    self.navigationItem.rightBarButtonItem = self.editButtonItem;
	//Handle display of help msg when edit is enabled
	[self.editButtonItem setAction:@selector(editButtonPressed:)];
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
    self.tableSectionFooters = nil;
    self.tableSectionTitles = nil;
    self.sectionsRows = nil;
    self.editableSections = nil;
}

- (void)viewDidUnload {
	[self setErrorLabel:nil];
	[super viewDidUnload];
}

#pragma mark - Error Handling
//Blank string = hide label
-(void)displayError:(NSString *)error {
	self.errorLabel.hidden = YES;
	if (error && error.length > 0) {
		self.errorLabel.hidden = NO;
		self.errorLabel.text = error;
        [self.tableView setContentOffset:CGPointMake(0, 0) animated:YES];
	}
}

#pragma mark - Table cell manipulation
-(void)deselectSelectedCell {
	NSIndexPath *selectedIndexPath = [self.tableView indexPathForSelectedRow];
	[self.tableView deselectRowAtIndexPath:selectedIndexPath animated:NO];
}

#pragma mark - Table view structure
-(NSArray *)tableSectionTitlesSetup {
	NSMutableArray *sectionTitles = [NSMutableArray new];
	[sectionTitles addObject:NSLocalizedString(@"Create a New Server Profile",@"MainVC Table Action Section Header Text")];
	[sectionTitles addObject:NSLocalizedString(@"Saved Server Profiles",@"MainVC Table Saved Profile List Section Header Text")];
	
	return sectionTitles;
}

//Determine which sections are editable
-(NSArray *)editableSectionsSetup {
	NSMutableArray *editableSections = [NSMutableArray new];
	[editableSections addObject:@NO];
	[editableSections addObject:@YES];
	
	return editableSections;
}

//CellId is preconfigured in SB
-(NSArray *)tableSectionRowsSetup {
	NSMutableArray *sectionRows = [NSMutableArray new];
	//Static menu
	NSMutableArray *section0 = [NSMutableArray new];
	TableRowDetails *addServerRow = [[TableRowDetails alloc] initWithCellId:@"AddServerCell" Title:NSLocalizedString(@"Add VNC Server Profile...",@"MainVC Add Profile Table Cell Text") Subtitle:nil];
	TableRowDetails *discoveryRow = [[TableRowDetails alloc] initWithCellId:@"DiscoveryCell" Title:NSLocalizedString(@"Search for VNC Servers...", @"MainVC Search Profile Table Cell Text") Subtitle:nil];
	[section0 addObjectsFromArray:@[addServerRow,discoveryRow]];
	
	//Dynamic menu
	NSMutableArray *section1 = [self.savedServerProfiles objectForKey:SAVED_PROFILE_CELL_TEXTS];
		
	//Pull together sections and rows
	[sectionRows addObjectsFromArray:@[section0,section1]];
	return sectionRows;
}

//Reload table if required
-(void)reloadTableCellsIfRequired {
	if (self.tableNeedsReload) {
		self.savedServerProfiles = [self loadAllSavedProfileCellDetails];
		self.sectionsRows = [self tableSectionRowsSetup];
		
		//Disable Edit Button in Nav Bar if Saved Profiles section is empty
		if([[self.sectionsRows objectAtIndex:1] count] == 0)
			self.editButtonItem.enabled = NO;
        else
            self.editButtonItem.enabled = YES;
		
		[self.tableView reloadData]; //Required for re-rendering of tableView with new profiles.  Also conveniently clears button
		self.tableNeedsReload = NO;
	}
}

#pragma mark - Table Server Profile Cells Data Management
-(NSDictionary *)loadAllSavedProfileCellDetails {
	//Read dir for existing saved profiles
	__block NSError *error = nil;
	NSMutableArray *savedProfileURLs = [[ProfileSaverFetcher fetchSavedProfilesURLList:&error] mutableCopy];
	if (!savedProfileURLs) {
		if (error)
			DLogErr(@"Failed to retrieve list of saved Profiles, %@", [error localizedDescription]);
		return nil;
	}
	
	//Parse url array for labels needed
	__block NSMutableArray *savedProfileCellLabels = [NSMutableArray arrayWithCapacity:savedProfileURLs.count];
	[savedProfileURLs enumerateObjectsUsingBlock:^(NSURL *url, NSUInteger idx, BOOL *stop) {
		NSDictionary *urlResources;
		if (url) {
			//Extract title and subtitle for display
			urlResources = [ProfileSaverFetcher fetchTitleAndSubtitleFromURL:url];
			if (urlResources) {
				[savedProfileCellLabels addObject:[[TableRowDetails alloc] initWithCellId:@"ServerProfileCell"
																				Title:[urlResources objectForKey:PROFILE_TITLE_KEY]
																			 Subtitle:[urlResources objectForKey:PROFILE_SUBTITLE_KEY]]];
			}
		}
		if (!url || !urlResources) {
			//Save down invalid URL marker label
			[savedProfileCellLabels addObject:[[TableRowDetails alloc] initWithCellId:@"ServerProfileCell" Title:NSLocalizedString(@"Failed Saved Profile Path Read",@"MainVC Table Saved Profile Display Err Text") Subtitle:nil]];
		}
	}];
	
	//URL list count should match created labels count
	if (savedProfileURLs.count != savedProfileCellLabels.count) {
		DLogErr(@"Retrieved Profile URL list count %lu not equal to created labels: %lu", (unsigned long) savedProfileURLs.count, (unsigned long)savedProfileCellLabels.count);
		return nil;
	}
	
	//Assemble dictionary
	NSDictionary *savedProfileCellDetails = @{SAVED_PROFILE_CELL_TEXTS:savedProfileCellLabels, SAVED_PROFILE_CELL_URLS:savedProfileURLs};
	
	//Return dict
	return savedProfileCellDetails;
}

//Retrieve profile URL
-(NSURL *)loadSavedProfileCellURLFromRow:(NSUInteger)row Error:(NSError **)error {
	//Retrieve profile URL
	NSArray *profileURLs = [self.savedServerProfiles objectForKey:SAVED_PROFILE_CELL_URLS];
	NSURL *profileURL = [profileURLs objectAtIndex:row];
	
	if (!profileURL) {
		self.handleError(error, ObjectErrorDomain, ObjectNotFoundError, [NSString stringWithFormat:@"No profile URL at row %lu", (unsigned long)row]);
		return nil;
	}

    return profileURL;
}

//Remove selected profile from table (and storage)
-(BOOL)deleteProfileAtRow:(uint)row Error:(NSError **)error {
	NSMutableArray *profileURLs = [self.savedServerProfiles objectForKey:SAVED_PROFILE_CELL_URLS];
	NSMutableArray *profileTexts = [self.savedServerProfiles objectForKey:SAVED_PROFILE_CELL_TEXTS];
	
	//Attempt removal from storage
	NSURL *serverProfileToDelete = [profileURLs objectAtIndex:row];
	if (![ProfileSaverFetcher deleteSavedProfileFromURL:serverProfileToDelete
												  Error:error]) {
		return NO;
	}
	
	//Clean up arrays
	[profileURLs removeObjectAtIndex:row];
	[profileTexts removeObjectAtIndex:row];
	
	//????: Needed?
	self.savedServerProfiles = @{SAVED_PROFILE_CELL_TEXTS:profileTexts, SAVED_PROFILE_CELL_URLS:profileURLs};
	
	return YES;
}

#pragma mark - Table view data source - delegate methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return self.tableSectionTitles.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	
	// Return section titles IF there are rows for it
    if ([[self.sectionsRows objectAtIndex:section] count] == 0)
        return nil;
	return [self.tableSectionTitles objectAtIndex:section];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	// Return number of rows to be displayed per section
	return [[self.sectionsRows objectAtIndex:section] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	//Retrieve section and row details
	uint section = (uint)indexPath.section;
	uint row = (uint)indexPath.row;
	NSArray *sectionDetails = [self.sectionsRows objectAtIndex:section];
	TableRowDetails *rowDetails = [sectionDetails objectAtIndex:row];
	
    //FIXME: Update rowDetails class so don't need to use generic cell
	// Configure the cell...
	UITableViewCell *cell =  [tableView dequeueReusableCellWithIdentifier:rowDetails.cellId];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:rowDetails.uitvcs reuseIdentifier:rowDetails.cellId];
	cell.textLabel.text = rowDetails.title;
	if (rowDetails.uitvcs == UITableViewCellStyleSubtitle)
		cell.detailTextLabel.text = rowDetails.subtitle;
	
	return cell;
}

#pragma mark - Table Edit Button methods 
//Control display of edit info (edit button doesn't trigger tableView delegate methods)
-(IBAction)editButtonPressed:(UIBarButtonItem *)sender {
	if (!self.tableView.editing) { //"Edit" pressed
		[self tableEditingStart];
	} else { //"DONE" pressed
		[self tableEditingDone];
	}
}

-(void)tableEditingStart {
	[self.tableView setEditing:YES animated:YES];
	self.editButtonItem.title = NSLocalizedString(@"Done", @"MainVC table edit button done title");
	self.errorLabel.hidden = NO;
	self.errorLabel.text = NSLocalizedString(@"Tap Profile to Edit Connection Details", @"MainVC table edit footer title");
}

-(void)tableEditingDone {
	[self.tableView setEditing:NO animated:YES];
	self.editButtonItem.title = NSLocalizedString(@"Edit", @"MainVC table edit button edit title");
	self.errorLabel.hidden = YES;
	self.errorLabel.text = nil;
}

#pragma mark - Table cell row selection - delegate methods
//Load selected profile in normal and "Edit" view in prep for segue
- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	//Skip the bit below if clicking on "static" cells
	if (indexPath.section == 0)
		return indexPath;
		
	//Retrieve Profile object to pass into Mouse View Controller For Connection to take place
	NSError *error = nil;
	NSURL *loadedProfileURL = [self loadSavedProfileCellURLFromRow:indexPath.row
                                                         Error:&error];
    ServerProfile *loadedProfile = nil;
    if (loadedProfileURL)
        loadedProfile = [ProfileSaverFetcher readSavedProfileFromURL:loadedProfileURL
                                                              Error:&error];
	
	if (error) {
		DLogErr(@"Error: Failed to load profile, Error: %@", [error localizedDescription]);
		[self displayError:NSLocalizedString(@"Failed to load saved profile for connection",@"MainVC Profile Load Error Text")];
		return indexPath; //Stop by returning
	}
	
	//Load relevant scene/view, depending on whether in edit mode or not
	if (tableView.editing) {
		//Loade Profile for Editing
		[self showServerProfileViewWithProfile:loadedProfile WithURL:loadedProfileURL];
	} else {
		//Load Profile for COnnection
		[self showMouseViewWithProfile:loadedProfile];
	}
	
	return indexPath;
}

#pragma mark - Table data editing - delegate methods
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return [[self.editableSections objectAtIndex:indexPath.section] boolValue];
}

/*
// Control display of quick delete
- (void)tableView:(UITableView *)tableView willBeginEditingRowAtIndexPath:(NSIndexPath *)indexPath {

}

- (void)tableView:(UITableView *)tableView didEndEditingRowAtIndexPath:(NSIndexPath *)indexPath {
}
 */

// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
	[self displayError:@""]; //Reset error display if required
    if (editingStyle == UITableViewCellEditingStyleDelete) {
		//Update "profile URL array" first
		NSError *error = nil;
		if (![self deleteProfileAtRow:(uint)indexPath.row
                                Error:&error]) {
			[self displayError:NSLocalizedString(@"Failed to delete saved profile",@"MainVC Profile Delete Error Text")];
			DLogErr(@"Failed to delete profile: %@", [error localizedDescription]);
			return; //stop method early
		}
		
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath]
						 withRowAnimation:UITableViewRowAnimationFade];
    }
}

#pragma mark - ServerProfileViewControllerDelegate Protocol methods
- (void)serverProfileViewControllerSaveSuccessful:(ServerProfileViewController *)serverProfileVC {
	self.tableNeedsReload = YES;
}

#pragma mark - Scene Transition methods
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
	//Reset error label if present previously
	[self displayError:nil];
    //Clear nav bar title before push to force back button in subsequent controller to show just "back"
    self.title = nil;
 
    NSString *segueIdentifier = [segue identifier];
    if ([segueIdentifier isEqualToString:SEGUE_ADD_PROFILE]) {
		//Pass pointer to this VC so next VC can update table needs reload flag if required
		ServerProfileViewController *destinationVC = segue.destinationViewController;
		destinationVC.delegate = self;
        
		if (self.tableView.editing)
			[self tableEditingDone]; //turn off edit mode before transition
	}
}

//Class method for determining correct SB to reference VC transitions
+(NSString *)interfaceIdiomDependentStoryboardName {
    //Alter macro for reference to SB depending on whether iPad or iPhone
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        return @"MainStoryboard_iPad";
    } else { //"default" SB is iPhone
        return @"MainStoryboard_iPhone";
    }
}

//Transition to "Add Profile" in Edit mode
-(void)showServerProfileViewWithProfile:(ServerProfile *)serverProfile WithURL:(NSURL *)profileURL {
	UIStoryboard *sb = [UIStoryboard storyboardWithName:[[self class] interfaceIdiomDependentStoryboardName] bundle:nil];
	ServerProfileViewController *serverProfileVC = [sb instantiateViewControllerWithIdentifier:@"ServerProfileVC"];
	
    if (profileURL && serverProfile) {
        serverProfileVC.savedURL = profileURL;
		serverProfileVC.serverProfile = serverProfile;
		[self tableEditingDone]; //turn off edit mode before transition
	}
    
    serverProfileVC.delegate = self;
    
    [self pushViewController:serverProfileVC];
}

//Transition to "Mouse" input view
-(void)showMouseViewWithProfile:(ServerProfile *)serverProfile {
    //Using SB and VC/IB setup in SB, so must do the below in order for correct V to be also instantiated
	UIStoryboard *sb = [UIStoryboard storyboardWithName:[[self class] interfaceIdiomDependentStoryboardName] bundle:nil];
	RFBInputViewController *mouseVC = [sb instantiateViewControllerWithIdentifier:@"MouseVC"];
	mouseVC.serverProfile = serverProfile;
    
    [self pushViewController:mouseVC];
}

//Common code for navigation controller to push view controllers not using Segue's from this VC
-(void)pushViewController:(UIViewController *)viewController {
    //Check if iOS 7; Set edges to avoid nav bar overlaying view
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0)
        viewController.edgesForExtendedLayout = UIRectEdgeNone;
    
    //Clear nav bar title before push to force back button in subsequent controller to show just "back"
    self.title = nil;
    
	[self.navigationController pushViewController:viewController animated:YES];
}
@end
