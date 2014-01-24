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

//  Keep track of last coordinates, create RFBPointerEvents with scaling applied
//  using supplied Gesture Recognizers / Touches.

#import "TouchInputTracker.h"
#import "RFBPointerEvent.h"

#define ScrollSpeed 20

@interface TouchInputTracker()
@property (assign,nonatomic) CGFloat lastX, lastY;
@property (assign,nonatomic) NSTimeInterval lastTouchBegan;
@end

@implementation TouchInputTracker
-(id)init {
    return [self initWithScaleFactor:CGPointZero];
}

-(id)initWithScaleFactor:(CGPoint)scaleFactor {
    if ((self = [super init])) {
        _scaleFactor = ((scaleFactor.x+scaleFactor.y)/2); //Use a single average scale factor
        //Ceiling or floor for scaling factor for sensitivity purposes
        DLog(@"Avg scaling before cap/floor %f", _scaleFactor);
        if (_scaleFactor < 2.6)
            _scaleFactor = 2.6;
        else if (_scaleFactor > 6) 
            _scaleFactor = 6;
    }
    
    return self;
}

-(void)dealloc {
    DLogInf(@"TouchInputTracker dealloc");
}

#pragma mark - Pointer Event Creation Methods - Public
-(RFBPointerEvent *)pointerEventForPanGesture:(UIPanGestureRecognizer *)panner {
    CGPoint touchVelocity = [panner velocityInView:panner.view];
    
    //Obtain delta (1st translationInView is always the delta)
    CGPoint touchDelta = [panner translationInView:panner.view];
    //Reset translation for picking up delta again next time
    [panner setTranslation:CGPointZero inView:panner.view];

    //Apply scaling factor
    CGPoint scaledDelta = [self applyScaleFactorToPoints:touchDelta];

	//DLog(@"touchTracker: transInView: %@, adjusted transInView: %@", NSStringFromCGPoint(touchDelta), NSStringFromCGPoint(scaledDelta));
    
    if (panner.maximumNumberOfTouches == 1) { //Movement
        return [[RFBPointerEvent alloc] initWithDt:0 Dx:scaledDelta.x Dy:scaledDelta.y Sx:0 Sy:0 V:touchVelocity Button1Pressed:NO Button2Pressed:NO ScrollSensitivity:ScrollSpeed ButtonPresses:0];
    } else if (panner.maximumNumberOfTouches == 2) { //Scroll
        return [[RFBPointerEvent alloc] initWithDt:0 Dx:0 Dy:0 Sx:scaledDelta.x Sy:scaledDelta.y V:touchVelocity Button1Pressed:NO Button2Pressed:NO ScrollSensitivity:ScrollSpeed ButtonPresses:0];
    }
    
    return nil; //We don't support any other panner outside of criteria
}

-(void)pointerEventInitialPositionForGesture:(UIGestureRecognizer *) gesture {
    CGPoint currentLocation = [gesture locationInView:gesture.view];
    self.lastTouchBegan = [NSDate timeIntervalSinceReferenceDate];
    self.lastX = currentLocation.x;
    self.lastY = currentLocation.y;
}

-(void)clearStoredInitialPosition {
    self.lastX = -1;
    self.lastY = -1;
    self.lastTouchBegan = 0;
}

-(RFBPointerEvent *)button1HoldPointerEventForGesture:(UIGestureRecognizer *)gesture {
    if (self.lastTouchBegan == 0 || self.lastX == -1 || self.lastY == -1)
        return nil; //not initialised
    
    CGPoint currentLocation = [gesture locationInView:gesture.view];
    NSTimeInterval touchTime = [NSDate timeIntervalSinceReferenceDate];
    
    //Work out dt, dx, dy
    double dt = touchTime-self.lastTouchBegan;
    float dx = currentLocation.x - self.lastX;
    float dy = currentLocation.y - self.lastY;
    //DLog(@"dx %f, dy %f, dt: %f", dx, dy, dt);
    
    //Work out velocity
    float vx = dx/dt;
    float vy = dy/dt;
    //DLog(@"vx %f, vy %f", vx, vy);
    
    //Scale
    CGPoint scaledDelta = [self applyScaleFactorToPoints:CGPointMake(dx, dy)];
    
    //Update last touch values
    self.lastTouchBegan = touchTime;
    self.lastX = currentLocation.x;
    self.lastY = currentLocation.y;
    
    return [[RFBPointerEvent alloc] initWithDt:0 Dx:scaledDelta.x Dy:scaledDelta.y Sx:0 Sy:0 V:CGPointMake(vx, vy) Button1Pressed:YES Button2Pressed:NO ScrollSensitivity:0 ButtonPresses:-1];
}

#pragma mark - Misc Methods - Private
-(CGPoint)applyScaleFactorToPoints:(CGPoint)inputPoints {
//    if (CGPointEqualToPoint(CGPointZero, self.scaleFactor))
    if (self.scaleFactor == 0)
        return inputPoints; //Do nothing if 0 scaling factor
    
    CGFloat scaledX = inputPoints.x * self.scaleFactor;
    CGFloat scaledY = inputPoints.y * self.scaleFactor;
    return CGPointMake(scaledX, scaledY);
}
@end
