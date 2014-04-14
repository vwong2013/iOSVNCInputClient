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

//  Handle connection to server, process input events as well as handling received data from server
//  'stop' method MUST be called before setting pointer to this object to nil or read runloop will
//	cause object to stay in memory.

#import "RFBInputConnManager.h"

#import "ErrorHandlingMacros.h"

#import "ServerProfile.h"
#import "RFBConnection.h"

#import "RFBSecurity.h"
#import "RFBSecurityARD.h"
#import "RFBSecurityVNC.h"
#import "RFBSecurityNone.h"

#import "RFBEvent.h"
#import "RFBPointerEvent.h"
#import "RFBKeyEvent.h"

@interface RFBInputConnManager()
@property (strong,nonatomic) ServerProfile *serverProfile;
@property (strong,nonatomic) RFBConnection *rfbconn;
@property (assign,nonatomic) CGPoint pointerScaleFactor;
//@property (assign,nonatomic) dispatch_queue_t readQueue;
//@property (strong,nonatomic) NSTimer *loopedTimer; //continuous read loop
@end

@implementation RFBInputConnManager
#pragma mark - init, dealloc overrides
-(id)init {
	return [self initWithProfile:nil ProtocolDelegate:nil];
}

-(id)initWithProfile:(ServerProfile *)serverProfile ProtocolDelegate:(id<RFBInputConnManagerDelegate>)delegate {
	if ((self = [super init])) {
		_serverProfile = serverProfile;
		_delegate = delegate;
        _pointerScaleFactor = CGPointZero;
	}
	
	return self;
}

-(void)dealloc {
	DLogInf(@"RFBInputConnMgr dealloc");
	//CLose connection
	[self stop];
    self.delegate = nil;
	self.serverProfile = nil;
	self.rfbconn = nil;
}

#pragma mark - Error Management - Private
-(void)handleError:(NSError *)error duringAction:(ActionList)action {
	if (self.delegate) //pass error msg to delegate
		[self.delegate rfbInputConnManager:self
						   performedAction:action
						  encounteredError:error];
}

#pragma mark - Connection Management - Public
-(BOOL)isConnected {
	return [self.rfbconn isConnected];
}

-(void)start {
	//Delegate notification start signal
	if (self.delegate)
		[self.delegate rfbInputConnManager:self performedAction:CONNECTION_START encounteredError:nil];
	
	NSError *error = nil;
	//Init connection object
	self.rfbconn = [[self class] createConnectionWithProfile:self.serverProfile
													  Error:&error];
	
	if (!self.rfbconn || error) {
		[self handleError:error duringAction:CONNECTION_START];
		return;
	}
	
	//Connect
	__weak RFBInputConnManager *blockSafeSelf = self;
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		__block NSError *error = nil;
		__block BOOL success = [blockSafeSelf.rfbconn connect:&error];
		dispatch_async(dispatch_get_main_queue(), ^{ //Tell delegate connection complete, do rest of startup
			if (blockSafeSelf.delegate && !success) {
				[blockSafeSelf.delegate rfbInputConnManager:blockSafeSelf
                                            performedAction:CONNECTION_END
                                           encounteredError:error];
				return; 
			}
            
            //????: For gobbling any incoming server data, but not needed.
            //Setup timed received data buffer cleaner as we don't need anything sent from the server
            //self.readQueue = dispatch_queue_create("rfbReadQueue", NULL);
            //dispatch_async(self.readQueue, ^{[blockSafeSelf readAndIgnore:blockSafeSelf];});
            
            //Setup scaling factor
            CGSize inputScreenSize = [UIScreen mainScreen].bounds.size;
            [blockSafeSelf setScalingGivenInputScreenSize:inputScreenSize];
            
            //Delegate notification end signal
            if (blockSafeSelf.delegate)
                [blockSafeSelf.delegate rfbInputConnManager:blockSafeSelf performedAction:CONNECTION_END encounteredError:error];
		});
	});
}

-(void)stop {
	//Delegate notification start signal
	if (self.delegate && self.rfbconn) //check rfbconn to stop duplicate disconn firings due to calling method in dealloc and requiring user to call manually
		[self.delegate rfbInputConnManager:self performedAction:DISCONNECTION_START encounteredError:nil];
	
	//Disconnect
    [self.rfbconn disconnect];
	self.rfbconn = nil;
    
    /*
	if (self.readQueue) {
		dispatch_release(self.readQueue);
		self.readQueue = nil;		
	}
     */
	
	//Delegate notification end signal
	if (self.delegate && !self.rfbconn)
		[self.delegate rfbInputConnManager:self performedAction:DISCONNECTION_END encounteredError:nil];
}

#pragma mark - Input Event Management - Public
-(void)sendEvent:(RFBEvent *)event {
	//Send event
	__weak RFBInputConnManager *blockSafeSelf = self;
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        __block NSError *error = nil;
        [blockSafeSelf.rfbconn sendEvent:event
                                   Error:&error];
        //Delegate notification (in dispatch queue)
		dispatch_async(dispatch_get_main_queue(), ^{
			if (blockSafeSelf.delegate) {
				[blockSafeSelf.delegate rfbInputConnManager:blockSafeSelf
                                            performedAction:INPUT_EVENT
                                           encounteredError:error];
			}
		});
    });
}

-(CGPoint)serverScaleFactor {
    return self.pointerScaleFactor;
}

#pragma mark - Input Event Management - Private
-(BOOL)setScalingGivenInputScreenSize:(CGSize)ssize {
    //????: Use Scale instead?
    CGSize serverScreen = [self.rfbconn serverDisplaySize];
    if (CGSizeEqualToSize(CGSizeZero, ssize) || ssize.height < 0 || ssize.width < 0 || CGSizeEqualToSize(CGSizeZero, serverScreen))
        return NO; //invalid input size
    
    CGFloat scaleX = serverScreen.width / ssize.width;
    CGFloat scaleY = serverScreen.height / ssize.height;
    
    self.pointerScaleFactor = CGPointMake(scaleX, scaleY);
    
    DLog(@"server: %@, screensize: %@, scaling: %@", NSStringFromCGSize(serverScreen), NSStringFromCGSize(ssize), NSStringFromCGPoint(self.pointerScaleFactor));
    
    return YES;
}

#pragma mark - Connection Management - Private
+(RFBConnection *)createConnectionWithProfile:(ServerProfile *)profile Error:(NSError **)error {
	//determine appropriate RFBSecurity object
	RFBSecurity *security;
	if (profile.macAuthentication) { //Mac Auth
		security = [[RFBSecurityARD alloc] initWithUsername:profile.username
													 Password:profile.password];
	} else if (profile.password.length > 0) { //VNC Auth
		security = [[RFBSecurityVNC alloc] initWithPassword:profile.password];
	} else { //"None" security if password length is 0
		security = [[RFBSecurityNone alloc] init];
	}
	
	//Create connection object
	RFBConnection *conn = [[RFBConnection alloc] initWithHostname:profile.address
																 Port:profile.port
															 Security:security];
	if (!conn) {
		if (error)
			*error = [NSError errorWithDomain:ObjectErrorDomain
										 code:ObjectInitError
									 userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Could not init %@ with supplied Profile details", NSStringFromClass([conn class])]}];
		DLogWar(@"Could not create RFB Connection object with supplied details: %@, %i, %@", profile.address, profile.port, security);
		return nil;
	}
	
	return conn;
}

#pragma mark - Server Read Management - Private
/*
//To be run inside a "read" thread only - don't run in main thread
-(void)readAndIgnore:(RFBInputConnManager *)blockSafeSelf {
	//While RFBConnection is Connected...
	NSMethodSignature *methSig = [RFBInputConnManager instanceMethodSignatureForSelector:@selector(timedReadUsingConnMgr:)];
	NSInvocation *invoc = [NSInvocation invocationWithMethodSignature:methSig];
	[invoc setSelector:@selector(timedReadUsingConnMgr:)];
	[invoc setTarget:blockSafeSelf];
	[invoc setArgument:&blockSafeSelf atIndex:2]; //indexes 0 and 1 are reserved for self and _cmd, respectively.
	self.loopedTimer = [NSTimer scheduledTimerWithTimeInterval:2.0
											   invocation:invoc
												  repeats:YES];
	[[NSRunLoop currentRunLoop] run];
}
//To be run inside a "read" thread only - don't run in main thread
-(void)timedReadUsingConnMgr:(RFBInputConnManager *)blockSafeSelf {
	DLog(@"Read and discard - rfbconn: %@", blockSafeSelf.rfbconn);

	//Stop read run loop
	if (!blockSafeSelf.rfbconn) {
		CFRunLoopStop(CFRunLoopGetCurrent()); //Stop runloop in current thread
		[blockSafeSelf.loopedTimer invalidate]; //invalidate attached timer
	}
	
	//Call read to gobble server data (and ignore)
	[blockSafeSelf.rfbconn discardIncomingData];
}
*/
@end
