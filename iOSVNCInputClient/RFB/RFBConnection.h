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

#import <Foundation/Foundation.h>

@class RFBSecurity, VersionMsg, RFBEvent;

@interface RFBConnection : NSObject
#pragma mark - Properties - Public
@property (nonatomic, assign) BOOL ard35Compatibility;

#pragma mark - Getters
-(NSString *)serverName;
-(VersionMsg *)serverVersion;
-(NSData *)securityTypes;
-(NSArray *)securityTypesList;
-(CGSize)serverDisplaySize;

#pragma mark - Static defined values - Public
+ (int)DEFAULT_PORT;

#pragma mark - Init Methods - Public
//Handles both ip addresses and host names
-(id)initWithHostname:(NSString*)address Port:(int)port Password:(NSString *)password;
-(id)initWithHostname:(NSString *)address Password:(NSString *)password;
-(id)initWithHostname:(NSString *)address;
-(id)initWithHostname:(NSString *)address Port:(int)port Security:(RFBSecurity *)security;
-(id)initWithHostname:(NSString *)address Security:(RFBSecurity *)security;

#pragma mark - Connectivity - Public
-(BOOL)isConnected;
-(BOOL)probeSecurity:(NSError **)error;
-(BOOL)connect:(NSError **)error;
-(void)disconnect;

#pragma mark - RFB Event handling - Public
-(BOOL)sendEvent:(RFBEvent *)event Error:(NSError **)error;

#pragma mark - Read Methods - Public
-(void)discardIncomingData;
@end
