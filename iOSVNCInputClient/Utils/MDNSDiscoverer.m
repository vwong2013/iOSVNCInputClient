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

#import "MDNSDiscoverer.h"
#import <netinet/in.h>
#import <netdb.h>
#import <sys/socket.h>

@interface MDNSDiscoverer() <NSNetServiceBrowserDelegate, NSNetServiceDelegate>
@property (strong,nonatomic) NSNetServiceBrowser *serviceBrowser;
@property (strong,nonatomic) __block NSNetService *tempService;
@property (assign,nonatomic) int serviceTimeout, browserTimeout;
@property (strong,nonatomic) __block NSMutableArray *searchResults;
@property (strong,nonatomic) NSMutableArray *invalidServiceResults;
@property (strong,nonatomic) NSMutableArray *serviceBuffer;
@property (assign,nonatomic) __block int serviceBufferRead;
@end

@implementation MDNSDiscoverer 

-(id)init {
    if ((self = [super init])) {
        _searchResults = [NSMutableArray new];
        _invalidServiceResults = [NSMutableArray new];
        _serviceBuffer = [NSMutableArray new];
        _serviceBufferRead = 0;
        _serviceTimeout = DEFAULT_TIMEOUT;
        _browserTimeout = DEFAULT_TIMEOUT;
    }
    
    return self;
}

-(void)dealloc {
    DLogInf(@"MDNSDiscoverer dealloc!");    
    [self stop];
    [self.serviceBrowser setDelegate:nil];
}

#pragma mark - Search management - Public
-(void)startSearch {
    if (self.delegate)
        [self.delegate MDNSDiscovererStartedSearch:self];
    
    if (self.serviceBuffer.count > 0) {
        self.serviceBufferRead = 0;
        [self.serviceBuffer removeAllObjects];
        [self.searchResults removeAllObjects];
        [self.invalidServiceResults removeAllObjects];
    }
    
    if (!self.serviceBrowser) {
        self.serviceBrowser = [[NSNetServiceBrowser alloc] init];
        [self.serviceBrowser setDelegate:self];
    }
    
    [self.serviceBrowser searchForServicesOfType:@"_rfb._tcp." inDomain:@"local."];
    
    //Setup timeout check if no services found
    [NSTimer scheduledTimerWithTimeInterval:self.browserTimeout
                                     target:self
                                   selector:@selector(timeoutServiceBrowser:)
                                   userInfo:nil
                                    repeats:NO];
}

-(void)stop {
    if (self.serviceBrowser)
        [self.serviceBrowser stop];
    if (self.tempService) {
        [self.tempService stop];
        [self.tempService setDelegate:nil];
        self.tempService = nil;
    }
    [self.searchResults removeAllObjects];
    [self.serviceBuffer removeAllObjects];
    [self.invalidServiceResults removeAllObjects];
}

#pragma mark - Search management - Private
-(void)timeoutServiceBrowser:(NSTimer *)timer {
    if (self.serviceBuffer.count == 0) {
        [self.serviceBrowser stop];
        NSError *error = [NSError errorWithDomain:ServiceDiscoveryErrorDomain
                                             code:ServiceDiscoveryErrorCode
                                         userInfo:@{NSLocalizedDescriptionKey:@"Service search timeout"}];
        [self.delegate MDNSDiscoverer:self failedSearch:error];
    }
}

-(void)returnFormattedSearchResults {
    [self.delegate MDNSDiscoverer:self completedSearch:self.searchResults];
}

-(void)processServiceSearchResults:(NSMutableArray *)results {
    //Go through each netService and resolve
    [results enumerateObjectsUsingBlock:^(NSNetService *service, NSUInteger idx, BOOL *stop) {
        self.serviceBufferRead++;
        DLog(@"serviceBufferDone %i", self.serviceBufferRead);
        
        if ([self.invalidServiceResults containsObject:[NSNumber numberWithUnsignedInteger:[service hash]]])
            return; //skip remaining block
        
        self.tempService = service;
        [self.tempService setDelegate:self];
        [self.tempService resolveWithTimeout:self.serviceTimeout];
    }];
}

-(void)processResolvedService:(NSNetService *)aNetService {
    NSString *name = [aNetService name];
    NSInteger port = [aNetService port];
    NSArray *addressData = [aNetService addresses];
    
    //Extract port and address
    [addressData enumerateObjectsUsingBlock:^(NSData *saData, NSUInteger idx, BOOL *stop) {
        NSString *address = @"";
        
        //Check sockaddr type and cast accordingly, then grab port
        struct sockaddr *sa = (struct sockaddr *)[saData bytes];
        int addrBufferLength = 0;
        if (sa->sa_family == AF_INET) {
            addrBufferLength = INET_ADDRSTRLEN;
        } else if (sa->sa_family == AF_INET6) {
            addrBufferLength = INET6_ADDRSTRLEN;
        }
        
        //Get address in readable string
        char addrBuffer[addrBufferLength+1]; //+1 for null term
        int err=getnameinfo(sa, sizeof(sa), addrBuffer, (unsigned int)sizeof(addrBuffer), 0, 0, NI_NUMERICHOST);
        if (err != 0)
            DLogErr(@"Failed to convert address to C string, error: %d", err);
        addrBuffer[addrBufferLength] = '\n'; //0 index
        address = [NSString stringWithFormat:@"%s",addrBuffer];
        
        //Assemble into a dictionary
        NSDictionary *results = @{@"name":name,
                                  @"address":address,
                                  @"port":[NSString stringWithFormat:@"%li",(long)port]};
        DLog(@"service address: %@", results);
        
        //Add into results array for return
        [self.searchResults addObject:results];
    }];
}

-(void)isServiceBufferReadComplete {
    if (self.serviceBuffer.count == self.serviceBufferRead)
        [self returnFormattedSearchResults];
}

#pragma mark - NSNetServiceBrowserDelegate protocol methods
-(void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didNotSearch:(NSDictionary *)errorDict {
    //Search failed
    //Use the dictionary keys NSNetServicesErrorCode and NSNetServicesErrorDomain to retrieve the error information from the dictionary
    //NSNetServicesError type identifies the errorCode
    NSString *errorCode = [errorDict objectForKey:NSNetServicesErrorCode];
    NSString *errorDomain = [errorDict objectForKey:NSNetServicesErrorDomain];
    DLogErr(@"netServiceBrowser:didNotSearch: %@, %@", errorCode, errorDomain);
    
    NSError *error = [NSError errorWithDomain:errorDomain
                                         code:[errorCode intValue]
                                     userInfo:@{NSLocalizedDescriptionKey:[@"NetServiceBrowser failed - error: " stringByAppendingString:errorCode]}];
    [self.delegate MDNSDiscoverer:self failedSearch:error];
}

-(void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindService:(NSNetService *)aNetService moreComing:(BOOL)moreComing {
    //Service found
    //Add to discovered service queue
    [self.serviceBuffer addObject:aNetService];
    DLog(@"found service");
    //Attempt to resolve services once no more coming, and stop searching for more
    if (!moreComing) {
        [self.serviceBrowser stop];
        [self processServiceSearchResults:self.serviceBuffer];
    }
}

//????: Redundant? Failed resolve should deal with no longer present service anyways?
-(void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didRemoveService:(NSNetService *)aNetService moreComing:(BOOL)moreComing {
    //Service no longer available
    DLog(@"remove service");
    //Remove service from results (or queue)
    [self.invalidServiceResults addObject:[NSNumber numberWithUnsignedInteger:[aNetService hash]]];
}

-(void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser *)aNetServiceBrowser {
    //Service told to stop searching
    DLog(@"service search stopped");
}

#pragma mark - NSNetServiceDelegate protocol methods
-(void)netServiceDidResolveAddress:(NSNetService *)sender {
    //Test connection using GCDAsyncSocket?
    //Add connection to searchResults
    [self processResolvedService:sender];
    [self isServiceBufferReadComplete];
}

-(void)netService:(NSNetService *)sender didNotResolve:(NSDictionary *)errorDict {
    //Don't add connection to searchResults
    //Log error
    NSString *errorCode = [errorDict objectForKey:NSNetServicesErrorCode];
    NSString *errorDomain = [errorDict objectForKey:NSNetServicesErrorDomain];
    DLogErr(@"netService:didNotResolve: %@, %@", errorCode, errorDomain);
    [self isServiceBufferReadComplete]; //Even if a resolve fails still need to return partial results!
}
@end
