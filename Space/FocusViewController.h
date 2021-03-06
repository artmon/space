//
//  FocusViewController.h
//  Space
//
//  Created by Nigel Brooke on 2013-08-21.
//  Copyright (c) 2013 University of British Columbia. All rights reserved.
//
//  This view represents the large text editor after zooming in a selected note circle.
//

#import <UIKit/UIKit.h>
#import "NoteView.h"

@interface FocusViewController : UIViewController <UITextViewDelegate>

// Called to pull the content from the selected note circle and display them in the editor.
-(void)focusOn:(NoteView*)noteView;

// Callback block for updating title label as text is being entered in the focus view.
@property (copy, nonatomic) void (^titleEntered)(NSString*);

@end
