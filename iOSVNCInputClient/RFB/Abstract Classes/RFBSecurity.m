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

/**
 ABSTRACT CLASS.  DO NOT INSTANTIATE DIRECTLY
 */

//Abstract class based on http://xcodeit.net/blog/abstract-classes-and-objective-c.html and exception warning based on http://stackoverflow.com/questions/8907793/how-to-forbid-the-basic-init-method-in-a-nsobject?rq=1

#import "RFBSecurity.h"

@implementation RFBSecurity
//Override init to stop class being instantiated as it's supposed to be an abstract class
-(id)init {
	if ([self class] == [RFBSecurity class]) {
		@throw [NSException exceptionWithName:NSInternalInconsistencyException
									   reason:@"Error, attempting to instantiate AbstractClass directly."
									 userInfo:nil];
        self = nil;
	} else
        self = [super init];
    
	if (self) {
		//init code here
	}
	
	return self;
}

//Chuck an exception for any attempted usage of unimplemented methods
+(void)abstractException {
	@throw [NSException exceptionWithName:NSInternalInconsistencyException
								   reason:[NSString stringWithFormat:@"You must override %@ in a subclass",
										   NSStringFromSelector(_cmd)]
								 userInfo:nil];
}

+(uint8_t)type {
	[[self class] abstractException];
	return '\0'; //Return NUL character for char values
}

+(NSString *)typeName {
	[[self class] abstractException];
	return nil;
}

- (BOOL)performAuthWithSocket:(RFBSocket *)socket ForVersion:(VersionMsg *)serverVersion Error:(NSError **)error {
	[[self class] abstractException];
	return NO;
}
@end
