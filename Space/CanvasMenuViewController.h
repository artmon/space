//
//  CanvasMenuViewController.h
//  Space
//
//  Created by Jeremy Chiang on 2013-10-30.
//  Copyright (c) 2013 University of British Columbia. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CanvasMenuViewController : UITableViewController <UITextFieldDelegate>

// Stores a list of canvas titles in which each title corresponds to an index number in the title indices.
// A potential mapping after some editing could look like this:

/*
 Array Index | Canvas Title Id | Canvas Title
 
 0             1                 Computer Science
 1             3                 Biology
 2             5                 Accounting
*/

// This way, a canvas title can always be represented by a 'primary-key' canvas index that is unique, while the
// array index which the canvas title corresponds to can change. This allows the reordering of the canvas titles
// inside the popover menu.
@property (strong, nonatomic) NSMutableArray* canvasTitles;
@property (strong, nonatomic) NSMutableArray* canvasTitlesIds;

@property (nonatomic) BOOL isEditingTableView;

+(CanvasMenuViewController*)canvasMenuViewController;
-(void)setupMenuWithCanvasTitles:(NSArray *)canvasTitles andIds:(NSArray *)canvasIds;

-(void)setEditing:(BOOL)editing animated:(BOOL)animated;
-(void)addCanvas;

@end
