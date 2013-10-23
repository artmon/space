//
//  DrawerViewController.m
//  Space
//
//  Created by Nigel Brooke on 2013-08-20.
//  Copyright (c) 2013 University of British Columbia. All rights reserved.
//

#import "DrawerViewController.h"
#import "Notifications.h"
#import "Constants.h"
#import "Note.h"
#import "Coordinate.h"

@interface DrawerViewController () {
    CanvasViewController* _topDrawerContents;
    CanvasViewController* _bottomDrawerContents;
}

@property (nonatomic) UIView* topDragHandle;
@property (nonatomic) UIView* bottomDragHandle;
@property (nonatomic) CGPoint dragStart;
@property (nonatomic) float initialFrameY;
@property (nonatomic) BOOL haveLayedOut;

@property (nonatomic) BOOL allowDrag;
@property (nonatomic) float allowedDragStartY;
@property (nonatomic) BOOL allowedDragStartYAssigned;

@property (nonatomic) BOOL fromTopDragHandle;
@property (nonatomic) BOOL fromBotDragHandle;

@property (nonatomic) float newPosition;

@property (nonatomic) CGSize realScreenSize;

@property (nonatomic) float maxY;
@property (nonatomic) float restY;
@property (nonatomic) float minY;

@property (nonatomic) float topDrawerHeight;
@property (nonatomic) float bottomDrawerHeight;
@property (nonatomic) float bottomDrawerStart;

@property (nonatomic) BOOL canvasesAreSlidOut;
@property (nonatomic) float slideAmountInPercentage;

@property (nonatomic) float currentDrawerYInPercentage;

@property (nonatomic) CGRect topCanvasFrameBeforeSlidingOut;

@property (strong, nonatomic) UIDynamicAnimator* animator;
@property (strong, nonatomic) UIDynamicItemBehavior* drawerBehavior;
@property (strong, nonatomic) UICollisionBehavior* collision;
@property (strong, nonatomic) UIGravityBehavior* gravity;
@property (nonatomic) BOOL isDownwardGravity;

@end

@implementation DrawerViewController

#pragma mark - Initial Setup

-(void)viewDidLoad {
    [super viewDidLoad];
    
    [self setEdgesForExtendedLayout:UIRectEdgeNone];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(slideOutCanvases) name:kFocusNoteNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(slideInCanvases) name:kNoteDismissedNotification object:nil];
    
    self.view.backgroundColor = [UIColor clearColor];
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    self.topDragHandle = [[UIView alloc] init];
    self.bottomDragHandle = [[UIView alloc] init];

    self.topDragHandle.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin;
    self.topDragHandle.backgroundColor = [UIColor clearColor];
    [self.view addSubview:self.topDragHandle];

    self.bottomDragHandle.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin;
    self.bottomDragHandle.backgroundColor = [UIColor clearColor];
    [self.view addSubview:self.bottomDragHandle];
    
    self.isDownwardGravity = YES;
}

-(void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [self drawCanvasLayout];
    [self stopPhysicsEngine];
    [self startPhysicsEngine];
    
    UITapGestureRecognizer* tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapOutsideOfCanvases:)];
    [self.view addGestureRecognizer:tapGestureRecognizer];
    
    UIPanGestureRecognizer* panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panOutsideOfCanvases:)];
    [self.view addGestureRecognizer:panGestureRecognizer];
    
    panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panningDrawer:)];
    [self.topDrawerContents.view addGestureRecognizer:panGestureRecognizer];
    
    panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panningDrawer:)];
    [self.bottomDrawerContents.view addGestureRecognizer:panGestureRecognizer];
    
    panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragHandleMoved:)];
    [self.topDragHandle addGestureRecognizer:panGestureRecognizer];
    
    panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragHandleMoved:)];
    [self.bottomDragHandle addGestureRecognizer:panGestureRecognizer];
}

-(void)viewWillLayoutSubviews {
    [self drawCanvasLayout];
}

// Allows dismissing a zoomed in note when the empty space outside the top and bottom canvases is tapped.
-(void)tapOutsideOfCanvases:(UITapGestureRecognizer*)recognizer {
    if(self.topDrawerContents.isCurrentlyZoomedIn && self.topDrawerContents.isRunningZoomAnimation == NO) {
        self.topDrawerContents.isRefocus = NO;
        [[NSNotificationCenter defaultCenter] postNotificationName:kDismissNoteNotification object:self];
    }
}

#pragma mark - Setup Top and Bottom Canvases

-(void)setTopDrawerContents:(CanvasViewController *)contents {
    [_topDrawerContents removeFromParentViewController];
    [_topDrawerContents.view removeFromSuperview];
    _topDrawerContents = contents;
    
    if(_topDrawerContents) {
        [self addChildViewController:_topDrawerContents];
        [self.view addSubview:_topDrawerContents.view];
    }
}

-(CanvasViewController*)topDrawerContents {
    return _topDrawerContents;
}

-(void)setBottomDrawerContents:(CanvasViewController *)contents {
    [_bottomDrawerContents removeFromParentViewController];
    [_bottomDrawerContents.view removeFromSuperview];
    _bottomDrawerContents = contents;
    
    if(_bottomDrawerContents) {
        [self addChildViewController:_bottomDrawerContents];
        [self.view addSubview:_bottomDrawerContents.view];
    }
}

-(CanvasViewController*)bottomDrawerContents {
    return _bottomDrawerContents;
}

#pragma mark - UIDynamic

-(void)startPhysicsEngine {
    self.animator = [[UIDynamicAnimator alloc] initWithReferenceView:self.view.superview];
    self.animator.delegate = self;
    
    self.gravity = [[UIGravityBehavior alloc] initWithItems:@[self.view]];
    [self.gravity setMagnitude:5.0];
    
    self.collision = [[UICollisionBehavior alloc] initWithItems:@[self.view]];
    self.collision.collisionDelegate = self;
    
    self.drawerBehavior = [[UIDynamicItemBehavior alloc] initWithItems:@[self.view]];
    self.drawerBehavior.resistance = 0;
    self.drawerBehavior.allowsRotation = NO;
    self.drawerBehavior.density = self.view.frame.size.width * self.view.frame.size.height;
    self.drawerBehavior.elasticity = 0.3;
    
    [self.animator addBehavior:self.gravity];
    [self.animator addBehavior:self.collision];
    [self.animator addBehavior:self.drawerBehavior];
    
    // Create top and bottom boundaries for two sections layout.
    if (![[self.collision boundaryIdentifiers] containsObject:Key_TopBoundary]) {
        [self.collision addBoundaryWithIdentifier:Key_TopBoundary
                                        fromPoint:CGPointMake(0, self.minY)
                                          toPoint:CGPointMake(self.view.frame.size.width, self.minY)];
    }
    
    if (![[self.collision boundaryIdentifiers] containsObject:Key_BotBoundary]) {
        [self.collision addBoundaryWithIdentifier:Key_BotBoundary
                                        fromPoint:CGPointMake(0, self.view.frame.size.height + Key_NavBarHeight)
                                          toPoint:CGPointMake(self.view.frame.size.width, self.view.frame.size.height + Key_NavBarHeight)];
    }
}

-(void)stopPhysicsEngine {
    if (self.animator) {
        [self.animator removeAllBehaviors];
    }
    self.animator = nil;
    self.collision = nil;
    self.drawerBehavior = nil;
    self.gravity = nil;
}

-(void)dynamicAnimatorDidPause:(UIDynamicAnimator *)animator {
    self.currentDrawerYInPercentage = abs(self.view.frame.origin.y - Key_NavBarHeight) / self.view.frame.size.height;
}

-(void)dynamicAnimatorWillResume:(UIDynamicAnimator *)animator {
}

-(void)collisionBehavior:(UICollisionBehavior *)behavior
      beganContactForItem:(id<UIDynamicItem>)item
   withBoundaryIdentifier:(id<NSCopying>)identifier
                  atPoint:(CGPoint)p {
    // Resistance is set to 0 when gravity is taking place,
    // but we'll need to increase resistance to keep the bounce from gravity at collision under control.
    self.drawerBehavior.resistance = 2.5;
}

-(void)physicsForBottomHandleDraggedDownwards {
    int gravityTriggerThreshold = -550;
    BOOL pastGravityThreshold;
    pastGravityThreshold = (self.view.frame.origin.y > gravityTriggerThreshold) ? YES : NO;
    
    // Let gravity pull the drawer down when the drawer is dragged past a certain point.
    if (pastGravityThreshold) {
        [self.gravity setMagnitude:-5.0];
        self.isDownwardGravity = YES;
        
        self.drawerBehavior.resistance = 0;
    }
}

-(void)physicsForBottomHandleDraggedUpwards {
    int gravityTriggerThreshold = -200;
    BOOL pastGravityThreshold;
    pastGravityThreshold = (self.view.frame.origin.y < gravityTriggerThreshold) ? YES : NO;
    
    // Let gravity pull the drawer up when the drawer is dragged past a certain point.
    if (pastGravityThreshold) {
        [self.gravity setMagnitude:-5.0];
        self.isDownwardGravity = NO;

        self.drawerBehavior.resistance = 0;
    }
}

#pragma mark - Render Layout

-(void)drawCanvasLayout {
    
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    CGSize screenSize = [[UIScreen mainScreen] bounds].size;
    
    if (orientation == UIInterfaceOrientationLandscapeRight || orientation == UIInterfaceOrientationLandscapeLeft){
        // Fix the iPad faulty screen size numbers due to a system bug in changing orientations
        float tmp = screenSize.height;
        screenSize.height = screenSize.width;
        screenSize.width = tmp;
    }
    
    // NSLog(@"Orientation: %d Screen: %@", orientation, NSStringFromCGSize(screenSize));
    
    // Redraw the layout if device orientation has changed.
    if (screenSize.height != self.realScreenSize.height) {
        [self updateExtentsForScreenSize:screenSize];
        [self updateViewSizes];
        [self updateCanvasSizes];
    }
}

-(void)updateExtentsForScreenSize:(CGSize)screenSize {
    // Store the actual screen size so we can reference it later to fix an iPad system bug where it'll report the wrong
    // size after changes in orientation
    self.realScreenSize = screenSize;

    // The empty space between the top canvas and the bottom of the screen at resting position
    int bottomSpace = 100;
    
    // Alternative layout requires a different height for the top canvas, or else notes can get fly out of sight
    self.topDrawerHeight = screenSize.height - bottomSpace - Key_NavBarHeight;
    self.bottomDrawerHeight = screenSize.height - 224;

    // When the drawer is pulled down all the way with the top canvas fully revealed, it will be resting at (0, 0)
    self.maxY = Key_NavBarHeight;
    
    // Resting position is with the canvas pulled all the way down
    self.restY = self.maxY;
    
    // When the drawer reveals the trash canvas, it is pulled up and outside the screen even more, and this represents
    // how far the drawer can be pulled up
    // Reupdate minY using new restY value so we can pull up the trash canvas to the proper height
    self.minY = self.restY - self.bottomDrawerHeight;
    
    // Bottom drawer starts right at the bottom of the screen in alternative layout
    self.bottomDrawerStart = screenSize.height - Key_NavBarHeight;
}

-(void)updateViewSizes {
    
    // Frames for original layout
    int viewHeight = self.bottomDrawerStart + self.bottomDrawerHeight;
    self.view.frame = CGRectMake(0, self.restY, self.realScreenSize.width, viewHeight);
    
    int dragHeight = 50;
    int dragWidth = 600;
    float dragTop = self.topDrawerHeight + 25;
    float dragLeft = (self.view.bounds.size.width - dragWidth) / 2;
    float dragBottom = self.bottomDrawerStart - dragHeight - 25;

    self.topDragHandle.frame = CGRectMake(dragLeft, dragTop, dragWidth, dragHeight);
    self.topDragHandle.layer.cornerRadius = 15;
    self.bottomDragHandle.frame = CGRectMake(dragLeft, dragBottom, dragWidth, dragHeight);
    self.bottomDragHandle.layer.cornerRadius = 15;
    
    self.topDragHandle.frame = CGRectZero;
}

-(void)updateCanvasSizes {
    [self updateTopCanvasSize];
    [self updateBottomCanvasSize];
}

-(void)updateTopCanvasSize {
    self.topDrawerContents.view.frame = CGRectMake(0, 0, self.realScreenSize.width, self.topDrawerHeight);
    [self.topDrawerContents updateNotesForBoundsChange];
    [self.topDrawerContents setTrashThreshold:self.bottomDrawerStart];
}

-(void)updateBottomCanvasSize {
    self.bottomDrawerContents.view.frame = CGRectMake(0, self.bottomDrawerStart, self.realScreenSize.width, self.bottomDrawerHeight);
    [self.bottomDrawerContents updateNotesForBoundsChange];
}

-(void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    if(!self.haveLayedOut) {
        self.haveLayedOut = YES;
    }
}

#pragma mark - Drag Drawer

-(void)setDrawerPosition:(float)positionY {
    CGRect frame = self.view.frame;
    frame.origin.y = positionY;
    
    if(frame.origin.y > self.maxY) {
        frame.origin.y = self.maxY;
    } else if(frame.origin.y < self.minY) {
        frame.origin.y = self.minY;
    }
    
    self.view.frame = frame;
    
    self.currentDrawerYInPercentage = abs(self.view.frame.origin.y - Key_NavBarHeight) / self.view.frame.size.height;
    // NSLog(@"Drawer current Y in percentage = %f", self.currentDrawerYInPercentage);
    NSLog(@"Drawer current Y = %f", self.view.frame.origin.y);
}

-(void)animateDrawerPosition:(float)positionY {
    CGRect frame = self.view.frame;
    frame.origin.y = positionY;

    [UIView animateWithDuration:0.5 animations:^{
        self.view.frame = frame;
    }];
}

-(void)dragHandleMoved:(UIPanGestureRecognizer*)recognizer {
    CGPoint drag = [recognizer locationInView:self.view.superview];
    BOOL fromTopHandle = [recognizer.view isEqual:self.topDragHandle];
    
    if(recognizer.state == UIGestureRecognizerStateBegan) {
        [self.animator removeBehavior:self.gravity];
        
        self.dragStart = drag;
        self.initialFrameY = self.view.frame.origin.y;
    }
    
    self.newPosition = self.initialFrameY + (drag.y - self.dragStart.y);
    
    // If dragged past a certain point, change gravity direction and let it extend or hide the canvas.
    if (recognizer.state == UIGestureRecognizerStateEnded) {
        
        [self.animator addBehavior:self.gravity];
        
        BOOL velocityDownwards = [recognizer velocityInView:self.view].y >= 0;
        
        if (!fromTopHandle && velocityDownwards) { // Case for dragging the canvas downward.
            [self physicsForBottomHandleDraggedDownwards];
        } else if (!fromTopHandle && !velocityDownwards) { // Case for dragging canvas upward.
            [self physicsForBottomHandleDraggedUpwards];
        }
        
        // Add throwable feel to the drawer
        CGPoint verticalVelocity = [recognizer velocityInView:self.view.superview];
        verticalVelocity = CGPointMake(0, verticalVelocity.y);
        
        [self.drawerBehavior addLinearVelocity:verticalVelocity forItem:self.view];
        
    } else { // If we are still dragging, continue updating the drawer's position.
        
        // Don't allow the drawer to be dragged further down when it's already fully revealed.
        if (!fromTopHandle && self.newPosition > self.restY) {
            self.newPosition = self.restY;
        }
        
        [self setDrawerPosition:self.newPosition];
        
        [self.animator updateItemUsingCurrentState:self.view];
    }
}

// Allows "catching" of the handle if a pan gesture started outside the handle from the canvases' empty space.
-(void)panningDrawer:(UIPanGestureRecognizer*)recognizer {
    CGPoint touchPointRelativeToWindow = [recognizer locationInView:self.view.superview];
    CGPoint touchPointRelativeToDrawer = [recognizer locationInView:self.view];
    
    UIView* hitView = [self.view hitTest:touchPointRelativeToDrawer withEvent:nil];
    UIView* targetView;
    
    if ([recognizer.view isEqual:_topDrawerContents.view]) {
            targetView = self.bottomDragHandle;
    } else if ([recognizer.view isEqual:_bottomDrawerContents.view]) {
        targetView = self.bottomDragHandle;
    } else {
        targetView = nil;
    }
    
    if (hitView == targetView) {
        
        if (self.allowedDragStartYAssigned == NO) {
            self.allowedDragStartY = touchPointRelativeToWindow.y;
            self.allowedDragStartYAssigned = YES;
        }
        
        self.allowDrag = YES;
    }
    
    float newPosition;
    BOOL fromTopDrawer;
    
    if(recognizer.state == UIGestureRecognizerStateBegan) {
        [self.animator removeBehavior:self.gravity];
        
        self.dragStart = touchPointRelativeToWindow;
        self.initialFrameY = self.view.frame.origin.y;
    }
    
    if (self.allowDrag) {
        newPosition = self.initialFrameY + (touchPointRelativeToWindow.y - self.allowedDragStartY);
    } else {
        newPosition = self.initialFrameY;
    }
    
    fromTopDrawer = [recognizer.view isEqual:_topDrawerContents.view];
    
    if (recognizer.state == UIGestureRecognizerStateEnded) {
        [self.animator addBehavior:self.gravity];
        
        BOOL velocityDownwards = [recognizer velocityInView:self.view].y >= 0;
        
        if (fromTopDrawer && velocityDownwards) {
            
            if (self.allowDrag) {
                [self physicsForBottomHandleDraggedDownwards];
            }
            
        } else if (fromTopDrawer && !velocityDownwards) {

            if (self.allowDrag) {
                [self physicsForBottomHandleDraggedUpwards];
            }

        } else if (!fromTopDrawer && velocityDownwards) {
            
            if (self.allowDrag) {
                [self physicsForBottomHandleDraggedDownwards];
            }
            
        } else if (!fromTopDrawer && !velocityDownwards) {
            
            if (self.allowDrag) {
                [self physicsForBottomHandleDraggedUpwards];
            }
        }
        
        if (self.allowDrag) {
            // Add throwable feel to the drawer
            CGPoint verticalVelocity = [recognizer velocityInView:self.view.superview];
            verticalVelocity = CGPointMake(0, verticalVelocity.y);
            
            [self.drawerBehavior addLinearVelocity:verticalVelocity forItem:self.view];
        }
    
        self.allowDrag = NO;
        self.allowedDragStartYAssigned = NO;
        
        self.fromTopDragHandle = NO;
        self.fromBotDragHandle = NO;
        
    } else {
        
        NSLog(@"New position = %f", newPosition);
        [self setDrawerPosition:newPosition];
        
        [self.animator updateItemUsingCurrentState:self.view];
    }
}

// Allows "catching" of the handle if a pan gesture started outside the handle from the drawer's empty space.
-(void)panOutsideOfCanvases:(UIPanGestureRecognizer*)recognizer {
    CGPoint touchPointRelativeToWindow = [recognizer locationInView:self.view.superview];
    CGPoint touchPointRelativeToDrawer = [recognizer locationInView:self.view];
    
    UIView* hitView = [self.view hitTest:touchPointRelativeToDrawer withEvent:nil];
    
    if (hitView == self.topDragHandle) {
        
        self.fromTopDragHandle = YES;
        
        if (self.allowedDragStartYAssigned == NO) {
            self.allowedDragStartY = touchPointRelativeToWindow.y;
            self.allowedDragStartYAssigned = YES;
        }
        
        self.allowDrag = YES;
        
    } else if (hitView == self.bottomDragHandle) {
        
        self.fromBotDragHandle = YES;
        
        if (self.allowedDragStartYAssigned == NO) {
            self.allowedDragStartY = touchPointRelativeToWindow.y;
            self.allowedDragStartYAssigned = YES;
        }
        
        self.allowDrag = YES;
        
    }
    
    float newPosition;
    
    if(recognizer.state == UIGestureRecognizerStateBegan) {
        
        [self.animator removeBehavior:self.gravity];
        
        self.dragStart = touchPointRelativeToWindow;
        self.initialFrameY = self.view.frame.origin.y;
    }
    
    if (self.allowDrag) {
        newPosition = self.initialFrameY + (touchPointRelativeToWindow.y - self.allowedDragStartY);
    } else {
        newPosition = self.initialFrameY;
    }
    
    if (recognizer.state == UIGestureRecognizerStateEnded) {
        
        self.allowDrag = NO;
        self.allowedDragStartYAssigned = NO;
        
        [self.animator addBehavior:self.gravity];
        
        BOOL velocityDownwards = [recognizer velocityInView:self.view].y >= 0;
        
        if (self.fromBotDragHandle && velocityDownwards) {
            
                [self physicsForBottomHandleDraggedDownwards];
            
        } else if (self.fromBotDragHandle && !velocityDownwards) {
            
                [self physicsForBottomHandleDraggedUpwards];
        }
        
        self.fromTopDragHandle = NO;
        self.fromBotDragHandle = NO;
        
    } else {
        
        if (self.fromBotDragHandle && newPosition > self.restY) {
            self.newPosition = self.restY;
            return;
        }
        
        [self setDrawerPosition:newPosition];
        
        [self.animator updateItemUsingCurrentState:self.view];
    }
}

#pragma mark - Drawer Rotation

-(void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    // Prevents animator from overriding our custom changes to views that are needed for orientation changes.
    [self stopPhysicsEngine];
}

-(void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    if (self.animator == nil) {
        [self startPhysicsEngine];
    }
}

-(void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    // Calculates the drawer's current y coordinate relatively, and reposition the drawer during device rotation animation
    // in order to persist the drawer's current scroll.
    CGFloat newY = self.currentDrawerYInPercentage * self.view.frame.size.height;
    // NSLog(@"New Y = %f", newY);
    
    // Occasionally, the calculated offset can be less than minY, which would cause the canvas to reposition incorrectly,
    // so we readjust newY by the amount it would go past minY.
    if ((self.view.frame.origin.y - newY) < self.minY) {
        newY = self.view.frame.origin.y - self.minY;
    }
    
    if (self.canvasesAreSlidOut == YES) {
        // NSLog(@"Slide amount = %f", self.topDrawerContents.view.frame.size.height * self.slideAmountInPercentage);
        self.topCanvasFrameBeforeSlidingOut = self.topDrawerContents.view.frame;
        
        // The focus view shifts up or down using Key_Landscape or Key_Portrait adjustments when device orientation changes, so
        // in addition to reposition the actual note view frame that's underneath the focus view using the new slide offset, we
        // also need to take the focus view's shifting values into consideration.
        if (toInterfaceOrientation == UIInterfaceOrientationLandscapeLeft || toInterfaceOrientation == UIInterfaceOrientationLandscapeRight) {
            self.topDrawerContents.slideOffset =
            self.topDrawerContents.view.frame.size.height * self.slideAmountInPercentage + (Key_LandscapeFocusViewAdjustment - Key_PortraitFocusViewAdjustment);
        } else {
            self.topDrawerContents.slideOffset =
            self.topDrawerContents.view.frame.size.height * self.slideAmountInPercentage - (Key_LandscapeFocusViewAdjustment - Key_PortraitFocusViewAdjustment);
        }
        
        self.topDrawerContents.view.frame = CGRectMake(self.topDrawerContents.view.frame.origin.x,
                                                       self.topDrawerContents.view.frame.size.height * self.slideAmountInPercentage,
                                                       self.topDrawerContents.view.frame.size.width,
                                                       self.topDrawerContents.view.frame.size.height);
        
    }
}

#pragma mark - Canvas Sliding

-(void)slideOutCanvases {
    // UIDynamic overwrites manual frame positioning, so it needs to be turned off first.
    [self stopPhysicsEngine];
    
    if (self.topDrawerContents.isRefocus == NO) {
        self.topCanvasFrameBeforeSlidingOut = self.topDrawerContents.view.frame;
    }
    
    int previousY = self.topDrawerContents.view.frame.origin.y;
    self.topDrawerContents.previousOffset = previousY;
    CGRect destination = self.topDrawerContents.view.frame;
    destination.origin.y = -(self.view.frame.origin.y + self.realScreenSize.height);
    
    // Find how far down the canvas the selected note circle is located at to help determine how far the
    // canvas should slide out.
    float targetedNoteY = self.topDrawerContents.currentlyZoomedInNoteView.note.originalY;
    
    // Give some room between the bottom of the nav bar and the note circle that the canvas is sliding up to.
    destination.origin.y = -(targetedNoteY - Key_NoteRadius * 2);
    
    if (destination.origin.y > 0) {
        destination.origin.y = self.topDrawerContents.view.frame.origin.y;
    }
    
    // Handle cases where the drawer is not completely drawn out or closed.
    if (self.view.frame.origin.y < Key_NavBarHeight) {
        destination.origin.y += Key_NavBarHeight - self.view.frame.origin.y;
    }
    
    // Stores current amount of slide to help with device rotation.
    self.topDrawerContents.slideOffset = destination.origin.y;
    self.slideAmountInPercentage = [Coordinate normalizeYCoord:destination.origin.y withReferenceBounds:self.topDrawerContents.view.bounds];
    
    [UIView animateWithDuration:1 animations:^{
        self.topDrawerContents.view.frame = destination;
        self.topDragHandle.alpha = 0;
        self.bottomDragHandle.alpha = 0;
    } completion:^(BOOL finished) {
        if (finished) {
            // After sliding the canvas up, reposition the zoomed in note view so that it is still at the same location as the focus view.
            CGRect zoomedInNoteViewFrame = self.topDrawerContents.currentlyZoomedInNoteView.frame;
            CGFloat offset;
            if (self.topDrawerContents.hasRefocused) {
                offset = destination.origin.y - previousY;
            } else {
                offset = destination.origin.y;
            }
            
            self.topDrawerContents.currentlyZoomedInNoteView.frame = CGRectMake(zoomedInNoteViewFrame.origin.x,
                                                                                zoomedInNoteViewFrame.origin.y - offset,
                                                                                zoomedInNoteViewFrame.size.width,
                                                                                zoomedInNoteViewFrame.size.height);
            
            self.topDrawerContents.originalZoomedInNoteViewFrame = self.topDrawerContents.currentlyZoomedInNoteView.frame;
        }
    }];
    
    self.canvasesAreSlidOut = YES;
}

-(void)slideInCanvases {
    if (self.topDrawerContents.isRefocus) {
        return;
    }
    
    self.topDrawerContents.hasRefocused = NO;
    
    [UIView animateWithDuration:1 animations:^{
        self.topDrawerContents.view.frame = self.topCanvasFrameBeforeSlidingOut;
        self.topDragHandle.alpha = 1;
        self.bottomDragHandle.alpha = 1;
    } completion:^(BOOL finished) {
        if (finished) {
            if (self.animator == nil) {
                [self startPhysicsEngine];
            }
        }
    }];
    
    self.canvasesAreSlidOut = NO;
}

@end
