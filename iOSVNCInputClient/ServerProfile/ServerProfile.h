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
#import "VersionMsg.h"

@interface ServerProfile : NSObject
@property (copy, nonatomic) NSString *address;
@property (nonatomic, assign) int port;
@property (nonatomic, copy) NSString *serverName;
@property (nonatomic, copy) NSString *serverVersion;
@property (nonatomic, copy) NSString *username;
@property (nonatomic, copy) NSString *password;
@property (nonatomic, assign) BOOL ard35Compatibility;
@property (nonatomic, assign) BOOL macAuthentication;

#pragma mark - public methods
-(id)init;
-(id)initWithAddress:(NSString *)address Port:(int)port Username:(NSString *)username Password:(NSString *)password ServerName:(NSString *)serverName ServerVersion:(NSString *)serverVersion ARD35:(BOOL)ard35 MacAuth:(BOOL)macAuth;

-(NSUInteger)hash;
-(BOOL)isEqual:(id)obj;

@end
