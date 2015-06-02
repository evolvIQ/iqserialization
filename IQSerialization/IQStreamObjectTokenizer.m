//
//  IQStreamObjectTokenizer.m
//  IQSerialization
//
//  Created by Rickard Lyrenius on 30/05/15.
//  Copyright (c) 2015 EvolvIQ. All rights reserved.
//

#import <CoreFoundation/CoreFoundation.h>
#import "IQSerialization+Tokenization.h"
#import "IQStreamObjectTokenizer.h"

@interface IQStreamObjectTokenizer () {
    NSInputStream* _stream;
    IQSerialization* _serialization;
    NSObject* _state;
    IQSerializationFormat _format;
}
- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode;
@end

@implementation IQStreamObjectTokenizer

#pragma mark - Public methods

- (id) initWithStream:(NSInputStream*)strm serialization:(IQSerialization*)ser format:(IQSerializationFormat)format {
    if(self = [super init]) {
        _stream = strm;
        _serialization = ser;
        self.maxObjectSize = 4*1024*1024;
        _format = format;
    }
    return self;
}

- (void) scheduleInRunLoop:(NSRunLoop*)runLoop forMode:(NSString*)mode {
    [_stream scheduleInRunLoop:runLoop forMode:mode];
    /*if([_stream hasBytesAvailable]) {
        CFRunLoopPerformBlock(runLoop.getCFRunLoop, (CFStringRef)mode, ^{
            [self stream:_stream handleEvent:NSStreamEventHasBytesAvailable];
        });
    }*/
}

- (void) run {
    NSObject* state = nil;
    NSData* docData;
    while(_stream.streamStatus != NSStreamStatusAtEnd) {
        docData = [_serialization extractNextDocumentFromStream:_stream format:_format state:&state maxDocumentLength:self.maxObjectSize startDepth:self.startDepth];
        if(docData) {
            [self.delegate stream:_stream containsDocumentWithData:docData];
        }
    }
    do {
        docData = [_serialization extractNextDocumentFromStream:nil format:_format state:&state maxDocumentLength:self.maxObjectSize startDepth:self.startDepth];
        if(docData) {
            [self.delegate stream:_stream containsDocumentWithData:docData];
        }
    } while (docData);
    if([(id)self.delegate respondsToSelector:@selector(endOfStream:)]) {
        [self.delegate endOfStream:_stream];
    }
}

#pragma mark - Private methods

- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode {
    switch(eventCode) {
        case NSStreamEventHasBytesAvailable:
            while(((NSInputStream*)stream).hasBytesAvailable) {
                NSObject* state = _state;
                NSData* docData = [_serialization extractNextDocumentFromStream:(NSInputStream*)stream format:_format state:&state maxDocumentLength:self.maxObjectSize startDepth:self.startDepth];
                if(_state != state) _state = state;
                if(docData) {
                    [self.delegate stream:stream containsDocumentWithData:docData];
                }
                if(stream.streamStatus == NSStreamStatusAtEnd) {
                    docData = [_serialization extractNextDocumentFromStream:nil format:_format state:&state maxDocumentLength:self.maxObjectSize startDepth:self.startDepth];
                    if(_state != state) _state = state;
                    if(docData) {
                        [self.delegate stream:stream containsDocumentWithData:docData];
                    }
                    if([(id)self.delegate respondsToSelector:@selector(endOfStream:)]) {
                        [self.delegate endOfStream:stream];
                    }
                }
            }
            break;
        case NSStreamEventEndEncountered:
            break;
        default:
            break;
    }
}
@end
