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

#import "VersionMsg.h"

#define RFB_VERSION_DATA_LENGTH 12

@interface VersionMsg()

@end

@implementation VersionMsg
#pragma mark - Init Methods
-(id)init {
	return [self initWithMajor:0 Minor:0];
}

- (id)initWithVersion:(int)version { 
	int major = (version >> 8) & 0xFF;
	int minor = version & 0xFF;
	return [self initWithMajor:major Minor:minor];
}

- (id)initWithMajor:(int)major
			  Minor:(int)minor {
	if ((self = [super init])) {
		_major = major;
		_minor = minor;
	}
	return self;
}

- (id)initWithData:(NSData *)version {
	const char *versionString = [version bytes];
	
	if (version.length != RFB_VERSION_DATA_LENGTH) {
        /*@throw [NSException exceptionWithName:NSRangeException
									   reason:@"Error, cannot init Version outside of RFB Version specification."
									 userInfo:nil];*/
        DLogErr(@"Error, cannot init Version outside of RFB Version specification.  Data Length: %lu", (unsigned long)version.length);
		return nil;
	}
	if (versionString[0] != 'R' || versionString[1] != 'F' || versionString[2] != 'B' || versionString[3] != ' ' || versionString[7] != '.' || versionString[11] != 0x000a) {
        /*@throw [NSException exceptionWithName:NSInvalidArgumentException
									   reason:@"Error, cannot init Version with supplied byte data, does not match RFB Version format specification."
									 userInfo:nil];*/
        DLogErr(@"Error, cannot init Version with supplied byte data, does not match RFB Version format specification.");
		return nil;
	}
	
	NSData *majorD = [version subdataWithRange:NSMakeRange(4, 3)];
	NSData *minorD = [version subdataWithRange:NSMakeRange(8, 3)];
	int major = [[NSString stringWithCString:[majorD bytes] encoding:NSUTF8StringEncoding] intValue];
	int minor = [[NSString stringWithCString:[minorD bytes] encoding:NSUTF8StringEncoding] intValue];
	
	if (major == 0 && minor == 0) {
        /*@throw [NSException exceptionWithName:NSInvalidArgumentException
									   reason:@"Error, cannot init Version with supplied byte data, invalid RFB Version string."
									 userInfo:nil];*/
        DLogErr(@"Error, cannot init Version with supplied byte data, invalid RFB Version string.");
		return nil;
	}
	
	return [self initWithMajor:major
                         Minor:minor];
}

#pragma mark - Other Public Methods
-(NSData *)data {
	char buffer[RFB_VERSION_DATA_LENGTH];
    snprintf(buffer, sizeof(buffer), "RFB %03d.%03d", self.major, self.minor);
    buffer[RFB_VERSION_DATA_LENGTH-1] = '\n'; //Overwrite null byte 00 with newline 0a
    //DLog(@"buffer %@",  [NSData dataWithBytes:buffer length:sizeof(buffer)]);
	return [NSData dataWithBytes:buffer
						  length:sizeof(buffer)];
}

- (int)intValue {
	return self.major << 8 | self.minor;
}

- (NSString *)stringValue {
	return [NSString stringWithFormat:@"%d.%d", self.major, self.minor];
}

- (BOOL)isAppleRemoteDesktop {
	if (self.major == 3 && self.minor == 889)
		return YES;
	else
		return NO;
}
@end
