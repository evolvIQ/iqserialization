//
//  MyTestClass.h
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


@interface MyInnerClass : NSObject
@property (nonatomic, retain) NSString* innerString;
@property (nonatomic) BOOL innerBool;
@property (nonatomic) int innerInt;
@end

@interface MyTestClass : NSObject
@property (nonatomic, retain) NSString* stringProperty;
@property (nonatomic, retain) MyInnerClass* innerObject;
@property (nonatomic) int intProperty;
@end

#if !defined(__MAC_10_10) && !defined(__IPHONE_8_0)
@interface NSString (Contains)
- (BOOL)containsString:(NSString*)other;
@end
#endif