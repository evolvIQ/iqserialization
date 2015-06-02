//
//  IQSerialization.h
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

#import <Foundation/Foundation.h>

#import "IQSerialization.h"

@protocol IQStreamObjectDelegate
@required
- (void) stream:(NSStream*)stream containsDocumentWithData:(NSData*)data;
@optional
- (void) endOfStream:(NSStream*)stream;
@end

@interface IQStreamObjectTokenizer : NSObject
- (id) initWithStream:(NSInputStream*)stream serialization:(IQSerialization*)serialization format:(IQSerializationFormat)format;
- (void) scheduleInRunLoop:(NSRunLoop*)runLoop forMode:(NSString*)mode;
- (void) run;

@property (nonatomic) id<IQStreamObjectDelegate> delegate;
@property (nonatomic) NSUInteger maxObjectSize;
@property (nonatomic) NSUInteger startDepth;
@end
