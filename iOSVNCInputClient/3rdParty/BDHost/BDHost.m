// Source: http://www.bdunagan.com/2009/11/28/iphone-tip-no-nshost/

// MIT license
/*
 The MIT License (MIT)
 
 Copyright (c) 2009 Brian Dunagan
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */

// Usage:
// Remember to add CFNetwork.framework to your project using Add=>Existing Frameworks.
 
#import "BDHost.h"
#import <CFNetwork/CFNetwork.h>
#import <netinet/in.h>
#import <netdb.h>
#import <ifaddrs.h>
#import <arpa/inet.h>
#import <net/ethernet.h>
#import <net/if_dl.h>

//Needed for ping
#import <SystemConfiguration/SystemConfiguration.h>
 
@implementation BDHost
 
+ (NSString *)addressForHostname:(NSString *)hostname {
    NSArray *addresses = (NSArray *)[BDHost addressesForHostname:hostname]; /**Forced return type to shutup Xcode semantics warning @author V Wong vwong122013 (at) gmail.com*/
    if ([addresses count] > 0)
        return [addresses objectAtIndex:0];
    else
        return nil;
}
 
+ (NSArray *)addressesForHostname:(NSString *)hostname {
    // Get the addresses for the given hostname.
    CFHostRef hostRef = CFHostCreateWithName(kCFAllocatorDefault, (__bridge CFStringRef)hostname); /**_bridge as suggested by Xcode @author V Wong vwong122013 (at) gmail.com*/
    BOOL isSuccess = CFHostStartInfoResolution(hostRef, kCFHostAddresses, nil);
    if (!isSuccess) {
		if (hostRef)
			CFRelease(hostRef); /** Adding CFRelease for CF structs as recommended by compiler @author V Wong vwong122013 (at) gmail.com*/
		return nil;
	}
    CFArrayRef addressesRef = CFHostGetAddressing(hostRef, nil);
    if (addressesRef == nil) {
		if (hostRef)
			CFRelease(hostRef);
		return nil;
	}
    // Convert these addresses into strings.
    char ipAddress[INET6_ADDRSTRLEN];
    NSMutableArray *addresses = [NSMutableArray array];
    CFIndex numAddresses = CFArrayGetCount(addressesRef);
    for (CFIndex currentIndex = 0; currentIndex < numAddresses; currentIndex++) {
        struct sockaddr *address = (struct sockaddr *)CFDataGetBytePtr(CFArrayGetValueAtIndex(addressesRef, currentIndex));
        if (address == nil) {
			CFRelease(hostRef);
			return nil;
		}
        getnameinfo(address, address->sa_len, ipAddress, INET6_ADDRSTRLEN, nil, 0, NI_NUMERICHOST);
        if (ipAddress == nil) return nil;
        [addresses addObject:[NSString stringWithCString:ipAddress encoding:NSASCIIStringEncoding]];
    }
	
	//Cleanup... as suggested by compiler
	CFRelease(hostRef);
 
    return addresses;
}
 
+ (NSString *)hostnameForAddress:(NSString *)address {
    NSArray *hostnames = [BDHost hostnamesForAddress:address];
    if ([hostnames count] > 0)
        return [hostnames objectAtIndex:0];
    else
        return nil;
}
 
+ (NSArray *)hostnamesForAddress:(NSString *)address {
    // Get the host reference for the given address.
    struct addrinfo      hints;
    struct addrinfo      *result = NULL;
    memset(&hints, 0, sizeof(hints));
    hints.ai_flags    = AI_NUMERICHOST;
    hints.ai_family   = PF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_protocol = 0;
    int errorStatus = getaddrinfo([address cStringUsingEncoding:NSASCIIStringEncoding], NULL, &hints, &result);
    if (errorStatus != 0) return nil;
    CFDataRef addressRef = CFDataCreate(NULL, (uint8_t *)result->ai_addr, result->ai_addrlen);
    if (addressRef == nil) return nil;
    freeaddrinfo(result);
    CFHostRef hostRef = CFHostCreateWithAddress(kCFAllocatorDefault, addressRef);
    if (hostRef == nil) {
		if (addressRef)
			CFRelease(addressRef);
		return nil;
	}
    CFRelease(addressRef);
    BOOL isSuccess = CFHostStartInfoResolution(hostRef, kCFHostNames, NULL);
    if (!isSuccess) {
		if (hostRef)
			CFRelease(hostRef); /** Adding CFRelease for CF structs as recommended by compiler @author V Wong vwong122013 (at) gmail.com*/
		return nil;
	}
    // Get the hostnames for the host reference.
    CFArrayRef hostnamesRef = CFHostGetNames(hostRef, NULL);
    NSMutableArray *hostnames = [NSMutableArray array];
    for (int currentIndex = 0; currentIndex < [(__bridge NSArray *)hostnamesRef count]; currentIndex++) { /**_bridge as suggested by Xcode @author V Wong vwong122013 (at) gmail.com*/
        [hostnames addObject:[(__bridge NSArray *)hostnamesRef objectAtIndex:currentIndex]];  /**_bridge as suggested by Xcode @author V Wong vwong122013 (at) gmail.com*/
    }
	
	//Cleanup.. as suggested by compiler
	CFRelease(hostRef);
 
    return hostnames;
}
 
+ (NSArray *)ipAddresses {
    NSMutableArray *addresses = [NSMutableArray array];
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *currentAddress = NULL;
 
    int success = getifaddrs(&interfaces);
    if (success == 0) {
        currentAddress = interfaces;
        while(currentAddress != NULL) {
            if(currentAddress->ifa_addr->sa_family == AF_INET) {
                NSString *address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)currentAddress->ifa_addr)->sin_addr)];
                if (![address isEqual:@"127.0.0.1"]) {
                    NSLog(@"%@ ip: %@", [NSString stringWithUTF8String:currentAddress->ifa_name], address);
                    [addresses addObject:address];
                }
            }
            currentAddress = currentAddress->ifa_next;
        }
    }
    freeifaddrs(interfaces);
    return addresses;
}
 
+ (NSArray *)ethernetAddresses {
    NSMutableArray *addresses = [NSMutableArray array];
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *currentAddress = NULL;
    int success = getifaddrs(&interfaces);
    if (success == 0) {
        currentAddress = interfaces;
        while(currentAddress != NULL) {
            if(currentAddress->ifa_addr->sa_family == AF_LINK) {
                NSString *address = [NSString stringWithUTF8String:ether_ntoa((const struct ether_addr *)LLADDR((struct sockaddr_dl *)currentAddress->ifa_addr))];
 
                // ether_ntoa doesn't format the ethernet address with padding.
                char paddedAddress[80];
                int a,b,c,d,e,f;
                sscanf([address UTF8String], "%x:%x:%x:%x:%x:%x", &a, &b, &c, &d, &e, &f);
                sprintf(paddedAddress, "%02X:%02X:%02X:%02X:%02X:%02X",a,b,c,d,e,f);
                address = [NSString stringWithUTF8String:paddedAddress];
 
                if (![address isEqual:@"00:00:00:00:00:00"] && ![address isEqual:@"00:00:00:00:00:FF"]) {
                    NSLog(@"%@ mac: %@", [NSString stringWithUTF8String:currentAddress->ifa_name], address);
                    [addresses addObject:address];
                }
            }
            currentAddress = currentAddress->ifa_next;
        }
    }
    freeifaddrs(interfaces);
    return addresses;
}
@end
