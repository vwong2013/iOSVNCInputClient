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

//  Convenience methods to allow easy creation of a centred spinner view with
//  accompanying "wait" text and dark background rectangle for contrast.

#import "UIViewController+Spinner.h"
#import <QuartzCore/QuartzCore.h> //Masking

#define NSLineBreakByWordWrapping UILineBreakModeWordWrap //iOS5 compatibility
#define NSTextAlignmentCenter UITextAlignmentCenter //iOS5 compatibility

#define SPINBG_TAG 100000
#define SPINVIEW_TAG 101000
#define SPINVIEWMSG_TAG 102000

@implementation UIViewController (Spinner)
-(void)startSpinnerWithWaitText:(NSString *)waitText {
    [self stopSpinner]; //stop spinner before starting another one
    
	NSUInteger viewWidth = self.view.frame.size.width;
	NSUInteger viewHeight = self.view.frame.size.height;
    
    //Flip dimensions when in landscape, as that is the perceived dimensions from the user's pov.
    //Required as there seems to be a possible bug with UIActivityIndicatorView with reported orientation dimensions (in iOS5.1 at least)
    if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation)) {
        viewHeight = self.view.frame.size.width;
        viewWidth = self.view.frame.size.height;
    }
    
	//Setup spinner
	UIActivityIndicatorView *spinView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
	NSUInteger spinWidth = spinView.frame.size.width;
	NSUInteger spinHeight = spinView.frame.size.height;
	[spinView setTag:SPINVIEW_TAG];
	
	//Setup label accompanying spinner
    NSString *waitingText = @"";
    if (waitText && waitText.length > 0)
        waitingText = waitText;
    
	//Adjust UILabel to width of supplied text
	CGFloat textSize;
	//UIFont *font = [UIFont fontWithName:@"Helvetica-Bold" size:14];
    UIFont *font = [UIFont boldSystemFontOfSize:14];
	[waitingText sizeWithFont:font
			   minFontSize:10
			actualFontSize:&textSize
				  forWidth:viewWidth
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wenum-conversion"
			 lineBreakMode:NSLineBreakByWordWrapping];
#pragma clang diagnostic pop

	CGSize actualSize = [waitingText sizeWithFont:[UIFont boldSystemFontOfSize:textSize]];
	float spinTextX = 0; //Temp value
	float spinTextY = 0; //Temp value
	UILabel *spinText = [[UILabel alloc] initWithFrame:CGRectMake(spinTextX, spinTextY, actualSize.width, actualSize.height)];
	spinText.text = waitingText;
	spinText.font = font;
    spinText.textColor = [UIColor whiteColor];
    spinText.shadowColor = [UIColor blackColor];
    spinText.backgroundColor = [UIColor clearColor]; //Setting to default of 'nil' doesn't result in a transparent BG
	[spinText setTag:SPINVIEWMSG_TAG];
    
    //Setup background for spinner and text
    float bgWidth = ((spinWidth > actualSize.width) ? spinWidth : actualSize.width) + 50; //arbitrary padding
    float bgHeight = spinHeight + (actualSize.height + 10) + 30;
    float bgStartX = (viewWidth-bgWidth)/2;
    float bgStartY = (viewHeight-bgHeight)/2;
    UIView *spinBackground = [[UIView alloc] initWithFrame:CGRectMake(bgStartX, bgStartY, bgWidth, bgHeight)];
    spinBackground.backgroundColor = [UIColor blackColor];
    spinBackground.alpha = 0.7;
    spinBackground.tag = SPINBG_TAG;
    
    //Setup mask for rounded background corners
    UIBezierPath *maskPath;
    maskPath = [UIBezierPath bezierPathWithRoundedRect:spinBackground.bounds byRoundingCorners:UIRectCornerAllCorners cornerRadii:CGSizeMake(10.0, 10.0)];
    
    CAShapeLayer *maskLayer = [[CAShapeLayer alloc] init];
    maskLayer.frame = spinBackground.bounds;
    maskLayer.path = maskPath.CGPath;
    spinBackground.layer.mask = maskLayer;

    //Set frame for spinner and text in context of spinBG
	float spinLocationX = (bgWidth-spinWidth)/2;
	float spinLocationY = (bgHeight-spinHeight)/2;
    [spinView setFrame:CGRectMake(spinLocationX, spinLocationY, spinWidth, spinHeight)];
	[spinView startAnimating];
    
    spinTextX = (bgWidth-actualSize.width)/2;
    spinTextY = spinLocationY + spinHeight + 10; //10 = arbitrary padding
    [spinText setFrame:CGRectMake(spinTextX, spinTextY, actualSize.width, actualSize.height)];
    
    //Add to spinBG
    [spinBackground addSubview:spinView];
    [spinBackground addSubview:spinText];
    
    //Helps stop spinBG's alpha from being inherited by the subviews, despite documentation suggesting this doesn't happen
    spinBackground.layer.shouldRasterize = YES;
    spinBackground.layer.rasterizationScale =[[UIScreen mainScreen] scale];  //Avoid blurry images on Retina
    
    //Add combined view to VC's view
    [self.view addSubview:spinBackground];
}

-(void)stopSpinner {
    UIView *spinBG = (UIView *)[self.view viewWithTag:SPINBG_TAG];
    if (!spinBG)
        return; //Do nothing if subview doesn't exist
    
	UIActivityIndicatorView *spinView = (UIActivityIndicatorView *)[spinBG viewWithTag:SPINVIEW_TAG];
	if (spinView) {
		[spinView stopAnimating];
		[spinView removeFromSuperview];
	}
	UILabel *spinText = (UILabel *)[spinBG viewWithTag:SPINVIEWMSG_TAG];
	if (spinText)
		[spinText removeFromSuperview];
    
    [spinBG removeFromSuperview];    
}

//For responding to orientation changes/changed while spinner is still running
-(void)refreshSpinnerPosition {
    UIView *spinBG = (UIView *)[self.view viewWithTag:SPINBG_TAG];
    if (!spinBG)
        return; //Do nothing if subview doesn't exist
    
    spinBG.center = self.view.center;
}
@end
