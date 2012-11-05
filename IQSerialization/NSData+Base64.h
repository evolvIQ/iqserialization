//
//  NSData+Base64.h
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

/**
 A reasonably fast Base64 encoder/decoder implementation operating on Foundation
 data types.
 
 Inspired by a number of projects, including http://libb64.cvs.sourceforge.net, 
 http://migbase64.sourceforge.net.
 */
@interface NSData (Base64Encoding)
/**
 Decodes a Base64-encoded string into a NSData object.
 
 Returns nil if the input is invalid.
 */
+ (NSData*)dataWithBase64String:(NSString*)string;
/**
 Decodes a Base64-encoded NSData object into a NSData object.
 
 Returns nil if the input is invalid.
 */
+ (NSData*)dataWithBase64Data:(NSData*)data;
/**
 Encodes a NSData object into a Base64 string.
 */
- (NSString*)base64String;
/**
 Encodes a NSData object into Base64.
 */
- (NSData*)base64Data;
@end

