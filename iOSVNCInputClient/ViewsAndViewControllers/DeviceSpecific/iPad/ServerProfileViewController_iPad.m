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

#import "ServerProfileViewController_iPad.h"

@interface ServerProfileViewController_iPad ()
//Property outlets for iPad
//For Keyboard Management
@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;
@property (weak,nonatomic) UITextField *activeTextField;
//Need these to extract user entered properties
@property (weak, nonatomic) IBOutlet UITextField *ServerAddressField;
@property (weak, nonatomic) IBOutlet UITextField *PortNumberField;
@property (weak, nonatomic) IBOutlet UITextField *UsernameField;
@property (weak, nonatomic) IBOutlet UITextField *PasswordField;
@property (weak, nonatomic) IBOutlet UITextField *ServerNameField;
@property (weak, nonatomic) IBOutlet UISwitch *ard35CompatSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *macAuthSwitch;
@property (weak, nonatomic) IBOutlet UILabel *errorLabel;
//For enabling/disabling button as necessary
@property (weak, nonatomic) IBOutlet UIBarButtonItem *ConnectBtn;
//Allow dynamic setting of title
@property (weak, nonatomic) IBOutlet UINavigationItem *serverProfileDetailsNavigationBar;
@end

@implementation ServerProfileViewController_iPad
#pragma mark - Scene transitions
- (IBAction)saveProfileButtonPressed:(UIBarButtonItem *)sender {
 [super saveProfileButtonClicked];
}

#pragma mark - Field changes
- (IBAction)fieldChanged:(UITextField *)sender {
    [super captureFieldChanged];
}

- (IBAction)serverAddressEditingDidEnd:(UITextField *)sender {
    [super captureAddressEditingEnd:sender];
}

- (IBAction)portEditingDidEnd:(UITextField *)sender {
    [super capturePortEditingEnd:sender];
}

- (IBAction)serverNameEditingDidEnd:(UITextField *)sender {
    [super captureNameEditingEnd:sender];
}

- (IBAction)usernameFieldEditingDidEnd:(UITextField *)sender {
    [super captureUsernameEditingEnd:sender];
}

- (IBAction)passwordFieldEditingDidEnd:(UITextField *)sender {
    [super capturePasswordEditingEnd:sender];
}

- (IBAction)ardSwitchTouchUpInside:(UISwitch *)sender {
    [super captureARDSwitch];
}

- (IBAction)macAuthSwitchTouchUpInside:(UISwitch *)sender {
    [super captureMacAuthSwitch:sender];
}

@end
