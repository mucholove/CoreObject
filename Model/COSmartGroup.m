/*
    Copyright (C) 2010 Eric Wasylishen, Quentin Mathe

    Date:  November 2010
    License:  MIT  (see COPYING)
 */

#import "COSmartGroup.h"

@implementation COSmartGroup

@synthesize targetCollection, predicate, contentBlock;

+ (void)initialize
{
    if (self != [COSmartGroup class])
        return;

    [self applyTraitFromClass: [ETCollectionTrait class]];
}

+ (ETEntityDescription *)newEntityDescription
{
    ETEntityDescription *group = [self newBasicEntityDescription];

    // For subclasses that don't override -newEntityDescription, we must not add the 
    // property descriptions that we will inherit through the parent
    if (![group.name isEqual: [COSmartGroup className]])
        return group;

    ETUTI *uti = [ETUTI registerTypeWithString: @"org.etoile-project.objc.class.COSmartGroup"
                                   description: @" Smart Core Object Group"
                              supertypeStrings: @[]
                                      typeTags: @{}];
    ETAssert([[ETUTI typeWithClass: [self class]] isEqual: uti]);

    [group setLocalizedDescription: _(@"Smart Group")];

    ETPropertyDescription *content =
        [ETPropertyDescription descriptionWithName: @"content" typeName: @"COObject"];
    content.multivalued = YES;
    content.ordered = YES;

    group.propertyDescriptions = @[content];

    return group;
}

- (instancetype)initWithObjectGraphContext: (COObjectGraphContext *)aContext
{
    self = [super initWithObjectGraphContext: aContext];
    if (self == nil)
        return nil;

    content = [NSArray new];
    return self;
}

- (void)awakeFromDeserialization
{
    [super awakeFromDeserialization];
    content = [NSArray new];
}

- (void)setTargetCollection: (id <ETCollection>)aGroup
{
    targetCollection = (id)aGroup;
    [self refresh];
}

- (void)setContentBlock: (COContentBlock)aBlock
{
    contentBlock = [aBlock copy];
    [self refresh];
}

- (void)setPredicate: (NSPredicate *)aPredicate
{
    predicate = aPredicate;
    [self refresh];
}

- (BOOL)isOrdered
{
    return YES;
}

- (id)content
{
    return content;
}

- (NSArray *)contentArray
{
    return [NSArray arrayWithArray: content];
}

- (void)didUpdate
{
    [[NSNotificationCenter defaultCenter]
        postNotificationName: ETCollectionDidUpdateNotification object: self];
}

- (void)refresh
{
    NSArray *result = nil;

    if (contentBlock != NULL)
    {
        result = contentBlock();
    }
    else if (targetCollection != nil && predicate != nil)
    {
        result = [[targetCollection contentArray] filteredArrayUsingPredicate: predicate];
    }
    else
    {
        result = [targetCollection contentArray];
    }
    ETAssert([result isKindOfClass: [NSArray class]]);

    content = result;
    [self didUpdate];
}

- (id)objectForIdentifier: (NSString *)anId
{
    for (id object in self.content)
    {
        if ([[object identifier] isEqualToString: anId])
        {
            return object;
        }
    }
    return nil;
}

@end
