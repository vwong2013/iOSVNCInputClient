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

#import "RFBEvent.h"

@interface RFBPointerEvent : RFBEvent
@property (nonatomic, assign) NSTimeInterval dt; //delta time
@property (nonatomic, assign) float dx; //delta Pointer movement x/y
@property (nonatomic, assign) float dy;
@property (nonatomic, assign) BOOL button1;
@property (nonatomic, assign) BOOL button2;
@property (nonatomic, assign) float sx; //Scroll x/y
@property (nonatomic, assign) float sy;
@property (assign,nonatomic) CGPoint v; //Velocity, points per second, one for x and y
@property (assign,nonatomic) int8_t scrollSensitivity;
@property (assign,nonatomic) int8_t buttonIterations; //-1 for no automation (ie. hold button down); x+ for x pointer clicks.  eg. 1 = 1 button click.  0 = 0 clicks.

-(id)init;
-(id)initWithDt:(NSTimeInterval)dt Dx:(float)dx Dy:(float)dy Sx:(float)sx Sy:(float)sy V:(CGPoint)v Button1Pressed:(BOOL)button1 Button2Pressed:(BOOL)button2 ScrollSensitivity:(int8_t)sS ButtonPresses:(int8_t)btnIts;
@end
