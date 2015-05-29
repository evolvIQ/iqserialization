//
//  IQXMLWriter.h
//  IQSerialization for iOS and Mac OS X
//
//  Copyright © 2012-2015 Rickard Lyrenius
//  Based on XSWI by Thomas Rørvik Skjølberg
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

#import <Foundation/Foundation.h>

@interface IQXMLWriter : NSObject

#pragma mark - Properties

@property (nonatomic, retain, readwrite) NSString* indentation;
@property (nonatomic, retain, readwrite) NSString* lineBreak;
@property (nonatomic, readwrite) BOOL automaticEmptyElements;
@property (nonatomic, readonly) int level;
/** \brief Output string encoding.
 
 Default is NSUTF8StringEncoding.
 */
@property (nonatomic) NSStringEncoding encoding;


#pragma mark - Initialization

- (id)initWithStream:(NSOutputStream*)stream;
- (id)initWithStringBuffer:(NSMutableString*)buffer;
- (id)initWithBuffer:(NSMutableData*)buffer;

#pragma mark - XML writing

- (void) writeStartDocument;

- (void) writeStartElement:(NSString *)localName;

- (void) writeEndElement; // automatic end element (mirrors previous start element at the same level)
- (void) writeEndElement:(NSString *)localName;

- (void) writeEmptyElement:(NSString *)localName;

- (void) writeEndDocument; // write any remaining end elements

- (void) writeAttribute:(NSString *)localName value:(NSString *)value;

- (void) writeCharacters:(NSString*)text;
- (void) writeComment:(NSString*)comment;
- (void) writeProcessingInstruction:(NSString*)target data:(NSString*)data;
- (void) writeCData:(NSString*)cdata;

// helpful for formatting, special needs
// write linebreak, if any
- (void) writeLinebreak;
// write indentation, if any
- (void) writeIndentation;
// write end of start element, so that the start tag is complete
- (void) writeCloseStartElement;

// write any outstanding namespace declaration attributes in a start element
- (void) writeNamespaceAttributes;
// write escaped text to the stream
- (void) writeEscape:(NSString*)value;

@end
