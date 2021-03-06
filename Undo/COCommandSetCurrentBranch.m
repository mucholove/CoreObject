/*
    Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

    Date:  September 2013
    License:  MIT  (see COPYING)
 */

#import "COCommandSetCurrentBranch.h"

#import "COEditingContext.h"
#import "COPersistentRoot.h"
#import "COBranch.h"
#import "COStoreTransaction.h"

static NSString *const kCOCommandOldBranchUUID = @"COCommandOldBranchUUID";
static NSString *const kCOCommandNewBranchUUID = @"COCommandNewBranchUUID";

@implementation COCommandSetCurrentBranch

@synthesize oldBranchUUID = _oldBranchUUID;
@synthesize branchUUID = _newBranchUUID;

- (instancetype)initWithPropertyList: (id)plist parentUndoTrack: (COUndoTrack *)aParent
{
    self = [super initWithPropertyList: plist parentUndoTrack: aParent];
    self.oldBranchUUID = [ETUUID UUIDWithString: plist[kCOCommandOldBranchUUID]];
    self.branchUUID = [ETUUID UUIDWithString: plist[kCOCommandNewBranchUUID]];
    return self;
}

- (id)propertyList
{
    NSMutableDictionary *result = super.propertyList;
    result[kCOCommandOldBranchUUID] = [_oldBranchUUID stringValue];
    result[kCOCommandNewBranchUUID] = [_newBranchUUID stringValue];
    return result;
}

- (COCommand *)inverse
{
    COCommandSetCurrentBranch *inverse = [[COCommandSetCurrentBranch alloc] init];
    inverse.storeUUID = _storeUUID;
    inverse.persistentRootUUID = _persistentRootUUID;

    inverse.oldBranchUUID = _newBranchUUID;
    inverse.branchUUID = _oldBranchUUID;
    return inverse;
}

- (BOOL)canApplyToContext: (COEditingContext *)aContext
{
    NILARG_EXCEPTION_TEST(aContext);
    return YES;
}

- (void)addToStoreTransaction: (COStoreTransaction *)txn
         withRevisionMetadata: (NSDictionary *)metadata
  assumingEditingContextState: (COEditingContext *)ctx
{
    [txn setCurrentBranch: _newBranchUUID forPersistentRoot: _persistentRootUUID];
}

- (void)applyToContext: (COEditingContext *)aContext
{
    NILARG_EXCEPTION_TEST(aContext);

    COPersistentRoot *proot = [aContext persistentRootForUUID: _persistentRootUUID];
    COBranch *branch = [proot branchForUUID: _newBranchUUID];
    ETAssert(branch != nil);

    proot.currentBranch = branch;
}

- (NSString *)kind
{
    return _(@"Branch Switch");
}

- (id)copyWithZone: (NSZone *)zone
{
    COCommandSetCurrentBranch *aCopy = [super copyWithZone: zone];
    aCopy->_oldBranchUUID = _oldBranchUUID;
    aCopy->_newBranchUUID = _newBranchUUID;
    return aCopy;
}

@end
