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

#import "UIViewController+ErrorOverlay.h"
#import <QuartzCore/QuartzCore.h> //Masking
#import "UILabel+MultiLineAutoSize.h"
#import "UsefulMacros.h" //iOS version macro checks

#define ERRORMSG_TAG 2000
#define ERRORMSGBG_TAG 2001

@implementation UIViewController (ErrorOverlay)
-(void)displayErrorMessage:(NSString *)errorMsg {
    if (!errorMsg || errorMsg.length == 0)
        return;
    
    //Remove existing label if present
    [self removeErrorMessage];
    
	NSUInteger viewWidth = self.view.frame.size.width;
    
	//Adjust UILabel to width of supplied text
	UIFont *font = [UIFont systemFontOfSize:15];
    
    //Temp.. will redefined once added inside subview
    float labelWidth = viewWidth-10;
    float labelHeight = [font lineHeight];
   	float errTextX = 0; //temp values
	float errTextY = 5;
	
    UILabel *errText = [[UILabel alloc] initWithFrame:CGRectMake(errTextX, errTextY, labelWidth, labelHeight)];
	errText.text = errorMsg;
    errText.minimumFontSize = 12;
	errText.font = font;
	errText.textColor = [UIColor redColor];
    errText.numberOfLines = 0; //use as many lines as needed
    
    //iOS version compatibility
    if (IS_IOS6_AND_UP) {
        errText.textAlignment = NSTextAlignmentCenter;
        errText.lineBreakMode = NSLineBreakByWordWrapping;
    } else { //iOS 5+
        errText.textAlignment = NSTextAlignmentCenter;
        errText.lineBreakMode = UILineBreakModeWordWrap;
    }
    
    errText.backgroundColor = [UIColor clearColor];
    
	[errText setTag:ERRORMSG_TAG];
    [errText setAutoresizingMask:UIViewAutoresizingFlexibleBottomMargin| UIViewAutoresizingFlexibleWidth];    
    
    //Setup background
    float bgWidth = labelWidth;
    float bgHeight = 50; //dummy value
    float bgStartX = (viewWidth-bgWidth)/2;
    float bgStartY = 10; //(viewHeight-bgHeight)/2;
    UIView *errBackground = [[UIView alloc] initWithFrame:CGRectMake(bgStartX, bgStartY, bgWidth, bgHeight)];
    errBackground.backgroundColor = [UIColor whiteColor];
    errBackground.alpha = 0.9;
    errBackground.tag = ERRORMSGBG_TAG;
    [errBackground setAutoresizingMask:UIViewAutoresizingFlexibleBottomMargin| UIViewAutoresizingFlexibleWidth];
    
    //Add to BG view
    [errBackground addSubview:errText];
    
    //Resize label given a font size to the match superview
    [errText sizeToFit];
    
    //reseize again
    //Reposition errText for inside the BG
    errTextX = (bgWidth-errText.frame.size.width)/2;
    [errText setFrame:CGRectMake(errTextX, errTextY, errText.frame.size.width, errText.frame.size.height)];
    
    //Resize BG view to now match adjusted label frame
    [errBackground setFrame:CGRectMake(bgStartX, bgStartY, bgWidth, (errText.frame.size.height+10))]; //+10 height padding
    
    //Setup mask for rounded background corners
    errBackground.layer.mask = [[self class] roundCornerMaskForView:errBackground];
    
    //Helps stop BG's alpha from being inherited by the subviews, despite documentation suggesting this doesn't happen
    errBackground.layer.shouldRasterize = YES;
    errBackground.layer.rasterizationScale =[[UIScreen mainScreen] scale];  //Avoid blurry images on Retina
    
    //Add combined view to VC's view
    [self.view addSubview:errBackground];
}

-(void)removeErrorMessage {
    UIView *errBG = (UIView *)[self.view viewWithTag:ERRORMSGBG_TAG];
    if (!errBG)
        return; //Do nothing if subview doesn't exist
    
	UILabel *errorText = (UILabel *)[errBG viewWithTag:ERRORMSG_TAG];
	if (errorText)
		[errorText removeFromSuperview];
    
    [errBG removeFromSuperview];  
}

//For responding to orientation changes/changed 
-(void)refreshErrorMessagePosition {
    UIView *errBG = (UIView *)[self.view viewWithTag:ERRORMSGBG_TAG];
    if (!errBG)
        return; //Do nothing if subview doesn't exist
    
    //Update the rounded corner mask on rotation
    errBG.layer.mask = [[self class] roundCornerMaskForView:errBG];
}

#pragma mark - Private
+(CAShapeLayer *)roundCornerMaskForView:(UIView *)view {
    UIBezierPath *maskPath;
    maskPath = [UIBezierPath bezierPathWithRoundedRect:view.bounds byRoundingCorners:UIRectCornerAllCorners cornerRadii:CGSizeMake(10.0, 10.0)];
    
    CAShapeLayer *maskLayer = [[CAShapeLayer alloc] init];
    maskLayer.frame = view.bounds;
    maskLayer.path = maskPath.CGPath;
    
    return maskLayer;
}
@end
