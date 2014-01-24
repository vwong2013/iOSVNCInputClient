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

//Modified from source: http://stackoverflow.com/questions/9059631/autoshrink-on-a-uilabel-with-multiple-lines

#import "UILabel+MultiLineAutoSize.h"
#import "UsefulMacros.h" //iOS version macro checks

@implementation UILabel (MultiLineAutoSize)
//Note: Must set number of lines > 1 or it just makes the text really small....
-(void)adjustFontSizeToFit
{
	//iOS runtime version check for pre iOS6.0 compatibility
	CGFloat scalingFactor;
    if (IS_IOS5_AND_UP && !IS_IOS6_AND_UP)
        scalingFactor = self.minimumFontSize; //iOS 5 compat
	else
		scalingFactor = self.minimumScaleFactor; //iOS 6+
	
	//Must trim whitespace to avoid resize fail
    self.text = [self.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	
    UIFont *font = self.font;
    CGSize size = self.frame.size;
	
    for (CGFloat maxSize = self.font.pointSize; maxSize >= scalingFactor; maxSize -= 1.f)
    {
        font = [font fontWithSize:maxSize];
        CGSize constraintSize = CGSizeMake(size.width, MAXFLOAT);
        
		//iOS runtime version check for various iOS version compatibility
        CGSize labelSize;
        if (IS_IOS7_AND_UP) { //iOS 7+
            NSDictionary *fontAttributes = [NSDictionary dictionaryWithObject:font
                                                                      forKey:NSFontAttributeName];
            labelSize = [self.text boundingRectWithSize:constraintSize
                                                options:NSStringDrawingUsesLineFragmentOrigin
                                             attributes:fontAttributes
                                                context:nil].size;
        }
		else if (IS_IOS6_AND_UP && !IS_IOS7_AND_UP) //iOS 6
			labelSize = [self.text sizeWithFont:font
                              constrainedToSize:constraintSize
                                  lineBreakMode:NSLineBreakByWordWrapping];
        else //iOS 5
            labelSize = [self.text sizeWithFont:font
                              constrainedToSize:constraintSize
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wenum-conversion"
                                  lineBreakMode:UILineBreakModeWordWrap];
#pragma clang diagnostic pop
        
            
        if(labelSize.height <= size.height)
        {
            self.font = font;
            [self setNeedsLayout];
            break;
        }
    }
    // set the font to the minimum size anyway
    self.font = font;
    [self setNeedsLayout];
}
@end
