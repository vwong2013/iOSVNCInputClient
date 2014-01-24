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

#import <Foundation/Foundation.h>

#define SERVICE_NAME @"name"
#define SERVICE_PORT @"port"
#define SERVICE_ADDRESS @"address"

#define ServiceDiscoveryErrorDomain @"serviceDiscoveryError"
#define ServiceDiscoveryErrorCode 800

#define DEFAULT_TIMEOUT 5.0 //Service, browser timeout

@protocol MDNSDiscovererDelegateProtocol;

@interface MDNSDiscoverer : NSObject
@property (weak,nonatomic) id<MDNSDiscovererDelegateProtocol> delegate;

-(id)init;
-(void)startSearch;
-(void)stop;
@end

@protocol MDNSDiscovererDelegateProtocol <NSObject>

@optional
-(void)MDNSDiscovererStartedSearch:(MDNSDiscoverer *)discoverer;

@required
-(void)MDNSDiscoverer:(MDNSDiscoverer *)discoverer completedSearch:(NSArray *)searchResults;
-(void)MDNSDiscoverer:(MDNSDiscoverer *)discoverer failedSearch:(NSError *)error;

@end
