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

#import "RFBSecurityNone.h"
#import "RFBSocket.h"
#import "VersionMsg.h"

#import "HandleErrors.h"

#define SECURITY__NONE 1
#define RFBNAME @"None"

@interface RFBSecurityNone()

@end

@implementation RFBSecurityNone
- (id)init {
	self = [super init];
	if (self) {
		//Do nothing
	}
	return self;
}

+ (uint8_t)type {
	return SECURITY__NONE;
}

+ (NSString *)typeName {
	return RFBNAME;
}

-(void)dealloc {
    DLogInf(@"RFBSecNone dealloc");
}

- (BOOL)performAuthWithSocket:(RFBSocket *)socket ForVersion:(VersionMsg *)serverVersion Error:(NSError **)error {
    //Error handling block
	HandleError he = [HandleErrors handleErrorBlock];
    
    //3.8+ auth behaviour for "None" Security - Read SecurityResult message
    int version = [serverVersion intValue];
    if (version >= MAX_VERSION) {
        if ([socket readSecurityResult] == 1) { // failure - should never happen
            NSString *header = NSLocalizedString(@"Security handshake with server failed, reason:  ", @"None Security 3.8+ Handshake Failed Header Error Text");
            he(error,SocketErrorDomain,SocketConnectError,[header stringByAppendingString:[socket readString]]);
            return NO;
        }
    }
	
	return YES;
}
@end
