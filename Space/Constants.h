//
//  Constants.h
//  Space
//
//  Created by Jeremy Chiang on 2013-09-05.
//  Copyright (c) 2013 University of British Columbia. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString* const Key_CanvasTitles;
extern NSString* const Key_CanvasTitleIndices;

extern NSString* const Key_CanvasNumber;
extern NSString* const Key_CanvasName;

extern NSString* const Key_CurrentCanvasIndex;

extern NSString* const Key_TrashedNotes;
extern NSString* const Key_RecoveredNote;

extern int const Key_NavBarHeight;
extern int const Key_LandscapeFocusViewAdjustment;
extern int const Key_PortraitFocusViewAdjustment;

extern int const Key_NoteTitleWidth;
extern int const Key_NoteTitleHeight;

typedef enum DragModeEnum {
    UIViewAnimation,
    UIDynamicFreeSliding,
    UIDynamicFreeSlidingWithGravity
} DragMode;
