#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import <EtoileFoundation/ETModelDescriptionRepository.h>
#import "TestCommon.h"

@interface TestMerge : EditingContextTestCase <UKTest>
{
    COObjectGraphContext *ctx1;
    COObjectGraphContext *ctx2;
    COObjectGraphContext *ctx3;
}
@end

@implementation TestMerge

- (id) init
{
    self = [super init];
    ctx1 = [[COObjectGraphContext alloc] init];
	ctx2 = [[COObjectGraphContext alloc] init];
    ctx3 = [[COObjectGraphContext alloc] init];
    return self;
}

- (void) dealloc
{
    [ctx1 release];
    [ctx2 release];
    [ctx3 release];
    [super dealloc];
}

- (void)testSimpleNonconflictingMerge
{
	OutlineItem *parent = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	OutlineItem *child1 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	OutlineItem *child2 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	OutlineItem *child3 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	OutlineItem *subchild1 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[ctx1 setRootObject: parent];
    
	[child1 insertObject: subchild1 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	[parent insertObject: child1 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	[parent insertObject: child2 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	[parent insertObject: child3 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	
    // Copy into ctx2 and ctx3
    
    [ctx2 setItemGraph: ctx1];
    [ctx3 setItemGraph: ctx1];
    
	// ctx2: remove child2, set a label for subchild1
    [[ctx2 objectWithUUID: [parent UUID]] removeObject: [ctx2 objectWithUUID: [child2 UUID]] atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	[[ctx2 objectWithUUID: [subchild1 UUID]] setValue: @"Groceries" forProperty: @"label"];
    
	// ctx3: move subchild1 to child3, insert child4
	[(id)[ctx3 objectWithUUID: [child3 UUID]] insertObject: [ctx3 objectWithUUID: [subchild1 UUID]] atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	OutlineItem *child4Ctx3 = [ctx3 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[(id)[ctx3 objectWithUUID: [parent UUID]] insertObject: child4Ctx3 atIndex: 0];
	assert([[(id)[ctx1 objectWithUUID: [parent UUID]] contentArray] count] == 3);
	
	// Now do the merge
    COItemGraphDiff *diff12 = [COItemGraphDiff diffItemTree: ctx1 withItemTree: ctx2 sourceIdentifier: @"diff12"];
    COItemGraphDiff *diff13 = [COItemGraphDiff diffItemTree: ctx1 withItemTree: ctx3 sourceIdentifier: @"diff13"];
	COItemGraphDiff *merged = [diff12 itemTreeDiffByMergingWithDiff: diff13];
    
    UKFalse([merged hasConflicts]);
    
    [merged applyTo: ctx1];
    
	UKStringsEqual(@"Groceries", [subchild1 valueForProperty: @"label"]);
    UKObjectsEqual(@[subchild1], [child3 contents]);
	UKObjectsSame(child3, [subchild1 valueForProperty: @"parentContainer"]);
	UKIntsEqual(3, [[parent contentArray] count]);
	OutlineItem *child4 = (id)[ctx1 objectWithUUID: [child4Ctx3 UUID]];
    UKObjectsSame(child4, [[parent contentArray] objectAtIndex: 0]);
    UKObjectsSame(child1, [[parent contentArray] objectAtIndex: 1]);
    UKObjectsSame(child3, [[parent contentArray] objectAtIndex: 2]);
}

//
// Move/Delete tests: (merging two diffs, where one diff moves an object and the other deletes it)
//

- (void)testMoveAndDeleteOnOneToManyRelationship
{
	// Expected result: conflict
	
	OutlineItem *parent = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
    [ctx1 setRootObject: parent];
	OutlineItem *child1 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	OutlineItem *child2 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	
	[parent insertObject: child1 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	[parent insertObject: child2 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	
	// ctx1:
	//
	// parent
	//  |
	//  |--child1
	//  |
	//   \-child2
    
	[ctx2 setItemGraph: ctx1];
	[ctx3 setItemGraph: ctx1];
	
	// ctx2: remove child1
	[(id)[ctx2 objectWithUUID: [parent UUID]] removeObject: [ctx2 objectWithUUID: [child1 UUID]] atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	
	// ctx2:
	//
	// parent
	//  |
	//   \-child2
    
	// ctx3: put child1 inside  child2, and add a new child3 inside child2
	OutlineItem *child3Ctx3 = [ctx3 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[(id)[ctx3 objectWithUUID: [child2 UUID]] insertObject: [ctx3 objectWithUUID: [child1 UUID]] atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	[(id)[ctx3 objectWithUUID: [child2 UUID]] insertObject: child3Ctx3 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	
	// ctx3:
	//
	// parent
	//  |
	//   \-child2
	//       |
	//       |-child1
	//       |
	//       \-child3
	
	
	// Now do the merge
    COItemGraphDiff *diff12 = [COItemGraphDiff diffItemTree: ctx1 withItemTree: ctx2 sourceIdentifier: @"diff12"];
    COItemGraphDiff *diff13 = [COItemGraphDiff diffItemTree: ctx1 withItemTree: ctx3 sourceIdentifier: @"diff13"];
	COItemGraphDiff *merged = [diff12 itemTreeDiffByMergingWithDiff: diff13];
	
    // Currently fails:
    //UKTrue([merged hasConflicts]);
}

- (void)testMoveAndDeleteOnManyToManyRelationship
{
	// Expected: both succeed
    Tag *parent = [ctx1 insertObjectWithEntityName: @"Anonymous.Tag"];
    [ctx1 setRootObject: parent];
    
	Tag *tag1 = [ctx1 insertObjectWithEntityName: @"Anonymous.Tag"];
	Tag *tag2 = [ctx1 insertObjectWithEntityName: @"Anonymous.Tag"];
	OutlineItem *child = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	
    [parent insertObject: tag1 atIndex: ETUndeterminedIndex hint: nil forProperty: @"childTags"];
    [parent insertObject: tag2 atIndex: ETUndeterminedIndex hint: nil forProperty: @"childTags"];
	[tag1 insertObject: child atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	
	// ctx1:
	//
	// tag1         tag2
	//  |
	//   \--child
	
    [ctx2 setItemGraph: ctx1];
    [ctx3 setItemGraph: ctx1];
    
	Tag *tag1Ctx2 = (Tag *)[ctx2 objectWithUUID: [tag1 UUID]];
	Tag *tag2Ctx2 = (Tag *)[ctx2 objectWithUUID: [tag2 UUID]];
	OutlineItem *childCtx2 = (OutlineItem *)[ctx2 objectWithUUID: [child UUID]];
	
	Tag *tag1Ctx3 = (Tag *)[ctx3 objectWithUUID: [tag1 UUID]];
	OutlineItem *childCtx3 = (OutlineItem *)[ctx3 objectWithUUID: [child UUID]];
	
	// ctx2: move child to tag2
	UKTrue([[tag1Ctx2 contents] containsObject: childCtx2]);
	[tag1Ctx2 removeObject: childCtx2 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	[tag2Ctx2 insertObject: childCtx2 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	
	// ctx2:
	//
	// tag1         tag2
	//               |
	//                \--child
	
	// ctx3: delete child from tag1
	UKTrue([[tag1Ctx3 contents] containsObject: childCtx3]);
	[tag1Ctx3 removeObject: childCtx3 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	
	// ctx3:
	//
	// tag1         tag2
	//
	// child
	
	
	// Now do the merge
	//NSArray *uuids = (id)[[A(tag1, tag2, child) mappedCollection] UUID];
    COItemGraphDiff *diff12 = [COItemGraphDiff diffItemTree: ctx1 withItemTree: ctx2 sourceIdentifier: @"diff12"];
    COItemGraphDiff *diff13 = [COItemGraphDiff diffItemTree: ctx1 withItemTree: ctx3 sourceIdentifier: @"diff13"];
	COItemGraphDiff *merged = [diff12 itemTreeDiffByMergingWithDiff: diff13];

    UKFalse([merged hasConflicts]);
	
	// Apply the resulting diff to ctx1
	[merged applyTo: ctx1];
	
	// Expected result:
	//
	// tag1         tag2
	//               |
	//                \--child
	
	UKIntsEqual(0, [[tag1 contents] count]);
	UKIntsEqual(1, [[tag2 contents] count]);
	UKObjectsEqual(S(tag2), [child valueForProperty: @"parentCollections"]);
}

//
// Insert/Insert tests: (merging two diffs, where both diffs insert the same object, possibly in different places)
//


- (void)testConflictingInsertInsertOnOneToManyRelationship
{
	OutlineItem *parent = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
    [ctx1 setRootObject: parent];
	OutlineItem *child1 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	OutlineItem *child2 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	
	[parent insertObject: child1 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	[parent insertObject: child2 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	
	// ctx1:
	//
	// parent
	//  |
	//  |\-child1
	//  |
	//   \-child2
	
	[ctx2 setItemGraph: ctx1];	
	
	// ctx2: insert subchild1 in child1
	OutlineItem *subchild1Ctx2 = [ctx2 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[(id)[ctx2 objectWithUUID: [child1 UUID]] insertObject: subchild1Ctx2 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	UKObjectsSame([ctx2 objectWithUUID: [child1 UUID]], [subchild1Ctx2 valueForProperty: @"parentContainer"]);
	UKIntsEqual(1, [[(id)[ctx2 objectWithUUID: [child1 UUID]] contentArray] count]);
	UKIntsEqual(0, [[(id)[ctx2 objectWithUUID: [child2 UUID]] contentArray] count]);
	
	// ctx2:
	//
	// parent
	//  |
	//  |\-child1
	//  |   |
	//  |   \-subchild1
	//  |
	//   \-child2
	
	
	// ctx3: insert subchild1 in child2
    [ctx3 setItemGraph: ctx2];
	[(id)[ctx3 objectWithUUID: [child2 UUID]] insertObject: [ctx3 objectWithUUID: [subchild1Ctx2 UUID]] atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	UKObjectsSame([ctx3 objectWithUUID: [child2 UUID]], [[ctx3 objectWithUUID: [subchild1Ctx2 UUID]] valueForProperty: @"parentContainer"]);
	UKIntsEqual(0, [[(id)[ctx3 objectWithUUID: [child1 UUID]] contentArray] count]);
	UKIntsEqual(1, [[(id)[ctx3 objectWithUUID: [child2 UUID]] contentArray] count]);
	
	// ctx3:
	//
	// parent
	//  |
	//  |\-child1
	//  |
	//   \-child2
	//      |
	//      \-subchild1
	
    COItemGraphDiff *diff12 = [COItemGraphDiff diffItemTree: ctx1 withItemTree: ctx2 sourceIdentifier: @"diff12"];
    COItemGraphDiff *diff13 = [COItemGraphDiff diffItemTree: ctx1 withItemTree: ctx3 sourceIdentifier: @"diff13"];
	COItemGraphDiff *merged = [diff12 itemTreeDiffByMergingWithDiff: diff13];

    UKTrue([merged hasConflicts]);
}

- (void)testNonconflictingInsertInsertOnOneToManyRelationship
{
	// Expected: both succeed

	OutlineItem *parent = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
    [ctx1 setRootObject: parent];
	OutlineItem *child1 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	
	[parent insertObject: child1 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	
	// ctx1:
	//
	// parent
	//  |
	//   \-child1
	
	[ctx2 setItemGraph: ctx1];
	
	// ctx2: insert subchild1 in child1
	OutlineItem *subchild1Ctx2 = [ctx2 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[(id)[ctx2 objectWithUUID: [child1 UUID]] insertObject: subchild1Ctx2 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	UKObjectsSame([ctx2 objectWithUUID: [child1 UUID]], [subchild1Ctx2 valueForProperty: @"parentContainer"]);
	UKIntsEqual(1, [[(id)[ctx2 objectWithUUID: [child1 UUID]] contentArray] count]);
	
	// ctx2:
	//
	// parent
	//  |
	//   \-child1
	//      |
	//      \-subchild1
	
	
	// ctx3: insert subchild1 in child1
    [ctx3 setItemGraph: ctx2];
	UKObjectsSame([ctx3 objectWithUUID: [child1 UUID]], [[ctx3 objectWithUUID: [subchild1Ctx2 UUID]] valueForProperty: @"parentContainer"]);
    UKIntsEqual(1, [[(id)[ctx3 objectWithUUID: [child1 UUID]] contents] count]);
	
	// ctx3:
	//
	// parent
	//  |
	//   \-child1
	//      |
	//      \-subchild1
	
    COItemGraphDiff *diff12 = [COItemGraphDiff diffItemTree: ctx1 withItemTree: ctx2 sourceIdentifier: @"diff12"];
    COItemGraphDiff *diff13 = [COItemGraphDiff diffItemTree: ctx1 withItemTree: ctx3 sourceIdentifier: @"diff13"];
	COItemGraphDiff *merged = [diff12 itemTreeDiffByMergingWithDiff: diff13];
    UKFalse([merged hasConflicts]);
	
    [merged applyTo: ctx1];
    
	OutlineItem *subchild1 = (id)[ctx1 objectWithUUID: [subchild1Ctx2 UUID]];
    UKNotNil(subchild1);
	UKObjectsSame(child1, [subchild1 valueForProperty: @"parentContainer"]);
    UKIntsEqual(1, [[child1 contents] count]);
	UKObjectsEqual(A(subchild1), [child1 contents]);
}

/**
 * Tests a sequence edit that is a mix of both sides making some of the same
 * changes, and some that interleave
 */
- (void)testNonconflictingMixedSequenceEdit
{
	// Expected: both succeed
    
	OutlineItem *parent = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
    [ctx1 setRootObject: parent];
	OutlineItem *child1 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	OutlineItem *child2 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
    OutlineItem *child3 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
    
	[parent insertObject: child1 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	[parent insertObject: child2 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	[parent insertObject: child3 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
    
	// ctx1:
	//
	// parent
	//  |
	//  |--child1
	//  |
	//  |--child2
	//  |
	//   \-child3
    
	[ctx2 setItemGraph: ctx1];
	
	OutlineItem *child0 = [ctx2 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	OutlineItem *child1a = [ctx2 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	OutlineItem *child4 = [ctx2 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
    
	[[ctx2 rootObject] insertObject: child0 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	[[ctx2 rootObject] insertObject: child1a atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
    [[ctx2 rootObject] insertObject: child4 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
    
	// ctx2:
	//
	// parent
	//  |
	//  |--child0    ** new
	//  |
	//  |--child1
	//  |
	//  |--child1a   ** new
	//  |
	//  |--child2
	//  |
	//  |--child3
	//  |
	//   \-child4    ** new
	
	
	// ctx3:
    [ctx3 setItemGraph: ctx2];
    
    OutlineItem *child2a = [ctx3 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
    [[[ctx3 rootObject] mutableArrayValueForKey: @"contents"] removeObjectAtIndex: 2];
    [[[ctx3 rootObject] mutableArrayValueForKey: @"contents"] insertObject: child2a atIndex: 3];

	// ctx3:
	//
	// parent
	//  |
	//  |--child0    ** new
	//  |
	//  |--child1
	//  |
	//  |--child2
	//  |
	//  |--child2a   ** new
	//  |
	//  |--child3
	//  |
	//   \-child4    ** new
	
    COItemGraphDiff *diff12 = [COItemGraphDiff diffItemTree: ctx1 withItemTree: ctx2 sourceIdentifier: @"diff12"];
    COItemGraphDiff *diff13 = [COItemGraphDiff diffItemTree: ctx1 withItemTree: ctx3 sourceIdentifier: @"diff13"];
	COItemGraphDiff *merged = [diff12 itemTreeDiffByMergingWithDiff: diff13];
    
    // FIXME: Currently failing
#if 0
    UKFalse([merged hasConflicts]);
	   
    [merged applyTo: ctx1];
    
    // ctx1:
	//
	// parent
	//  |
	//  |--child0    ** new (from ctx2 and ctx3)
	//  |
	//  |--child1
	//  |
	//  |--child1a   ** new (from ctx2)
	//  |
	//  |--child2
	//  |
	//  |--child2a   ** new (from ctx3)
	//  |
	//  |--child3
	//  |
	//   \-child4    ** new (from ctx2 and ctx3)
    
	UKObjectsEqual((@[[child0 UUID],
                      [child1 UUID],
                      [child1a UUID],
                      [child2 UUID],
                      [child2a UUID],
                      [child3 UUID],
                      [child4 UUID]]), [[[parent contents] mappedCollection] UUID]);
#endif
}

- (void)testInsertInsertOnManyToManyRelationship
{
	// Expected: both succeed

    Tag *parent = [ctx1 insertObjectWithEntityName: @"Anonymous.Tag"];
    [ctx1 setRootObject: parent];
	Tag *tag1 = [ctx1 insertObjectWithEntityName: @"Anonymous.Tag"];
	Tag *tag2 = [ctx1 insertObjectWithEntityName: @"Anonymous.Tag"];
    
    [parent insertObject: tag1 atIndex: ETUndeterminedIndex hint: nil forProperty: @"childTags"];
    [parent insertObject: tag2 atIndex: ETUndeterminedIndex hint: nil forProperty: @"childTags"];
	
	// ctx1:
	//
	// tag1         tag2
	
    [ctx2 setItemGraph: ctx1];

	OutlineItem *childCtx2 = [ctx2 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
    [[ctx2 objectWithUUID: [tag1 UUID]] insertObject: childCtx2 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	
	// ctx2:
	//
	// tag1         tag2
	//  |
	//   \--child
	
    [ctx3 setItemGraph: ctx2];
	
    [[ctx3 objectWithUUID: [tag1 UUID]] removeObject: [ctx3 objectWithUUID: [childCtx2 UUID]] atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
    [[ctx3 objectWithUUID: [tag2 UUID]] insertObject: [ctx3 objectWithUUID: [childCtx2 UUID]] atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	
	// ctx3:
	//
	// tag1         tag2
	//               |
	//                \--child
	
	// Now do the merge

    COItemGraphDiff *diff12 = [COItemGraphDiff diffItemTree: ctx1 withItemTree: ctx2 sourceIdentifier: @"diff12"];
    COItemGraphDiff *diff13 = [COItemGraphDiff diffItemTree: ctx1 withItemTree: ctx3 sourceIdentifier: @"diff13"];
	COItemGraphDiff *merged = [diff12 itemTreeDiffByMergingWithDiff: diff13];
    UKFalse([merged hasConflicts]);
	
	// Apply the resulting diff to ctx1
	[merged applyTo: ctx1];
	
	// Expected result:
	//
	// tag1         tag2
	//  |            |
	//   \--child    \--child
	
	
	OutlineItem *child = (id)[ctx1 objectWithUUID: [childCtx2 UUID]];
	UKIntsEqual(1, [[tag1 contents] count]);
	UKIntsEqual(1, [[tag2 contents] count]);
	
    UKObjectsEqual(S(tag1, tag2), [child valueForProperty: @"parentCollections"]);
	UKObjectsEqual(A(child), [tag1 contentArray]);
	UKObjectsEqual(A(child), [tag2 contentArray]);
	UKObjectsEqual(S(child), [tag1 content]);
	UKObjectsEqual(S(child), [tag2 content]);
}


//
// Move/Move tests: (merging two diffs, where both diffs move the same objects)
//


- (void)testConflictingMoveAndMoveOnOneToManyRelationship
{
	OutlineItem *parent = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
    [ctx1 setRootObject: parent];
	OutlineItem *child1 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	OutlineItem *child2 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	OutlineItem *child3 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	OutlineItem *subchild1 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	
	[child1 insertObject: subchild1 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	[parent insertObject: child1 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	[parent insertObject: child2 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	[parent insertObject: child3 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
    
	// ctx1:
	//
	// parent
	//  |
	//  |\-child1
	//  |   |
	//  |   \-subchild1
	//  |
	//  |\-child2
	//  |
	//   \-child3
	
	[ctx2 setItemGraph: ctx1];
	[ctx3 setItemGraph: ctx1];
    
	// ctx2: move subchild1 to child2
	[[ctx2 objectWithUUID: [child2 UUID]] insertObject: [ctx2 objectWithUUID: [subchild1 UUID]] atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
    
	// ctx2:
	//
	// parent
	//  |
	//  |\-child1
	//  |
	//  |\-child2
	//  |   |
	//  |   \-subchild1
	//  |
	//   \-child3
	
	
	// ctx3: move subchild1 to child3
	[[ctx3 objectWithUUID: [child3 UUID]] insertObject: [ctx3 objectWithUUID: [subchild1 UUID]] atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	
	// ctx3:
	//
	// parent
	//  |
	//  |\-child1
	//  |
	//  |\-child2
	//  |
	//   \-child3
	//      |
	//      \-subchild1
	
    COItemGraphDiff *diff12 = [COItemGraphDiff diffItemTree: ctx1 withItemTree: ctx2 sourceIdentifier: @"diff12"];
    COItemGraphDiff *diff13 = [COItemGraphDiff diffItemTree: ctx1 withItemTree: ctx3 sourceIdentifier: @"diff13"];
	COItemGraphDiff *merged = [diff12 itemTreeDiffByMergingWithDiff: diff13];
    
    UKTrue([merged hasConflicts]);
}

#if 0
- (void)testNonconflictingMoveAndMoveOnOneToManyRelationship
{
	OutlineItem *parent = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	OutlineItem *child1 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	OutlineItem *child2 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	OutlineItem *subchild1 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	
	[child1 insertObject: subchild1 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	[parent insertObject: child1 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	[parent insertObject: child2 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	
	// ctx1:
	//
	// parent
	//  |
	//  |\-child1
	//  |    |
	//  |    \-subchild1
	//  |
	//   \-child2
	
	[ctx2 setItemGraph: ctx1];
	[ctx3 setItemGraph: ctx1];
	
	// ctx2: move subchild1 to child2
	[(id)[ctx2 objectWithUUID: [child2 UUID]] insertObject: [ctx2 objectWithUUID: [subchild1 UUID]] atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
    
	// ctx2:
	//
	// parent
	//  |
	//  |\-child1
	//  |
	//   \-child2
	//      |
	//      \-subchild1
	
	// ctx3: move subchild1 to child2
	[(id)[ctx3 objectWithUUID: [child2 UUID]] insertObject: [ctx3 objectWithUUID: [subchild1 UUID]] atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	
	// ctx3:
	//
	// parent
	//  |
	//  |\-child1
	//  |
	//   \-child2
	//      |
	//      \-subchild1
	
    COItemGraphDiff *diff12 = [COItemGraphDiff diffItemTree: ctx1 withItemTree: ctx2 sourceIdentifier: @"diff12"];
    COItemGraphDiff *diff13 = [COItemGraphDiff diffItemTree: ctx1 withItemTree: ctx3 sourceIdentifier: @"diff13"];
	COItemGraphDiff *merged = [diff12 itemTreeDiffByMergingWithDiff: diff13];
    
    UKFalse([merged hasConflicts]);
	
	UKIntsEqual(2, [[parent contentArray] count]);
	// FIXME: UKIntsEqual(0, [[child1 contentArray] count]);
	// UKIntsEqual(1, [[child2 contentArray] count]);
	// UKObjectsEqual(child2, [subchild1 valueForProperty: @"parentContainer"]);
	UKObjectsEqual(A(child1, child2), [parent contentArray]);
	// FIXME: UKObjectsEqual(A(subchild1), [child2 contentArray]);
}

- (void)testMoveAndMoveOnManyToManyRelationship
{
	// Expected: both succeed

	COGroup *tag1 = [ctx1 insertObjectWithEntityName: @"Anonymous.Tag"];
	COGroup *tag2 = [ctx1 insertObjectWithEntityName: @"Anonymous.Tag"];
	COGroup *tag3 = [ctx1 insertObjectWithEntityName: @"Anonymous.Tag"];
	OutlineItem *child = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	
	[tag1 insertObject: child atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	
	// ctx1:
	//
	// tag1         tag2          tag3
	//  |
	//   \--child
	
    [ctx2 setItemGraph: ctx1];
    [ctx3 setItemGraph: ctx1];
    
	COGroup *tag1Ctx2 = [ctx2 insertObject: tag1];
	COGroup *tag2Ctx2 = [ctx2 insertObject: tag2];
	//COGroup *tag3Ctx2 = [ctx2 insertObject: tag3];
	COGroup *childCtx2 = [ctx2 insertObject: child];
	
	COGroup *tag1Ctx3 = [ctx3 insertObject: tag1];
	//COGroup *tag2Ctx3 = [ctx3 insertObject: tag2];
	COGroup *tag3Ctx3 = [ctx3 insertObject: tag3];
	COGroup *childCtx3 = [ctx3 insertObject: child];
	
	// ctx2: move child to tag2
	UKTrue([[tag1Ctx2 contentArray] containsObject: childCtx2]);
	[tag1Ctx2 removeObject: childCtx2 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"]];
	[tag2Ctx2 insertObject: childCtx2 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	
	// ctx2:
	//
	// tag1         tag2          tag3
	//               |
	//                \--child
	
	// ctx3: move child to tag3
	UKTrue([[tag1Ctx3 contentArray] containsObject: childCtx3]);
	[tag1Ctx3 removeObject: childCtx3 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"]];
	[tag3Ctx3 insertObject: childCtx3 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	
	// ctx3:
	//
	// tag1         tag2          tag3
	//                             |
	//                              \--child
	
	// Now do the merge
	NSArray *uuids = (id)[[A(tag1, tag2, tag3, child) mappedCollection] UUID];
    COItemGraphDiff *diff12 = [COItemGraphDiff diffItemTree: ctx1 withItemTree: ctx2 sourceIdentifier: @"diff12"];
    COItemGraphDiff *diff13 = [COItemGraphDiff diffItemTree: ctx1 withItemTree: ctx3 sourceIdentifier: @"diff13"];
	COItemGraphDiff *merged = [diff12 itemTreeDiffByMergingWithDiff: diff13];
    
    UKFalse([merged hasConflicts]);
    
	// Apply the resulting diff to ctx1
	[merged applyTo: ctx1];
	
	// Expected result:
	//
	// tag1         tag2          tag3
	//               |             |
	//                \--child      \--child
	
	// FIXME: UKIntsEqual(0, [[tag1 contentArray] count]);
	UKIntsEqual(1, [[tag2 contentArray] count]);
	UKIntsEqual(1, [[tag3 contentArray] count]);
	// FIXME: UKObjectsEqual(S(tag2, tag3), [child valueForProperty: @"parentCollections"]);
	UKObjectsEqual(A(child), [tag2 contentArray]);
	UKObjectsEqual(A(child), [tag3 contentArray]);
}

- (void)testSelectiveUndoOfGroupOperation
{
	OutlineItem *doc = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	OutlineItem *line1 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	OutlineItem *circle1 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	OutlineItem *square1 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	OutlineItem *image1 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
    
	[line1 setValue: @"line1" forProperty: @"label"];
	[circle1 setValue: @"circle1" forProperty: @"label"];
	[square1 setValue: @"square1" forProperty: @"label"];
	[image1 setValue: @"image1" forProperty: @"label"];
	
	[doc insertObject: line1 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	[doc insertObject: circle1 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	[doc insertObject: square1 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	[doc insertObject: image1 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	
	[ctx1 commit];
	
	// snapshot the state: (line1, circle1, square1, image1) into ctx2
	[ctx2 insertObject: doc];
	
	OutlineItem *group1 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[group1 setValue: @"group1" forProperty: @"label"];
	[doc insertObject: group1 atIndex: 1];
	[group1 insertObject: circle1 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	[group1 insertObject: square1 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
	[ctx1 commit];
	
	// snapshot the state:  (line1, group1=(circle1, square1), image1) into ctx3
	[ctx3 insertObject: doc];
	
	OutlineItem *triangle1 = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[triangle1 setValue: @"triangle1" forProperty: @"label"];
	[doc insertObject: triangle1 atIndex: 0];
	[ctx1 commit];
	
	
	// ctx1 state:  (triangl1, line1, group1=(circle1, square1), image1)
	
	
	// Now do the merge
	
	COItemGraphDiff *diff_ctx3_vs_ctx2 = [COItemGraphDiff diffContainer: (id)[ctx3 objectWithUUID: [doc UUID]]
                                                          withContainer: (id)[ctx2 objectWithUUID: [doc UUID]]];
	UKNotNil(diff_ctx3_vs_ctx2);
    
	COItemGraphDiff *diff_ctx3_vs_ctx1 = [COItemGraphDiff diffContainer: (id)[ctx3 objectWithUUID: [doc UUID]]
                                                          withContainer: (id)[ctx1 objectWithUUID: [doc UUID]]];
	UKNotNil(diff_ctx3_vs_ctx2);
	
    
	COItemGraphDiff *merged = [COItemGraphDiff mergeDiff: diff_ctx3_vs_ctx2
                                                withDiff: diff_ctx3_vs_ctx1];
	// FIXME: Test that there are no conflicts
	
	
	// Apply the resulting diff to ctx3
	UKFalse([ctx1 hasChanges]);
	[merged applyTo: ctx3];
	
	UKIntsEqual(5, [[(OutlineItem *)[ctx3 objectWithUUID: [doc UUID]] contentArray] count]);
	if (5 == [[doc contentArray] count])
	{
		UKStringsEqual(@"triangle1", [[[(OutlineItem *)[ctx3 objectWithUUID: [doc UUID]] contentArray] objectAtIndex: 0] valueForProperty: @"label"]);
		UKStringsEqual(@"line1", [[[(OutlineItem *)[ctx3 objectWithUUID: [doc UUID]] contentArray] objectAtIndex: 1] valueForProperty: @"label"]);
		UKStringsEqual(@"circle1", [[[(OutlineItem *)[ctx3 objectWithUUID: [doc UUID]] contentArray] objectAtIndex: 2] valueForProperty: @"label"]);
		UKStringsEqual(@"square1", [[[(OutlineItem *)[ctx3 objectWithUUID: [doc UUID]] contentArray] objectAtIndex: 3] valueForProperty: @"label"]);
		UKStringsEqual(@"image1", [[[(OutlineItem *)[ctx3 objectWithUUID: [doc UUID]] contentArray] objectAtIndex: 4] valueForProperty: @"label"]);
	}
	
	for (OutlineItem *object in [(OutlineItem *)[ctx3 objectWithUUID: [doc UUID]] contentArray])
	{
		UKObjectsSame([ctx3 objectWithUUID: [doc UUID]], [object valueForProperty: @"parentContainer"]);
	}
}
#endif
@end
