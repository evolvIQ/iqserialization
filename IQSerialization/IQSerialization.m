//
//  IQSerialization.m
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

#import "IQSerialization.h"

extern BOOL _IQDeserializeJSONData(id object, NSData* jsonData, IQSerialization* serialization, IQSerializationFlags flags, NSError** outError);
extern BOOL _IQDeserializeXMLRPCData(id object, NSData* jsonData, IQSerialization* serialization, IQSerializationFlags flags, NSError** outError);
extern NSData* _IQJSONSerializeObject(id object, IQSerialization* serialization, IQSerializationFlags flags, NSError** outError);
extern NSData* _IQXMLRPCSerializeObject(id object, IQSerialization* serialization, IQSerializationFlags flags, NSError** outError);
extern NSString* _IQXMLRPCSerializeObjectToString(id object, IQSerialization* serialization, IQSerializationFlags flags, NSError** outError);
extern BOOL _IQXMLRPCSerializeObjectToStream(NSOutputStream* stream, id object, IQSerialization* serialization, IQSerializationFlags flags, NSError** outError);

@implementation IQSerialization
@synthesize error, textEncoding, pretty, ignoreUnknownProperties, ignoreNilValues, timeZone;

- (id)init
{
    self = [super init];
    if(self) {
        textEncoding = NSUTF8StringEncoding;
        ignoreNilValues = YES;
    }
    return self;
}

- (NSDictionary*)dictionaryFromString:(NSString*)string format:(IQSerializationFormat)fmt
{
    return [self dictionaryFromData:[string dataUsingEncoding:NSUTF8StringEncoding] format:fmt];
}

- (NSArray*)arrayFromString:(NSString*)string format:(IQSerializationFormat)fmt
{
    return [self arrayFromData:[string dataUsingEncoding:NSUTF8StringEncoding] format:fmt];
}
- (NSDictionary*)dictionaryFromData:(NSData *)data format:(IQSerializationFormat)fmt
{
    NSMutableDictionary* ret = [NSMutableDictionary dictionary];
    if(fmt == IQSerializationFormatXMLPlist || fmt == IQSerializationFormatBinaryPlist) {
        NSError* err = nil;
        NSDictionary* ret = [NSPropertyListSerialization propertyListWithData:data options:kCFPropertyListImmutable format:nil error:&err];
        if(!ret) {
            error = err;
        }
        return ret;
    } else if([self deserializeObject:ret fromData:data format:fmt]) {
        return ret;
    }
    return nil;
}
- (NSArray*)arrayFromData:(NSData *)data format:(IQSerializationFormat)fmt
{
    NSMutableArray* ret = [NSMutableArray array];
    if(fmt == IQSerializationFormatXMLPlist || fmt == IQSerializationFormatBinaryPlist) {
        NSError* err = nil;
        NSArray* ret = [NSPropertyListSerialization propertyListWithData:data options:kCFPropertyListImmutable format:nil error:&err];
        if(!ret) {
            error = err;
        }
        return ret;
    } else if([self deserializeObject:ret fromData:data format:fmt]) {
        return ret;
    }
    return nil;
}

- (BOOL)deserializeObject:(id)object fromString:(NSString*)string format:(IQSerializationFormat)fmt
{
    return [self deserializeObject:object fromString:string format:fmt flags:IQSerializationFlagsDefault];
}

- (BOOL)deserializeObject:(id)object fromData:(NSData*)data format:(IQSerializationFormat)fmt
{
    return [self deserializeObject:object fromData:data format:fmt flags:IQSerializationFlagsDefault];
}

- (NSString*)stringFromObject:(id)object format:(IQSerializationFormat)fmt
{
    return [self stringFromObject:object format:fmt flags:IQSerializationFlagsDefault];
}

- (NSData*)serializeObject:(id)object format:(IQSerializationFormat)fmt
{
    return [self serializeObject:object format:fmt flags:IQSerializationFlagsDefault];
}

- (BOOL)deserializeObject:(id)object fromString:(NSString*)string format:(IQSerializationFormat)fmt flags:(IQSerializationFlags)flags
{
    return [self deserializeObject:object fromData:[string dataUsingEncoding:NSUTF8StringEncoding] format:fmt flags:flags];
}

- (BOOL)deserializeObject:(id)object fromData:(NSData*)data format:(IQSerializationFormat)fmt flags:(IQSerializationFlags)flags
{
    NSError* err = nil;
    BOOL result;
    if(fmt == IQSerializationFormatJSON) {
        result = _IQDeserializeJSONData(object, data, self, flags, &err);
    } else if(fmt == IQSerializationFormatXMLRPC) {
        result = _IQDeserializeXMLRPCData(object, data, self, flags, &err);
    } else {
        [NSException raise:@"BadSerializationFormat" format:@"Illegal serialization format specifier"];
        return NO;
    }
    if(!result) {
        self->error = err;
        return NO;
    }
    return YES;
}

- (NSString*)stringFromObject:(id)object format:(IQSerializationFormat)fmt flags:(IQSerializationFlags)flags
{
    return [[NSString alloc] initWithData:[self serializeObject:object format:fmt flags:flags] encoding:self.textEncoding];
}
- (NSData*)serializeObject:(id)object format:(IQSerializationFormat)fmt flags:(IQSerializationFlags)flags
{
    NSData* result = nil;
    NSError* err = nil;
    if(fmt == IQSerializationFormatJSON) {
        result = _IQJSONSerializeObject(object, self, flags, &err);
    } else if(fmt == IQSerializationFormatXMLRPC) {
        result = _IQXMLRPCSerializeObject(object, self, flags, &err);
    }
    if(!result) {
        self->error = err;
        return nil;
    }
    return result;
}

@end

