#import "COCommandUndeletePersistentRoot.h"
#import "COCommandDeletePersistentRoot.h"

#import "COEditingContext.h"
#import "COPersistentRoot.h"
#import "COBranch.h"
#import "CORevision.h"
#import "CORevisionCache.h"

@implementation COCommandUndeletePersistentRoot

- (COCommand *) inverse
{
    COCommandDeletePersistentRoot *inverse = [[COCommandDeletePersistentRoot alloc] init];
    inverse.storeUUID = _storeUUID;
    inverse.persistentRootUUID = _persistentRootUUID;
    inverse.timestamp = _timestamp;
    return inverse;
}

- (BOOL) canApplyToContext: (COEditingContext *)aContext
{
	NILARG_EXCEPTION_TEST(aContext);
    if (nil == [aContext persistentRootForUUID: _persistentRootUUID])
    {
        return NO;
    }
    return YES;
}

- (void) applyToContext: (COEditingContext *)aContext
{
	NILARG_EXCEPTION_TEST(aContext);
    [[aContext persistentRootForUUID: _persistentRootUUID] setDeleted: NO];
}

- (NSString *)kind
{
	return _(@"Persistent Root Undeletion");
}

@end


static NSString * const kCOCommandInitialRevisionID = @"COCommandInitialRevisionID";

@implementation COCommandCreatePersistentRoot

- (id) initWithPropertyList: (id)plist
{
    self = [super initWithPropertyList: plist];
	if (self == nil)
		return nil;

   	_initialRevisionID = [ETUUID UUIDWithString: plist[kCOCommandInitialRevisionID]];
    return self;
}

- (id) propertyList
{
    NSMutableDictionary *result = [super propertyList];
    [result setObject: [_initialRevisionID stringValue] forKey: kCOCommandInitialRevisionID];
    return result;
}

- (COCommand *) inverse
{
    COCommandDeletePersistentRoot *inverse = (id)[super inverse];
	inverse.initialRevisionID = _initialRevisionID;
    return inverse;
}

- (NSString *)kind
{
	return _(@"Persistent Root Creation");
}

- (CORevision *)revision
{
	return [CORevisionCache revisionForRevisionUUID: _initialRevisionID
								 persistentRootUUID: _persistentRootUUID
	                                    storeUUID: [self storeUUID]];
}

#pragma mark -
#pragma mark Track Node Protocol

- (ETUUID *)UUID
{
	return _initialRevisionID;
}

- (NSDictionary *)metadata
{
	return [[self revision] metadata];
}

- (NSString *)localizedTypeDescription
{
	return [[self revision] localizedTypeDescription];
}

- (NSString *)localizedShortDescription
{
	return [[self revision] localizedShortDescription];
}

@end
