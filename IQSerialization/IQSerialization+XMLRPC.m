//
//  NSXMLRPCSerialization.m
//  IQSerialization for iOS and Mac OS X
//
//  Copyright © 2012-2015 Rickard Lyrenius
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
#import "IQObjectFactory.h"
#import "IQXMLWriter.h"

typedef enum IQXMLRPCSerializerState {
    IQXMLRPCSerializerStateRoot = 0,
    IQXMLRPCSerializerStateMethodResponse,
    IQXMLRPCSerializerStateParams,
    IQXMLRPCSerializerStateParam,
    IQXMLRPCSerializerStateValue,
    IQXMLRPCSerializerStateMember,
    IQXMLRPCSerializerStateMemberName,
    IQXMLRPCSerializerStateValueContent,
    IQXMLRPCSerializerStateValueStruct,
    IQXMLRPCSerializerStateValueArray,
    IQXMLRPCSerializerStateValueArrayData,
} IQXMLRPCSerializerState;

@interface _IQXMLRPCObjectFactory : _IQObjectFactory<NSXMLParserDelegate> {
    IQXMLRPCSerializerState state;
    NSString* stringBuffer;
    BOOL ownBuffer;
    NSString* dataType;
    NSMutableArray* elementStack;
    NSDateFormatter* dateFormatter;
}
@end

@implementation _IQXMLRPCObjectFactory
- (id)initWithSerialization:(IQSerialization*)serialization
{
    self = [super init];
    if(self) {
        formatter = [NSNumberFormatter new];
        [formatter setNumberStyle:0];
        formatter.locale = [NSLocale systemLocale];
        dateFormatter = [NSDateFormatter new];
        dateFormatter.dateFormat = @"yyyyMMdd'T'HH:mm:ss";
        if(serialization.timeZone != nil) {
            dateFormatter.timeZone = serialization.timeZone;
        }
        explicitNull = !serialization.ignoreNilValues;
        encoding = serialization.textEncoding;
    }
    return self;
}
- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict
{
    switch(state) {
        case IQXMLRPCSerializerStateRoot:
            if([elementName isEqualToString:@"methodResponse"]) {
                state = IQXMLRPCSerializerStateMethodResponse;
            } else if([elementName isEqualToString:@"params"]) {
                state = IQXMLRPCSerializerStateParams;
            } else if([elementName isEqualToString:@"value"]) {
                state = IQXMLRPCSerializerStateValue;
            } else {
                [self _fail:[NSString stringWithFormat:@"Expected 'value', 'methodResponse' or 'params' element, but got '%@'", elementName]];
                [parser abortParsing];
            }
            break;
        case IQXMLRPCSerializerStateMethodResponse:
            if([elementName isEqualToString:@"params"]) {
                state = IQXMLRPCSerializerStateParams;
            } else {
                [self _fail:[NSString stringWithFormat:@"Expected 'params' element, but got '%@'", elementName]];
                [parser abortParsing];
            }
            break;
        case IQXMLRPCSerializerStateParams:
            if([elementName isEqualToString:@"param"]) {
                state = IQXMLRPCSerializerStateParam;
                if(![self _createChildArray]) {
                    [parser abortParsing];
                }
            } else {
                [self _fail:[NSString stringWithFormat:@"Expected 'param' element, but got '%@'", elementName]];
                [parser abortParsing];
            }
            break;
        case IQXMLRPCSerializerStateParam:
        case IQXMLRPCSerializerStateValueArrayData:
            if([elementName isEqualToString:@"value"]) {
                state = IQXMLRPCSerializerStateValue;
            } else {
                [self _fail:[NSString stringWithFormat:@"Expected 'value' element, but got '%@'", elementName]];
                [parser abortParsing];
            }
            break;
        case IQXMLRPCSerializerStateMember:
            if([elementName isEqualToString:@"value"]) {
                state = IQXMLRPCSerializerStateValue;
            } else if([elementName isEqualToString:@"name"]) {
                state = IQXMLRPCSerializerStateMemberName;
            } else {
                [self _fail:[NSString stringWithFormat:@"Expected 'value' element, but got '%@'", elementName]];
                [parser abortParsing];
            }
            break;
        case IQXMLRPCSerializerStateValue:
            dataType = elementName;
            if([elementName isEqualToString:@"struct"]) {
                state = IQXMLRPCSerializerStateValueStruct;
                if(![self _createChildObject]) {
                    [parser abortParsing];
                }
            } else if([elementName isEqualToString:@"array"]) {
                state = IQXMLRPCSerializerStateValueArray;
                if(![self _createChildArray]) {
                    [parser abortParsing];
                }
            } else {
                state = IQXMLRPCSerializerStateValueContent;
            }
            break;
        case IQXMLRPCSerializerStateValueStruct:
            if([elementName isEqualToString:@"member"]) {
                state = IQXMLRPCSerializerStateMember;
            } else {
                [self _fail:[NSString stringWithFormat:@"Expected 'member' element, but got '%@'", elementName]];
                [parser abortParsing];
            }
            break;
        case IQXMLRPCSerializerStateValueArray:
            if([elementName isEqualToString:@"data"]) {
                state = IQXMLRPCSerializerStateValueArrayData;
            } else {
                [self _fail:[NSString stringWithFormat:@"Expected 'data' element, but got '%@'", elementName]];
                [parser abortParsing];
            }
            break;
        case IQXMLRPCSerializerStateValueContent:
        case IQXMLRPCSerializerStateMemberName:
            [self _fail:[NSString stringWithFormat:@"Unexpected '%@' element", elementName]];
            [parser abortParsing];
            break;
    }
    if(!elementStack) elementStack = [NSMutableArray arrayWithCapacity:1];
    [elementStack addObject:[NSNumber numberWithInt:state]];
}
- (BOOL)_setScalarValueForElement:(NSString*)elementName
{
    BOOL ret;
    if([elementName isEqualToString:@"string"]) {
        ret = [self _setScalarValue:stringBuffer];
    } else if([elementName isEqualToString:@"int"] || [elementName isEqualToString:@"i4"]) {
        ret = [self _setScalarValue:[formatter numberFromString:stringBuffer]];
    } else if([elementName isEqualToString:@"boolean"]) {
        ret = [self _setScalarValue:[NSNumber numberWithBool:[stringBuffer intValue] != 0]];
    } else if([elementName isEqualToString:@"nil"]) {
        ret = [self _setScalarValue:nil];
    } else if([elementName isEqualToString:@"double"]) {
        ret = [self _setScalarValue:[formatter numberFromString:stringBuffer]];
    } else if([elementName isEqualToString:@"dateTime.iso8601"]) {
        NSDate* date = [dateFormatter dateFromString:stringBuffer];
        if(!date) {
            ret = [self _fail:[NSString stringWithFormat:@"Unparseable date '%@'", stringBuffer]];
        } else {
            ret = [self _setScalarValue:date];
        }
    } else if([elementName isEqualToString:@"base64"]) {
        ret = [self _setScalarValue:[NSData dataWithBase64String:stringBuffer]];
    } else {
        ret = [self _fail:[NSString stringWithFormat:@"Unknown data type name '%@'", elementName]];
    }
    stringBuffer = nil;
    return ret;
}
- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
    switch (state) {
        case IQXMLRPCSerializerStateValueContent:
            if(![self _setScalarValueForElement:elementName]) {
                [parser abortParsing];
            }
            break;
        case IQXMLRPCSerializerStateMemberName:
            key = stringBuffer;
            stringBuffer = nil;
            break;
        case IQXMLRPCSerializerStateValueArray:
        case IQXMLRPCSerializerStateValueStruct:
            if(![self _popObject]) {
                [parser abortParsing];
            }
            break;
        default:
            break;
    }
    if(elementStack.count > 1) {
        [elementStack removeLastObject];
        state = [[elementStack lastObject] intValue];
    }
}
- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
    if(state == IQXMLRPCSerializerStateValueContent || state == IQXMLRPCSerializerStateMemberName) {
        if(stringBuffer == nil) {
            stringBuffer = string;
            ownBuffer = NO;
        } else {
            if(!ownBuffer) {
                ownBuffer = YES;
                stringBuffer = [stringBuffer mutableCopy];
            }
            [(NSMutableString*)stringBuffer appendString:string];
        }
    }
}
- (void)parserDidEndDocument:(NSXMLParser *)parser
{
}
- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
    if(!error) error = parseError;
}
@end


BOOL _IQDeserializeXMLRPCData(id object, NSData* xmlData, IQSerialization* serialization, IQSerializationFlags flags, NSError** outError)
{
    NSError* error = nil;
    @autoreleasepool {
        _IQXMLRPCObjectFactory* objectFactory = [[_IQXMLRPCObjectFactory alloc] initWithSerialization:serialization];
        objectFactory->object = object;
        objectFactory->isRoot = YES;
        objectFactory->dictionaryMode = [object isKindOfClass:[NSArray class]]
        || [object isKindOfClass:[NSDictionary class]]
        || [object isKindOfClass:[NSSet class]]
        || [object isKindOfClass:[NSOrderedSet class]];
        
        
        NSXMLParser* parser = [[NSXMLParser alloc] initWithData:xmlData];
        parser.delegate = objectFactory;
        if(![parser parse] || objectFactory->error) {
            NSLog(@"Failed to parse: %@", objectFactory->error);
            if(objectFactory->error) {
                error = objectFactory->error;
            } else if(parser.parserError) {
                error = parser.parserError;
            } else {
                [objectFactory _fail:@"Unknown error"];
                error = objectFactory->error;
            }
        }
    }
    if(error) {
        if(outError) {
            *outError = error;
        }
        return NO;
    }
    return YES;
}
static BOOL _IQXMLRPCSerializeValue(IQXMLWriter* writer, id object, IQSerialization* serialization, IQSerializationFlags flags, NSError** outError)
{
    [writer writeStartElement:@"value"];
    if(!object || object == [NSNull null]) {
        [writer writeEmptyElement:@"nil"];
    } else if ([object isKindOfClass:[NSNumber class]]) {
        const char* t = [object objCType];
        BOOL handled = NO;
        if(t && t[0] == 'c') {
            char val = [object charValue];
            if(val == 0 || val == 1) {
                [writer writeStartElement:@"boolean"];
                [writer writeCharacters:val?@"1":@"0"];
                [writer writeEndElement];
            }
        } else if(t && (t[0] == 'd' || t[0] == 'f')) {
            [writer writeStartElement:@"double"];
            [writer writeCharacters:[object stringValue]];
            [writer writeEndElement];
        }
        if(!handled) {
            [writer writeStartElement:@"int"];
            [writer writeCharacters:[object stringValue]];
            [writer writeEndElement];
        }
    } else if([object isKindOfClass:[NSString class]]) {
        [writer writeStartElement:@"string"];
        [writer writeCharacters:(NSString*)object];
        [writer writeEndElement];
    } else if([object isKindOfClass:[NSArray class]] || [object isKindOfClass:[NSSet class]] || [object isKindOfClass:[NSOrderedSet class]]) {
        [writer writeStartElement:@"array"];
        [writer writeStartElement:@"data"];
        for(id value in object) {
            if(!_IQXMLRPCSerializeValue(writer, value, serialization, flags, outError))
                return NO;
        }
        [writer writeEndElement];
        [writer writeEndElement];
    } else if([object isKindOfClass:[NSDictionary class]]) {
        [writer writeStartElement:@"struct"];
        for(NSString* key in object) {
            id value = [object objectForKey:key];
            if((!value || value == [NSNull null]) && serialization.ignoreNilValues) {
                continue;
            }
            [writer writeStartElement:@"member"];
            [writer writeStartElement:@"name"];
            [writer writeCharacters:key];
            [writer writeEndElement];
            if(!_IQXMLRPCSerializeValue(writer, value, serialization, flags, outError))
                return NO;
            [writer writeEndElement];
        }
        [writer writeEndElement];
    } else {
        [writer writeStartElement:@"struct"];
        for(NSString* property in [serialization _propertiesForObject:object]) {
            id value = [object valueForKey:property];
            if((!value || value == [NSNull null]) && serialization.ignoreNilValues) {
                continue;
            }
            [writer writeStartElement:@"member"];
            [writer writeStartElement:@"name"];
            [writer writeCharacters:property];
            [writer writeEndElement];
            if(!_IQXMLRPCSerializeValue(writer, value, serialization, flags, outError))
                return NO;
            [writer writeEndElement];
        }
        [writer writeEndElement];
    }
    [writer writeEndElement];
    return YES;
}
static BOOL _IQXMLRPCSerializeRoot(IQXMLWriter* writer, id object, IQSerialization* serialization, IQSerializationFlags flags, NSError** outError)
{
    writer.encoding = serialization.textEncoding;
    if(flags & (IQSerializationFlagsRPCResponse|IQSerializationFlagsRPCFault)) {
        [writer writeStartElement:@"methodResponse"];
    } else if(flags & IQSerializationFlagsRPCRequest) {
        [writer writeStartElement:@"methodCall"];
        id name = object[@"methodName"];
        if(!name) name = object[@"method"];
        id params = object[@"params"];
        if(name || params) {
            object = params;
        }
        if(name) {
            [writer writeStartElement:@"methodName"];
            [writer writeCharacters:name];
            [writer writeEndElement];
        }
    }
    [writer writeStartElement:@"params"];
    if([object isKindOfClass:[NSArray class]] || [object isKindOfClass:[NSSet class]] || [object isKindOfClass:[NSOrderedSet class]]) {
        for(id value in object) {
            if((value == nil || value == [NSNull null]) && serialization.ignoreNilValues)
                continue;
            [writer writeStartElement:@"param"];
            if(!_IQXMLRPCSerializeValue(writer, value, serialization, flags, &outError))
                return NO;
            [writer writeEndElement];
        }
    } else {
        [writer writeStartElement:@"param"];
        // Write the value
        [writer writeEndElement];
    }
    [writer writeEndElement];
    if(flags & (IQSerializationFlagsRPCResponse|IQSerializationFlagsRPCFault|IQSerializationFlagsRPCRequest)) {
        [writer writeEndElement];
    }
    return YES;
}
NSData* _IQXMLRPCSerializeObject(id object, IQSerialization* serialization, IQSerializationFlags flags, NSError** outError)
{
    NSMutableData* data = [NSMutableData data];
    IQXMLWriter* writer = [[IQXMLWriter alloc] initWithBuffer:data];
    if(!_IQXMLRPCSerializeRoot(writer, object, serialization, flags, outError)) return nil;
    return data;
}
NSString* _IQXMLRPCSerializeObjectToString(id object, IQSerialization* serialization, IQSerializationFlags flags, NSError** outError)
{
    NSMutableString* string = [NSMutableString string];
    IQXMLWriter* writer = [[IQXMLWriter alloc] initWithStringBuffer:string];
    if(!_IQXMLRPCSerializeRoot(writer, object, serialization, flags, outError)) return nil;
    return string;
}
BOOL _IQXMLRPCSerializeObjectToStream(NSOutputStream* stream, id object, IQSerialization* serialization, IQSerializationFlags flags, NSError** outError)
{
    IQXMLWriter* writer = [[IQXMLWriter alloc] initWithStream:stream];
    return _IQXMLRPCSerializeRoot(writer, object, serialization, flags, outError);
}

@implementation NSDictionary (XMLRPCSerialization)
+ (NSDictionary*) dictionaryWithXMLRPCData:(NSData*)jsonData
{
    return [[IQSerialization new] dictionaryFromData:jsonData format:IQSerializationFormatXMLRPC];
}

+ (NSDictionary*) dictionaryWithXMLRPCString:(NSString*)jsonString
{
    return [[IQSerialization new] dictionaryFromString:jsonString format:IQSerializationFormatXMLRPC];
}
@end