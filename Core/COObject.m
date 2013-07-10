/*
	Copyright (C) 2010 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>, 
	         Quentin Mathe <quentin.mathe@gmail.com>
	Date:  November 2010
	License:  Modified BSD  (see COPYING)

	COObjectMatching protocol concrete implementation is based on MIT-licensed 
	code by Yen-Ju Chen <yjchenx gmail> from the previous CoreObject.
 */

#import "COObject.h"
#import "COError.h"
#import "COPersistentRoot.h"
#import "COPersistentRoot+RelationshipCache.h"
#import "CORelationshipCache.h"
#import "COSQLiteStore.h"
#import "COTag.h"
#import "COGroup.h"
#include <objc/runtime.h>

@implementation COObject

// For EtoileUI
/** <override-dummy />
Returns <em>CO</em>.
 
See +[NSObject typePrefix]. */
+ (NSString *) typePrefix
{
	return @"CO";
}

+ (ETEntityDescription *) newEntityDescription
{
	ETEntityDescription *object = [self newBasicEntityDescription];

	// For subclasses that don't override -newEntityDescription, we must not add the 
	// property descriptions that we will inherit through the parent
	if ([[object name] isEqual: [COObject className]] == NO) 
		return object;

	ETUTI *uti = [ETUTI registerTypeWithString: @"org.etoile-project.objc.class.COObject"
	                               description: @"Core Object"
	                          supertypeStrings: [NSArray array]
	                                  typeTags: [NSDictionary dictionary]];
	ETAssert([[ETUTI typeWithClass: [self class]] isEqual: uti]);

	[object setLocalizedDescription: _(@"Basic Object")];

	ETPropertyDescription *nameProperty = 
		[ETPropertyDescription descriptionWithName: @"name" type: (id)@"Anonymous.NSString"];
	// TODO: Declare as a transient property... ETLayoutItem overrides it to be 
	// a persistent property.
	//ETPropertyDescription *idProperty = 
	//	[ETPropertyDescription descriptionWithName: @"identifier" type: (id)@"Anonymous.NSString"];
	ETPropertyDescription *modificationDateProperty = 
		[ETPropertyDescription descriptionWithName: @"modificationDate" type: (id)@"Anonymous.NSDate"];
	ETPropertyDescription *creationDateProperty = 
		[ETPropertyDescription descriptionWithName: @"creationDate" type: (id)@"Anonymous.NSDate"];
	ETPropertyDescription *lastVersionDescProperty = 
		[ETPropertyDescription descriptionWithName: @"lastVersionDescription" type: (id)@"Anonymous.NSString"];
	ETPropertyDescription *tagDescProperty = 
		[ETPropertyDescription descriptionWithName: @"tagDescription" type: (id)@"Anonymous.NSString"];
	ETPropertyDescription *typeDescProperty = 
		[ETPropertyDescription descriptionWithName: @"typeDescription" type: (id)@"Anonymous.NSString"];

	// TODO: Figure out how to compute and present each core object size...
	// Possible choices would be:
	// - a raw size including the object history data
	// - a snapshot size (excluding the history data)
	// - a directory or file size to be expected if the object is exported

	// TODO: Move these properties to EtoileFoundation... See -[NSObject propertyNames].
	// We should create a NSObject entity description and use it as our parent entity probably.
#ifndef GNUSTEP // We don't link NSImage on GNUstep because AppKit won't work
	ETPropertyDescription *iconProperty = 
		[ETPropertyDescription descriptionWithName: @"icon" type: (id)@"Anonymous.NSImage"];
#endif // GNUSTEP
	ETPropertyDescription *displayNameProperty = 
		[ETPropertyDescription descriptionWithName: @"displayName" type: (id)@"Anonymous.NSString"];

	ETPropertyDescription *tagsProperty = 
		[ETPropertyDescription descriptionWithName: @"tags" type: (id)@"Anonymous.COTag"];
	[tagsProperty setMultivalued: YES];
	[tagsProperty setOrdered: YES];

	NSArray *transientProperties = A(displayNameProperty, modificationDateProperty, 
		creationDateProperty, lastVersionDescProperty, tagDescProperty, typeDescProperty);
#ifndef GNUSTEP
	transientProperties = [transientProperties arrayByAddingObject: iconProperty];
#endif
	NSArray *persistentProperties = A(nameProperty, tagsProperty);

	[[persistentProperties mappedCollection] setPersistent: YES];
	[object setPropertyDescriptions: [transientProperties arrayByAddingObjectsFromArray: persistentProperties]];

	return object;
}

- (NSMutableDictionary *)newVariableStorage
{
	return [[NSMutableDictionary alloc] initWithCapacity: 20];
}

// FIXME: Remove
/* Puts mutable collections into multivalued properties. */
- (void)didCreate
{
	BOOL wasIgnoringDamage = _isIgnoringDamageNotifications;
	_isIgnoringDamageNotifications = YES;
	
	for (ETPropertyDescription *propDesc in [[self entityDescription] allPropertyDescriptions])
	{
		if ([propDesc isMultivalued])
		{
			id container = ([propDesc isOrdered] ? [NSMutableArray array] : [NSMutableSet set]);
			[self setValue: container forProperty: [propDesc name]];
		}
	}
	
	_isIgnoringDamageNotifications = wasIgnoringDamage;
}

- (id) commonInitWithUUID: (ETUUID *)aUUID 
        entityDescription: (ETEntityDescription *)anEntityDescription
                  context: (COPersistentRoot *)aContext
{
	NSParameterAssert(aUUID != nil);
	BOOL isPersistent = (aContext != nil);
	if (isPersistent)
	{
		NSParameterAssert(anEntityDescription != nil);
	}
	else
	{
		NSParameterAssert(aContext == nil);
	}

	ASSIGN(_uuid, aUUID);
	if (anEntityDescription != nil)
	{
		ASSIGN(_entityDescription, anEntityDescription);
	}
	else
	{
		// NOTE: Ensure we can use -propertyNames and metamodel-based 
		// introspection before -becomePersistentInContext: is called.
		// TODO: Could be removed if -propertyNames in NSObject(Model) do a 
		// lookup in the main repository.
		ASSIGN(_entityDescription, [[ETModelDescriptionRepository mainRepository] 
			entityDescriptionForClass: [self class]]);
	}

	_isIgnoringDamageNotifications = NO;
	_isInitialized = YES;

	[(id)_persistentRoot markObjectAsUpdated: self forProperty: nil];
	_variableStorage = [self newVariableStorage];
	_incomingRelationships = [[CORelationshipCache alloc] init];
	[self didCreate];

	return self;
}

- (id)initWithUUID: (ETUUID *)aUUID 
 entityDescription: (ETEntityDescription *)anEntityDescription
           context: (COPersistentRoot *)aContext
{
	SUPERINIT;
	
	NILARG_EXCEPTION_TEST(aUUID);
	NILARG_EXCEPTION_TEST(anEntityDescription);
	//NILARG_EXCEPTION_TEST(aContext);

	self = [self commonInitWithUUID: aUUID 
	              entityDescription: anEntityDescription
	                        context: aContext];
	[self init];
	return self;
}

- (id) init
{
	if (_isInitialized == NO)
	{
		SUPERINIT;
		self = [self commonInitWithUUID: [ETUUID UUID]
		              entityDescription: nil
		                        context: nil];
	}
	return self;
}

- (id) initWithEntityDescription: (ETEntityDescription *)anEntityDesc
{
	return [self initWithUUID: [ETUUID UUID] entityDescription: anEntityDesc context: nil];
}

- (void)dealloc
{
	_persistentRoot = nil;
	DESTROY(_uuid);
	DESTROY(_entityDescription);
	DESTROY(_variableStorage);
    DESTROY(_incomingRelationships);
	[super dealloc];
}

- (BOOL)isSharedInstance
{
	return [[[[self class] ifResponds] sharedInstance] isEqual: self];
}

// TODO: Remove 
- (void)becomePersistentInContext: (COPersistentRoot *)aContext
{
	/* For transitively persisted objects, shared objects (e.g. action handlers
	   in EtoileUI) can receive -becomePersistentInContext: multiple times.
	   In such a case, the receiver can belong or not to another persistent root
	   than the context argument. */
	if ([self isPersistent])
		return;

	NILARG_EXCEPTION_TEST(aContext);
	INVALIDARG_EXCEPTION_TEST(aContext, [aContext isKindOfClass: [COPersistentRoot class]]);

    // i.e., a shared instance cannot _become_ persistent, it must have been created persistent
	if ([self isSharedInstance])
	{
		/* For example, EtoileUI aspects returned by -sharedInstance must remain transient */
		[NSException raise: NSInternalInconsistencyException
					format: @"Shared instance such as %@ must never become "
		                     "persistent to prevent ownership and aliasing issues", self];
	}
	
	/* Both transient and persistent objects must have a valid UUID */
	ETAssert(_uuid != nil);
	_persistentRoot = aContext;
	if (_entityDescription == nil)
	{
		ASSIGN(_entityDescription, [[[(id)aContext parentContext] modelRepository] entityDescriptionForClass: [self class]]);
	}
	[aContext registerObject: self];
}

// TODO: Maybe add convenience copying method, - (COObject *) copyWithCopier: (COCopier *)aCopier
// where the copier stores the state relating to copying, e.g. which context to copy into.

// TODO: Remove; COObject should not respond to -copyWithZone
- (id) copyWithZone: (NSZone *)aZone usesModelDescription: (BOOL)usesModelDescription
{
	COObject *newObject = [[self class] allocWithZone: aZone];
	
	newObject->_uuid = [[ETUUID alloc] init];
	newObject->_persistentRoot = _persistentRoot;
	if (_variableStorage != nil)
	{
		newObject->_variableStorage = [self newVariableStorage];
        newObject->_incomingRelationships = [[CORelationshipCache alloc] init];
        
		if (usesModelDescription)
		{
			// TODO: For variable storage properties, support a metamodel-driven copy
			// Share support code with -insertObjectCopy: or make -insertObjectCopy: 
			// uses -copyWithZone:
		}
	}

	return newObject;
}

- (id) copyWithZone: (NSZone *)aZone
{
	return [self copyWithZone: aZone usesModelDescription: NO];
}

// Attributes

- (ETEntityDescription *)entityDescription
{
	return _entityDescription;
}

- (ETUUID*) UUID
{
	return _uuid;
}

- (COPersistentRoot *)persistentRoot
{
	return _persistentRoot;
}

- (COObject *) rootObject
{
	return [_persistentRoot rootObject];
}

- (BOOL) isRoot
{
	return ([self rootObject] == self);
}

- (BOOL) isFault
{
	return NO;
}

- (CORevision *)revision
{
	return [_persistentRoot revision];
}

- (BOOL) isPersistent
{
	return (_persistentRoot != nil);
	// TODO: Switch to the code below on root object are saved in the db
	// return (_persistentRoot != nil && _rootObject != nil);
}

- (BOOL) isDamaged
{
	return [[self persistentRoot] isUpdatedObject: self];
}

/* Helper methods based on the metamodel */

- (NSArray*)allStronglyContainedObjects
{
	NSMutableArray *result = [NSMutableArray array];
	for (ETPropertyDescription *propDesc in [[self entityDescription] allPropertyDescriptions])
	{
		if ([propDesc isComposite])
		{
			id value = [self valueForProperty: [propDesc name]];
			
			assert([propDesc isMultivalued] ==
				   ([value isKindOfClass: [NSArray class]] || [value isKindOfClass: [NSSet class]]));
			
			if ([propDesc isMultivalued])
			{
				for (id subvalue in value)
				{
					if ([subvalue isKindOfClass: [COObject class]])
					{
						[result addObject: subvalue];
						[result addObjectsFromArray: [subvalue allStronglyContainedObjects]];
					}
				}
			}
			else
			{
				if ([value isKindOfClass: [COObject class]])
				{
					[result addObject: value];
					[result addObjectsFromArray: [value allStronglyContainedObjects]];
				}
				// Ignore non-COObject objects
			}
		}
	}
	return result;
}

- (NSArray*)allStronglyContainedObjectsIncludingSelf
{
	return [[self allStronglyContainedObjects] arrayByAddingObject: self];
}

- (NSSet *)allInnerObjects
{
	if ([self isRoot] == NO)
		return nil;

	if ([self isPersistent] == NO)
	{
		[NSException raise: NSInternalInconsistencyException
		            format: @"Inner objects cannot be known until %@ has become persistent", self];
	}

	// FIXME: Remove or reimplement without accessing the store directly
	//CORevision *loadedRev = [_persistentRoot revision];
	//ETUUID *trackUUID = [[[self persistentRoot] commitTrack] UUID];
	//NSSet *innerObjectUUIDs = [[[self persistentRoot] store] objectUUIDsForCommitTrackUUID: trackUUID atRevision: loadedRev];
	NSSet *innerObjectUUIDs = nil;
	NSMutableSet *innerObjects = [NSMutableSet setWithCapacity: [innerObjectUUIDs count]];

	for (ETUUID *uuid in innerObjectUUIDs)
	{
		[innerObjects addObject: [[_persistentRoot parentContext] objectWithUUID: uuid]];
	}
	return innerObjects;
}

- (NSSet *)allInnerObjectsIncludingSelf
{
	return [[self allInnerObjects] setByAddingObject: self];
}

- (NSString *)displayName
{
	return [self name];
}

- (NSString *)name
{
	return [self valueForUndefinedKey: @"name"];
}

- (NSString *)identifier
{
	return [self name];
}

- (void)setName: (NSString *)aName
{
	[self willChangeValueForProperty: @"name"];
	[self setValue: aName forUndefinedKey: @"name"];
	[self didChangeValueForProperty: @"name"];
}

- (NSDate *)modificationDate
{
	return nil;
	// FIXME: Port to the new store
#if 0
	ETUUID *branchUUID = [[[self persistentRoot] commitTrack] UUID];
	CORevision *rev = [[[self persistentRoot] store] maxRevision: INT64_MAX
	                                          forCommitTrackUUID: branchUUID];
	return [rev date];
#endif
}

- (NSDate *)creationDate
{
	return  nil;
	// FIXME: Port to the new store
#if 0
	ETUUID *branchUUID = [[[self persistentRoot] commitTrack] UUID];
	CORevision *rev = [[[self persistentRoot] store] maxRevision: 0 
	                                          forCommitTrackUUID: branchUUID];
	return [rev date];
#endif
}

- (NSArray *)parentGroups
{
	return [self valueForProperty: @"parentCollections"];
}

- (NSArray *)tags
{
	return [self primitiveValueForKey: @"tags"];
}

/* Property-value coding */

- (NSSet *) observableKeyPaths
{
	return S(@"name", @"lastVersionDescription", @"tagDescription");
}

- (NSArray *)propertyNames
{
	return [[self entityDescription] allPropertyDescriptionNames];
}

- (NSArray *) persistentPropertyNames
{
	return (id)[[[[self entityDescription] allPersistentPropertyDescriptions] mappedCollection] name];
}

- (BOOL)isPersistentProperty: (NSString *)key
{
	return [[self persistentPropertyNames] containsObject: key];
}

- (id) valueForProperty:(NSString *)key
{
	if (![[self propertyNames] containsObject: key])
	{
		[NSException raise: NSInvalidArgumentException format: @"Tried to get value for invalid property %@", key];
		return nil;
	}
	
	return [super valueForKey: key];
}

+ (BOOL) isPrimitiveCoreObjectValue: (id)value
{  
	return [value isKindOfClass: [NSNumber class]] ||
		[value isKindOfClass: [NSDate class]] ||
		[value isKindOfClass: [NSData class]] ||
		[value isKindOfClass: [NSString class]] ||
		[value isKindOfClass: [COObject class]] ||
		value == nil;
}

+ (BOOL) isCoreObjectValue: (id)value
{
	if ([value isKindOfClass: [NSArray class]] ||
		[value isKindOfClass: [NSSet class]])
	{
		for (id subvalue in value)
		{
			if (![COObject isPrimitiveCoreObjectValue: subvalue])
			{
				return NO;
			}
		}
		return YES;
	}
	else 
	{
		return [COObject isPrimitiveCoreObjectValue: value];
	}
}

/* Makes sure the value is in the same context as us. */
- (void)checkEditingContextForValue:(id)value
{
	if ([value isKindOfClass: [NSArray class]] ||
		[value isKindOfClass: [NSSet class]])
	{
		for (id subvalue in value)
		{
			[self checkEditingContextForValue: subvalue];
		}
	}
	else 
	{
		if ([value isKindOfClass: [COObject class]])
		{
			assert([[value persistentRoot] parentContext] == [_persistentRoot parentContext]);
		}    
	}
}

- (BOOL) setValue: (id)value forProperty: (NSString *)key
{
	/* We call the setter directly if implemented */

	NSString *setterName = [NSString stringWithFormat: @"set%@:", [key stringByCapitalizingFirstLetter]];
	SEL setter = NSSelectorFromString(setterName);

	if ([self respondsToSelector: setter])
	{
		// NOTE: Don't use -performSelector:withObject: because it doesn't
		// support unboxing scalar values as Key-Value Coding does.
		[self setValue: value forKey: key];
		return YES;
	}

	/* Otherwise we do the integrity check, update the variable storage, and 
	   trigger the change notifications */

	if (![[self propertyNames] containsObject: key])
	{
		[NSException raise: NSInvalidArgumentException format: @"Tried to set value for invalid property %@", key];
		return NO;
	}

	// FIXME: Move this check elsewhere or rework it because it can break on 
	// transient values or archived objects such as NSColor, NSView.
	//if (![COObject isCoreObjectValue: value])
	//{
	//	[NSException raise: NSInvalidArgumentException format: @"Invalid property type"];
	//}

 	BOOL isMultivalued = [[[self entityDescription] propertyDescriptionForName: key] isMultivalued];
    
    if (isMultivalued)
    {
        if (([value isKindOfClass: [NSArray class]] && ![value isKindOfClass: [NSMutableArray class]]))
        {
            value = [NSMutableArray arrayWithArray: value];
        }
        else if (([value isKindOfClass: [NSSet class]] && ![value isKindOfClass: [NSMutableSet class]]))
        {
            value = [NSSet setWithSet: value];
        }
    }
    
	id oldValue = [self valueForProperty: key];
	 
    oldValue = [(isMultivalued ? [oldValue mutableCopy] : [oldValue retain]) autorelease];

	[self checkEditingContextForValue: value];

	[self willChangeValueForProperty: key];
	[self setPrimitiveValue: value forKey: key];
	[self didChangeValueForProperty: key oldValue: oldValue];

	return YES;
}

- (NSArray *)validateAllValues
{
	NSMutableArray *results = [NSMutableArray array];

	// TODO: We might want to coalesce bidirectional relationships validation results
	for (NSString *key in [self persistentPropertyNames])
	{
		[results addObjectsFromArray: [self validateValue: [self valueForProperty: key] 
		                                      forProperty: key]];
	}
	return results;
}

- (ETValidationResult *)validateValueUsingMetamodel: (id)value forProperty: (NSString *)key
{
	ETPropertyDescription *propertyDesc = [_entityDescription propertyDescriptionForName: key];
	ETPropertyDescription *opposite = [propertyDesc opposite];
	ETValidationResult *oppositeResult = nil;

	if (opposite != nil)
	{
		NSString *oppositeKey = [opposite name];
		id oppositeValue = [value valueForProperty: oppositeKey];

		oppositeResult = [opposite validateValue: oppositeValue forKey: oppositeKey];
	}
	
	ETValidationResult *result = [propertyDesc validateValue: value forKey: key];
	// TODO: [result setOppositeResult: oppositeResult];

	return result;
}

- (ETValidationResult *)validateValueUsingPVC: (id)value forProperty: (NSString *)key
{
	SEL keySelector = NSSelectorFromString([NSString stringWithFormat: @"validate%@:",
		[key stringByCapitalizingFirstLetter]]);

	if ([self respondsToSelector: keySelector] == NO)
		return [ETValidationResult validResult: value];

	return [self performSelector: keySelector withObject: value];
}

// TODO: If we want to support -validateValue:forKey:error: too, implement 
// -validateUsingKVC:forProperty:
// TODO: Would be cleaner to return an aggregate validation result
- (NSArray *)validateValue: (id)value forProperty: (NSString *)key
{
	ETValidationResult *result = [self validateValueUsingMetamodel: value forProperty: key];
	ETValidationResult *pvcResult = [self validateValueUsingPVC: value forProperty: key];
	NSMutableArray *results = [NSMutableArray arrayWithCapacity: 2];

	if ([result isValid] == NO)
	{
		[results addObject: result];
	}
	if ([pvcResult isValid] == NO)
	{
		[results addObject: pvcResult];
	}
	return results;
}

- (NSError *)validateForInsert
{
	return nil;
}

- (NSError *)validateForUpdate
{
	return [COError errorWithValidationResults: [self validateAllValues]];
}

- (NSError *)validateForDelete
{
	return nil;
}

- (BOOL)validateValue:(id *)aValue forKey:(NSString *)key error:(NSError **)anError
{
	NSArray *results = [self validateValue: *aValue forProperty: key];

	if ([results count] == 1 && [[results firstObject] isValid])
		return YES;

	*aValue = [[results lastObject] value];
	*anError = [COError errorWithValidationResults: results];
	return NO;
}

- (id)primitiveValueForKey: (NSString *)key
{
    ETPropertyDescription *propDesc = [[self entityDescription] propertyDescriptionForName: key];

    // Special case for searching the relationship cache
    if (![propDesc isPersistent]
        && (nil != [propDesc opposite])
        && ([[propDesc opposite] isPersistent]))
    {
        if ([propDesc isMultivalued])
        {
            NSSet *results = [_incomingRelationships referringObjectsForPropertyInTarget: key];
            
            return results;
        }
        COObject *result = [_incomingRelationships referringObjectForPropertyInTarget: key];
        return result;
    }

	id value = [_variableStorage objectForKey: key];
	return (value == [NSNull null] ? nil : value);
}

- (void)setPrimitiveValue: (id)value forKey: (NSString *)key
{
	[_variableStorage setObject: (value == nil ? [NSNull null] : value)
						 forKey: key];
}

// FIXME: Investigate whether this way of implementing KVC is really KVC compliant
- (id)valueForUndefinedKey: (NSString *)key
{
	return [self primitiveValueForKey: key];
}

- (void)setValue: (id)value forUndefinedKey: (NSString *)key
{
	[self setPrimitiveValue: value forKey: key];
}

- (void)willChangeValueForProperty: (NSString *)key
{
	[super willChangeValueForKey: key];
}

- (void) markAsUpdatedIfNeededForProperty: (NSString*)prop
{
	if (_isIgnoringDamageNotifications || [self isPersistent] == NO)
		return;
	
	[[self persistentRoot] markObjectAsUpdated: self forProperty: prop];
}

- (void)didChangeValueForProperty: (NSString *)key
{
	[self didChangeValueForProperty: key oldValue: nil];
}

- (void) becomePersistentAccordingToModelDescriptionForProperty: (NSString *)key
{
	ETPropertyDescription *propertyDesc = [_entityDescription propertyDescriptionForName: key];
	
	if ([propertyDesc isPersistent] && [propertyDesc isMultivalued] == NO && [[propertyDesc type] isPrimitive] == NO)
	{
		[[self valueForProperty: key] becomePersistentInContext: [self persistentRoot]];
	}
}

- (void)didChangeValueForProperty: (NSString *)key oldValue: (id)oldValue
{
    ETPropertyDescription *propertyDesc = [_entityDescription propertyDescriptionForName: key];
    
	// TODO: Evaluate whether -checkEditingContextForValue: is too costly
	//[self checkEditingContextForValue: [self valueForProperty: key]];
    
    // Remove objects in newValue from their old parents
    // as perscribed by the COEditingContext class docs
    // FIXME: Ugly implementation
    if ([propertyDesc isComposite])
    {
        ETPropertyDescription *parentDesc = [propertyDesc opposite];
        id aValue = [self valueForKey: key];
        
        for (COObject *objectBeingInserted in ([propertyDesc isMultivalued] ? aValue : [NSArray arrayWithObject: aValue]))
        {
            COObject *objectBeingInsertedParent = [[objectBeingInserted relationshipCache] referringObjectForPropertyInTarget: [parentDesc name]];
            
            // FIXME: Minor flaw, you can insert a composite twice if the collection is ordered.
            // e.g.
            // (a, b, c) => (a, b, c, a) since we only remove the objects from their old parents if the
            // parent is different than the object we're inserting into
            
            if (objectBeingInsertedParent != nil && objectBeingInsertedParent != self)
            {
                [objectBeingInsertedParent removeObject: objectBeingInserted atIndex: ETUndeterminedIndex hint: nil forProperty: key];
            }
        }
    }
    
    [_persistentRoot updateCachedOutgoingRelationshipsForOldValue: oldValue
                                                         newValue: [self valueForKey: key]
                                        ofPropertyWithDescription: [_entityDescription propertyDescriptionForName: key]
                                                         ofObject: self];
    
	[self markAsUpdatedIfNeededForProperty: key];
	// FIXME: [self becomePersistentAccordingToModelDescriptionForProperty: key];
	
	[super didChangeValueForKey: key];
}

- (id)collectionForProperty: (NSString *)key insertionIndex: (NSInteger)index
{
	ETPropertyDescription *desc = [[self entityDescription] propertyDescriptionForName: key];
	id collection = [self valueForProperty: key];

	if (index == ETUndeterminedIndex)
	{
		if (![desc isMultivalued])
		{
			[NSException raise: NSInvalidArgumentException 
						format: @"Attempt to call addObject:forProperty: for %@ which is not a multivalued property of %@", key, self];
		}
		if (!([collection isKindOfClass: [NSMutableArray class]] || [collection isKindOfClass: [NSMutableSet class]]))
		{
			[NSException raise: NSInternalInconsistencyException 
						format: @"Multivalued property not set up properly"];
		}
	}
	else
	{
		if (!([desc isMultivalued] && [desc isOrdered]))
		{
			[NSException raise: NSInvalidArgumentException format: @"Attempt to call insertObject:atIndex:forProperty: for %@ which is not an ordered multivalued property of %@", key, self];
		}
		if (!([collection isKindOfClass: [NSMutableArray class]]))
		{
			[NSException raise: NSInternalInconsistencyException format: @"Multivalued property not set up properly"];
		}
	}
	return collection;
}

- (void)insertObject: (id)object atIndex: (NSUInteger)index hint: (id)hint forProperty: (NSString *)key
{
	[self checkEditingContextForValue: object];

	id oldCollection = [[self valueForProperty: key] mutableCopy];
	id collection = [self collectionForProperty: key insertionIndex: index];

	[self willChangeValueForProperty: key];
	[collection insertObject: object atIndex: index hint: hint];
	[self didChangeValueForProperty: key oldValue: oldCollection];
}

- (id)collectionForProperty: (NSString *)key removalIndex: (NSInteger)index
{
	ETPropertyDescription *desc = [[self entityDescription] propertyDescriptionForName: key];
	id collection = [self valueForProperty: key];

	if (index == ETUndeterminedIndex)
	{
		if (![desc isMultivalued])
		{
			[NSException raise: NSInvalidArgumentException format: @"Attempt to call removeObject:forProperty: for %@ which is not a multivalued property of %@", key, self];
		}
		if (!([collection isKindOfClass: [NSMutableArray class]] || [collection isKindOfClass: [NSMutableSet class]]))
		{
			[NSException raise: NSInternalInconsistencyException format: @"Multivalued property not set up properly"];
		}
	}
	else
	{
		if (!([desc isMultivalued] && [desc isOrdered]))
		{
			[NSException raise: NSInvalidArgumentException format: @"Attempt to call removeObject:atIndex:forProperty: for %@ which is not an ordered multivalued property of %@", key, self];
		}
		if (!([collection isKindOfClass: [NSMutableArray class]]))
		{
			[NSException raise: NSInternalInconsistencyException format: @"Multivalued property not set up properly"];
		}
	}
	return collection;
}

- (void)removeObject: (id)object atIndex: (NSUInteger)index hint: (id)hint forProperty: (NSString *)key
{
	[self checkEditingContextForValue: object];

	id oldCollection = [[self valueForProperty: key] mutableCopy];
	id collection = [self collectionForProperty: key removalIndex: index];

	[self willChangeValueForProperty: key];
	[collection removeObject: object atIndex: index hint: hint];
	[self didChangeValueForProperty: key oldValue: oldCollection];
}

// TODO: Change to new -didAwaken method called in a predetermined order
- (void)awakeFromFetch
{
    [_persistentRoot addCachedOutgoingRelationshipsForObject: self];
    
	// Debugging check that collections were set up properly
	for (ETPropertyDescription *propDesc in [[self entityDescription] allPropertyDescriptions])
	{
		if ([propDesc isMultivalued])
		{
			Class cls = [propDesc isOrdered] ? [NSMutableArray class] : [NSMutableSet class];
			if (![[self valueForProperty: [propDesc name]] isKindOfClass: cls])
			{
				[NSException raise: NSInternalInconsistencyException format: @"Property %@ of %@ is a collection but was not set up properly", [propDesc name], self];
			}
		}
	}
}

- (void)willLoad
{
	assert(_variableStorage == nil);
	_variableStorage = [self newVariableStorage];
    _incomingRelationships = [[CORelationshipCache alloc] init];
}

- (void)didLoad
{
	
}

- (void)didReload
{

}

- (NSUInteger)hash
{
	return [_uuid hash] ^ 0x39ab6f39b15233de;
}

- (BOOL)isEqual: (id)anObject
{
	if (anObject == self)
	{
		return YES;
	}
	if (![anObject isKindOfClass: [COObject class]])
	{
		return NO;
	}
	if ([[anObject UUID] isEqual: _uuid])
	{
		return YES;
	}
	return NO;
}

- (BOOL)isDeeplyEqual: (id)object
{
	// FIXME: Incomplete/incorrect
	if ([object isKindOfClass: [COObject class]])
	{
		COObject *other = (COObject*)object;
		if (![[self UUID] isEqual: [other UUID]])
		{
			return NO; 
		}
		for (ETPropertyDescription *propDesc in [[self entityDescription] allPropertyDescriptions])
		{
			if (![propDesc isDerived])
			{
				id selfValue = [self valueForProperty: [propDesc name]];
				id otherValue = [other valueForProperty: [propDesc name]];
				if (selfValue == otherValue)
				{
					continue;
				}
				if (![selfValue isEqual: otherValue] && !(selfValue == nil && otherValue == nil))
				{
					return NO; 
				}
			}
		}
		return YES;
	}
	return NO;
}

- (BOOL) isTemporalInstance: (id)anObject
{
	if (anObject == self)
	{
		return YES;
	}
	if (![anObject isKindOfClass: [COObject class]])
	{
		return NO;
	}
	if ([[anObject UUID] isEqual: _uuid] && [[anObject revision] isEqual: [self revision]])
	{
		return YES;
	}
	return NO;
}

- (COCommitTrack *)commitTrack
{
	return [[self persistentRoot] commitTrack];
}

- (NSArray *)objectsMatchingQuery: (COQuery *)aQuery
{
	// TODO: Check and traverse relationships to visit the object graph
	return ([[aQuery predicate] evaluateWithObject: self] ? A(self) : [NSArray array]);
}

// TODO: Remove or port to COSerialization. -serializedRepresentation is basically
// the same than -storeItem.
#if 0
- (id)serializedRepresentation
{
	NSMutableDictionary *serializationRep = [NSMutableDictionary dictionary];

	for (NSString *prop in [self persistentPropertyNames])
	{
		id value = [self serializedValueForProperty: prop];
		id plist = [self propertyListForValue: value];

		[serializationRep setObject: (plist != nil ? plist : [NSNull null]) forKey: prop];
	}
	return serializationRep;
}

- (id)roundTripValueForProperty: (NSString *)key
{
	id plist = [self propertyListForValue: [self serializedValueForProperty: key]];
	return [self valueForPropertyList: plist];
}
#endif

static int indent = 0;

- (NSString *)detailedDescription
{
	if (_inDescription)
	{
		return [NSString stringWithFormat: @"<Recursive reference to %@(%@) at %p UUID %@>", [[self entityDescription] name], NSStringFromClass([self class]), self, _uuid];
	}
	_inDescription = YES;
	indent++;
	NSMutableString *str = [NSMutableString stringWithFormat: @"<%@(%@) at %p UUID %@ data: {\n",  [[self entityDescription] name], NSStringFromClass([self class]), self, _uuid];
	indent++;
	
	NSMutableArray *props = [NSMutableArray arrayWithArray: [self persistentPropertyNames]];
	if ([props containsObject: @"contents"])
	{
		[props removeObject: @"contents"];
		[props insertObject: @"contents" atIndex: 0];
	}
	if ([props containsObject: @"label"])
	{
		[props removeObject: @"label"];
		[props insertObject: @"label" atIndex: 0];
	}
	for (NSString *prop in props)
	{
		NSMutableString *valuestring = [NSMutableString string];
		id value = [self valueForProperty: prop];
		if ([value isKindOfClass: [NSSet class]])
		{
			[valuestring appendFormat: @"(\n"];
			for (id item in value)
			{
				for (int i=0; i<indent + 1; i++) [valuestring appendFormat: @"\t"];
				[valuestring appendFormat: @"%@\n", [item description]];	
			}
			for (int i=0; i<indent; i++) [valuestring appendFormat: @"\t"];
			[valuestring appendFormat: @"),\n"];
		}
		else if ([value isKindOfClass: [NSArray class]])
		{
			[valuestring appendFormat: @"{\n"];
			for (id item in value)
			{
				for (int i=0; i<indent + 1; i++) [valuestring appendFormat: @"\t"];
				[valuestring appendFormat: @"%@", [item description]];	
			}
			for (int i=0; i<indent; i++) [valuestring appendFormat: @"\t"];
			[valuestring appendFormat: @"},\n"];
		}
		else
		{
			[valuestring appendFormat: @"%@,\n", [value description]];
		}

		
		for (int i=0; i<indent; i++) [str appendFormat: @"\t"];
		[str appendFormat:@"%@ : %@", prop, valuestring]; 
	}
	indent--;
	for (int i=0; i<indent; i++) [str appendFormat: @"\t"];
	[str appendFormat:@"}>\n"];
	indent--;
	_inDescription = NO;
	return str;
}

- (NSString *)description
{
	if (_inDescription)
	{
		// If we are called recursively, don't print the contents of _variableStorage
		// since it would result in an infinite loop.
		return [NSString stringWithFormat: @"<Recursive reference to %@(%@) at %p UUID %@>", [[self entityDescription] name], NSStringFromClass([self class]), self, _uuid];
	}
	
	_inDescription = YES;
	NSString *desc = [NSString stringWithFormat: @"<%@(%@) %p UUID=%@ properties=%@>", [[self entityDescription] name], NSStringFromClass([self class]), self, _uuid, [self propertyNames]];

	_inDescription = NO;
	return desc;
}

- (NSString *)typeDescription
{
	return [[self entityDescription] localizedDescription];
}

- (NSString *)revisionDescription
{
	return [[self revision] description];
}

- (NSString *)tagDescription
{
	return [(NSArray *)[[[self tags] mappedCollection] tagString] componentsJoinedByString: @", "];
}

/* 
 * Private 
 */

- (CORelationshipCache *)relationshipCache
{
    return _incomingRelationships;
}

@end