//
//  IQObjectFactory.m
//  IQSerialization for iOS and Mac OS X
//
//  Copyright 2012 Rickard Petzäll, EvolvIQ
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "IQObjectFactory.h"
#import "IQSerialization.h"
#import <objc/runtime.h>

@implementation _IQObjectFactory
@synthesize ignoreUnknownProperties;

- (BOOL)_fail:(NSString*)err
{
    self->error = [NSError errorWithDomain:IQSerializationErrorDomain code:1000 userInfo:
                   [NSDictionary dictionaryWithObject:err forKey:NSLocalizedDescriptionKey]];
    return NO;
}

- (BOOL)_setScalarValue:(id)scalar
{
    if(isRoot) {
        return [self _fail:@"Scalar root objects not supported"];
    }
    if(!object) {
        return [self _fail:@"Did not expect value here"];
    }
    if(!key) {
        if([object respondsToSelector:@selector(addObject:)]) {
            if(scalar == nil && explicitNull) scalar = [NSNull null];
            if(scalar) {
                [(id)object addObject:scalar];
            }
        } else {
            return [self _fail:@"Object is not a collection, but got an array input"];
        }
    } else {
        if(dictionaryMode) {
            if(scalar == nil && explicitNull) scalar = [NSNull null];
            if(scalar != nil) {
                [(NSMutableDictionary*)object setObject:scalar forKey:key];
            } else {
                [(NSMutableDictionary*)object removeObjectForKey:key];
            }
        } else {
            @try {
                [object setValue:scalar forKey:key];
            }
            @catch (NSException *exception) {
                if([exception.name isEqualToString:@"NSUnknownKeyException"]) {
                    if(ignoreUnknownProperties) {
                        key = nil;
                        return YES;
                    } else {
                        error = [NSError errorWithDomain:IQSerializationErrorDomain code:1003 userInfo:
                                 [NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"Property '%@' not found on object", key] forKey:NSLocalizedDescriptionKey]];
                        key = nil;
                        return NO;
                    }
                }
                NSLog(@"Exception: %@", exception.name);
            }
        }
    }
    key = nil;
    return YES;
}

- (BOOL)_createChildObject
{
    NSObject* child;
    if(!object) return [self _fail:@"Did not expect object here"];
    if(isRoot) {
        isRoot = NO;
        return YES;
    }
    BOOL newDictionaryMode = NO;
    if(!dictionaryMode) {
        Class objClass = [IQSerialization _classForProperty:key ofObject:object];
        Class propClass = objClass;
        while(propClass) {
            if(propClass == [NSDictionary class]) {
                child = [NSMutableDictionary dictionary];
                newDictionaryMode = YES;
            }
            propClass = class_getSuperclass(propClass);
            if(propClass == [NSObject class]) break;
        }
        if(!child) {
            child = [[objClass alloc] init];
        }
    }
    if(!child) {
        child = [NSMutableDictionary dictionary];
        newDictionaryMode = YES;
    }
    [self _setScalarValue:child];
    dictionaryMode = newDictionaryMode;
    isRoot = NO;
    if(!stack) stack = [NSMutableArray arrayWithCapacity:1];
    [stack addObject:object];
    object = child;
    return YES;
}

- (BOOL)_createChildArray
{
    NSObject* child;
    if(!object) return [self _fail:@"Did not expect object here"];
    if(isRoot) {
        isRoot = NO;
        return YES;
    }
    if(!dictionaryMode) {
        Class propClass = [IQSerialization _classForProperty:key ofObject:object];
        while(propClass) {
            if(propClass == [NSArray class]) {
                child = [NSMutableArray array];
            } else if(propClass == [NSSet class]) {
                child = [NSMutableSet set];
            } else if(propClass == [NSOrderedSet class]) {
                child = [NSMutableOrderedSet orderedSet];
            }
            propClass = class_getSuperclass(propClass);
            if(propClass == [NSObject class]) break;
        }
    }
    if(!child) {
        child = [NSMutableArray array];
    }
    [self _setScalarValue:child];
    dictionaryMode = YES;
    isRoot = NO;
    if(!stack) stack = [NSMutableArray arrayWithCapacity:1];
    [stack addObject:object];
    object = child;
    return YES;
}

- (BOOL)_popObject
{
    if(!object) {
        return [self _fail:@"Unexpected end of child"];
    }
    if(!stack || !stack.count) {
        object = nil;
    } else {
        object = [stack lastObject];
        [stack removeLastObject];
    }
    if(object && ([object isKindOfClass:[NSArray class]] || [object isKindOfClass:[NSDictionary class]])) {
        dictionaryMode = YES;
    } else {
        dictionaryMode = NO;
    }
    return YES;
}

@end

@implementation IQSerialization(PrivateMethods)

+ (Class)_classForProperty:(NSString*)propName ofObject:(id)obj
{
    Class objectClass = [obj class];
    objc_property_t prop = class_getProperty(objectClass, propName.UTF8String);
    if(prop) {
        const char * propertyAttrs = property_getAttributes(prop);
        if(propertyAttrs && propertyAttrs[1] == '@') {
            const char* e = strchr(propertyAttrs+3, '"');
            if(e) {
                char cn[e-propertyAttrs-2];
                strncpy(cn, propertyAttrs+3, sizeof(cn));
                cn[sizeof(cn)-1] = 0;
                Class theClass = objc_getClass(cn);
                if(theClass) {
                    return theClass;
                }
            }
        }
    }
    return nil;
}

- (NSSet*)_propertiesForObject:(id)object
{
    if([object respondsToSelector:@selector(serializableProperties)]) {
        return [object serializableProperties];
    }
    unsigned int propertyCount = 0;
    objc_property_t *properties = class_copyPropertyList([object class], &propertyCount);
    if(propertyCount == 0) return nil;
    NSMutableSet* ret = [NSMutableSet setWithCapacity:propertyCount];
    for(unsigned int i = 0; i < propertyCount; i++) {
        [ret addObject:[NSString stringWithUTF8String:property_getName(properties[i])]];
    }
    free(properties);
    return ret;
}
@end