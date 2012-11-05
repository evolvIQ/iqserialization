//
//  IQSerialization.h
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

#import <Foundation/Foundation.h>

#import "IQSerialization+Base64.h"
#import "IQSerialization+JSON.h"
#import "IQSerialization+XMLRPC.h"

typedef enum _IQSerializationFormat {
    /**
     JSON serialization, using the YAJL parser/generator
     http://json.org
     */
    IQSerializationFormatJSON = 1,
    IQSerializationFormatYAML = 2,
    /**
     XML-RPC serialization 
     http://xmlrpc.scripting.com/spec.html
     */
    IQSerializationFormatXMLRPC = 3,
    /**
     Wrapper for Cocoa XML property list serializer, for convenience
     */
    IQSerializationFormatXMLPlist = 10,
    /**
     Wrapper for Cocoa binary property list serializer, for convenience
     */
    IQSerializationFormatBinaryPlist = 11,
} IQSerializationFormat;

@protocol IQSerializationSupport
@optional
- (NSSet*)serializableProperties;

@end

// Error keys
NSString *const IQSerializationErrorDomain;

@interface IQSerialization : NSObject
- (NSDictionary*)dictionaryFromString:(NSString*)string format:(IQSerializationFormat)fmt;
- (NSDictionary*)dictionaryFromData:(NSData*)data format:(IQSerializationFormat)fmt;
- (NSArray*)arrayFromString:(NSString*)string format:(IQSerializationFormat)fmt;
- (NSArray*)arrayFromData:(NSData*)data format:(IQSerializationFormat)fmt;
- (BOOL)deserializeObject:(id)object fromString:(NSString*)string format:(IQSerializationFormat)fmt;
- (BOOL)deserializeObject:(id)object fromData:(NSData*)data format:(IQSerializationFormat)fmt;
- (NSString*)stringFromObject:(id)object format:(IQSerializationFormat)fmt;
- (NSData*)serializeObject:(id)object format:(IQSerializationFormat)fmt;
/**
 The error from the last serialization/deserialization call.
 */
@property (nonatomic, readonly) NSError* error;
/**
 The text encoding to use when reading raw bytes. Default is UTF-8.
 */
@property (nonatomic) NSStringEncoding textEncoding;
/**
 If YES, format output for display. If NO, make output as compact as possible. Default
 is NO.
 */
@property (nonatomic) BOOL pretty;
/**
 If YES and deserializing typed objects (POCOs), specifies that properties not found
 on the object should be ignored. If NO, an unknown property results in a deserialization
 error. Default is NO.
 */
@property (nonatomic) BOOL ignoreUnknownProperties;
/**
 If YES when serializing, does not add nil values to the output. If NO, writes explicit nil
 values when serializing.
 
 If YES when deserializing, ignores all nil values in dictionaries and arrays. If NO, 
 inserts NSNull objects for nil values. Other objects always receive nil values.
 
 Default is YES.
 */
@property (nonatomic) BOOL ignoreNilValues;

/**
 The time zone used for serializers that do not encode timezone information (e.g. XML-RPC).
 Default is nil, which uses the default time zone.
 */
@property (nonatomic, retain) NSTimeZone* timeZone;
@end
