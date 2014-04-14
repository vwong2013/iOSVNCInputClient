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

#import "ServerProfileViewController.h"

#import "UILabel+MultiLineAutoSize.h" //UILabel text resizing
#import "UIViewController+Spinner.h" //Wait spinning animation

#import "ErrorHandlingMacros.h"

//Need to import the view controller header to transition to via segue
#import "MasterViewController.h"

#import "ServerProfile.h"
#import "ServerProfile+Probe.h"

#import "BDHost.h"
#import "ProfileSaverFetcher.h"
#import "VersionMsg.h"
#import "RFBSecurityNone.h"

//TextField Delegate for controlling auto-dismissal of keyboard.  Requires TextField's Delegate to be set to the VC!
@interface ServerProfileViewController () <UITextFieldDelegate>
@property (assign, nonatomic) BOOL fieldChanged; //Track field changes
@property (assign, nonatomic) BOOL successfulSecurityProbe, successfulAuthProbe; //Track state of probe checks
@end

@implementation ServerProfileViewController
#pragma mark - Inits, view load
//Init override.  Gets called everytime Segue pushes VC
-(id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
	if (self) {
		_serverProfile =  [[ServerProfile alloc] init]; //Init profile object for storing connection details
        _successfulAuthProbe = NO;
        _successfulSecurityProbe = NO;
	}
	
	return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    //Set scrollView content size
    [self refreshScrollViewContentSize];
    
	//Keyboard Management, ie. make fields accessible when keyboard overlaps view
	[self registerForKeyboardNotifications];
	//Dismiss Keyboard when touch outside textfield in ScrollView
	[self registerTapGestureForKBDismiss];
	
	//Disable Username, Password, Switches, Connect button on view load IF not in Edit mode (ie. no URL supplied with profile)
	if (!self.savedURL) {
		[self disableUsernameFields];
		[self disableMacARDSwitches];
		[self disableConnectButton];
		self.serverProfileDetailsNavigationBar.title = NSLocalizedString(@"Add Server", @"ServerProfileVC Add Server Nav Bar Title");
        //Check propertys present in profile, initiate address/port check straightaway if present.
        if (self.serverProfile.address.length > 0 && self.serverProfile.port > 0) {
            [self textFieldSetupFromProfile:self.serverProfile];            
            [self checkAddressPortAndProbeServerProfile:self.serverProfile];
        }
	} else {
		self.serverProfileDetailsNavigationBar.title = NSLocalizedString(@"Edit Server", @"ServerProfileVC Edit Server Nav Bar Title");
		[self textFieldSetupFromProfile:self.serverProfile];
	}
	
	//Hide errorLabel if present
	self.errorLabel.hidden = YES;
}

- (void)viewDidUnload {  
	[self setErrorLabel:nil];
	[self setServerProfileDetailsNavigationBar:nil];
	[self setScrollView:nil];
	
	[self deregisterForKeyboardNotifications];
	
	[super viewDidUnload];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)dealloc {
    DLogInf(@"ServerProfileVC dealloc!");
}

#pragma mark - Orientation view control methods
- (void)refreshScrollViewContentSize {
    //Update contentSize of scroll view to accomodate for rotation changes
    UIView *contentView = [self.scrollView.subviews objectAtIndex:0]; //Should be the view holding all the labels etc
    self.scrollView.contentSize = contentView.frame.size;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    [self refreshScrollViewContentSize];
    [self refreshSpinnerPosition];
}

#pragma mark - Scene transitions
//Method to be called when Save button is pressed
-(void)saveProfileButtonClicked {
	[self handleDisplayErrors:nil];
	
    [self startSpinnerWithWaitText:NSLocalizedString(@"Saving...", @"ServerProfileVC Save Profile Spinner Text")];
	//Should have "complete" profile details by the time Save Profile button is pressed
	//Save successfully probed profile to plist
    //self.strongDelegate = self.delegate;
    __weak ServerProfileViewController *blockSafeSelf = self;
    dispatch_queue_t saveQueue = dispatch_queue_create("saveQueue", NULL);
    dispatch_async(saveQueue, ^ {
        NSError *error = nil;
        BOOL saved = [ProfileSaverFetcher saveServerProfile:blockSafeSelf.serverProfile
                                                ToURL:self.savedURL
                                                Error:&error];
        [blockSafeSelf stopSpinner];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            //Warning if profile is duplicate or save failed, stop transition
            if (!saved || error) {
                //Unhide warning label and populate with error message
                if ([error code] == FileDuplicateError)
                    [blockSafeSelf handleDisplayErrors:[error localizedDescription]];
                else
                    [blockSafeSelf handleDisplayErrors:NSLocalizedString(@"Error encountered during profile save.  Refer to Logs",@"ServerProfileVC Profile Save Error Text")];
                DLogErr(@"Error: failed to save details into profile file: %@", [error localizedDescription]);
                return; //stop method early
            }
            
            //Transition to next scene if successful, and tell next scene to reload tableview data
            if (blockSafeSelf.delegate) { //????: Use notifications to tell profile list to reload instead?
                [blockSafeSelf.delegate serverProfileViewControllerSaveSuccessful:blockSafeSelf];
                //blockSafeSelf.delegate = nil; //release after use as property is strong.
            }
            //Pop VC back to root VC
            [blockSafeSelf.navigationController popToRootViewControllerAnimated:YES];
        });
    });
    dispatch_release(saveQueue);
}

#pragma mark - ServerProfile VC behaviour change Methods
-(void)textFieldSetupFromProfile:(ServerProfile *)profile {
    if (profile.username.length > 0)
        self.UsernameField.text = profile.username;
    if (profile.password.length > 0)
        self.PasswordField.text = profile.password;
    if (profile.serverName.length > 0)
        self.ServerNameField.text = profile.serverName;
    if (profile.address.length > 0)
        self.ServerAddressField.text = profile.address;
    if (profile.ard35Compatibility)
        self.ard35CompatSwitch.on = profile.ard35Compatibility;
    if (profile.macAuthentication)
        self.macAuthSwitch.on = profile.macAuthentication;
}

#pragma mark - Field change capture for subclasses to use
//Capture when certain fields are being / have been edited
- (void)captureFieldChanged {
	if (!self.fieldChanged) //Change from NO to YES if set to NO
		self.fieldChanged = YES;
	
	//hide Error label when value is being edited
	[self handleDisplayErrors:nil];
}

//Populate Profile object fields as they're completed or modified
- (void)captureAddressEditingEnd:(UITextField *)sender {
	if (self.fieldChanged && ![self zeroLengthAfterTrimmingWhiteSpace:sender.text] && ![self zeroLengthAfterTrimmingWhiteSpace:self.PortNumberField.text]) {
		self.fieldChanged = NO; //Reset flag prop
		
		self.serverProfile.address = sender.text;
		self.serverProfile.port = [self.PortNumberField.text intValue];
		self.successfulSecurityProbe = NO; //Reset validity check everytime field is edited
		[self checkAddressPortAndProbeServerProfile:self.serverProfile];
	}
}

- (void)capturePortEditingEnd:(UITextField *)sender {
	if (self.fieldChanged && ![self zeroLengthAfterTrimmingWhiteSpace:sender.text] && ![self zeroLengthAfterTrimmingWhiteSpace:self.ServerAddressField.text]) {
		self.fieldChanged = NO; //Reset flag prop
		
		self.serverProfile.address = self.ServerAddressField.text;
		self.serverProfile.port = [sender.text intValue];
		self.successfulSecurityProbe = NO; //Reset validity check everytime field is edited
		[self checkAddressPortAndProbeServerProfile:self.serverProfile];
	}
}

//Server Profile name
- (void)captureNameEditingEnd:(UITextField *)sender {
	//ServerName is optional, not required for probe
	//Ignore blank strings or strings with only whitespaces
	if (![self zeroLengthAfterTrimmingWhiteSpace:sender.text])
		self.serverProfile.serverName = self.ServerNameField.text;
}

//username, password field changes
- (void)captureUsernameEditingEnd:(UITextField *)sender {
	//Ignore blank strings or strings with only whitespaces
	if (![self zeroLengthAfterTrimmingWhiteSpace:sender.text])
		self.serverProfile.username = self.UsernameField.text;
	
	//Break method if mac auth and password field empty
	if (self.serverProfile.macAuthentication && self.PasswordField.text.length == 0)
		return;
	
	//Probe again, this time with username and password details (checks done in next method)
	if (self.fieldChanged && self.successfulSecurityProbe) {
		self.fieldChanged = NO; //Reset flag prop
		
		self.successfulAuthProbe = NO;
		[self checkUsernamePwdAndProbeServerProfile:self.serverProfile];
	}
}

- (void)capturePasswordEditingEnd:(UITextField *)sender {
	//Ignore blank strings or strings with only whitespaces
	if (![self zeroLengthAfterTrimmingWhiteSpace:sender.text])
		self.serverProfile.password = self.PasswordField.text;
	
	//Break method if mac auth and username field empty
	if (self.serverProfile.macAuthentication && self.UsernameField.text.length == 0)
		return;
	
	//Probe, either with a password or a blank one (for "None" security)
	if (self.successfulSecurityProbe) {
		self.fieldChanged = NO; //Reset flag prop
		
		self.successfulAuthProbe = NO;
		[self checkUsernamePwdAndProbeServerProfile:self.serverProfile];
	}
}

//Covers flicking of the ard35 and macAuth switches
- (void)captureARDSwitch {
	self.serverProfile.ard35Compatibility = self.ard35CompatSwitch.on;
}

- (void)captureMacAuthSwitch:(UISwitch *)sender {
    DLog(@"macAuth: %i", sender.on);
	self.serverProfile.macAuthentication = sender.on;
    if (self.serverProfile.macAuthentication)
        [self enableUsernameFields];
    else
        [self disableUsernameFields];
}

//Disable username field
-(void)disableUsernameFields {
	self.UsernameField.enabled = FALSE;
    self.UsernameField.alpha = 0.5;
}

//Enable username field
-(void)enableUsernameFields {
	self.UsernameField.enabled = TRUE;
    self.UsernameField.alpha = 1.0;
}

//Enable Connect button
-(void)enableConnectButton {
	self.ConnectBtn.enabled = TRUE;
}

//Disable Connect button until username and password check out fine
-(void)disableConnectButton {
	self.ConnectBtn.enabled = FALSE;
}

//Disable Mac auth and compatibility switches
-(void)disableMacARDSwitches {
	self.macAuthSwitch.enabled = FALSE;
	self.ard35CompatSwitch.enabled = FALSE;
}

//Enable Mac auth and compatibility switches
-(void)enableMacARDSwitches {
	self.macAuthSwitch.enabled = TRUE;
	self.ard35CompatSwitch.enabled = TRUE;
}

#pragma mark - Text management
//Check for fields that are nothing but spaces / tabs
-(BOOL)zeroLengthAfterTrimmingWhiteSpace:(NSString *)text {
	NSString *temp = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	if (temp.length == 0)
		return YES;
	return NO;
}

#pragma mark - Error Handling
//Handle whether error label needs to be displayed or not, + error msg if any
-(void)handleDisplayErrors:(NSString *)errorText {
	self.errorLabel.hidden = YES;
	if (errorText && errorText.length > 0) {
		self.errorLabel.text = errorText;
		[self.errorLabel adjustFontSizeToFit];
		self.errorLabel.hidden = NO;
        //Force focus on error msg
        [self.scrollView scrollRectToVisible:self.errorLabel.frame
                                    animated:YES];
	}
}

#pragma mark - Connectivity Methods
//Probe security method
-(void)probe {
    [self startSpinnerWithWaitText:NSLocalizedString(@"Probing Server...", @"ServerProfileVC Details Probe Spinner Text")];
    
    __weak ServerProfileViewController *blockSafeSelf = self;
    __block NSDictionary *probeResults;
    __block NSError *error = nil;
    dispatch_queue_t probeQueue = dispatch_queue_create("probeQueue", NULL);
    dispatch_async(probeQueue, ^{
        if (!blockSafeSelf.successfulSecurityProbe)
            probeResults = [ServerProfile probeServerProfile:blockSafeSelf.serverProfile
                                       ProbeType:ProbeSecurity
                                           Error:&error];
        else if (!blockSafeSelf.successfulAuthProbe)
            probeResults = [ServerProfile probeServerProfile:blockSafeSelf.serverProfile
                                       ProbeType:ProbeAuth
                                           Error:&error];
        
        //Parse probe results and stop spinner in main queue after results are returned
		dispatch_async(dispatch_get_main_queue(), ^{
			[blockSafeSelf stopSpinner];
            
            if (!probeResults || !probeResults.count == ProbeResultFieldCount) {
                //Display Error Message
                NSString *header = NSLocalizedString(@"Connection Error: ", @"ServerProfileVC Connection Error Header Text");
                [blockSafeSelf handleDisplayErrors:[NSString stringWithFormat:@"%@ %@", header,[error localizedDescription]]];
                DLogErr(@"Error: Probe problem - %@", [error localizedDescription]);
                return; //break early
            }
            
            ServerProfile *probeProfile = [probeResults objectForKey:ProbeResultKey_ServerProfile];
            if (!probeProfile) {
                [blockSafeSelf handleDisplayErrors:NSLocalizedString(@"Could not read probe results for server details", @"ServerProfileVC probe result profile read error text")];
                DLogErr(@"Probe profile read error from probe results, %@", probeProfile);
                return;
            }
            blockSafeSelf.serverProfile = probeProfile;
            
            ProbeType probeType = [[probeResults objectForKey:ProbeResultKey_Type] unsignedIntValue];
            if (probeType != ProbeSecurity && probeType != ProbeAuth) {
                [blockSafeSelf handleDisplayErrors:NSLocalizedString(@"Could not read probe results for probe type", @"ServerProfileVC probe result probe type read error text")];
                DLogErr(@"Probe type read error from probe results, %i", probeType);
                return;
            }
            
            //Populate servername in view if present
            if (blockSafeSelf.serverProfile.serverName.length > 0)
                blockSafeSelf.ServerNameField.text = self.serverProfile.serverName;
            
            if (probeType == ProbeSecurity) {
                //Read probe results, determine available Auth methods and enable various UI bits as required
                VersionMsg *serverVersion = [probeResults objectForKey:ProbeResultKey_SVer];
                if (!serverVersion) {
                    [blockSafeSelf handleDisplayErrors:NSLocalizedString(@"Could not determine server protocol version",@"ServerProfileVC Unidentified Protocol Version Msg Text")];
                    DLogErr(@"No server version from probe results");
                    return; 
                }
                NSArray *securityTypesList = [probeResults objectForKey:ProbeResultKey_SecTypes];
                if (!securityTypesList || securityTypesList.count <= 0) {
                    [blockSafeSelf handleDisplayErrors:NSLocalizedString(@"Could not read probe results for probe type", @"ServerProfileVC probe result probe type read error text")];
                    DLogErr(@"Security type read error from probe results, %@", securityTypesList);
                    return;
                }
                
                [blockSafeSelf disableMacARDSwitches]; //Partially redundant, but required if details edited and server profile probed isn't a Mac
                if ([serverVersion isAppleRemoteDesktop])
                    [blockSafeSelf enableMacARDSwitches];
                
                //Enable Save Profile if "NONE" security supported
                if ([securityTypesList containsObject:[NSNumber numberWithUnsignedChar:[RFBSecurityNone type]]])
                    [blockSafeSelf enableConnectButton];
                
                //Update security probe BOOL state if successful probe
                blockSafeSelf.successfulSecurityProbe = YES;
            } else if (probeType == ProbeAuth) {
                //Update Auth BOOL state if successful probe
                blockSafeSelf.successfulAuthProbe = YES;
                //Call relevant method for enabling Save Profile button
                [blockSafeSelf enableConnectButton];
            }
            
            //Display any warnings that aren't showstoppers if present
            if (error) {
                NSString *header = NSLocalizedString(@"Warning: ", @"ServerProfileVC Warning Header Text");
                [blockSafeSelf handleDisplayErrors:[NSString stringWithFormat:@"%@ %@", header,[error localizedDescription]]];
            }
		});
    });
    dispatch_release(probeQueue);
}

#pragma mark - Server Profile model methods
//2.  Check and Set server address and port fields as soon as both are filled in, return probe results for next stage prep
-(void)checkAddressPortAndProbeServerProfile:(ServerProfile *) serverProfile {
	NSString *addressCheck = [BDHost addressForHostname:serverProfile.address];
	if (addressCheck) {
		//Call Probe Method here
		[self probe];
	} else {
		//Display error message about dodgy ip address
		[self handleDisplayErrors:NSLocalizedString(@"Invalid IP address supplied, cannot start checks",@"ServerProfileVC Invalid Address Msg Text")];
		DLogWar(@"Invalid IP address supplied, cannot start probe");
	}
}

//4. Check username and password is correct if filled in
-(void)checkUsernamePwdAndProbeServerProfile:(ServerProfile *) serverProfile {
	if (self.serverProfile.macAuthentication) {
		if (self.serverProfile.username.length == 0 || self.serverProfile.username.length == 0) {
			//missing username
			[self handleDisplayErrors:NSLocalizedString(@"Username cannot be blank",@"ServerProfileVC Missing Username Msg Text")];
			return;
		}
		if (self.serverProfile.password.length == 0 || self.serverProfile.password.length == 0) {
			//missing password
			[self handleDisplayErrors:NSLocalizedString(@"Password cannot be blank",@"ServerProfileVC Missing Password Msg Text")];
			return;
		}
	}
	
	//Call probe method again here
	[self probe];
}

#pragma mark - Scroll View Keyboard Management
//Dismiss keyboard when touch outside of a textfield in UIScrollView
-(void)registerTapGestureForKBDismiss {
	UITapGestureRecognizer *tapOnce = [[UITapGestureRecognizer alloc] initWithTarget:self
																			  action:@selector(tapOnce)];
	tapOnce.cancelsTouchesInView = NO; //Allow other touches to pass thru to view
	[self.scrollView addGestureRecognizer:tapOnce];
}

-(void)tapOnce {
	[self.view endEditing:YES];
}

//Cleanup of notification registration for below
- (void)deregisterForKeyboardNotifications {
    [[NSNotificationCenter defaultCenter] removeObserver:self
													name:UIKeyboardDidShowNotification
												  object:nil];
	
    [[NSNotificationCenter defaultCenter] removeObserver:self
													name:UIKeyboardWillHideNotification
												  object:nil];
}

/*Code Snippet Adapted From Apple Documentation, "Handling the keyboard notifications" and http://stackoverflow.com/questions/1126726/how-to-make-a-uitextfield-move-up-when-keyboard-is-present
 Changes: Modified for Scroll View, fix for landscape orientation, iOS 7 compatibility*/

// Call this method somewhere in your view controller setup code.
- (void)registerForKeyboardNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(keyboardWasShown:)
												 name:UIKeyboardDidShowNotification object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(keyboardWillBeHidden:)
												 name:UIKeyboardWillHideNotification object:nil];
	
}

// Called when the UIKeyboardDidShowNotification is sent.
- (void)keyboardWasShown:(NSNotification*)aNotification
{
    //Get kb size, adjusting the kb rect for orientation
    NSDictionary* info = [aNotification userInfo];
    CGRect adjKbRect = [self.view convertRect:[[info objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue]
                                     fromView:Nil];
    CGSize kbSize = adjKbRect.size;
    
    //iOS 7 fullscreen layout compatibility
    CGFloat topEdge = 0.0;
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0)
        topEdge = self.topLayoutGuide.length;
    
    UIEdgeInsets contentInsets = UIEdgeInsetsMake(topEdge, 0.0, kbSize.height, 0.0);
    self.scrollView.contentInset = contentInsets;
    self.scrollView.scrollIndicatorInsets = contentInsets;
    
    // If active text field is hidden by keyboard, scroll it so it's visible.  Must have contentSize set when used with a scrollView to function properly
    //Subtract status bar and navigation bar height to get view frame size
    CGRect aRect = self.view.frame;
    aRect.size.height -= kbSize.height;
    
	CGPoint origin = self.activeTextField.frame.origin;
	origin.y += self.activeTextField.frame.size.height; //Add height of field to origin to allow fields partially overlapping to scroll properly
	origin.y -= self.scrollView.contentOffset.y;	//take into account offset for when scrollview may have scrolled
    
    if (!CGRectContainsPoint(aRect, origin) ) {
        [self.scrollView scrollRectToVisible:self.activeTextField.frame
                                    animated:YES];
    }
}

// Called when the UIKeyboardWillHideNotification is sent
- (void)keyboardWillBeHidden:(NSNotification*)aNotification
{
    UIEdgeInsets contentInsets = UIEdgeInsetsZero;
    
    //iOS 7 fullscreen layout compatibility
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0)
        contentInsets = UIEdgeInsetsMake(self.topLayoutGuide.length, 0, 0, 0);
    
    self.scrollView.contentInset = contentInsets;
    self.scrollView.scrollIndicatorInsets = contentInsets;
	//Reset contentsize to scrollView's 'primary' subview frame size after keyboard hides to avoid unnecessary scrolling
    [self refreshScrollViewContentSize];
}

#pragma mark - UITextFieldDelegate Protocol methods
//Keyboard Management - set which textfield is the active one
-(void)textFieldDidBeginEditing:(UITextField *)textField {
	self.activeTextField = textField;
}

-(void)textFieldDidEndEditing:(UITextField *)textField {
	self.activeTextField = nil;
}

/*End Code Snippet*/

-(BOOL)textFieldShouldReturn:(UITextField *)textField {
	//Dismiss keyboard
	[textField resignFirstResponder];

	return YES;
}
@end
