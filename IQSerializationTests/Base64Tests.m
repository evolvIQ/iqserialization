//
//  Base64Tests.m
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

#import <SenTestingKit/SenTestingKit.h>
#import "IQSerialization+Base64.h"

@interface Base64Tests : SenTestCase

@end

@implementation Base64Tests

- (void) testBase64StringEncoding
{
    const char dataToEncode[] = "SomeData\0\xff\x03\x08\xfe";
    for(int i=0; i<sizeof(dataToEncode); i++) {
        NSData* data = [NSData dataWithBytes:dataToEncode length:i];
        NSString* string = [data base64String];
        STAssertNotNil(string, @"Failed to encode data");
        if(i == 3) {
            STAssertEqualObjects(string, @"U29t", @"Invalid Base64 encode");
        }
        if(i == sizeof(dataToEncode)-1) {
            STAssertEqualObjects(string, @"U29tZURhdGEA/wMI/g==", @"Invalid Base64 encode");
        }
        NSData* decData = [NSData dataWithBase64String:string];
        STAssertNotNil(decData, @"Failed to decode string");
        STAssertEquals((int)decData.length, i, @"Decoded data from %@ is of the wrong length", string);
        if(i!=decData.length) break;
        STAssertEqualObjects(decData, data, @"Invalid Base64 decode of encode");
        
        NSUInteger origLength = string.length;
        string = [string stringByReplacingOccurrencesOfString:@"=" withString:@""];
        if(string.length != origLength) {
            NSData* decDataNoPad = [NSData dataWithBase64String:string];
            STAssertNotNil(decDataNoPad, @"Failed to decode string with missing padding (%d)", i);
            if(decDataNoPad) {
                STAssertEqualObjects(decDataNoPad, data, @"Invalid Base64 decode of encode");
            }
        }
    }
}

- (void) testBase64DataEncoding
{
    char dataToEncode[192];
    srand(123182);
    for(int i=0; i<sizeof(dataToEncode); i++) {
        dataToEncode[i] = (char)rand();
    }
    for(int i=0; i<sizeof(dataToEncode); i++) {
        NSData* data = [NSData dataWithBytes:dataToEncode length:i];
        NSData* encData = [data base64Data];
        STAssertNotNil(encData, @"Failed to encode data in iteration %d", i);
        if(!encData) break;
        NSData* decData = [NSData dataWithBase64Data:encData];
        STAssertNotNil(decData, @"Failed to decode data in iteration %d", i);
        STAssertEquals((int)decData.length, i, @"Decoded data is of the wrong length");
        if(i!=decData.length) break;
        if(!decData) {
            NSLog(@"Data: %@", [[NSString alloc] initWithData:encData encoding:NSASCIIStringEncoding]);
            break;
        }
        STAssertEqualObjects(decData, data, @"Invalid Base64 decode of encode");
    }
}

@end
