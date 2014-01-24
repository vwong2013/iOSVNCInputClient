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

#import "RFBMessage.h"

//Supported Protocol Versions (ie. 3.3, 3.7, 3.8)
#define MAX_VERSION 0x0308 //3.8 - hex integer
#define MIN_VERSION 0x0303 //3.3

@interface VersionMsg : RFBMessage
@property (nonatomic, assign) int major;
@property (nonatomic, assign) int minor;

- (id)init;
- (id)initWithVersion:(int)version; //Takes a hex integer representation of the version, eg. 0x308 = 3.8
- (id)initWithMajor:(int)major
			  Minor:(int)minor;
- (id)initWithData:(NSData *)version;

#pragma mark -
- (NSData *)data;
- (int)intValue; //Returns a hex integer representation of the current RFB protocol version
- (NSString *)stringValue;
//Apple Remote Desktop used by OS X reports a non-standard RFB number, so check is required to override code behaviour to avoid protocol issues
- (BOOL)isAppleRemoteDesktop;
@end
