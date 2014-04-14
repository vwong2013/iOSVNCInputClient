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

#import "RFBConnection.h"

#import "ErrorHandlingMacros.h"
#import "HandleErrors.h"

#import "RFBSecurity.h"
#import "VersionMsg.h"
#import "RFBSocket.h"

#import "RFBSecurityARD.h"
#import "RFBSecurityNone.h"
#import "RFBSecurityVNC.h"

#import "RFBEvent.h"
#import "RFBKeyEvent.h"
#import "RFBPointerEvent.h"

#import "keysymdef.h"

#define DEFAULT__PORT 5900

@interface RFBConnection()
@property (nonatomic, copy) NSString *address;
@property (nonatomic, assign) int port;
@property (nonatomic, strong) RFBSecurity *security;
@property (nonatomic, strong) RFBSocket *rfbSocket;
@property (nonatomic, strong) VersionMsg *serverVersion;
@property (nonatomic, strong) NSData *securityTypes;
@property (nonatomic, copy) NSString *serverName;
@property (nonatomic, assign) int width;
@property (nonatomic, assign) int height;
@property (nonatomic, assign) float pointerX;
@property (nonatomic, assign) float pointerY;
@property (nonatomic, assign) float yDist;
@end

@implementation RFBConnection
#pragma mark - Inits using Hostname, Port, Password/Security object
//Override default init
-(id)init {
	return [self initWithHostname:nil Port:[[self class] DEFAULT_PORT] Password:nil];
}

-(id)initWithHostname:(NSString *)address Port:(int)port Security:(RFBSecurity *)security {
	if ((self = [super init])) {
		_address = address;
		_port = port;
		_security = security;
	}
	return self;
}

-(id)initWithHostname:(NSString*)address Port:(int)port Password:(NSString *)password {
	return [self initWithHostname:address Port:port Security:[[RFBSecurityVNC alloc] initWithPassword:password]];
}

-(id)initWithHostname:(NSString *)address Password:(NSString *)password {
	return [self initWithHostname:address Port:[[self class] DEFAULT_PORT] Password:password];
}

-(id)initWithHostname:(NSString *)address {
	return [self initWithHostname:address Port:[[self class] DEFAULT_PORT] Security:[[RFBSecurityNone alloc] init]];
}

-(id)initWithHostname:(NSString *)address Security:(RFBSecurity *)security {
	return [self initWithHostname:address Port:[[self class] DEFAULT_PORT] Security:security];
}

#pragma mark -
-(void)dealloc {
    DLogInf(@"RFBConnection dealloc");
    [self disconnect];
}

#pragma mark - Static Getters - Public
+ (int)DEFAULT_PORT {
	return DEFAULT__PORT;
}

#pragma mark - Getters - Public
-(NSString *)serverName {
	if (!_serverName)
		_serverName = @"";
	return _serverName;
}

-(VersionMsg *)serverVersion {
	if (!_serverVersion)
		_serverVersion = [[VersionMsg alloc] init];
	return _serverVersion;
}

-(NSData *)securityTypes {
	if (!_securityTypes)
		_securityTypes = [NSMutableData new];
	return _securityTypes;
}

//Present available security types in an easier to parse form
-(NSArray *)securityTypesList {
    if (self.securityTypes.length == 0)
        return @[];
    
    NSMutableArray *securityTypes = [NSMutableArray arrayWithCapacity:[self.securityTypes length]];
    const uint8_t *secTypes = [self.securityTypes bytes];
    for (int i=0; i < [self.securityTypes length]; i++) {
        [securityTypes addObject:[NSNumber numberWithUnsignedChar:secTypes[i]]];
    }
    return securityTypes;
}

-(CGSize)serverDisplaySize {
    if (!_height || !_width)
        return CGSizeZero;
    return CGSizeMake(self.width, self.height);
}

#pragma mark - Lazy Init (some) propertys - Private
-(float)yDist {
	if (!_yDist)
		_yDist = 0;
	return _yDist;
}

#pragma mark - Connectivity - Public
-(BOOL)isConnected {
	if (self.rfbSocket)
		return [self.rfbSocket isConnected];
	return NO;
}

-(BOOL)probeSecurity:(NSError **)error {
	//Connect and establish protocol version
	BOOL success = [self establishSocketAndRFBProtocol:error];
	
	if (!success) //Abort security probe
		return NO;
	
	//Get the list of supported security types from the server
	self.securityTypes = [self.rfbSocket readSecurity];
	if (self.securityTypes.length == 0) {
        HandleError he = [HandleErrors handleErrorBlock];
        NSString *header = NSLocalizedString(@"Failed security read, error from server: ", @"RFBConn Security Probe Failed Header Error Text");
        he(error,SocketErrorDomain,SocketReadError,[header stringByAppendingString:[self.rfbSocket readString]]);
		return NO;
	}
	
	//Disconnect
	[self disconnect];
	
	return YES;
}

//FIXME: Could be refined... duplicates code from probeSecurity
-(BOOL)connect:(NSError **)error {
	//Connect and establish protocol version
	BOOL success = [self establishSocketAndRFBProtocol:error];
	
	if (!success) //Abort security probe
		return NO;
	
	//Error handling block
	HandleError he = [HandleErrors handleErrorBlock];
    
	// security
	// read the list of supported security types from the server
	self.securityTypes = [self.rfbSocket readSecurity];
	if (!self.securityTypes) {
        NSString *header = NSLocalizedString(@"error from server: ", @"RFBConn Connect Security Failed Header Error Text");
        he(error,SocketErrorDomain,SocketReadError,[header stringByAppendingString:[self.rfbSocket readString]]);
		return NO;
	}
	
    //Parse security types, determine if "None" and selected security type (self.security) is available.
	BOOL securityNoneIsAvailable = NO;
	BOOL preferredSecurityIsAvailable = NO;
	uint sLength = (uint)self.securityTypes.length;
	const uint8_t *securityTypes = [self.securityTypes bytes];
    for (uint i = 0; i < sLength; i++) {
		uint8_t securityType = securityTypes[i];
		if (securityType == [RFBSecurityNone type]) {
			securityNoneIsAvailable = YES;
		}
		if ([[self.security class] type] == securityType) { //Note: self.security should have been set when this obj init'ed
			preferredSecurityIsAvailable = YES;
		}
    }
	
    //Attempt to use "None" security if selected auth method not available
	if (! preferredSecurityIsAvailable) {
		if (securityNoneIsAvailable) {
			//FIXME: Send back an error msg when desired security type is not present?
			self.security = [[RFBSecurityNone alloc] init]; //Replace with "None" Security
		} else {
            NSString *header = NSLocalizedString(@"The server does not support security type: ", @"RFBConn Connect Preferred Security Failed Header Error Text");            
            he(error,SocketErrorDomain,SocketSecurityError,[header stringByAppendingString:[[self.security class] typeName]]);
			return NO;
		}
	}
	
	//Inform server of desired auth method
	[self.rfbSocket writeSecurity:[[self.security class] type]];
	
	//perform the security handshake using given socket connection and protocol version
    NSError *handshakeErr = nil;
	if (![self.security performAuthWithSocket:self.rfbSocket ForVersion:self.serverVersion Error:&handshakeErr]) {
        DLogErr(@"Security handshake problem: %@", [handshakeErr localizedDescription]); 
        NSString *header = NSLocalizedString(@"Authentication with server failed: ", @"RFBConn Handshake Failed Header Error Text");
		he(error, SocketErrorDomain, SocketSecurityError, [header stringByAppendingString:[handshakeErr localizedDescription]]);
		return NO;
	}
	
	//Success - start connection initialization
	NSArray *serverDetails = [self.rfbSocket performInitialization];
	if (!serverDetails || serverDetails.count == 0) { //init failed
		he(error, SocketErrorDomain, SocketConnectError, @"Failed to complete initialization phase");
		return NO;
	}
    
    //Set Connection Details
	self.serverName = [serverDetails objectAtIndex:0];
	self.width = [[serverDetails objectAtIndex:1] intValue];
	self.height = [[serverDetails objectAtIndex:2] intValue];
	self.pointerX = (float)self.width/2; //Start pointer location at the "centre" of the supplied screen dimensions
	self.pointerY = (float)self.height/2;
	
	DLogInf(@"Reported server width: %i height %i, starting pointer x: %f, pointer y: %f", self.width, self.height, self.pointerX, self.pointerY);
	
	return YES;
}

-(void)disconnect {
	//DLogInf(@"BWRFBSocket released");
    [self.rfbSocket disconnect]; //Must call to kill any existing pending network requests
	self.rfbSocket = nil;
}

#pragma mark - Connectivity - Private
//Connect and establish protocol version to use
-(BOOL)establishSocketAndRFBProtocol:(NSError**)error {
	//Error handling block
	HandleError he = [HandleErrors handleErrorBlock];
    
    if (self.address && self.address.length > 0) {
		self.rfbSocket = [[RFBSocket alloc] initWithAddress:self.address
                                                       Port:self.port];
	} else {
        he(error,SocketErrorDomain,SocketConnectError,NSLocalizedString(@"Could not instantiate BWRFBStream object", @"RFBConn invalid address error text"));
		return NO; //Skip rest of method
	}
	
	//Connect to supplied address/port
	BOOL connecting = [self.rfbSocket connect:error];
	if (!connecting) {
		return NO;
    }
	
	//Get server protocol version and reply with desired RFB protocol version
    VersionMsg *serverVer = [self.rfbSocket readVersion];
    if (serverVer == nil) { //No version returned
        he(error,SocketErrorDomain,SocketConnectError,NSLocalizedString(@"Could not negotiate connection.  Screen Sharing disabled?", @"RFBConn Server NIL Protocol Version Error text"));
        return NO;
    }
    self.serverVersion = serverVer;
    
	int version = [self.serverVersion intValue];
    DLog(@"server version: %i", version);    
	if (self.serverVersion.isAppleRemoteDesktop) {
		//Apple Remote Desktop reports non-standard VNC version (3.889),
        //apparently similar to v3.7 so we tell server to use that instead.
		version = 0x0307;
	} else {
		if (version == 0) { //Likely not connected at all
            he(error,SocketErrorDomain,SocketConnectError,NSLocalizedString(@"VNC Server/Screen Sharing Not Enabled or Invalid Server Address", @"RFBConn Server Protocol Version Error text"));			
			return NO;
		}
		if (version < MIN_VERSION) {
            NSString *header = NSLocalizedString(@"Cannot connect with RFB version  ", @"RFBConn Unsupported Protocol Version Header Error Text");
            he(error,SocketErrorDomain,SocketConnectError,[NSString stringWithFormat:@"%@ %@", header,[self.serverVersion stringValue]]);
			return NO;
		}
		if (version > MAX_VERSION) //Only allow up to client supported max protocol version
			version = MAX_VERSION;
        
        //Set socket TCP_NODELAY to stop jerky mouse movements.  Not set for ARD as it seems unaffected
        if (![self.rfbSocket setTCPNoDelay:YES])
            he(error,SocketErrorDomain,SocketConnectError,NSLocalizedString(@"Failed to set TCP_NODELAY", @"RFBConn failed tcp_nodelay set error text"));
	}

    DLog(@"reported version: %i", version);
	[self.rfbSocket writeVersion:version];
	
	return YES;
}

#pragma mark - Read Methods - Public
//Gobble incoming data from server, if any
-(void)discardIncomingData {
	[self.rfbSocket readAndDiscard];
}

#pragma mark - RFB Event handling - Public
//RFB event handling
-(BOOL)sendEvent:(RFBEvent *)event Error:(NSError **)error {
	HandleError he = [HandleErrors handleErrorBlock];
    
	if (!self.rfbSocket || [self.rfbSocket isDisconnected]) {
        he(error, SocketErrorDomain, SocketConnectError, NSLocalizedString(@"Disconnected from server", @"RFBConn socket not ready error text"));
		return NO;
	}
	
	if([event isMemberOfClass:[RFBKeyEvent class]]) {
		return [self handleKeyEvent:(RFBKeyEvent *)event
                              Error:error]; 
	} else if ([event isMemberOfClass:[RFBPointerEvent class]]) {
		return [self handlePointerEvent:(RFBPointerEvent *)event
								  Error:error]; 
	}

	return NO; //Should never happen
}

#pragma mark - RFB Event handling - Private
-(BOOL)handleKeyEvent:(RFBKeyEvent *)keyEvent Error:(NSError **)error {
    //No connection check again because done in sendEvent already
	[self.rfbSocket sendKeyWithEvent:keyEvent];	
	return YES;
}

-(BOOL)handlePointerEvent:(RFBPointerEvent *)pointerEvent Error:(NSError **)error {	
	//map movement
	if ((pointerEvent.dx != 0 || pointerEvent.dy != 0) && !CGPointEqualToPoint(CGPointZero, pointerEvent.v)) {
        //Adjust velocity to points per ?centisecond
        float xSpeed = fabsf(pointerEvent.v.x/100);
        float ySpeed = fabsf(pointerEvent.v.y/100);
        
        //Average speed...
        float speed = (xSpeed+ySpeed)/2;
        
        //Cap speed
        if (speed > 2)
            speed = 2;
        
        //Use velocity given as the speed scaler
		self.pointerX += (pointerEvent.dx*speed);
		self.pointerY += (pointerEvent.dy*speed);
        
        //Constrain movement to within reported screen borders
		if (self.pointerX >= self.width) {
            if ([self.security isMemberOfClass:[RFBSecurityARD class]])
                self.pointerX = self.width-1; //In OSX, a hidden Dock doesn't show unless cursor is ~1 pixels from the edge of screen?
            else
                self.pointerX = self.width;
        }
		if (self.pointerY >= self.height) {
            if ([self.security isMemberOfClass:[RFBSecurityARD class]])
                self.pointerY = self.height-1; //In OSX, a hidden Dock doesn't show unless cursor is ~1 pixels from the edge of screen?
            else
                self.pointerY = self.height;
        }
		if (self.pointerX <= 0)
			self.pointerX = 0;
		if (self.pointerY <= 0)
			self.pointerY = 0;
        
        DLog(@"vx vy: %f,%f avg v: %f dx dy: %f,%f New pXY: %f,%f, Sent pXY: %i,%i", xSpeed,ySpeed,speed, pointerEvent.dx,pointerEvent.dy, self.pointerX,self.pointerY, (int)self.pointerX, (int)self.pointerY);
	}
	
	//map buttons
	uint8_t buttonMask = 0x00;
	if (pointerEvent.button1) {
		buttonMask |= 0x01;
	}
	if (pointerEvent.button2) {
        //Apple Remote Desktop 3.5 button compatibility fix
		if (self.ard35Compatibility) {
			buttonMask |= 0x02;
		} else {
			buttonMask |= 0x04;
		}
	}
	
	//work out scroll events
	//TODO: support horizontal scrolling
    int8_t (^shouldScroll)(float totalDist, int8_t threshold) = ^ int8_t (float totalDist, int8_t threshold) {
        if (totalDist == 0)
            return 0; //no scrolling happening
        
        int8_t scrollDirection = 0;
        if (totalDist >= threshold || totalDist <= -threshold) {
            scrollDirection = ceilf(totalDist/threshold);
        }
        
        return scrollDirection; //if not at accumulated level
    };

    int8_t scrollDirection = 0;
    if (pointerEvent.sy != 0 && pointerEvent.scrollSensitivity != 0) {
        self.yDist += pointerEvent.sy;
        scrollDirection = shouldScroll(self.yDist, pointerEvent.scrollSensitivity);
        if (scrollDirection != 0)
            self.yDist = 0; //reset
    }
        
    if (scrollDirection != 0) {
		if (scrollDirection > 0) { //"reverse" scrolling
			buttonMask |= 0x10; //btn 5
		} else if (scrollDirection < 0) {
			buttonMask |= 0x08; //btn 4
		}
		uint8_t clearScrollButtonMask = buttonMask;
        clearScrollButtonMask &= (~(0x08 | 0x10)); //bitwise twiddle of bitwise or btn4 and 5
        
        /*if (xScroll > 0) {
         buttons |= 0x20; //btn 6 left
         } else if (xScroll < 0) {
         buttons |= 0x40; //btn 7 right
         }
         uint8_t clearScrollButtons = buttons;
        if (xScroll != 0)
         clearScrollButtons &= (~(0x20 | 0x40));*/
     
		[self.rfbSocket sendMultiplePointerEventsForIterations:abs(scrollDirection)
												 setButtons:buttonMask
											   clearButtons:clearScrollButtonMask
                                                       XPos:(int)self.pointerX
                                                       YPos:(int)self.pointerY];
	} else if (pointerEvent.buttonIterations >= 1) {
        //Setup clear button mask
		uint8_t clearButtonMask = buttonMask;
        clearButtonMask &= (~(0x01 | 0x02 | 0x04));
        
        DLog(@"buttonMask: %i", buttonMask);
        DLog(@"clearbtnmask: %i", clearButtonMask);
        
        //send multiple (button) pointer events
		[self.rfbSocket sendMultiplePointerEventsForIterations:pointerEvent.buttonIterations
                                                    setButtons:buttonMask
                                                  clearButtons:clearButtonMask
                                                          XPos:(int)self.pointerX
                                                          YPos:(int)self.pointerY];
    } else {
		[self.rfbSocket sendPointerEventWithButtons:buttonMask
                                            XPos:(int)self.pointerX
                                            YPos:(int)self.pointerY];
	}
	
	return YES;
}
@end
