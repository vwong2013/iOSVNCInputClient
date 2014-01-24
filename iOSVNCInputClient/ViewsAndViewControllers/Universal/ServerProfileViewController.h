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

#import <UIKit/UIKit.h>

@class ServerProfile;
@protocol ServerProfileViewControllerDelegate;

@interface ServerProfileViewController : UIViewController
@property (strong, nonatomic) NSURL *savedURL; //Indicates profile is a saved one that needs editing
@property (strong, nonatomic) ServerProfile *serverProfile; //profile property for probing and saving

@property (weak, nonatomic) id<ServerProfileViewControllerDelegate> delegate; //Delegate pointer

//Exposed for subclass to override for Storyboard connections...
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

//Exposed for subclasses to process user input
-(void)saveProfileButtonClicked;
-(void)captureFieldChanged;
-(void)captureAddressEditingEnd:(UITextField *)sender;
-(void)capturePortEditingEnd:(UITextField *)sender;
-(void)captureNameEditingEnd:(UITextField *)sender;
-(void)captureUsernameEditingEnd:(UITextField *)sender;
-(void)capturePasswordEditingEnd:(UITextField *)sender;
-(void)captureARDSwitch;
-(void)captureMacAuthSwitch:(UISwitch *)sender;
@end

#pragma mark - Protocol definition
@protocol ServerProfileViewControllerDelegate <NSObject>

//Profile Saved successfully
-(void)serverProfileViewControllerSaveSuccessful:(ServerProfileViewController *)serverProfileVC;

@end