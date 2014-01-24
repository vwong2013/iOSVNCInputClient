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

#import "RFBInputViewController.h"

#import "UILabel+MultiLineAutoSize.h"
#import "UIViewController+Spinner.h"
#import "UIViewController+ErrorOverlay.h"

#import "RFBInputView.h" //Implement delegate protocol
#import "ServerProfile.h"
#import "RFBInputConnManager.h"
#import "TouchInputTracker.h"
#import "VersionMsg.h"

#import "RFBEvent.h"
#import "RFBKeyEvent.h"
#import "RFBPointerEvent.h"

#define HELPMSG_TAG 1000

@interface RFBInputViewController () <KeyboardInputDelegate, RFBInputConnManagerDelegate>
@property (strong, nonatomic) RFBInputConnManager *rfbInputConnMgr;
@property (strong, nonatomic) TouchInputTracker *touchInputTrkr;
@end

@implementation RFBInputViewController
- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
	
	//Add show keyboard button into navigation bar
    self.navigationItem.rightBarButtonItem = [self showKeyboardButton];
    self.navigationItem.rightBarButtonItem.enabled = NO; //Enable after successful connection
    
	//Set view delegate for keyboardInputDelegate protocol
	((RFBInputView *)self.view).delegate = self;
	
	//Add gesture recognizers for mouse control
	[self setupGestureRecognizers];
    
	//establish connection
	//Note: No need to check and deal with ard compat... handled in RFBConnection - just init the connection with supplied profile
	//Load connection mgr if profile present
	if (self.serverProfile) {
		self.rfbInputConnMgr = [[RFBInputConnManager alloc] initWithProfile:self.serverProfile
															ProtocolDelegate:self];
        [self.rfbInputConnMgr start];
    } else {
        [self displayErrorMessage:NSLocalizedString(@"No VNC server to connect to", @"InputVC No Server Found Text")];
    }
}

-(void)viewWillDisappear:(BOOL)animated	{
	//Get rid of any existing dynamic text
	[self removeErrorMessage];
	[self stopSpinner];
	
	//Get rid of VNC connection
	[self.rfbInputConnMgr stop];
	self.rfbInputConnMgr = nil;
	DLogInf(@"Unloading Mouse View");
	
	[super viewWillDisappear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)dealloc {
    DLogInf(@"InputVC dealloc!");
    [self.rfbInputConnMgr stop]; //Must stop manually or stuff gets stuck in memory
}

#pragma mark - Orientation view control methods
- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    [self refreshSpinnerPosition]; //Refresh spinner position if present in view
    [self refreshErrorMessagePosition]; //Refresh error msg position and size if present in view
}

#pragma mark - navigation button overrides
-(UIBarButtonItem *)showKeyboardButton {
	UIBarButtonItem *showKBButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCompose
																				  target:self
																				  action:@selector(showKeyboard:)];
	return showKBButton;
}

-(void)showKeyboard:(UIBarButtonItem *)sender {
	if ([self.view isFirstResponder])
		[self.view resignFirstResponder];
	else
		[self.view becomeFirstResponder];
}

#pragma mark - Mouse input - Gesture Recognizer Setup Methods
-(void)setupGestureRecognizers {
	//init
	UITapGestureRecognizer *singleFingerTap = [[UITapGestureRecognizer alloc] initWithTarget:self
																					  action:@selector(singleFingerTap:)];
	UITapGestureRecognizer *doubleFingerTap = [[UITapGestureRecognizer alloc] initWithTarget:self
																					  action:@selector(doubleFingerTap:)];
	UITapGestureRecognizer *threeFingerTap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                     action:@selector(threeFingerTap:)];
    UILongPressGestureRecognizer *longTap = [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                                                        action:@selector(longSingleFingerTap:)];
	UIPanGestureRecognizer *singleFingerDrag = [[UIPanGestureRecognizer alloc] initWithTarget:self
																					  action:@selector(singleFingerDrag:)];
	UIPanGestureRecognizer *doubleFingerDrag = [[UIPanGestureRecognizer alloc] initWithTarget:self
																					  action:@selector(doubleFingerDrag:)];
	
	//Configure
	doubleFingerTap.numberOfTouchesRequired = 2;
    threeFingerTap.numberOfTouchesRequired = 3;
    longTap.minimumPressDuration = 0.4; //0.4 seconds instead of 0.5 default
	singleFingerDrag.minimumNumberOfTouches = 1;
	singleFingerDrag.maximumNumberOfTouches = singleFingerDrag.minimumNumberOfTouches;
	doubleFingerDrag.minimumNumberOfTouches = 2;
	doubleFingerDrag.maximumNumberOfTouches = doubleFingerDrag.minimumNumberOfTouches;
	
	//Add to View
	[self.view addGestureRecognizer:singleFingerTap];
	[self.view addGestureRecognizer:doubleFingerTap];
    [self.view addGestureRecognizer:threeFingerTap];
    [self.view addGestureRecognizer:longTap];
	[self.view addGestureRecognizer:singleFingerDrag];
	[self.view addGestureRecognizer:doubleFingerDrag];
}

#pragma mark - Mouse input - Gesture Recognizer Action Selectors
//button 1
-(void)singleFingerTap:(UITapGestureRecognizer *)tapper {
	DLog(@"singleFingerTap");
    //Package action into PointerEvent
    RFBPointerEvent *tapEvent = [[RFBPointerEvent alloc] initWithDt:0 Dx:0 Dy:0 Sx:0 Sy:0 V:CGPointZero Button1Pressed:YES Button2Pressed:NO ScrollSensitivity:0 ButtonPresses:1];
    //BWRFBPointerEvent *tapOffEvent = [[BWRFBPointerEvent alloc] init];
    //Send to server
    [self.rfbInputConnMgr sendEvent:tapEvent];
    //[self.rfbInputConnMgr sendEvent:tapOffEvent];
}

//button 2
-(void)doubleFingerTap:(UITapGestureRecognizer *)tapper {
	DLog(@"doubleFingerTap");
    RFBPointerEvent *tapEvent = [[RFBPointerEvent alloc] initWithDt:0 Dx:0 Dy:0 Sx:0 Sy:0 V:CGPointZero Button1Pressed:NO Button2Pressed:YES ScrollSensitivity:0 ButtonPresses:1];
    //BWRFBPointerEvent *tapOffEvent = [[BWRFBPointerEvent alloc] init];
    [self.rfbInputConnMgr sendEvent:tapEvent];
    //[self.rfbInputConnMgr sendEvent:tapOffEvent];
}

//button1 and button2
-(void)threeFingerTap:(UITapGestureRecognizer *)tapper {
	DLog(@"threeFingerTap");    
    RFBPointerEvent *tapEvent = [[RFBPointerEvent alloc] initWithDt:0 Dx:0 Dy:0 Sx:0 Sy:0 V:CGPointZero Button1Pressed:YES Button2Pressed:YES ScrollSensitivity:0 ButtonPresses:1];
    //BWRFBPointerEvent *tapOffEvent = [[BWRFBPointerEvent alloc] init];
    [self.rfbInputConnMgr sendEvent:tapEvent];
    //[self.rfbInputConnMgr sendEvent:tapOffEvent];
}

//button1 hold and drag
-(void)longSingleFingerTap:(UILongPressGestureRecognizer *)lpresser {
    if (lpresser.state == UIGestureRecognizerStateBegan) {
        DLog(@"LP start");
        [self.touchInputTrkr pointerEventInitialPositionForGesture:lpresser];
    } else if (lpresser.state == UIGestureRecognizerStateChanged) {
        RFBPointerEvent *tapHoldEvent = [self.touchInputTrkr button1HoldPointerEventForGesture:lpresser];
        [self.rfbInputConnMgr sendEvent:tapHoldEvent];
    } else if (lpresser.state == UIGestureRecognizerStateEnded) {
        DLog(@"LP end");        
        [self.touchInputTrkr clearStoredInitialPosition];
        RFBPointerEvent *tapHoldEndEvent = [[RFBPointerEvent alloc] init];
        [self.rfbInputConnMgr sendEvent:tapHoldEndEvent];
    }
}

//moving
-(void)singleFingerDrag:(UIPanGestureRecognizer *)panner {
    DLog(@"singleFingerDRAG");
    RFBPointerEvent *panEvent = [self.touchInputTrkr pointerEventForPanGesture:panner];
    [self.rfbInputConnMgr sendEvent:panEvent];
}

//Scrolling
-(void)doubleFingerDrag:(UIPanGestureRecognizer *)panner {
	DLog(@"doubleFingerDRAG");
    RFBPointerEvent *panEvent = [self.touchInputTrkr pointerEventForPanGesture:panner];
    [self.rfbInputConnMgr sendEvent:panEvent];
}

#pragma mark - KB input - KeyboardInputDelegate protocol methods
-(void)rfbInputView:(RFBInputView *)view receivedKey:(unichar)keycode {
    //Package keypress into Event object
    RFBKeyEvent *keyEvent = [[RFBKeyEvent alloc] initWithKeypress:keycode];    
    //Send to server
    [self.rfbInputConnMgr sendEvent:keyEvent];
}

#pragma mark - RFB Connection - RFBInputConnManagerDelegate protocol methods
//Basically used to inform when to start / stop certain animations, display errors etc
-(void)rfbInputConnManager:(RFBInputConnManager *)inputConnMgr performedAction:(ActionList)action encounteredError:(NSError *)error {
	if (error != nil) {
        [self stopSpinner];                
		NSString *errorMsg = [NSLocalizedString(@"Encountered Problem: ", @"InputVC Error Text") stringByAppendingString:[error localizedDescription]];
		[self displayErrorMessage:errorMsg];
        self.helpTextView.hidden = YES;
		return; //break method early
	}
	
	[self removeErrorMessage];
    self.helpTextView.hidden = NO;
	
	switch (action) {
		case CONNECTION_START:
			[self startSpinnerWithWaitText:NSLocalizedString(@"Connecting...", @"InputVC Connection Start Text")];
			break;
		case CONNECTION_END:
			[self stopSpinner];
            self.touchInputTrkr = [[TouchInputTracker alloc] initWithScaleFactor:[self.rfbInputConnMgr serverScaleFactor]]; //Create scaled pointer events for movement/scrolling
            self.navigationItem.rightBarButtonItem.enabled = YES; //Enable after successful connection
			break;
		case DISCONNECTION_START:
			[self startSpinnerWithWaitText:NSLocalizedString(@"Disconnecting...", @"InputVC Disconnection Start Text")];
            self.navigationItem.rightBarButtonItem.enabled = NO;
			break;
		case DISCONNECTION_END:
            //DLog(@"input conn mgr stop end reached");
            self.touchInputTrkr = nil;
			[self stopSpinner];
			break;
		case INPUT_EVENT: //do nothing
			break;			
		default: //do nothing
			break;
	}
}
- (void)viewDidUnload {
    [self setHelpTextView:nil];
    [super viewDidUnload];
}
@end
