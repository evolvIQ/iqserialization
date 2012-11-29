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

#import "NSData+Base64.h"
#import "IQSerialization+JSON.h"
#import "IQSerialization+XMLRPC.h"

/**
 Serialization format specifier.
 */
typedef enum IQSerializationFormat {
    /**
     JSON or JSON-RPC serialization, using the YAJL parser/generator.
     See http://json.org, http://json-rpc.org
     */
    IQSerializationFormatJSON = 1,
    /**
     YAML serialization. Not yet implemented, placeholder only.
     */
    IQSerializationFormatYAML = 2,
    /**
     XML-RPC serialization, using NSXMLParser
     See http://xmlrpc.scripting.com/spec.html
     */
    IQSerializationFormatXMLRPC = 3,
    /**
     Simple XML serialization, using NSXMLParser
     See http://en.wikipedia.org/wiki/Simple_XML
     */
    IQSerializationFormatSimpleXML = 4,
    /**
     Wrapper for Cocoa XML property list serializer, for convenience
     */
    IQSerializationFormatXMLPlist = 10,
    /**
     Wrapper for Cocoa binary property list serializer, for convenience
     */
    IQSerializationFormatBinaryPlist = 11,
} IQSerializationFormat;

/**
 Objects implementing this protocol can control how they are serialized and deserialized.
 All methods are optional and override default serialization behavior.
 */
@protocol IQSerializationSupport
@optional
/** \brief Properties to serialize.
 
 When serializing the object, this method is called to query the object for a list of serializable properties.
 If this method does not exist, the default behavior to use all Objective-C properties, is selected.
 */
- (NSSet*)serializableProperties;

@end

/**
 Flags used to control the serialization for a specific object. Not all flags are understood by all serializers, and some flags
 are mutually exclusive.
 */
typedef enum IQSerializationFlags {
    /**
     Specifies the default serialization flags.
     */
    IQSerializationFlagsDefault = 0,
    
    /**
     Specifies that the object should be (de)serialized as a RPC request. Understood by \ref IQSerializationFormatJSON (JSON-RPC) and
     \ref IQSerializationFormatXMLRPC. Mutually exclusive with \ref IQSerializationFlagsRPCResponse
     and \ref IQSerializationFlagsRPCFault.
     */
    IQSerializationFlagsRPCRequest = 1,
    
    /**
     Specifies that the object should be (de)serialized as a RPC response. Understood by \ref IQSerializationFormatJSON (JSON-RPC) and
     \ref IQSerializationFormatXMLRPC. Mutually exclusive with \ref IQSerializationFlagsRPCRequest
     and \ref IQSerializationFlagsRPCFault.
     */
    IQSerializationFlagsRPCResponse = 2,
    
    /**
     Specifies that the object should be (de)serialized as a RPC fault or exception. Understood by \ref IQSerializationFormatJSON (JSON-RPC) and
     \ref IQSerializationFormatXMLRPC. Mutually exclusive with \ref IQSerializationFlagsRPCRequest
     and \ref IQSerializationFlagsRPCResponse.
     */
    IQSerializationFlagsRPCFault = 3,
} IQSerializationFlags;

/**
 Error domain for \ref NSError objects created by this library.
 */
#define IQSerializationErrorDomain @"IQSerializationErrorDomain"

/**
 The main entry point to the IQSerialization library. To serialize and deserialize objects, instantiate
 this class and configure it by setting its properties, e.g.:
 \code{.m}
 // Create some object to serialize
 NSMutableDictionary* dict = [NSMutableDictionary dictionary];
 dict[@"someKey"] = @"someValue";
 
 // Instantiate and configure the serialization
 IQSerialization* serialization = [IQSerialization new];
 serialization.pretty = YES;
 
 // Serialize the object
 NSString* str = [serialization stringFromObject:dict fmt:IQSerializationFormatJSON];
 
 // Prints 'Value is: {"someKey":"someValue"}'
 NSLog(@"Value is: %@", str);
 \endcode
 */
@interface IQSerialization : NSObject

/**
 @name Convenience methods
 @{
 */
#pragma mark - Convenience methods

/**
 Reads a dictionary from a string. Convenience method that will call deserializeObject:fromString.
 
 @returns The dictionary if successful, or nil if an error occurred. The error property will hold the
 error in this case.
 */

- (NSDictionary*)dictionaryFromString:(NSString*)string format:(IQSerializationFormat)fmt;
/**
 Reads a dictionary from a NSData object. Convenience method that will call deserializeObject:fromData.
 
 @returns The dictionary if successful, or nil if an error occurred. The error property will hold the
 error in this case.
 */

- (NSDictionary*)dictionaryFromData:(NSData*)data format:(IQSerializationFormat)fmt;
/**
 Reads an array from a string. Convenience method that will call deserializeObject:fromString.
 
 @returns The array if successful, or nil if an error occurred. The error property will hold the
 error in this case.
 */
- (NSArray*)arrayFromString:(NSString*)string format:(IQSerializationFormat)fmt;

/**
 Reads an array from a NSData object. Convenience method that will call deserializeObject:fromData.
 
 @returns The array if successful, or nil if an error occurred. The error property will hold the
 error in this case.
 */
- (NSArray*)arrayFromData:(NSData*)data format:(IQSerializationFormat)fmt;

/**
 Serializes an object to a string. Convenience method that will call <code>serializeObject:format</code>.
 
 @returns The string if successful, or nil if an error occurred. The error property will hold the
 error in this case.
 */
- (NSString*)stringFromObject:(id)object format:(IQSerializationFormat)fmt;
/**
 Serializes an object to a string. Convenience method that will call <code>serializeObject:format</code>.
 
 @returns The string if successful, or nil if an error occurred. The error property will hold the
 error in this case.
 */
- (NSString*)stringFromObject:(id)object format:(IQSerializationFormat)fmt flags:(IQSerializationFlags)flags;

/**
 Deserializes an object from a string. Convenience method that will call deserializeObject:fromData:format:flags:.
 
 @returns <code>YES</code> if successful, or <code>NO</code> if an error occurred. The error property will hold the
 error in this case.
 */
- (BOOL)deserializeObject:(id)object fromString:(NSString*)string format:(IQSerializationFormat)fmt;

/**
 Deserializes an object from a string. Convenience method that will call deserializeObject:fromData:format:flags:.
 
 @returns <code>YES</code> if successful, or <code>NO</code> if an error occurred. The error property will hold the
 error in this case.
 */
- (BOOL)deserializeObject:(id)object fromString:(NSString*)string format:(IQSerializationFormat)fmt flags:(IQSerializationFlags)flags;

/**
 @}
 */

/**
 @name Deserialization
 @{
 */
#pragma mark - Deserialization
/**
 Deserializes an object from a <code>NSData</code> object.
 
 @returns <code>YES</code> if successful, or <code>NO</code> if an error occurred. The error property will hold the
 error in this case.
 */
- (BOOL)deserializeObject:(id)object fromData:(NSData*)data format:(IQSerializationFormat)fmt flags:(IQSerializationFlags)flags;

/**
 @}
 */

/**
 @name Serialization
 @{
 */
#pragma mark - Serialization
/**
 Serializes an object to a <code>NSData</code> object.
 
 @returns The data if successful, or <code>nil</code> if an error occurred. The error property will hold the
 error in this case.
 */
- (NSData*)serializeObject:(id)object format:(IQSerializationFormat)fmt flags:(IQSerializationFlags)flags;

/**
 @}
 */

#pragma mark - Properties
/**  \brief The error from the last serialization/deserialization operation.
 */
@property (nonatomic, readonly) NSError* error;

/**  \brief The text encoding to use when reading/writing raw bytes.
 
 Default is UTF-8. This property is made available only to support some legacy or broken
 services. There should normally not be any reason not to use UTF-8, and choosing another
 encoding may violate protocol standards. Use with caution.
 */
@property (nonatomic) NSStringEncoding textEncoding;

/** \brief Pretty-printing mode (newlines and indentation).
 
 If YES, format output for display. If NO, make output as compact as possible. Default
 is NO.
 */
@property (nonatomic) BOOL pretty;

/** \brief Fault-tolerant mode.
 
 If YES and deserializing typed objects (POCOs), specifies that properties not found
 on the object should be ignored. If NO, an unknown property results in a deserialization
 error. Default is NO.
 */
@property (nonatomic) BOOL ignoreUnknownProperties;

/** \brief <code>nil</code> value handling for <code>NSDictionary</code>, <code>NSArray</code>, etc.
 
 If YES when serializing, does not add nil values to the output. If NO, writes explicit nil
 values when serializing.
 
 If YES when deserializing, ignores all nil values in dictionaries and arrays. If NO, 
 inserts NSNull objects for nil values. Other objects always receive nil values.
 
 Default is YES.
 */
@property (nonatomic) BOOL ignoreNilValues;

/**  \brief Default time zone.
 
 The time zone used for serializers that do not encode timezone information (e.g. XML-RPC).
 Default is nil, which uses the default time zone.
 
 To use UTC times, set this property to <code>[NSTimeZone timeZoneWithName:@"UTC"]</code>.
 */
@property (nonatomic, retain) NSTimeZone* timeZone;

@end
