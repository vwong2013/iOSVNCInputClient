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

#import "RFBSocket.h"

#import "GCDAsyncSocket.h"

#import <arpa/inet.h> //htons, ntohs, etc
#import <netinet/in.h> //IPPROTO_TCP
#import <netinet/tcp.h> //TCP_NODELAY

#import "RFBConnection.h"
#import "RFBMessage.h"
#import "VersionMsg.h"

#import "RFBSecurityInvalid.h"

#import "RFBKeyEvent.h"
#import "KeyMapping.h"

#define TIMEOUT 10 //seconds

@interface RFBSocket()
@property (assign, nonatomic) int version;

@property (copy, nonatomic) NSString *address; //ip or domain name
@property (assign, nonatomic) int port;
@property (strong, nonatomic) GCDAsyncSocket *socket;

//Read temp data buffers for CocoaAsyncSocket to read data from
@property (strong, nonatomic) NSData *readBuffer;
@property (assign, nonatomic) BOOL requestReadyOrTimedOut;
@end

@implementation RFBSocket 
#pragma mark - Inits / Dealloc
//Override, not used.
-(id)init {
	return [self initWithAddress:nil Port:0];
}

-(id)initWithAddress:(NSString *)address Port:(int)port {
	if ((self = [super init]) ) {
		_version = 0;
		_address = address;
		_port = port;
        dispatch_queue_t socketQ = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
		_socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:socketQ];
	}
	return self;
}

-(void)dealloc {
	DLogInf(@"BWRFBStream dealloc");
	[self disconnect];
    self.socket = nil;
}

#pragma mark - Socket Options - Public
-(BOOL)setTCPNoDelay:(BOOL)on {
    __block BOOL ok = NO;
    __weak RFBSocket *blockSafeSelf = self;
    [self.socket performBlock:^{
        int socketFD = [blockSafeSelf.socket socketFD];
        int onOff = on;
        if (setsockopt(socketFD, IPPROTO_TCP, TCP_NODELAY, (void *)&onOff, sizeof(onOff)) == -1)
            DLogErr(@"Socket tcp no delay set %i failed with errno: %i", on, errno);
        ok = YES;
    }];
    
    return ok;
}

#pragma mark - Read Methods - Private
-(uint8_t)readByte {
	NSData *received =[self readReceived:1];
	if (!received || received.length == 0)
		return 0; //Read failed or empty
	const uint8_t *recvBytes = [received bytes];
	return recvBytes[0];
}

-(uint32_t)readInt {
	NSData *received = [self readReceived:4]; //4 bytes, U32
	if (!received || received.length == 0)
		return 0; //Read failed or empty
    const uint32_t *recvBytes = [received bytes];
    return ntohl(*recvBytes);
}

#pragma mark - Read Methods - Public
//For reading error messages, etc from the server
-(NSString *)readString {
	uint32_t length = [self readInt]; //Length of string
	NSData *received = [self readReceived:length]; //Contents, U8 array
	
	if (length == 0 || !received)
		return @""; //If nothing sent or blank string
	
	return [[NSString alloc] initWithData:received encoding:NSUTF8StringEncoding];
}

//GCDAsyncSocket reads are forced to be *SYNCHRONOUS* using the while loop
-(NSData *)readReceived:(int)length {
	if ([self isDisconnected])
		return nil;
	
	[self.socket readDataToLength:length
                      withTimeout:TIMEOUT //Set a timeout for this to allow loop to exit nicely
                              tag:0];
	
	self.requestReadyOrTimedOut = NO;
	while (!self.requestReadyOrTimedOut) {
		//DLog(@"Waiting for request to complete...");
		if (self.readBuffer.length == length)
			self.requestReadyOrTimedOut = YES;
	}
	
	NSData *read = [NSData dataWithData:self.readBuffer];
	self.readBuffer = nil; //purge previously received socket data, otherwise may end up accidentally re-reading previous received data.  THis is because we don't have a 'bytes read' counter and we're forcing synchronous reads...
	return read; //Assuming method only returns when data of specified length is read
}

-(uint16_t)readShort {
	NSData *received = [self readReceived:2];
	if (!received || received.length == 0)
		return 0; //Read failed or empty
    const uint16_t *recvBytes = [received bytes];
    return ntohs(*recvBytes);
}

#pragma mark - Write methods - Private
-(void)writeByte:(uint8_t)singleByte {
	NSData *wrapper = [NSData dataWithBytes:&singleByte length:sizeof(singleByte)];
    [self writeBytes:wrapper];
}

-(void)writeMessage:(RFBMessage *)msg {
    [self writeBytes:[msg data]];
}

#pragma mark - Write methods - Public
//ASYNCHRONOUS
-(void)writeBytes:(NSData *)wrapper {
    if (!wrapper)
        return; //Do nothing if nil data to send
    
	[self.socket writeData:wrapper
               withTimeout:TIMEOUT
                       tag:0]; //TODO: Implement tagging for writes?
}

#pragma mark - Connection Methods - Public
//Returns YES if no basic errors like invalid address/port/interface/socket already connected.  Also returns NSError object if one is generated by socket
-(BOOL)connect:(NSError **)connErr {	
	NSError *error = nil;
	if ([self.socket connectToHost:self.address
							onPort:self.port
					   withTimeout:TIMEOUT
							 error:&error]) {
		return YES;
    }
	
	*connErr = error;	
	
	return NO; //default behaviour if connection string has errors
}

-(void)disconnect {
    DLog(@"rfbstream socket disconn called");
    //Set timeout property to YES to avoid getting stuck in a loop
    self.requestReadyOrTimedOut = YES;
    //release socket in recommended manner.  
	[self.socket setDelegate:nil delegateQueue:NULL];
	[self.socket disconnect];
}

#pragma mark - Read Methods - Public
-(VersionMsg *)readVersion {
	NSData *dataBuffer = [self readReceived:12];
	VersionMsg *version = [[VersionMsg alloc] initWithData:dataBuffer];
	return version;
}

-(NSData *)readSecurity {
	if (self.version >= 0x0307) {
		uint8_t numSecTypes = [self readByte];
		//DLog(@"numSecTypes: %i", numSecTypes);
		if (numSecTypes == 0) //Connection failed response, eg. unsupported protocol version
			return nil;
		return [self readReceived:numSecTypes]; //Read supported security types
	} else { //V 3.3 protocol
		uint32_t buff = [self readInt];
		if (buff == [RFBSecurityInvalid type])
			return nil;
		else {
			return [NSData dataWithBytes:&buff length:sizeof(buff)];
		}
	}
}

-(uint32_t)readSecurityResult {
	uint32_t results =[self readInt];
	return results;
}

-(void)readAndDiscard {
	//Read first available bytes available to socket... and do nothing with it
	[self.socket readDataWithTimeout:TIMEOUT tag:0];
}

#pragma mark - Other Write Methods - Public
-(void)writeVersion:(int)version {
	self.version = version;
	VersionMsg *v = [[VersionMsg alloc] initWithVersion:version];
    [self writeBytes:[v data]];
}

-(void)writeSecurity:(uint8_t)securityType {
    [self writeByte:securityType];
}

#pragma mark - RFB Event Methods - Public
//RFB initialization phase
-(NSArray *)performInitialization {
	//shared-flag = 1, ie. no sharing with other clients
    [self writeByte:0x01];
	
	// read the ServerInit
	NSData *displayInfo = [self readReceived:20];
	NSString *name = [self readString];
	
	if (displayInfo.length == 0)
		return nil;
	
	// parse the server display info. 
    uint16_t dimensions[(sizeof(uint16_t) * 2)]; //U16 width, height
    [displayInfo getBytes:&dimensions length:sizeof(dimensions)];
    uint16_t width = ntohs(dimensions[0]);
    uint16_t height = ntohs(dimensions[1]);
    
    PixelFormatMsg pixelFormat; //Not used, but parsed anyways for debugging
    [displayInfo getBytes:&pixelFormat range:NSMakeRange((sizeof(uint16_t) * 2), PixelFormatMsg_Size)];
    DLog(@"pixelFormat - bitsperpixel %i, depth %i, BEflag %i, TCflag %i, redMax %i, grMax %i, bluMax %i, redShif %i, greenShift %i, bluShift %i", pixelFormat.bitsPerPixel, pixelFormat.depth, pixelFormat.bigEndianFlag, pixelFormat.trueColourFlag, pixelFormat.redMax, pixelFormat.greenMax, pixelFormat.blueMax, pixelFormat.redShift, pixelFormat.greenShift, pixelFormat.blueShift);
	
	//return only the server name, width, height AND pixel format
	return @[name, [NSNumber numberWithUnsignedInt:width], [NSNumber numberWithUnsignedInt:height]];
}

/*
-(void)sendSetPixelFormat:(PixelFormatMsg *)pfMsg {
    PixelFormatClientMsg clientPixelFormat;
    clientPixelFormat.msgType = PixelFormatClient_MsgType;
    clientPixelFormat.paddingOneByte = 0;
    clientPixelFormat.paddingTwoBytes = 0;
    clientPixelFormat.pixelFormat = *pfMsg;
    NSData *wrapper = [NSData dataWithBytes:&clientPixelFormat
                                     length:PixelFormatClientMsg_Size];
    [self writeBytes:wrapper];
}*/

-(void)sendPointerEventWithButtons:(uint8_t)btns XPos:(int)x YPos:(int)y {
    PointerMsg pointerEvent;
    pointerEvent.msgType = PointerEvt_MsgType;
    pointerEvent.btnMask = btns;
    pointerEvent.xPosition = htons(x); //All multiple byte integers are Big Endian order except pixel values
    pointerEvent.yPosition = htons(y);
	NSData *wrapper = [NSData dataWithBytes:&pointerEvent
									 length:PointerMsg_Size];
    [self writeBytes:wrapper];
}

-(void)sendMultiplePointerEventsForIterations:(int)iterations setButtons:(uint8_t)buttons clearButtons:(uint8_t)clearBtns XPos:(int)x YPos:(int)y {
    PointerMsg pressedMsg, liftedMsg;
    pressedMsg.msgType = PointerEvt_MsgType;
    pressedMsg.btnMask = buttons;
    pressedMsg.xPosition = htons(x);
    pressedMsg.yPosition = htons(y);
    
    //Lifted
    liftedMsg.msgType = PointerEvt_MsgType;
    liftedMsg.btnMask = clearBtns;
    liftedMsg.xPosition = pressedMsg.xPosition; //No change in x/y when lifting mouse btn
    liftedMsg.yPosition = pressedMsg.yPosition; //No change in x/y when lifting mouse btn
    
    NSMutableData *wrapper = [NSMutableData dataWithCapacity:(2*iterations*PointerMsg_Size)];
    for (int i=0; i<iterations; i++) {
        [wrapper appendBytes:&pressedMsg
                      length:PointerMsg_Size];
        [wrapper appendBytes:&liftedMsg
                      length:PointerMsg_Size]; //Send both events 'together'
    }
    
    //More efficient to bundle multiple msgs in a single packet before sending
    [self writeBytes:wrapper];
}

-(void)sendKeyWithEvent:(RFBKeyEvent *)keyEvent {
	//TODO: Probably doesn't handle certain keys like modifiers and special characters
	
	//resolve the keysym
	int keysym = [KeyMapping unicharToX11KeySym:keyEvent.keyPress];
	[self sendKeyDown:keysym];
	[self sendKeyUp:keysym];
}

-(void)sendKeyDown:(int)keysym {
    KeyMsg keyDownMsg;
    keyDownMsg.msgType = KeyEvt_MsgType;
    keyDownMsg.downFlag = 1;
    keyDownMsg.padding = 0; //For clarity
    keyDownMsg.keyX11 = htonl(keysym);

	NSData *wrapper = [NSData dataWithBytes:&keyDownMsg
									 length:KeyMsg_Size];
    [self writeBytes:wrapper];
}

-(void)sendKeyUp:(int)keysym {
    KeyMsg keyUpMsg;
    keyUpMsg.msgType = KeyEvt_MsgType;
    keyUpMsg.downFlag = 0;
    keyUpMsg.padding = 0; //For clarity
    keyUpMsg.keyX11 = htonl(keysym);

	NSData *wrapper = [NSData dataWithBytes:&keyUpMsg
									 length:KeyMsg_Size];
    [self writeBytes:wrapper];
}

#pragma mark - Wrapper Getters for *SOME* CocoaAsyncSocket properties - Public
-(BOOL)isConnected {
	if (self.socket)
		return [self.socket isConnected];
	
	return NO;
}

-(BOOL)isDisconnected {
	if (self.socket)
		return [self.socket isDisconnected];
	
	return NO;
}

-(NSString *)connectedHost {
	if (self.socket)
		return [self.socket connectedHost];
	
	return nil;
}

-(uint16_t)connectedPort {
	if (self.socket)
		return [self.socket connectedPort];
	
	return 0;
}

//This is a 'struct sockaddr' value wrapped in a NSData object. If the socket is IPv4, the data will be of type 'struct sockaddr_in'. If the socket is IPv6, the data will be of type 'struct sockaddr_in6'.
-(NSData *)connectedAddress {
	if (self.socket)
		return [self.socket connectedAddress];
	
	return nil;
}

#pragma mark - CocoaAsyncSocket protocol delegate methods - Private - Connection
/**Comments for methods below lifted from GCDAsyncSocket Reference wiki**/

//Called when a socket connects and is ready to start reading and writing. The host parameter will be an IP address, not a DNS name.
- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port {
	DLogInf(@"Connected to %@ : %i", host, port);
	
}

#pragma mark - CocoaAsyncSocket protocol delegate methods - Private - Reading Data (input)
/*Called when a socket has completed reading the requested data into memory. Not called if there is an error.
 
 The tag parameter is the tag you passed when you requested the read operation. For example, in the readDataWithTimeout:tag: method.*/
- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
	DLog(@"Received data length: %lu", (unsigned long)data.length);
	DLog(@"Data: %@", data);
	self.readBuffer = data;
}

/*Called when a socket has read in data, but has not yet completed the read. This would occur if using readDataToData: or readDataToLength: methods. It may be used to for things such as updating progress bars.
 
 The tag parameter is the tag you passed when you requested the read operation. For example, in the readDataToLength:withTimeout:tag: method.*/
- (void)socket:(GCDAsyncSocket *)sock didReadPartialDataOfLength:(NSUInteger)partialLength tag:(long)tag {
	
}

/*Called if a read operation has reached its timeout without completing. This method allows you to optionally extend the timeout. If you return a positive time interval (> 0) the read's timeout will be extended by the given amount. If you don't implement this method, or return a non-positive time interval (<= 0) the read will timeout as usual.
 
 The elapsed parameter is the sum of the original timeout, plus any additions previously added via this method. The length parameter is the number of bytes that have been read so far for the read operation.
 
 Note that this method may be called multiple times for a single read if you return positive numbers.*/
- (NSTimeInterval)socket:(GCDAsyncSocket *)sock shouldTimeoutReadWithTag:(long)tag
				 elapsed:(NSTimeInterval)elapsed
			   bytesDone:(NSUInteger)length {
	DLogWar(@"Request timed out.  Bytes done %lu, time elapsed: %f", (unsigned long)length, elapsed);
	//Part of making reads synchronous
	self.requestReadyOrTimedOut = YES;
	
	return 0; //placeholder
}

#pragma mark - CocoaAsyncSocket protocol delegate methods - Private - Writing Data (output)
/*Called when a socket has completed writing the requested data. Not called if there is an error.
 
 The tag parameter is the tag you passed when you requested the write operation For example, in the writeData:withTimeout:tag: method.*/
- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag {
	DLog(@"Data sent");
	//Part of making reads synchronous
	//self.writeDoneOrTimedOut = YES;
}

/*Called when a socket has written some data, but has not yet completed the entire write. It may be used to for things such as updating progress bars.
 
 The tag parameter is the tag you passed when you requested the write operation For example, in the writeData:withTimeout:tag: method.*/
- (void)socket:(GCDAsyncSocket *)sock didWritePartialDataOfLength:(NSUInteger)partialLength tag:(long)tag {
	DLog(@"Sending data bytes: %lu", (unsigned long)partialLength);
}

/*Called if a write operation has reached its timeout without completing. This method allows you to optionally extend the timeout. If you return a positive time interval (> 0) the write's timeout will be extended by the given amount. If you don't implement this method, or return a non-positive time interval (<= 0) the write will timeout as usual.
 
 The elapsed parameter is the sum of the original timeout, plus any additions previously added via this method. The length parameter is the number of bytes that have been written so far for the write operation.
 
 Note that this method may be called multiple times for a single write if you return positive numbers.*/
- (NSTimeInterval)socket:(GCDAsyncSocket *)sock shouldTimeoutWriteWithTag:(long)tag
				 elapsed:(NSTimeInterval)elapsed
			   bytesDone:(NSUInteger)length {
	DLogWar(@"Write timed out.  Bytes done %lu, time elapsed: %f", (unsigned long)length, elapsed);
	//Part of making reads synchronous
	//self.writeDoneOrTimedOut = YES;
    
    //TODO: Setup error msg return call here?
	
	return 0; //placeholder
}

#pragma mark - CocoaAsyncSocket protocol delegate methods - Private - Socket Config
/*Called after the socket has successfully completed SSL/TLS negotiation. This method is not called unless you use the provided startTLS method.
 
 If a SSL/TLS negotiation fails (invalid certificate, etc) then the socket will immediately close, and the socketDidDisconnect:withError: delegate method will be called with the specific SSL error code.
 
 See Apple's SecureTransport.h file in Security.framework for the list of SSL error codes and their meaning.*/
- (void)socketDidSecure:(GCDAsyncSocket *)sock {
	
}

/*Called when a "server" socket accepts an incoming "client" connection. Another socket is automatically spawned to handle it.
 
 You must retain the newSocket if you wish to handle the connection. Otherwise the newSocket instance will be released and the spawned connection will be closed.
 
 By default the new socket will have the same delegate and delegateQueue. You may, of course, change this at any time.
 
 By default the socket will create its own internal socket queue to operate on. This is configurable by implementing the newSocketQueueForConnectionFromAddress:onSocket: method.*/
- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket {
	
}

/*This method is called immediately prior to socket:didAcceptNewSocket:. It optionally allows a listening socket to specify the socketQueue for a new accepted socket. If this method is not implemented, or returns NULL, the new accepted socket will create its own default queue.
 
 Since you cannot autorelease a dispatch_queue, this method uses the "new" prefix in its name to specify that the returned queue has been retained.
 
 Thus you could do something like this in the implementation:
 return dispatch_queue_create("MyQueue", NULL);
 If you are placing multiple sockets on the same queue, then care should be taken to increment the retain count each time this method is invoked.
 
 For example, your implementation might look something like this:
 dispatch_retain(myExistingQueue);
 return myExistingQueue;*/
- (dispatch_queue_t)newSocketQueueForConnectionFromAddress:(NSData *)address onSocket:(GCDAsyncSocket *)sock {
	
	return NULL; //placeholder
}

#pragma mark - CocoaAsyncSocket protocol delegate methods - Private - Socket Disconnection, Closes
/*Conditionally called if the read stream closes, but the write stream may still be writeable.
 
 This delegate method is only called if autoDisconnectOnClosedReadStream has been set to NO. See the discussion on the autoDisconnectOnClosedReadStream method for more information.*/
- (void)socketDidCloseReadStream:(GCDAsyncSocket *)sock {
	
}

/*Called when a socket disconnects with or without error.
 
 If you call the disconnect method, and the socket wasn't already disconnected, this delegate method will be called before the disconnect method returns. (Since the disconnect method is synchronous.)*/
- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)error {
	DLogInf(@"Disconnected");
    if (error)
        DLogErr(@"error description: %@, reason: %@", [error localizedDescription], [error localizedFailureReason]);
	//Part of making reads synchronous (for when attempting connection and not connected)
	self.requestReadyOrTimedOut = YES;
}
@end
