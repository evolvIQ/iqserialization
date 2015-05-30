//
//  IQSerializationTests.m
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

#import "IQSerialization.h"
#import "MyTestClass.h"
#import <XCTest/XCTest.h>

@interface IQJSONSerializationTests : XCTestCase

@end

@implementation IQJSONSerializationTests

- (void)testParseBadJSONInput
{
    NSString* json = @"}";
    IQSerialization* ser = [IQSerialization new];
    NSDictionary* dict = [ser dictionaryFromString:json format:IQSerializationFormatJSON];
    XCTAssertNil(dict, @"Should fail");
    XCTAssertEqual((int)ser.error.code, 1001, @"Error code should be 1001");
}

- (void)testParseBasicJSON
{
    NSString* json = @"{\"a\":3, \"b\":true, \"c\":false}";
    IQSerialization* ser = [IQSerialization new];
    NSDictionary* dict = [ser dictionaryFromString:json format:IQSerializationFormatJSON];
    XCTAssertNotNil(dict, @"Failed to generate dict: %@", ser.error);
    XCTAssertEqual((int)dict.count, 3, @"Counts should equal");
    XCTAssertEqualObjects(dict[@"a"], [NSNumber numberWithInt:3], @"Object 'a' is not 3");
    XCTAssertEqualObjects(dict[@"b"], [NSNumber numberWithBool:YES], @"Object 'b' is not true");
    XCTAssertEqualObjects(dict[@"c"], [NSNumber numberWithBool:NO], @"Object 'c' is not false");
}

- (void)testParseJSONArrays
{
    NSString* json = @"{\"a\":[1,2,3,[4]]}";
    IQSerialization* ser = [IQSerialization new];
    NSDictionary* dict = [ser dictionaryFromString:json format:IQSerializationFormatJSON];
    XCTAssertNotNil(dict, @"Failed to generate dict: %@", ser.error);
    XCTAssertEqual((int)dict.count, 1, @"Expected one item in parent");
    XCTAssertEqual((int)[[dict objectForKey:@"a"] count], 4, @"Object 'a.length' is not 4");
    XCTAssertEqualObjects([[dict objectForKey:@"a"] objectAtIndex:0], [NSNumber numberWithInt:1], @"Object 'a[0]' is not 1");
    XCTAssertEqualObjects([[[dict objectForKey:@"a"] objectAtIndex:3] objectAtIndex:0], [NSNumber numberWithInt:4], @"Object 'a[3]' is not 4");
}

- (void)testParseJSONTyped
{
    NSString* json = @"{\"stringProperty\":\"Hello World\", \"intProperty\":42, \"innerObject\":{\"innerString\":\"Hello Again\"}}";
    IQSerialization* ser = [IQSerialization new];
    MyTestClass* obj = [[MyTestClass alloc] init];
    if(![ser deserializeObject:obj fromString:json format:IQSerializationFormatJSON]) {
        XCTFail(@"Failed to parse JSON: %@", ser.error);
        return;
    }
    XCTAssertEqualObjects(obj.stringProperty, @"Hello World", @"stringProperty not parsed");
    XCTAssertEqual(obj.intProperty, 42, @"intProperty not parsed");
    XCTAssertEqualObjects(obj.innerObject.class, [MyInnerClass class], @"innerObject is of the wrong type");
    XCTAssertEqualObjects(obj.innerObject.innerString, @"Hello Again", @"innerObject.innerString not parsed");
}

- (void)testParseJSONTypedUnknown
{
    NSString* json = @"{\"stringProperty\":\"Hello World\", \"intProperty\":42, \"unknownProperty\":\"bad\"}";
    IQSerialization* ser = [IQSerialization new];
    MyTestClass* obj = [[MyTestClass alloc] init];
    if([ser deserializeObject:obj fromString:json format:IQSerializationFormatJSON]) {
        XCTFail(@"Parsing this object should have failed");
        return;
    }
    ser.ignoreUnknownProperties = YES;
    obj = [[MyTestClass alloc] init];
    if(![ser deserializeObject:obj fromString:json format:IQSerializationFormatJSON]) {
        XCTFail(@"Failed to parse JSON: %@", ser.error);
        return;
    }
    XCTAssertEqualObjects(obj.stringProperty, @"Hello World", @"stringProperty not parsed");
    XCTAssertEqual(obj.intProperty, 42, @"intProperty not parsed");
}

- (void)testParseJSONIgnoredNulls {
    NSString* json = @"{\"stringProperty\":\"Hello World\", \"nullProperty\":null}";
    IQSerialization* ser = [IQSerialization new];
    id dict = [ser dictionaryFromString:json format:IQSerializationFormatJSON];
    XCTAssertNotNil(dict, @"Failed to parse JSON: %@", ser.error);
    XCTAssertEqualObjects(dict, @{@"stringProperty":@"Hello World"});
}

- (void)testParseJSONExplicitNulls {
    NSString* json = @"{\"stringProperty\":\"Hello World\", \"nullProperty\":null}";
    IQSerialization* ser = [IQSerialization new];
    ser.ignoreNilValues = NO;
    id dict = [ser dictionaryFromString:json format:IQSerializationFormatJSON];
    XCTAssertNotNil(dict, @"Failed to parse JSON: %@", ser.error);
    id expected = @{@"stringProperty":@"Hello World", @"nullProperty":[NSNull null]};
    XCTAssertEqualObjects(dict, expected);
}

- (void)testGenerateJSONFromDict
{
    NSMutableDictionary* dict = [NSMutableDictionary dictionary];
    dict[@"a"] = @"b";
    dict[@"b"] = [NSNumber numberWithBool:YES];
    dict[@"c"] = [NSNumber numberWithBool:NO];
    dict[@"d"] = [NSNumber numberWithInt:1];
    dict[@"e"] = [NSNumber numberWithDouble:1.0];
    NSString* json = [dict JSONRepresentation];
    XCTAssertTrue([json rangeOfString:@"\"a\":\"b\""].length > 0, @"Did not find 'a'");
    XCTAssertTrue([json rangeOfString:@"\"b\":true"].length > 0, @"Did not find 'b'");
    XCTAssertTrue([json rangeOfString:@"\"c\":false"].length > 0, @"Did not find 'c'");
    XCTAssertTrue([json rangeOfString:@"\"d\":1"].length > 0, @"Did not find 'd'");
    XCTAssertTrue([json rangeOfString:@"\"e\":1.0"].length > 0, @"Did not find 'e'");
}

- (void)testGenerateJSONFromArray
{
    NSArray* arr = [NSArray arrayWithObjects:@"b", [NSNumber numberWithBool:YES], [NSNumber numberWithBool:NO],
                    [NSNumber numberWithInt:1], [NSNumber numberWithDouble:1.0], nil];
    NSString* json = [arr JSONRepresentation];
    XCTAssertEqualObjects(json, @"[\"b\",true,false,1,1.0]", @"Did not find array in output");
}

- (void)testGenerateTypedJSON
{
    MyTestClass* obj = [[MyTestClass alloc] init];
    obj.stringProperty = @"Hello";
    NSString* json = [obj JSONRepresentation];
    XCTAssertTrue([json rangeOfString:@"\"intProperty\":0"].length > 0, @"Did not find intProperty in JSON");
    XCTAssertTrue([json rangeOfString:@"\"stringProperty\":\"Hello\""].length > 0, @"Did not find stringProperty in JSON");
    IQSerialization* ser = [IQSerialization new];
    ser.ignoreNilValues = NO;
    json = [ser stringFromObject:obj format:IQSerializationFormatJSON];
    XCTAssertTrue([json rangeOfString:@"\"innerObject\":null"].length > 0, @"Did not find innerObject in JSON");
}

- (void)testGenerateJSONIgnoredNulls {
    id object = @{@"stringProperty":@"Hello World", @"nullProperty":[NSNull null]};
    IQSerialization* ser = [IQSerialization new];

    NSString* json = [ser stringFromObject:object format:IQSerializationFormatJSON];
    XCTAssertNotNil(json, @"Failed to generate JSON: %@", ser.error);

    XCTAssertTrue([json containsString:@"stringProperty"], @"stringProperty missing");
    XCTAssertTrue(![json containsString:@"nullProperty"], @"nullProperty should be removed but it is not");
}

- (void)testGenerateJSONExplicitNulls {
    id object = @{@"stringProperty":@"Hello World", @"nullProperty":[NSNull null]};
    IQSerialization* ser = [IQSerialization new];
    ser.ignoreNilValues = NO;

    NSString* json = [ser stringFromObject:object format:IQSerializationFormatJSON];
    XCTAssertNotNil(json, @"Failed to generate JSON: %@", ser.error);

    XCTAssertTrue([json containsString:@"stringProperty"], @"stringProperty missing");
    XCTAssertTrue([json containsString:@"nullProperty"], @"nullProperty missing");}

- (void)testParseAndGenerateJSON
{
    NSString* json = @"{\"a\":[true,2,\"3\",[4,1.0,-1,-1.0],[],{}]}";
    IQSerialization* ser = [IQSerialization new];
    NSDictionary* dict = [ser dictionaryFromString:json format:IQSerializationFormatJSON];
    XCTAssertNotNil(dict, @"Failed to generate dict: %@", ser.error);
    XCTAssertEqualObjects([[dict.description stringByReplacingOccurrencesOfString:@" " withString:@""] stringByReplacingOccurrencesOfString:@"\n" withString:@""]
                         , @"{a=(1,2,3,(4,1,\"-1\",\"-1\"),(),{});}", @"Unexpected parse result");
    NSString* outJson = [dict JSONRepresentation];
    XCTAssertEqualObjects(json, outJson, @"Generated JSON did not matched parsed JSON");
}

@end
