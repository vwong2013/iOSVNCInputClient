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

/*RFB Protocol Structs*/
#define PointerMsg_Size 6
#define PointerEvt_MsgType 5
typedef struct {
    uint8_t msgType; //Must be PointerMsg_MsgType
    uint8_t btnMask; //btn 1-8 = bits 0-7, 0=off, 1=pressed
    uint16_t xPosition;
    uint16_t yPosition;
}PointerMsg;

#define KeyMsg_Size 8
#define KeyEvt_MsgType 4
typedef struct {
    uint8_t msgType;    //KeyEvt_MsgType
    uint8_t downFlag;   //0 = released, 1 = pressed
    uint16_t padding;   //0's
    uint32_t keyX11;    //X11 keysym value
}KeyMsg;


#define PixelFormatMsg_Size 16
typedef struct {
    uint8_t bitsPerPixel;
    uint8_t depth;
    uint8_t bigEndianFlag;
    uint8_t trueColourFlag;
    uint16_t redMax;
    uint16_t greenMax;
    uint16_t blueMax;
    uint8_t redShift;
    uint8_t greenShift;
    uint8_t blueShift;
    uint16_t paddingTwoBytes;
    uint8_t paddingOneByte;
}PixelFormatMsg;

#define PixelFormatClientMsg_Size 19
#define PixelFormatClient_MsgType 0
typedef struct {
    uint8_t msgType;    //Must be PixelFormatClient_MsgType
    uint8_t paddingOneByte;
    uint16_t paddingTwoBytes;
    PixelFormatMsg pixelFormat;
}PixelFormatClientMsg;

/*RFB Protocol Structs End*/

@class VersionMsg, RFBKeyEvent;

@interface RFBSocket : NSObject
#pragma mark - Init, Connection
-(id)initWithAddress:(NSString *)address Port:(int)port;
-(BOOL)connect:(NSError **)connErr;
-(void)disconnect;

#pragma mark - GCDAsyncSocket underlying Socket Options
-(BOOL)setTCPNoDelay:(BOOL)on;

#pragma mark - Read methods
-(NSString *)readString;
-(NSData *)readReceived:(int)length;
-(uint16_t)readShort;

-(VersionMsg *)readVersion;
-(NSData *)readSecurity;
-(uint32_t)readSecurityResult;
-(void)readAndDiscard;

#pragma mark - Write methods
-(void)writeBytes:(NSData *)wrapper;

-(void)writeVersion:(int)version;
-(void)writeSecurity:(uint8_t)securityType;

#pragma mark - RFB Event Methods
-(NSArray *)performInitialization;
//-(void)sendSetPixelFormat:(PixelFormatMsg *)pfMsg;

-(void)sendPointerEventWithButtons:(uint8_t)btns XPos:(int)x YPos:(int)y;
//For multiple, sequential mouse 'button' events
-(void)sendMultiplePointerEventsForIterations:(int)iterations setButtons:(uint8_t)buttons clearButtons:(uint8_t)clearBtns XPos:(int)x YPos:(int)y;

-(void)sendKeyWithEvent:(RFBKeyEvent *)keyEvent;
-(void)sendKeyDown:(int)keysym;
-(void)sendKeyUp:(int)keysym;

#pragma mark - Wrapper Getters for some CocoaAsyncSocket properties - Public
-(BOOL)isConnected;
-(BOOL)isDisconnected;
-(NSString *)connectedHost;
-(uint16_t)connectedPort;
-(NSData *)connectedAddress; //This is a 'struct sockaddr' value wrapped in a NSData object. If the socket is IPv4, the data will be of type 'struct sockaddr_in'. If the socket is IPv6, the data will be of type 'struct sockaddr_in6'.

@end
