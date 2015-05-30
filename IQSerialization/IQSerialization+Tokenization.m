//
//  IQSerialization+Tokenization.m
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

#import "IQSerialization+Tokenization.h"

typedef enum {
    State_Init,
    State_Document,
    State_ElementOrComment,
    State_BeginElement,
    State_EmptyElement,
    State_EndElement,
    State_Instruction,
    State_Comment,

    State_String,

    State_Rescan
} State;

@interface _IQTokenizationState : NSObject {
@public
    NSMutableData* _data;
    int _depth, _endCommentCount;
    char _last;
    State _state;
    NSUInteger _startPos;
}
@end

@implementation IQSerialization (Tokenization)

#pragma mark - XML tokenization

static unsigned int ScanXml(_IQTokenizationState* s, NSUInteger max, uint8_t* buf, unsigned int len, unsigned int* start) {
    for(unsigned int i = 0; i < len; ++i) {
        switch(buf[i]) {
            case '<':
                if(s->_state == State_Init || s->_state == State_Document) {
                    if(s->_state == State_Init) {
                        *start = i;
                    }
                    s->_state = State_ElementOrComment;
                }
                break;
            case '>':
                if(s->_state == State_BeginElement || s->_state == State_ElementOrComment) {
                    s->_state = State_Document;
                    if(s->_last != '/') ++s->_depth;
                    else if(s->_depth == 0) {
                        s->_last = buf[i];
                        return i + 1;
                    }
                } else if(s->_state == State_EndElement) {
                    if(--s->_depth == 0) {
                        s->_last = buf[i];
                        return i + 1;
                    } else {
                        s->_state = State_Document;
                    }
                } else if((s->_state == State_Comment && s->_endCommentCount >= 2) || s->_state == State_Instruction) {
                    s->_state = State_Document;
                }
                break;
            case '/':
                if(s->_state == State_ElementOrComment) {
                    s->_state = State_EndElement;
                }
                break;
            case '?':
                if(s->_state == State_ElementOrComment) {
                    s->_state = State_Instruction;
                }
                break;
            case '!':
                if(s->_state == State_ElementOrComment) {
                    s->_state = State_Comment;
                }
                break;
            default:
                if(s->_state == State_ElementOrComment) {
                    s->_state = State_BeginElement;
                }
                break;
        }
        if(s->_state == State_Comment) {
            if(buf[i] == '-') ++s->_endCommentCount;
            else s->_endCommentCount = 0;
        }
        s->_last = buf[i];
    }
    return 0;
}

#pragma mark - JSON tokenization

static unsigned int ScanJson(_IQTokenizationState* s, NSUInteger max, uint8_t* buf, unsigned int len, unsigned int* start) {
    for(unsigned int i = 0; i < len; ++i) {
        switch(buf[i]) {
            case '{':
            case '[':
                if(s->_state == State_Init) {
                    *start = i;
                    s->_state = State_Document;
                }
                if(s->_state != State_String)
                    ++s->_depth;
                break;
            case '}':
            case ']':
                if(s->_state == State_Document) {
                    if(--s->_depth == 0) {
                        s->_last = buf[i];
                        return i + 1;
                    }
                }
                break;
            case '"':
                if(s->_state == State_String) {
                    if(s->_last != '\\') {
                        s->_state = State_Document;
                    }
                } else {
                    s->_state = State_String;
                }
                break;
        }
        s->_last = buf[i];
    }
    return 0;
}

#pragma mark - Generic helpers

typedef unsigned int (*Scanner)(_IQTokenizationState* s, NSUInteger max, uint8_t* buf, unsigned int len, unsigned int* start);

static NSData* TryGetDoc(_IQTokenizationState* s, NSUInteger max, uint8_t* buf, unsigned int len, Scanner scan) {
    unsigned int start = 0;
    unsigned int end = scan(s, max, buf, len, &start);
    NSData* documentData = nil;
    if(end > 0) {
        if(!s->_data) s->_data = [NSMutableData data];
        [s->_data appendBytes:buf+start length:end-start];
        NSLog(@"Has document: %@", [[NSString alloc] initWithData:s->_data encoding:NSUTF8StringEncoding]);
        documentData = s->_data;
        s->_data = nil;
        s->_state = State_Rescan;
        start = end;
    }
    if(s->_state != State_Init && start < len) {
        if(!s->_data) s->_data = [NSMutableData data];
        [s->_data appendBytes:buf+start length:len-start];
    }
    return documentData;
}

static NSData* ReadNextDocument(NSInputStream* stream, NSObject** state, NSUInteger max, Scanner scan) {
    if(!state) return nil;
    if(!*state) *state = [_IQTokenizationState new];
    _IQTokenizationState* s = (_IQTokenizationState*)*state;

    if(s->_state == State_Rescan) {
        s->_state = State_Init;
        if(s->_data) {
            NSData* oldDoc = s->_data;
            s->_data = nil;
            NSData* currentDocumentData = TryGetDoc(s, max, (uint8_t*)oldDoc.bytes, oldDoc.length, scan);
            if(currentDocumentData) return currentDocumentData;
        }
    }

    while(stream && stream.hasBytesAvailable) {
        uint8_t buf[12];
        unsigned int len = [(NSInputStream *)stream read:buf maxLength:sizeof(buf)];
        if(len == 0) return nil;

        NSData* currentDocumentData = TryGetDoc(s, max, buf, len, scan);
        if(currentDocumentData) return currentDocumentData;
    }

    return nil;
}

#pragma mark - Interface

- (NSData*) extractNextDocumentFromStream:(NSInputStream*)stream format:(IQSerializationFormat)fmt state:(NSObject**)state maxDocumentLength:(NSUInteger)maxSize {
    switch(fmt) {
        case IQSerializationFormatSimpleXML:
        case IQSerializationFormatXMLRPC:
        case IQSerializationFormatXMLPlist:
            return ReadNextDocument(stream, state, maxSize, ScanXml);
        case IQSerializationFormatJSON:
            return ReadNextDocument(stream, state, maxSize, ScanJson);
        default:
            return nil;
    }
}

@end

@implementation _IQTokenizationState
@end
