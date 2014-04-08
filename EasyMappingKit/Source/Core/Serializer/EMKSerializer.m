// Copyright (c) 2014 Yalantis.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "EMKSerializer.h"
#import "EMKAttributeMapping.h"
#import "EMKPropertyHelper.h"
#import "EMKRelationshipMapping.h"

@implementation EMKSerializer

+ (NSDictionary *)_serializeObject:(id)object usingMapping:(EMKMapping *)mapping {
	NSMutableDictionary *representation = [NSMutableDictionary dictionary];

	for (EMKAttributeMapping *fieldMapping in mapping.attributeMappings) {
		[self setValueOnRepresentation:representation fromObject:object withFieldMapping:fieldMapping];
	}

	for (EMKRelationshipMapping *relationshipMapping in mapping.relationshipMappings) {
		[self setRelationshipObjectOn:representation usingMapping:relationshipMapping fromObject:object];
	}

	return representation;
}

+ (NSDictionary *)serializeObject:(id)object usingMapping:(EMKMapping *)mapping {
	NSDictionary *representation = [self _serializeObject:object usingMapping:mapping];

	return mapping.rootPath.length > 0 ? @{mapping.rootPath : representation} : representation;
}

+ (id)_serializeCollection:(NSArray *)collection usingMapping:(EMKMapping *)mapping {
	NSMutableArray *representation = [NSMutableArray new];

	for (id object in collection) {
		NSDictionary *objectRepresentation = [self _serializeObject:object usingMapping:mapping];
		[representation addObject:objectRepresentation];
	}

	return representation;
}

+ (id)serializeCollection:(NSArray *)collection usingMapping:(EMKMapping *)mapping {
	NSArray *representation = [self _serializeCollection:collection usingMapping:mapping];

	return mapping.rootPath.length > 0 ? @{mapping.rootPath: representation} : representation;
}

+ (void)setValueOnRepresentation:(NSMutableDictionary *)representation fromObject:(id)object withFieldMapping:(EMKAttributeMapping *)fieldMapping {
	SEL selector = NSSelectorFromString(fieldMapping.property);
	id returnedValue = [EMKPropertyHelper performSelector:selector onObject:object];

	if (returnedValue) {
		returnedValue = [fieldMapping reverseMapValue:returnedValue];

		[self setValue:returnedValue forKeyPath:fieldMapping.keyPath inRepresentation:representation];
	}
}

+ (void)setValue:(id)value forKeyPath:(NSString *)keyPath inRepresentation:(NSMutableDictionary *)representation {
	NSArray *keyPathComponents = [keyPath componentsSeparatedByString:@"."];
	if ([keyPathComponents count] == 1) {
		[representation setObject:value forKey:keyPath];
	} else if ([keyPathComponents count] > 1) {
		NSString *attributeKey = [keyPathComponents lastObject];
		NSMutableArray *subPaths = [NSMutableArray arrayWithArray:keyPathComponents];
		[subPaths removeLastObject];

		id currentPath = representation;
		for (NSString *key in subPaths) {
			id subPath = [currentPath valueForKey:key];
			if (subPath == nil) {
				subPath = [NSMutableDictionary new];
				[currentPath setValue:subPath forKey:key];
			}
			currentPath = subPath;
		}
		[currentPath setValue:value forKey:attributeKey];
	}
}

+ (void)setRelationshipObjectOn:(NSMutableDictionary *)representation
                   usingMapping:(EMKRelationshipMapping *)relationshipMapping
			         fromObject:(id)object {
	id value = [EMKPropertyHelper performSelector:NSSelectorFromString(relationshipMapping.property) onObject:object];
	if (value) {
		id relationshipRepresentation = nil;
		if (relationshipMapping.isToMany) {
			relationshipRepresentation = [self _serializeCollection:value usingMapping:relationshipMapping.objectMapping];
		} else {
			relationshipRepresentation = [self _serializeObject:value usingMapping:relationshipMapping.objectMapping];
		}

		if (relationshipMapping.keyPath.length > 0) {
			[representation setObject:relationshipRepresentation forKey:relationshipMapping.keyPath];
		} else {
			NSParameterAssert([relationshipRepresentation isKindOfClass:NSDictionary.class]);
			[representation addEntriesFromDictionary:relationshipRepresentation];
		}
	}
}

@end