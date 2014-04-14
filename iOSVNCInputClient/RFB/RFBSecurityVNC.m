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

#import "RFBSecurityVNC.h"
#import "RFBSocket.h"
#import "VersionMsg.h"

#import "Des.h"

#import "HandleErrors.h"

#define SECURITY__VNCAUTH 2
#define RFBNAME @"VNC Authentication"
#define VNCAuthChallengeLength 16

@interface RFBSecurityVNC()
@property (copy,nonatomic) NSString *password;
@end

@implementation RFBSecurityVNC
//override of abstract superclass
- (id)init {
	return [self initWithPassword:nil];
}

- (id)initWithPassword:(NSString *)password {
	self = [super init];
	if (self) {
		if (password && password.length > 0)
			_password = password;
		else
			_password = @"";
	}
	return self;
}

-(void)dealloc {
    DLogInf(@"RFBSecVnc dealloc");
}

+ (uint8_t)type {
	return SECURITY__VNCAUTH;
}

+ (NSString *)typeName {
	return RFBNAME;
}

- (BOOL)performAuthWithSocket:(RFBSocket *)socket ForVersion:(VersionMsg *)serverVersion Error:(NSError **)error {
	if ([socket isDisconnected])
		return NO;
	
	NSData *challenge = [socket readReceived:VNCAuthChallengeLength];
	NSData *response = [Des encryptChallenge:challenge
                                  withPassword:self.password];

    //Error handling block
	HandleError he = [HandleErrors handleErrorBlock];
    
	//Abort if invalid response
	if (response.length == 0) {
        DLogErr(@"RFBSecurityVNC - could not generate response with supplied challenge and password");
        he(error, SecurityErrorDomain, SecurityEncryptError, NSLocalizedString(@"VNC Auth negotiation failed - unable to generate response", @"RFBSecurityVNC response generation error text"));
		return NO;
    }
	
    DLogInf(@"VNC Auth Response Sending");
	[socket writeBytes:response];
    
    //Read SecurityResult
    if ([socket readSecurityResult] == 1) { // failure
        int version = [serverVersion intValue];
        if (version >= MAX_VERSION) {//3.8+ auth failure behaviour
            NSString *header = NSLocalizedString(@"Security handshake with server failed, reason:  ", @"VNC Security 3.8+ Handshake Failed Header Error Text");
            he(error,SocketErrorDomain,SocketConnectError,[header stringByAppendingString:[socket readString]]);
        } else //Version 3.3 and 3.7 auth failure behaviour
            he(error,SocketErrorDomain,SocketConnectError,NSLocalizedString(@"Security handshake with server failed. Incorrect username and password?", @"VNC Security 3.3 3.7 Handshake Failed Error Text"));
        return NO;
    }
	
	return YES;
}
@end
