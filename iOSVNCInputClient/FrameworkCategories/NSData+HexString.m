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

#import "NSData+HexString.h"

@implementation NSData (HexString)
//Expects 1 byte hex per two chars in the string
+ (NSData *)dataFromHexString:(NSString *)s {
	NSString *noSpace = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	if (noSpace.length%2 > 0) { //Pad a 0 if length not even
		noSpace = [NSString stringWithFormat:@"%@0", noSpace];
    }
    
	uint8_t ba[noSpace.length/2]; //Input = 1 byte of hex, so int output size =input/2
    const char *inputStr = [noSpace cStringUsingEncoding:NSUTF8StringEncoding];
    
    //cString from NSString failed
    if (inputStr == NULL) {
        DLogErr(@"noSpace failed to encode to C String: %@", noSpace);
        return [NSData data];
    }
    
	for (int i=0; i<noSpace.length; i+=2) {
        char temp[3] = {inputStr[i],inputStr[i+1],'\0'}; //Pad with \0 to make C string
        ba[i/2] = strtol(temp, NULL, 16); //str to base 16 aka hex
//        DLog(@"BA: %s", ba);
	}
    
	return [NSData dataWithBytes:ba
						  length:sizeof(ba)];
}

//Returns 1 byte hex per two chars in the string
+ (NSString *)hexString:(NSData *)inputData {
    if (!inputData || inputData.length == 0) {
        DLogErr(@"Cannot convert nil or zero length NSData into hexString");
        return @"";
    }
    
	const uint8_t *ba = [inputData bytes];
    char result[(inputData.length*2)+1]; //1 byte of hex = 2 (hex) chars, +null term
	for (int i=0; i<inputData.length; i++) { //unsigned int to hex
		//convertedBa = [convertedBa stringByAppendingString:[NSString stringWithFormat:@"%02X", ba[i]]]; //Slower
        snprintf(&result[i*2], sizeof(result), "%02X", ba[i]);
	}
    
    NSString *convertedBa = [NSString stringWithCString:result encoding:NSUTF8StringEncoding];
    
    if (!convertedBa || convertedBa.length == 0) {
        DLogErr(@"Failed to covert C String into NSString: %s", result);
        convertedBa = @""; //Just in case issues with conversion...
    }
    
	return convertedBa;
}
@end
