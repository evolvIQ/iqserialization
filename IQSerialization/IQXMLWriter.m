//
//  IQXMLWriter.m
//  IQSerialization for iOS and Mac OS X
//
//  Based on XSWI by Thomas Rørvik Skjølberg
//
//  Copyright 2012 Rickard Petzäll, EvolvIQ
//  Copyright (C) 2010 by Thomas Rørvik Skjølberg
//
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

#import "IQXMLWriter.h"

#define NSBOOL(_X_) ((_X_) ? (id)kCFBooleanTrue : (id)kCFBooleanFalse)

static NSString *const EMPTY_STRING = @"";
static NSString *const XML_NAMESPACE_URI = @"http://www.w3.org/XML/1998/namespace";
static NSString *const XML_NAMESPACE_URI_PREFIX = @"xml";
static NSString *const XMLNS_NAMESPACE_URI = @"http://www.w3.org/2000/xmlns/";
static NSString *const XMLNS_NAMESPACE_URI_PREFIX = @"xmlns";
static NSString *const XSI_NAMESPACE_URI = @"http://www.w3.org/2001/XMLSchema/";
static NSString *const XSI_NAMESPACE_URI_PREFIX = @"xsi";

@interface IQXMLWriter () {
    NSOutputStream* outputStream;
    NSMutableData* outputBuffer;
    NSMutableString* outputStringBuffer;
    
    BOOL startedWriting, documentStarted;
    
    // the number current levels
    int level;
    // is the element open, i.e. the end bracket has not been written yet
    BOOL openElement;
    // does the element contain characters, cdata, comments
    BOOL emptyElement;
    
    // the element stack. one per element level
    NSMutableArray* elementLocalNames;
    NSMutableArray* elementNamespaceURIs;
    
    // the namespace array. zero or more namespace attributes can be defined per element level
    NSMutableArray* namespaceURIs;
    // the namespace count. one per element level
    NSMutableArray* namespaceCounts;
    // the namespaces which have been written to the stream
    NSMutableArray* namespaceWritten;
    
    // mapping of namespace URI to prefix and visa versa. Corresponds in size to the namespaceURIs array.
    NSMutableDictionary* namespaceURIPrefixMap;
    NSMutableDictionary* prefixNamespaceURIMap;
    
    // tag indentation
    NSString* indentation;
    // line break
    NSString* lineBreak;
    
    // if true, then write elements without children as <start /> instead of <start></start>
    BOOL automaticEmptyElements;
}

#pragma mark - Private methods

- (void)_writeStartDocumentWithEncodingAndVersion:(NSString*)encoding version:(NSString*)version;

- (void)_write:(NSString*)value;
- (void)_writeCharacters:(const unichar*)characters length:(int)length;
- (void)_writeEscapeCharacters:(const unichar*)characters length:(int)length;
@end

@implementation IQXMLWriter
@synthesize automaticEmptyElements, indentation, lineBreak, level, encoding;
- (id) init {
    self = [super init];
    if (self != nil) {
        level = 0;
        openElement = NO;
        emptyElement = NO;
        
        elementLocalNames = [[NSMutableArray alloc]init];
        elementNamespaceURIs = [[NSMutableArray alloc]init];
        
        namespaceURIs = [[NSMutableArray alloc]init];
        namespaceCounts = [[NSMutableArray alloc]init];
        namespaceWritten = [[NSMutableArray alloc]init];
        
        namespaceURIPrefixMap = [[NSMutableDictionary alloc] init];
        prefixNamespaceURIMap = [[NSMutableDictionary alloc] init];
        
        // load default custom behaviour
        indentation = @"\t";
        lineBreak = @"\n";
        automaticEmptyElements = YES;
        
        // setup default xml namespaces. assume both are previously known.
        [namespaceCounts addObject:[NSNumber numberWithInt:2]];
        [self setPrefix:XML_NAMESPACE_URI_PREFIX namespaceURI:XML_NAMESPACE_URI];
        [self setPrefix:XMLNS_NAMESPACE_URI_PREFIX namespaceURI:XMLNS_NAMESPACE_URI];
    }
    return self;
}

- (id)initWithStream:(NSOutputStream*)stream
{
    self = [self init];
    if(self) {
        outputStream = stream;
    }
    return self;
}

- (id)initWithStringBuffer:(NSMutableString*)buffer
{
    self = [self init];
    if(self) {
        outputStringBuffer = buffer;
    }
    return self;
}

- (id)initWithBuffer:(NSMutableData*)buffer
{
    self = [self init];
    if(self) {
        outputBuffer = buffer;
    }
    return self;
}

- (void) pushNamespaceStack {
    // step namespace count - add the current namespace count
    NSNumber* previousCount = [namespaceCounts lastObject];
    if([namespaceURIs count] == [previousCount intValue]) {
        // the count is still the same
        [namespaceCounts addObject:previousCount];
    } else {
        // the count has changed, save the it
        NSNumber* count = [NSNumber numberWithInt:[namespaceURIs count]];
        
        [namespaceCounts addObject:count];
    }
}

- (void) writeNamespaceAttributes {
    if(openElement) {
        // write namespace attributes in the namespace stack
        NSNumber* previousCount = [namespaceCounts lastObject];
        for(int i = [previousCount intValue]; i < [namespaceURIs count]; i++) {
            
            // did we already write this namespace?
            id written = [namespaceWritten objectAtIndex:i];
            if(written == NSBOOL(NO)) {
                // write namespace
                NSString* namespaceURI = [namespaceURIs objectAtIndex:i];
                NSString* prefix = [namespaceURIPrefixMap objectForKey:namespaceURI];
                
                [self writeNamespaceToStream:prefix namespaceURI:namespaceURI];
                
                [namespaceWritten replaceObjectAtIndex:i withObject:NSBOOL(YES)];
            } else {
                // already written namespace
            }
        }
    } else {
        @throw([NSException exceptionWithName:@"XMLWriterException" reason:@"No open start element" userInfo:NULL]);
    }
}

- (void) popNamespaceStack {
    // step namespaces one level down
    if([namespaceCounts lastObject] != [namespaceCounts objectAtIndex:([namespaceCounts count] - 2)]) {
        // remove namespaces which now are out of scope, i.e. between the current and the previus count
        NSNumber* previousCount = [namespaceCounts lastObject];
        NSNumber* currentCount = [namespaceCounts objectAtIndex:([namespaceCounts count] - 2)];
        for(int i = [previousCount intValue] - 1; i >= [currentCount intValue]; i--) {
            NSString* removedNamespaceURI = [namespaceURIs objectAtIndex:i];
            NSString* removedPrefix = [namespaceURIPrefixMap objectForKey:removedNamespaceURI];
            
            [prefixNamespaceURIMap removeObjectForKey:removedPrefix];
            [namespaceURIPrefixMap removeObjectForKey:removedNamespaceURI];
            
            [namespaceURIs removeLastObject];
            
            [namespaceWritten removeLastObject];
        }
    } else {
        // not necessary to remove any namespaces
    }
    [namespaceCounts removeLastObject];
}

- (void)setPrefix:(NSString*)prefix namespaceURI:(NSString *)namespaceURI {
    if(!namespaceURI) {
        // raise exception
        @throw([NSException exceptionWithName:@"XMLWriterException" reason:@"Namespace cannot be NULL" userInfo:NULL]);
    }
    if(!prefix) {
        // raise exception
        @throw([NSException exceptionWithName:@"XMLWriterException" reason:@"Prefix cannot be NULL" userInfo:NULL]);
    }
    if([namespaceURIPrefixMap objectForKey:namespaceURI]) {
        // raise exception
        @throw([NSException exceptionWithName:@"XMLWriterException" reason:[NSString stringWithFormat:@"Name namespace %@ has already been set", namespaceURI] userInfo:NULL]);
    }
    if([prefixNamespaceURIMap objectForKey:prefix]) {
        // raise exception
        if([prefix length]) {
            @throw([NSException exceptionWithName:@"XMLWriterException" reason:[NSString stringWithFormat:@"Prefix %@ has already been set", prefix] userInfo:NULL]);
        } else {
            @throw([NSException exceptionWithName:@"XMLWriterException" reason:@"Default namespace has already been set" userInfo:NULL]);
        }
    }
    
    // increase the namespaces and add prefix mapping
    [namespaceURIs addObject:namespaceURI];
    [namespaceURIPrefixMap setObject:prefix forKey:namespaceURI];
    [prefixNamespaceURIMap setObject:namespaceURI forKey:prefix];
    
    if(openElement) { // write the namespace now
        [self writeNamespaceToStream:prefix namespaceURI:namespaceURI];
        
        [namespaceWritten addObject:NSBOOL(YES)];
    } else {
        // write the namespace as the next start element is closed
        [namespaceWritten addObject:NSBOOL(NO)];
    }
}

- (NSString*)getPrefix:(NSString*)namespaceURI {
    return [namespaceURIPrefixMap objectForKey:namespaceURI];
}

- (void) pushElementStack:(NSString*)namespaceURI localName:(NSString*)localName {
    // save for end elements
    [elementLocalNames addObject:localName];
    if(namespaceURI) {
        [elementNamespaceURIs addObject:namespaceURI];
    } else {
        [elementNamespaceURIs addObject:EMPTY_STRING];
    }
}

- (void) popElementStack {
    // remove element traces
    [elementNamespaceURIs removeLastObject];
    [elementLocalNames removeLastObject];
}

- (void) writeStartDocument {
    NSString* xmlEncoding = (__bridge NSString*)CFStringConvertEncodingToIANACharSetName(encoding);
    if(!xmlEncoding) {
        [NSException raise:@"UnsupportedTextEncoding" format:@"An encoding was specified that is not supported by IQXMLWriter"];
    }
    [self _writeStartDocumentWithEncodingAndVersion:xmlEncoding version:@"1.0"];
}

- (void) _writeStartDocumentWithEncodingAndVersion:(NSString*)aEncoding version:(NSString*)version {
    documentStarted = YES;
    if(startedWriting) {
        [NSException raise:@"IllegalState" format:@"Document has already been started"];
    } else {
        [self _write:@"<?xml version=\""];
        [self _write:version];
        [self _write:@"\""];
        
        if(aEncoding) {
            [self _write:@" encoding=\""];
            [self _write:aEncoding];
            [self _write:@"\""];
        }
        [self _write:@" ?>"];
        
    }
}

- (void) writeEndDocument {
    while (level > 0) {
        [self writeEndElement];
    }
}

- (void) writeStartElement:(NSString *)localName {
    if(!documentStarted) {
        [self writeStartDocument];
    }
    [self writeStartElementWithNamespace:NULL localName:localName];
}

- (void) writeCloseStartElement {
    if(openElement) {
        [self writeCloseElement:NO];
    } else {
        // raise exception
        @throw([NSException exceptionWithName:@"XMLWriterException" reason:@"No open start element" userInfo:NULL]);
    }
}

- (void) writeCloseElement:(BOOL)empty {
    [self writeNamespaceAttributes];
    [self pushNamespaceStack];
    
    if(empty) {
        [self _write:@" />"];
    } else {
        [self _write:@">"];
    }
    
    openElement = NO;
}

- (void) writeEndElement:(NSString *)localName {
    [self writeEndElementWithNamespace:NULL localName:localName];
}

- (void) writeEndElement {
    if(openElement && automaticEmptyElements) {
        // go for <START />
        [self writeCloseElement:YES]; // write empty end element
        
        [self popNamespaceStack];
        [self popElementStack];
        
        emptyElement = YES;
        openElement = NO;
        
        level -= 1;
    } else {
        NSString* namespaceURI = [elementNamespaceURIs lastObject];
        NSString* localName = [elementLocalNames lastObject];
        
        if(namespaceURI == EMPTY_STRING) {
            [self writeEndElementWithNamespace:NULL localName:localName];
        } else {
            [self writeEndElementWithNamespace:namespaceURI localName:localName];
        }
    }
}

- (void) writeStartElementWithNamespace:(NSString *)namespaceURI localName:(NSString *)localName {
    if(openElement) {
        [self writeCloseElement:NO];
    }
    
    [self writeLinebreak];
    [self writeIndentation];
    
    [self _write:@"<"];
    if(namespaceURI) {
        NSString* prefix = [namespaceURIPrefixMap objectForKey:namespaceURI];
        
        if(!prefix) {
            // raise exception
            @throw([NSException exceptionWithName:@"XMLWriterException" reason:[NSString stringWithFormat:@"Unknown namespace URI %@", namespaceURI] userInfo:NULL]);
        }
        
        if([prefix length]) {
            [self _write:prefix];
            [self _write:@":"];
        }
    }
    [self _write:localName];
    
    [self pushElementStack:namespaceURI localName:localName];
    
    openElement = YES;
    emptyElement = YES;
    level += 1;
    
}

- (void) writeEndElementWithNamespace:(NSString *)namespaceURI localName:(NSString *)localName {
    if(level <= 0) {
        // raise exception
        @throw([NSException exceptionWithName:@"XMLWriterException" reason:@"Cannot write more end elements than start elements." userInfo:NULL]);
    }
    
    level -= 1;
    
    if(openElement) {
        // go for <START><END>
        [self writeCloseElement:NO];
    } else {
        if(emptyElement) {
            // go for linebreak + indentation + <END>
            [self writeLinebreak];
            [self writeIndentation];
        } else {
            // go for <START>characters<END>
        }
    }
    
    // write standard end element
    [self _write:@"</"];
    
    if(namespaceURI) {
        NSString* prefix = [namespaceURIPrefixMap objectForKey:namespaceURI];
        
        if(!prefix) {
            // raise exception
            @throw([NSException exceptionWithName:@"XMLWriterException" reason:[NSString stringWithFormat:@"Unknown namespace URI %@", namespaceURI] userInfo:NULL]);
        }
        
        if([prefix length]) {
            [self _write:prefix];
            [self _write:@":"];
        }
    }
    
    [self _write:localName];
    [self _write:@">"];
    
    [self popNamespaceStack];
    [self popElementStack];
    
    emptyElement = YES;
    openElement = NO;
}

- (void) writeEmptyElement:(NSString *)localName {
    if(openElement) {
        [self writeCloseElement:NO];
    }
    
    [self writeLinebreak];
    [self writeIndentation];
    
    [self _write:@"<"];
    [self _write:localName];
    [self _write:@" />"];
    
    emptyElement = YES;
    openElement = NO;
}

- (void) writeEmptyElementWithNamespace:(NSString *)namespaceURI localName:(NSString *)localName {
    if(openElement) {
        [self writeCloseElement:NO];
    }
    
    [self writeLinebreak];
    [self writeIndentation];
    
    [self _write:@"<"];
    
    if(namespaceURI) {
        NSString* prefix = [namespaceURIPrefixMap objectForKey:namespaceURI];
        
        if(!prefix) {
            // raise exception
            @throw([NSException exceptionWithName:@"XMLWriterException" reason:[NSString stringWithFormat:@"Unknown namespace URI %@", namespaceURI] userInfo:NULL]);
        }
        
        if([prefix length]) {
            [self _write:prefix];
            [self _write:@":"];
        }
    }
    
    [self _write:localName];
    [self _write:@" />"];
    
    emptyElement = YES;
    openElement = NO;
}

- (void) writeAttribute:(NSString *)localName value:(NSString *)value {
    [self writeAttributeWithNamespace:NULL localName:localName value:value];
}

- (void) writeAttributeWithNamespace:(NSString *)namespaceURI localName:(NSString *)localName value:(NSString *)value {
    if(openElement) {
        [self _write:@" "];
        
        if(namespaceURI) {
            NSString* prefix = [namespaceURIPrefixMap objectForKey:namespaceURI];
            if(!prefix) {
                // raise exception
                @throw([NSException exceptionWithName:@"XMLWriterException" reason:[NSString stringWithFormat:@"Unknown namespace URI %@", namespaceURI] userInfo:NULL]);
            }
            
            if([prefix length]) {
                [self _write:prefix];
                [self _write:@":"];
            }
        }
        [self _write:localName];
        [self _write:@"=\""];
        [self writeEscape:value];
        [self _write:@"\""];
    } else {
        // raise expection
        @throw([NSException exceptionWithName:@"XMLWriterException" reason:@"No open start element" userInfo:NULL]);
    }
}

- (void)setDefaultNamespace:(NSString*)namespaceURI {
    [self setPrefix:EMPTY_STRING namespaceURI:namespaceURI];
}

- (void) writeNamespace:(NSString*)prefix namespaceURI:(NSString *)namespaceURI {
    if(openElement) {
        [self setPrefix:prefix namespaceURI:namespaceURI];
    } else {
        // raise exception
        @throw([NSException exceptionWithName:@"XMLWriterException" reason:@"No open start element" userInfo:NULL]);
    }
}

- (void) writeDefaultNamespace:(NSString*)namespaceURI {
    [self writeNamespace:EMPTY_STRING namespaceURI:namespaceURI];
}

- (NSString*)getNamespaceURI:(NSString*)prefix {
    return [prefixNamespaceURIMap objectForKey:prefix];
}

-(void) writeNamespaceToStream:(NSString*)prefix namespaceURI:(NSString*)namespaceURI {
    if(openElement) { // write the namespace now
        [self _write:@" "];
        
        NSString* xmlnsPrefix = [self getPrefix:XMLNS_NAMESPACE_URI];
        if(!xmlnsPrefix) {
            // raise exception
            @throw([NSException exceptionWithName:@"XMLWriterException" reason:[NSString stringWithFormat:@"Cannot declare namespace without namespace %@", XMLNS_NAMESPACE_URI] userInfo:NULL]);
        }
        
        [self _write:xmlnsPrefix]; // xmlns
        if([prefix length]) {
            // write xmlns:prefix="namespaceURI" attribute
            
            [self _write:@":"]; // colon
            [self _write:prefix]; // prefix
        } else {
            // write xmlns="namespaceURI" attribute
        }
        [self _write:@"=\""];
        [self writeEscape:namespaceURI];
        [self _write:@"\""];
    } else {
        @throw([NSException exceptionWithName:@"XMLWriterException" reason:@"No open start element" userInfo:NULL]);
    }
}

- (void) writeCharacters:(NSString*)text {
    if(openElement) {
        [self writeCloseElement:NO];
    }
    
    [self writeEscape:text];
    
    emptyElement = NO;
}

- (void) writeComment:(NSString*)comment {
    if(openElement) {
        [self writeCloseElement:NO];
    }
    [self _write:@"<!--"];
    [self _write:comment]; // no escape
    [self _write:@"-->"];
    
    emptyElement = NO;
}

- (void) writeProcessingInstruction:(NSString*)target data:(NSString*)data {
    if(openElement) {
        [self writeCloseElement:NO];
    }
    [self _write:@"<![CDATA["];
    [self _write:target]; // no escape
    [self _write:@" "];
    [self _write:data]; // no escape
    [self _write:@"]]>"];
    
    emptyElement = NO;
}

- (void) writeCData:(NSString*)cdata {
    if(openElement) {
        [self writeCloseElement:NO];
    }
    [self _write:@"<![CDATA["];
    [self _write:cdata]; // no escape
    [self _write:@"]]>"];
    
    emptyElement = NO;
}

- (void)_write:(NSString*)value
{
    if(outputStringBuffer) {
        [outputStringBuffer appendString:value];
    } else {
        unsigned char buf[4096];
        NSUInteger length = value.length;
        CFStringRef r = (__bridge CFStringRef)value;
        for(CFIndex off = 0; off < length;) {
            CFIndex used;
            off += CFStringGetBytes(r, CFRangeMake(off, length - off), encoding, '?', !startedWriting, buf, 512, &used);
            startedWriting = YES;
            if(outputStream) {
                [outputStream write:buf maxLength:used];
            } else {
                [outputBuffer appendBytes:buf length:used];
            }
        }
    }
}

- (void)_writeCharacters:(const unichar*)characters length:(int)length
{
    if(outputStringBuffer) {
        CFStringAppendCharacters((CFMutableStringRef)outputStringBuffer, characters, length);
        startedWriting = YES;
    } else {
        CFStringRef r = CFStringCreateWithCharactersNoCopy(NULL, characters, length, kCFAllocatorNull);
        [self _write:(__bridge NSString *)(r)];
        CFRelease(r);
    }
}

- (void)writeEscape:(NSString*)value
{
    
    const unichar *characters = CFStringGetCharactersPtr((CFStringRef)value);
    
    if (characters) {
        // main flow
        [self _writeEscapeCharacters:characters length:[value length]];
    } else {
        // we need to read/copy the characters for some reason, from the docs of CFStringGetCharactersPtr:
        // A pointer to a buffer of Unicode character or NULL if the internal storage of the CFString does not allow this to be returned efficiently.
        // Whether or not this function returns a valid pointer or NULL depends on many factors, all of which depend on how the string was created and its properties. In addition, the function result might change between different releases and on different platforms. So do not count on receiving a non- NULL result from this function under any circumstances (except when the object is created with CFStringCreateMutableWithExternalCharactersNoCopy).
        
        // we dont need the whole data length at once
        NSMutableData *data = [NSMutableData dataWithLength:256 * sizeof(unichar)];
        
        if(!data) {
            // raise exception - no more memory
            @throw([NSException exceptionWithName:@"XMLWriterException" reason:[NSString stringWithFormat:@"Could not allocate data buffer of %i unicode characters", 256] userInfo:NULL]);
        }
        
        int count = 0;
        do {
            int length;
            if(count + 256 < [value length]) {
                length = 256;
            } else {
                length = [value length] - count;
            }
            
            [value getCharacters:[data mutableBytes] range:NSMakeRange(count, length)];
            
            [self _writeEscapeCharacters:[data bytes] length:length];
            
            count += length;
        } while(count < [value length]);
        
        // buffers autorelease
    }
}

- (void)_writeEscapeCharacters:(const unichar*)characters length:(int)length
{
    int rangeStart = 0;
    int rangeLength = 0;
    
    for(int i = 0; i < length; i++) {
        
        UniChar c = characters[i];
        if (c <= 0xd7ff)  {
            if (c >= 0x20) {
                switch (c) {
                    case 34: {
                        // write range if any
                        if(rangeLength) {
                            [self _writeCharacters:characters+rangeStart length:rangeLength];
                        }
                        [self _write:@"&quot;"];
                        
                        break;
                    }
                        // quot
                    case 38: {
                        // write range if any
                        if(rangeLength) {
                            [self _writeCharacters:characters+rangeStart length:rangeLength];
                        }
                        [self _write:@"&amp;"];
                        
                        break;
                    }
                        // amp;
                    case 60: {
                        // write range if any
                        if(rangeLength) {
                            [self _writeCharacters:characters+rangeStart length:rangeLength];
                        }
                        
                        [self _write:@"&lt;"];
                        
                        break;
                    }
                        // lt;
                    case 62: {
                        // write range if any
                        if(rangeLength) {
                            [self _writeCharacters:characters+rangeStart length:rangeLength];
                        }
                        
                        [self _write:@"&gt;"];
                        
                        break;
                    }
                        // gt;
                    default: {
                        // valid
                        rangeLength++;
                        
                        // note: we dont need to escape char 39 for &apos; because we use double quotes exclusively
                        
                        continue;
                    }
                }
                
                // set range start to next
                rangeLength = 0;
                rangeStart = i + 1;
                
            } else {
                if (c == '\n' || c == '\r' || c == '\t') {
                    // valid;
                    rangeLength++;
                    
                    continue;
                } else {
                    // invalid, skip
                }
            }
        } else if (c < 0xE000) {
            // invalid, skip
        } else if (c <= 0xFFFD) {
            // valid
            rangeLength++;
            
            continue;
        } else {
            // invalid, skip
        }
        
        // write range if any
        if(rangeLength) {
            [self _writeCharacters:characters+rangeStart length:rangeLength];
        }
        
        // set range start to next
        rangeLength = 0;
        rangeStart = i + 1;
    }
    
    // write range if any
    if(rangeLength) {
        // main flow will probably write all characters here
        [self _writeCharacters:characters+rangeStart length:rangeLength];
    }
}

- (void)writeLinebreak {
    if(lineBreak) {
        [self _write:lineBreak];
    }
}

- (void)writeIndentation {
    if(indentation) {
        for (int i = 0; i < level; i++ ) {
            [self _write:indentation];
        }
    }
}

@end