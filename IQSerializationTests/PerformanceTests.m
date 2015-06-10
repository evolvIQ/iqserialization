//
//  PerformanceTests.m
//  IQSerialization
//
//  Created by Rickard Lyrenius on 29/05/15.
//  Copyright (c) 2015 EvolvIQ. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NSData+Base64.h"

@interface PerformanceTests : XCTestCase

@end

@implementation PerformanceTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testBase64EncodingPerformance {
    char chunk[1023];
    srand(42);
    for(int i=0; i<sizeof(chunk); ++i) {
        chunk[i] = rand() & 0xFF;
    }
    NSMutableData* data = [NSMutableData dataWithCapacity:1024 * sizeof(chunk)];
    for(int i=0; i<1024; ++i) {
        [data appendBytes:chunk length:sizeof(chunk)];
    }

    // Encode the block
    [self measureBlock:^{
        for(int i=0; i<20; i++) {
            NSData *outData;
            @autoreleasepool {
                outData = [data base64Data];
            }
            XCTAssertNotNil(outData, @"Base64 encoding failed");
        }
    }];
}

- (void)testBase64DecodingPerformance {
    char chunk[1023];
    srand(42);
    for(int i=0; i<sizeof(chunk); ++i) {
        chunk[i] = rand() & 0xFF;
    }
    NSMutableData* data = [NSMutableData dataWithCapacity:1024 * sizeof(chunk)];
    for(int i=0; i<1024; ++i) {
        [data appendBytes:chunk length:sizeof(chunk)];
    }

    NSData *outData = [data base64Data];
    XCTAssertNotNil(outData, @"Base64 encoding failed");

    __block NSData* decodedData;
    // Decode the block
    [self measureBlock:^{
        for(int i=0; i<20; i++) {
            @autoreleasepool {
                decodedData = [NSData dataWithBase64Data:outData];
            }
            XCTAssertNotNil(outData, @"Base64 decoding failed");
        }
    }];

    XCTAssertEqualObjects(data, decodedData);
}

@end
