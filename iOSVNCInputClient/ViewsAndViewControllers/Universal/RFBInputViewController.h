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

@interface RFBInputViewController : UIViewController
//Server to establish communication with
//iOS 7 (?) property behaviour change from 5.1; if set to weak does not retain pointer set to an ivar
@property (strong,nonatomic) ServerProfile *serverProfile;

//Exposed for subclass
@property (weak, nonatomic) IBOutlet UITextView *helpTextView;
@end
