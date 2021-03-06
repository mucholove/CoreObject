/*
    Copyright (C) 2013 Quentin Mathe, Eric Wasylishen

    Date:  October 2013
    License:  MIT  (see COPYING)
 */

#import "KeyedAttributeModel.h"

@implementation KeyedAttributeModel

@dynamic entries;

+ (ETEntityDescription *)newEntityDescription
{
    ETEntityDescription *object = [self newBasicEntityDescription];

    // For subclasses that don't override -newEntityDescription, we must not add
    // the property descriptions that we will inherit through the parent
    if (![object.name isEqual: [KeyedAttributeModel className]])
        return object;

    ETPropertyDescription *entries =
        [ETPropertyDescription descriptionWithName: @"entries" typeName: @"NSString"];
    entries.multivalued = YES;
    entries.keyed = YES;
    entries.persistent = YES;

    [object addPropertyDescription: entries];

    return object;
}

@end
