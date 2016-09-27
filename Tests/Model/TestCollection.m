/*
    Copyright (C) 2013 Quentin Mathe

    Date:  March 2013
    License:  MIT  (see COPYING)
 */

#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import <EtoileFoundation/ETModelDescriptionRepository.h>
#import "TestCommon.h"
#import "COEditingContext.h"
#import "COBookmark.h"
#import "COObject.h"
#import "COCollection.h"
#import "COContainer.h"
#import "COGroup.h"
#import "COLibrary.h"
#import "COPersistentRoot.h"
#import "COTag.h"

@interface COObject (TestCollection)
/**
 * Includes at least 'tags' among the multivalued properties since all COObject 
 * derived instances can be tagged.
 */
- (NSSet *)multivaluedPropertyNames;
@end

@implementation COObject (TestCollection)

- (NSSet *)multivaluedPropertyNames
{
    NSMutableSet *properties = [NSMutableSet set];

    for (ETPropertyDescription *propertyDesc in self.entityDescription.allPropertyDescriptions)
    {
        if (propertyDesc.multivalued)
        {
            [properties addObject: propertyDesc.name];
        }
    }
    return properties;
}

@end


@interface TestCollection : EditingContextTestCase <UKTest>
@end

@implementation TestCollection

- (void)testExceptionOnAbstractCollectionInit
{
    UKRaisesException([ctx insertNewPersistentRootWithEntityName: @"COCollection"]);
}

- (void)testDefensiveCopyForContentArray
{
    COGroup *group = [ctx insertNewPersistentRootWithEntityName: @"COGroup"].rootObject;
    COGroup *container = [ctx insertNewPersistentRootWithEntityName: @"COContainer"].rootObject;

    UKFalse([[group contentArray] isMutable]);
    UKFalse([[container contentArray] isMutable]);
}

- (void)testLibraryGroup
{
    UKTrue([ctx.libraryGroup.content isEmpty]);

    /* Accessing libraries will create them */
    NSSet *someLibs = S(ctx.bookmarkLibrary, ctx.noteLibrary);

    UKObjectsEqual(someLibs, SA(ctx.libraryGroup.content));
}

- (void)testLibraryForContentType
{
    ETEntityDescription *bookmarkType = [ctx.modelDescriptionRepository descriptionForName: @"COBookmark"];

    UKObjectsEqual(ctx.bookmarkLibrary, [ctx libraryForContentType: bookmarkType]);
}

- (void)testBookmarkLibrary
{
    COLibrary *library = ctx.bookmarkLibrary;
    ETEntityDescription *entity = library.entityDescription;

    UKObjectsEqual([COLibrary class], [library class]);
    UKStringsEqual(@"COBookmarkLibrary", entity.name);
    UKStringsEqual(@"COLibrary", entity.parent.name);

    UKObjectsEqual(S(@"objects", @"tags"), [library multivaluedPropertyNames]);
    UKStringsEqual(@"COBookmark", [[entity propertyDescriptionForName: @"objects"].type name]);
    UKObjectsEqual([ETUTI typeWithClass: [COBookmark class]], library.objectType);

    UKTrue(library.ordered);
}

- (void)testNoteLibrary
{
    COLibrary *library = ctx.noteLibrary;
    ETEntityDescription *entity = library.entityDescription;

    UKObjectsEqual([COLibrary class], [library class]);
    UKStringsEqual(@"CONoteLibrary", entity.name);
    UKStringsEqual(@"COLibrary", entity.parent.name);

    UKObjectsEqual(S(@"objects", @"tags"), [library multivaluedPropertyNames]);
    UKStringsEqual(@"COContainer", [entity propertyDescriptionForName: @"objects"].type.name);
    UKObjectsEqual([ETUTI typeWithClass: [COContainer class]], library.objectType);

    UKTrue(library.ordered);
}

- (void)testTagLibrary
{
    COTagLibrary *library = [ctx insertNewPersistentRootWithEntityName: @"COTagLibrary"].rootObject;

    /* objects: the tags collected in the library
     tagGroups: the tag groups used to organize the tags in the library (see objects)
          tags: the tags applied to the library (inverse relationship) */
    UKObjectsEqual(S(@"objects", @"tagGroups", @"tags"), [library multivaluedPropertyNames]);
    UKObjectsEqual([ETUTI typeWithClass: [COTag class]], library.objectType);
    UKTrue([library.content isKindOfClass: [NSMutableArray class]]);
    UKTrue([library.tagGroups isKindOfClass: [NSMutableArray class]]);
}

- (void)testTagGroup
{
    COTagGroup *tagGroup = [ctx insertNewPersistentRootWithEntityName: @"COTagGroup"].rootObject;
    COTag *tag = [ctx insertNewPersistentRootWithEntityName: @"COTag"].rootObject;

    /* objects: the tags put in the tag group
          tags: the tags applied to the tag group (inverse relationship) */
    UKObjectsEqual(S(@"objects", @"tags"), [tagGroup multivaluedPropertyNames]);
    /* objects: the objects tagged using this tag
     tagGroups: the tag groups to which this tag belongs to (inverse relationship)
          tags: the tags applied to the tag (inverse relationship) */
    UKObjectsEqual(S(@"objects", @"tagGroups", @"tags"), [tag multivaluedPropertyNames]);

    UKObjectsEqual([ETUTI typeWithClass: [COTag class]], tagGroup.objectType);
    UKTrue([tagGroup.content isKindOfClass: [NSMutableArray class]]);
    UKTrue([tag.tagGroups isKindOfClass: [NSSet class]]);

    [tagGroup addObject: tag];

    UKObjectsEqual(A(tag), tagGroup.content);
    UKObjectsEqual(S(tagGroup), tag.tagGroups);
}

- (void)testTag
{
    COTag *tag = [ctx insertNewPersistentRootWithEntityName: @"COTag"].rootObject;
    COObject *object = [ctx insertNewPersistentRootWithEntityName: @"COObject"].rootObject;

    UKObjectsEqual(S(@"tags"), [object multivaluedPropertyNames]);
    UKObjectsEqual(S(@"objects", @"tagGroups", @"tags"), [tag multivaluedPropertyNames]);

    UKObjectsEqual([ETUTI typeWithClass: [COObject class]], tag.objectType);
    UKTrue([tag.content isKindOfClass: [NSMutableArray class]]);
    UKTrue([object.tags isKindOfClass: [NSSet class]]);

    [tag addObject: object];
    tag.name = @"bird";

    UKObjectsEqual(A(object), tag.content);
    UKObjectsEqual(S(tag), object.tags);
    UKStringsEqual(@"bird", object.tagDescription);
}

- (void)testCollectionContainingCheapCopyAndOriginal
{
    COTag *tag = [ctx insertNewPersistentRootWithEntityName: @"COTag"].rootObject;
    COObject *original = [ctx insertNewPersistentRootWithEntityName: @"COObject"].rootObject;
    
    [ctx commit];

    COObject *copy = [original.objectGraphContext.branch
        makePersistentRootCopyFromRevision: original.revision].rootObject;

    [tag addObject: original];
    [tag addObject: copy];

    UKObjectsEqual(A(original, copy), tag.content);
    UKObjectsEqual(S(tag), original.tags);
    UKObjectsEqual(S(tag), copy.tags);
}

- (void)testSimpleCrossReference
{
    COTag *tag = [ctx insertNewPersistentRootWithEntityName: @"COTag"].rootObject;
    COObject *original = [ctx insertNewPersistentRootWithEntityName: @"COObject"].rootObject;
    
    [ctx commit];
    
    [tag addObject: original];
    
    UKObjectsEqual(A(original), tag.content);
    UKObjectsEqual(S(tag), original.tags);
}
- (void)testSmartGroup
{
    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"COSmartGroup"];
    
    [ctx commit];

    [self checkPersistentRootWithExistingAndNewContext: persistentRoot
                                               inBlock: ^(COEditingContext *testCtx, COPersistentRoot *testPersistentRoot, COBranch *testBranch, BOOL isNewContext)
    {
        UKNotNil([testPersistentRoot.rootObject content]);
    }];
}

@end
