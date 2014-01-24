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

#import "ServerProfile+Probe.h"

#import "ErrorHandlingMacros.h"

#import "RFBSecurity.h"
#import "RFBSecurityARD.h"
#import "RFBSecurityVNC.h"
#import "RFBSecurityNone.h"
#import "RFBConnection.h"
#import "RFBInputConnManager.h"

@implementation ServerProfile (Probe)
#pragma mark - Probe connection - public
//Result returned as a probeResult Dictionary as well as directly updating values in profile passed in
+ (NSDictionary *)probeServerProfile:(ServerProfile *)serverProfile ProbeType:(ProbeType)type Error:(NSError **)error {
    //Create connection object based on supplied profile details
	RFBConnection *conn = [RFBInputConnManager createConnectionWithProfile:serverProfile
                                                                        Error:error];
	
    if (!conn)
        return nil;
    
	//Attempt probe
	BOOL success = NO;
	if (type == ProbeSecurity) {
		success = [conn probeSecurity:error];
	} else if (type == ProbeAuth) {
		success = [conn connect:error];
		//if (success)
		[conn disconnect];
	} else {
		DLogErr(@"Invalid probe Type supplied");
		return nil;
	}
	
	if (!success) {
		DLogErr(@"Probe type %i failed with error: %@", type, [*error localizedDescription]);
		return nil;
	}
	
    //Run Auth probe again if "NONE" security available to pull serverName.
    NSArray *availableAuthTypes = [conn securityTypesList];
    if ([availableAuthTypes containsObject:[NSNumber numberWithUnsignedChar:[RFBSecurityNone type]]]) {
        success = [conn connect:error];
		[conn disconnect];
        if (!success) {
            DLogErr(@"Probe type %i failed with error: %@", type, [*error localizedDescription]);
            return nil;
        }
    }
    
	//Fish results out of RFB Connection object
	NSDictionary *probeResult = @{ProbeResultKey_Type:[NSNumber numberWithUnsignedInteger:type],
                               ProbeResultKey_ServerProfile:serverProfile,
                               ProbeResultKey_SName:[conn serverName],
                               ProbeResultKey_SVer:[conn serverVersion], //BWVersion object
                               ProbeResultKey_SecTypes:availableAuthTypes};
    DLog(@"Available Auth: %@",availableAuthTypes);    
	if ([[[probeResult objectForKey:ProbeResultKey_SVer] stringValue] length] == 0 || [[probeResult objectForKey:ProbeResultKey_SecTypes] count] == 0) {
		if (error)
			*error = [NSError errorWithDomain:ObjectErrorDomain
										 code:ObjectMethodReturnError
									 userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"ProbeResult incomplete, cannot return results: %@", probeResult]}];
		DLogErr(@"Probe did not fill in properties in Conn object with probe results %@", probeResult);
		return nil;
	}
        
	//Fill in profile attributes retrieved from probe
	if (serverProfile.serverName.length == 0) { //Only save if there hasn't been an override from the user
		serverProfile.serverName = [probeResult objectForKey:ProbeResultKey_SName];
	}
	//Version stored as a string instead of a fancy object wrapper
	serverProfile.serverVersion = [(VersionMsg *)[probeResult objectForKey:ProbeResultKey_SVer] stringValue];
	
	return probeResult;
}
@end
