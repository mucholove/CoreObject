/*
	Copyright (C) 2014 Eric Wasylishen
 
	Date:  February 2014
	License:  MIT  (see COPYING)
 */

#import <Cocoa/Cocoa.h>
#import <CoreObject/CoreObject.h>
#import <CoreObject/COAttributedStringWrapper.h>

#import "EWTextView.h"
#import "EWUndoManager.h"

@class EWTagListDataSource;
@class EWNoteListDataSource;

NSString * EWNoteDragType;
NSString * EWTagDragType;


@interface EWTypewriterWindowController : NSWindowController <NSWindowDelegate, NSTextViewDelegate, NSTextStorageDelegate, EWUndoManagerDelegate>
{
    IBOutlet EWTextView *textView;
	IBOutlet NSTableView *notesTable;
	IBOutlet NSOutlineView *tagsOutline;
	IBOutlet NSSearchField *searchfield;
	
	COAttributedStringWrapper *textStorage;
	BOOL changedByUser;
	COPersistentRoot *selectedNote;
	COUndoTrack *undoTrack;
	EWUndoManager *undoManagerBridge;
	
	EWTagListDataSource *tagListDataSource;
	EWNoteListDataSource *noteListDataSource;
}

@property (nonatomic, readonly) NSTableView *notesTable;

@property (nonatomic, readonly) COEditingContext *editingContext;
@property (nonatomic, readonly) COUndoTrack *undoTrack;

- (IBAction) addTag:(id)sender;
- (IBAction) addTagGroup:(id)sender;
- (IBAction) addNote:(id)sender;
- (IBAction) duplicate:(id)sender;

- (IBAction) search: (id)sender;

- (COTagLibrary *)tagLibrary;
- (NSArray *) arrangedNotePersistentRoots;
- (void) commitWithIdentifier: (NSString *)identifier descriptionArguments: (NSArray*)args;
- (void) selectNote: (COPersistentRoot *)aNote;
- (void) selectTag: (COTag *)aTag;

@end

