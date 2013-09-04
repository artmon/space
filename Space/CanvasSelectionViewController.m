//
//  CanvasSelectionViewController.m
//  Space
//
//  Created by Nigel Brooke on 2013-08-26.
//  Copyright (c) 2013 University of British Columbia. All rights reserved.
//

#import "CanvasSelectionViewController.h"
#import "CanvasTitleEditPopover.h"
#import "Notifications.h"

@interface CanvasSelectionViewController ()

@property UIToolbar* toolbar;
@property NSArray* buttons;

@property (strong, nonatomic) NSMutableArray* canvasList;

@property (strong, nonatomic) UIButton* currentlyEditingButton;
@property (strong, nonatomic) UILabel* currentlyEditingTitle;
@property (strong, nonatomic) UIPopoverController* popoverController;

// Cannot use a variable name that starts with "new"
@property (strong, nonatomic) NSString* brandNewTitle;

@end

@implementation CanvasSelectionViewController

@synthesize popoverController;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.toolbar = [UIToolbar new];
        [self setupToolbarWithCanvasNames:@[@"One", @"Two"]];
        self.view = self.toolbar;
        
        Class popoverClass = NSClassFromString(@"UIPopoverController");
        
        if (popoverClass != nil && UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            
            CanvasTitleEditPopover *canvasTitlePopover = [[CanvasTitleEditPopover alloc] init];
            self.popoverController = [[UIPopoverController alloc] initWithContentViewController:canvasTitlePopover];
            canvasTitlePopover.popoverController = self.popoverController;
            
            __weak CanvasSelectionViewController* weakSelf = self;
            canvasTitlePopover.newTitleEntered = ^(NSString* title) {
                weakSelf.brandNewTitle = title;
                NSLog(@"New title = %@", weakSelf.brandNewTitle);
                [self.canvasList addObject:weakSelf.brandNewTitle];
                [self setupToolbarWithCanvasNames:self.canvasList];
            };
        }
    }
    return self;
}

-(void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.view.frame = CGRectMake(0, 0, self.view.superview.bounds.size.width, 50);
    self.view.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)setupToolbarWithCanvasNames:(NSArray*)canvasNames
{
    self.toolbar.items = nil;
    
    if ([self.canvasList count] <= 0) {
        self.canvasList = [canvasNames mutableCopy];
    }
    
    NSMutableArray* items = [NSMutableArray new];
    NSMutableArray* buttons = [NSMutableArray new];
    
    int tag = 0; // Used to help identify and locate the custom UIButton that's embedded in each of the BarButtonItems
    
    for (NSString* name in canvasNames) {
        [items addObject:[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil] ];
        
        CGRect rect = CGRectMake(0, 0, 100, 44);
        
        UITextField* buttonTextField = [[UITextField alloc] initWithFrame:rect];
        [buttonTextField setTextAlignment:NSTextAlignmentCenter];
        [buttonTextField setHidden:YES];
        [buttonTextField setDelegate:self];
        
        UILabel* buttonLabel = [[UILabel alloc] initWithFrame:rect];
        [buttonLabel setText:name];
        [buttonLabel setTextAlignment:NSTextAlignmentCenter];
        
        UIButton* customBarButton = [UIButton buttonWithType:UIButtonTypeCustom];
        customBarButton.frame = rect;
        [customBarButton addSubview:buttonTextField];
        [customBarButton addSubview:buttonLabel];
        [customBarButton addTarget:self action:@selector(buttonPress:) forControlEvents:UIControlEventTouchUpInside];
        
        UILongPressGestureRecognizer* longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(titleLongPress:)];
        [customBarButton addGestureRecognizer:longPress];
        
        customBarButton.tag = tag;
        tag++;
        
        UIBarButtonItem* button = [[UIBarButtonItem alloc] initWithCustomView:customBarButton];
        
        // UIBarButtonItem* button = [[UIBarButtonItem alloc] initWithTitle:name style:UIBarButtonItemStylePlain target:self action:@selector(buttonPress:)];
        [items addObject: button];
        [buttons addObject:button];
    }

    [items addObject:[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil] ];
    [items addObject:[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(showPopover:)]];
    
    self.toolbar.items = items;
    self.buttons = buttons;
}

-(IBAction)buttonPress:(id)sender {
    UIButton* pressedButton = (UIButton*)sender;
    
    NSLog(@"Button number = %@", [NSNumber numberWithInt:pressedButton.tag]);
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kCanvasChangedNotification object:self userInfo:@{@"canvas":[NSNumber numberWithInt:pressedButton.tag]}];
}

-(IBAction)titleLongPress:(UITapGestureRecognizer *)recognizer {
    
    if (recognizer.state != UIGestureRecognizerStateBegan) {
        return; // Disregard other states that are also part of a long press, so we don't enter this method multiple times
    }
    
    self.currentlyEditingButton = (UIButton*)recognizer.view;
    
    [self swapTextFieldWithTitleLabel];
}

-(BOOL)textFieldShouldReturn:(UITextField *)textField {
    
    [self.currentlyEditingTitle setText:textField.text];
    
    [self swapTextFieldWithTitleLabel];
    
    [textField resignFirstResponder];
    
    return YES;
}

-(void)swapTextFieldWithTitleLabel {
    
    for (UIView* view in self.currentlyEditingButton.subviews) {
        
        if ([view isKindOfClass:[UILabel class]]) {
            
            self.currentlyEditingTitle = (UILabel*)view;
            
            if (self.currentlyEditingTitle.hidden) {
                [self.currentlyEditingTitle setHidden:NO];
            } else {
                [self.currentlyEditingTitle setHidden:YES];
            }
            
        } else if ([view isKindOfClass:[UITextField class]]) {
            
            UITextField* textField = (UITextField*)view;
            [textField setText:@""];
            
            if (textField.hidden) {
                [textField setHidden:NO];
            } else {
                [textField setHidden:YES];
            }
            
            [textField becomeFirstResponder];
        }
    }
}

-(IBAction)showPopover:(id)sender {
    [self.popoverController presentPopoverFromBarButtonItem:sender permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
}

@end