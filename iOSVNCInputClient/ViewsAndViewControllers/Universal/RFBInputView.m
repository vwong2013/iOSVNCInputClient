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

#import "RFBInputView.h"

@interface RFBInputView() <UIKeyInput>

@end

@implementation RFBInputView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if ((self = [super initWithCoder:aDecoder])) {
        // initialization
    }
    
    return self;
}

#pragma mark - keyboard related method overrides
-(BOOL)canBecomeFirstResponder {
	return YES;
}

#pragma mark - UIKeyInput Protocol Methods
//UIKeyInput protocol to capture keyboard input in view
-(void)insertText:(NSString *)text {
	DLog(@"Key pressed: %@, Number: %hu", text, [text characterAtIndex:0]);
	//Pass key input as keycode to delegate if set
	if (self.delegate) {
		[self.delegate rfbInputView:self receivedKey:[text characterAtIndex:0]];
	}
}

-(BOOL)hasText {
	DLog(@"hasText fired");
	return NO;
}

-(void)deleteBackward {
	DLog(@"Delete key pressed");
	if (self.delegate) {
		[self.delegate rfbInputView:self receivedKey:0x08]; //8 = BS in Ascii
	}
}
@end
