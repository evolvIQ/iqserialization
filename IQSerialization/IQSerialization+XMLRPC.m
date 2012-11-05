//
//  NSXMLRPCSerialization.m
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
#import "IQObjectFactory.h"

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
    NSLog(@"Found %@ in state %d", elementName, state);
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
            NSLog(@"member name : %@", stringBuffer);
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
    NSLog(@"Did end document");
}
- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
    if(!error) error = parseError;
}
@end


BOOL _IQDeserializeXMLRPCData(id object, NSData* xmlData, IQSerialization* serialization, NSError** outError)
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
NSData* _IQXMLRPCSerializeObject(id object, IQSerialization* serialization, NSError** outError)
{
    return nil;
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