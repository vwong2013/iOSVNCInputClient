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

#import "RFBPointerEvent.h"

@implementation RFBPointerEvent
-(id)init {
    return [self initWithDt:0 Dx:0 Dy:0 Sx:0 Sy:0 V:CGPointZero Button1Pressed:NO Button2Pressed:NO ScrollSensitivity:0 ButtonPresses:0];
}

-(id)initWithDt:(NSTimeInterval)dt Dx:(float)dx Dy:(float)dy Sx:(float)sx Sy:(float)sy V:(CGPoint)v Button1Pressed:(BOOL)button1 Button2Pressed:(BOOL)button2 ScrollSensitivity:(int8_t)sS ButtonPresses:(int8_t)btnIts{
   	if ((self = [super init])) {
		_dt = dt;
		_dx = dx, _dy = dy;
		_button1 = button1;
		_button2 = button2;
		_sx = sx, _sy = sy;
        _v = v;
        _scrollSensitivity = sS;
        _buttonIterations = btnIts;
	}
	
	return self;
}
@end
