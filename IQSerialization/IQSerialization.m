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

NSString *const IQSerializationErrorDomain = @"IQSerializationErrorDomain";

extern BOOL _IQDeserializeJSONData(id object, NSData* jsonData, IQSerialization* serialization, NSError** outError);
extern BOOL _IQDeserializeXMLRPCData(id object, NSData* jsonData, IQSerialization* serialization, NSError** outError);
extern NSData* _IQJSONSerializeObject(id object, IQSerialization* serialization, NSError** outError);
extern NSData* _IQXMLRPCSerializeObject(id object, IQSerialization* serialization, NSError** outError);

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
    if([self deserializeObject:ret fromData:data format:fmt]) {
        return ret;
    }
    return nil;
}
- (NSArray*)arrayFromData:(NSData *)data format:(IQSerializationFormat)fmt
{
    NSMutableArray* ret = [NSMutableArray array];
    if([self deserializeObject:ret fromData:data format:fmt]) {
        return ret;
    }
    return nil;
}
- (BOOL)deserializeObject:(id)object fromString:(NSString*)string format:(IQSerializationFormat)fmt
{
    return [self deserializeObject:object fromData:[string dataUsingEncoding:NSUTF8StringEncoding] format:fmt];
}
- (BOOL)deserializeObject:(id)object fromData:(NSData*)data format:(IQSerializationFormat)fmt
{
    NSError* err = nil;
    BOOL result;
    if(fmt == IQSerializationFormatJSON) {
        result = _IQDeserializeJSONData(object, data, self, &err);
    } else if(fmt == IQSerializationFormatXMLRPC) {
        result = _IQDeserializeXMLRPCData(object, data, self, &err);
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

- (NSString*)stringFromObject:(id)object format:(IQSerializationFormat)fmt
{
    return [[NSString alloc] initWithData:[self serializeObject:object format:fmt] encoding:self.textEncoding];
}
- (NSData*)serializeObject:(id)object format:(IQSerializationFormat)fmt
{
    NSData* result = nil;
    NSError* err = nil;
    if(fmt == IQSerializationFormatJSON) {
        result = _IQJSONSerializeObject(object, self, &err);
    } else if(fmt == IQSerializationFormatXMLRPC) {
        result = _IQXMLRPCSerializeObject(object, self, &err);
    }
    if(!result) {
        self->error = err;
        return nil;
    }
    return result;
}

@end

