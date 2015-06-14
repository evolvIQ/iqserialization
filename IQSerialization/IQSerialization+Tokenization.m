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
#import <splitstream.h>

@interface _IQTokenizationState : NSObject {
@public
    SplitstreamState state;
    BOOL didReturnDocument;
}
- (id) initWithDepth:(int)depth;
@end

@implementation IQSerialization (Tokenization)

static NSData* ReadNextDocument(NSUInteger bufsize, NSInputStream* stream, NSObject** state, NSUInteger max, SplitstreamScanner scanner, int depth) {
    if(!state) return nil;
    if(!*state) *state = [[_IQTokenizationState alloc] initWithDepth:depth];
    _IQTokenizationState* s = (_IQTokenizationState*)*state;

    if(s->didReturnDocument) {
        SplitstreamDocument doc = SplitstreamGetNextDocument(&s->state, max, NULL, 0, scanner);
        if(doc.buffer) {
            s->didReturnDocument = YES;
            return [NSData dataWithBytesNoCopy:(void*)doc.buffer length:doc.length freeWhenDone:YES];
        }
    }

    while(stream && stream.hasBytesAvailable) {
        char buf[bufsize];
        NSInteger len = [(NSInputStream *)stream read:(unsigned char*)buf maxLength:sizeof(buf)];
        if(len == 0) return nil;

        SplitstreamDocument doc = SplitstreamGetNextDocument(&s->state, max, buf, len, scanner);
        if(doc.buffer) {
            s->didReturnDocument = YES;
            return [NSData dataWithBytesNoCopy:(void*)doc.buffer length:doc.length freeWhenDone:YES];
        }
    }
    s->didReturnDocument = NO;

    return nil;
}

#pragma mark - Interface

- (NSData*) extractNextDocumentFromStream:(NSInputStream*)stream format:(IQSerializationFormat)fmt state:(NSObject**)state maxDocumentLength:(NSUInteger)maxSize startDepth:(NSUInteger)startDepth {
    NSUInteger readBufferSize = self.readBufferSize;
    if(!readBufferSize) readBufferSize = 1024;
    switch(fmt) {
        case IQSerializationFormatSimpleXML:
        case IQSerializationFormatXMLRPC:
        case IQSerializationFormatXMLPlist:
            return ReadNextDocument(readBufferSize, stream, state, maxSize, SplitstreamXMLScanner, (int)startDepth);
        case IQSerializationFormatJSON:
            return ReadNextDocument(readBufferSize, stream, state, maxSize, SplitstreamJSONScanner, (int)startDepth);
        default:
            return nil;
    }
}

@end

@implementation _IQTokenizationState
- (id) initWithDepth:(int)depth {
    if(self = [super init]) {
        SplitstreamInitDepth(&state, depth);
    }
    return self;
}

- (id) init {
    return [self initWithDepth:0];
}

- (void) dealloc {
    SplitstreamFree(&state);
}
@end
