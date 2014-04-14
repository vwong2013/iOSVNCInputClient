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

#import "ServerProfile.h"

@interface ServerProfile() <NSCopying>

@end

@implementation ServerProfile
#pragma mark - init methods
-(id)init {
	return [self initWithAddress:@""
							Port:5900
						Username:@""
						Password:@""
					  ServerName:@""
				   ServerVersion:@""
						   ARD35:NO
						 MacAuth:NO];
}

-(id)initWithAddress:(NSString *)address Port:(int)port Username:(NSString *)username Password:(NSString *)password ServerName:(NSString *)serverName ServerVersion:(NSString *)serverVersion ARD35:(BOOL)ard35 MacAuth:(BOOL)macAuth {
	if ((self = [super init])) {
		_address = address;
		_port = port;
		_ard35Compatibility = ard35;
		_macAuthentication = macAuth;
		_serverName = serverName;
		_serverVersion = serverVersion;
		_password = password;
		_username = username;
	}
	
	return self;
}

#pragma mark - object comparison methods
//Hash method NSObject override - hash the address, port, username, password
-(NSUInteger)hash {
	NSUInteger prime = 31;
	NSUInteger result = 1;
	result = prime * result + ((self.address == nil) ? 0 : [self.address hash]);
	result = prime * result + ((self.username == nil) ? 0 : [self.username hash]);
	result = prime * result + ((self.password == nil) ? 0 : [self.password hash]);
	result = prime * result + self.port;
	return result;
}

//Override isEqual - compare address, port, username, password
-(BOOL)isEqual:(id)obj {
	if (!obj)
		return NO;
	if ([[self class] isSubclassOfClass: [obj class]]) //subclass or identical class comparison, apparently
		return NO;
	
    //Compare attributes
	ServerProfile *other = (ServerProfile *) obj;
	if ([obj respondsToSelector:NSSelectorFromString(@"setPort:")]) { //if property present, setPort method will be
		if (self.port != other.port)
			return NO;
	} else
		return NO;
	
	if ([obj respondsToSelector:NSSelectorFromString(@"setAddress:")]) {
		if (self.address == nil) {
			if (other.address != nil)
				return NO;
		} else if (![self.address isEqualToString:other.address])
			return NO;
	} else
		return NO;
    
    if ([obj respondsToSelector:NSSelectorFromString(@"setPassword:")]) {
		if (self.password == nil) {
			if (other.password != nil)
				return NO;
		} else if (![self.password isEqualToString:other.password])
			return NO;
	} else
		return NO;
    
    if ([obj respondsToSelector:NSSelectorFromString(@"setUsername:")]) {
		if (self.username == nil) {
			if (other.username != nil)
				return NO;
		} else if (![self.username isEqualToString:other.username])
			return NO;
	} else
		return NO;
	
	return YES;
}

#pragma mark - NSCopying protocol method
-(id)copyWithZone:(NSZone *)zone {
    ServerProfile *spCopy = [[[self class] allocWithZone:zone] initWithAddress:self.address
                                                                          Port:self.port
                                                                      Username:self.username
                                                                      Password:self.password
                                                                    ServerName:self.serverName
                                                                 ServerVersion:self.serverVersion
                                                                         ARD35:self.ard35Compatibility
                                                                       MacAuth:self.macAuthentication];
    return spCopy;
}
@end
