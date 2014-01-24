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

typedef enum {
	CONNECTION_START, //0
	CONNECTION_END,
	DISCONNECTION_START,
	DISCONNECTION_END,
	INPUT_EVENT //TODO: For delegate to respond to event errors
} ActionList;

@class ServerProfile, RFBEvent, RFBConnection;

@protocol RFBInputConnManagerDelegate;

@interface RFBInputConnManager : NSObject
@property (weak,nonatomic) id<RFBInputConnManagerDelegate> delegate;

#pragma mark - Methods
//Delegate is optional
-(id)initWithProfile:(ServerProfile *)serverProfile ProtocolDelegate:(id<RFBInputConnManagerDelegate>)delegate;

#pragma mark - Connection Management - Public
-(BOOL)isConnected;
-(void)start;
-(void)stop;
+(RFBConnection *)createConnectionWithProfile:(ServerProfile *)profile Error:(NSError **)error;

#pragma mark - Input Event Management - Public
-(void)sendEvent:(RFBEvent *)event;
-(CGPoint)serverScaleFactor;
@end

#pragma mark - Protocol declaration
@protocol RFBInputConnManagerDelegate <NSObject>

//For delegate to respond to conn mgr methods
-(void)rfbInputConnManager:(RFBInputConnManager *)inputConnMgr performedAction:(ActionList)action encounteredError:(NSError *)error;

@end