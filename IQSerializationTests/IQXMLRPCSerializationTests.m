//
//  IQXMLRPCSerializationTests.m
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
#import <XCTest/XCTest.h>

@interface IQXMLRPCSerializationTests : XCTestCase

@end

@implementation IQXMLRPCSerializationTests


- (void)testBadXMLRPCInput
{
    NSString* xml = @"<?xml";
    IQSerialization* ser = [IQSerialization new];
    NSDictionary* dict = [ser dictionaryFromString:xml format:IQSerializationFormatXMLRPC];
    XCTAssertNil(dict, @"Should fail");
    XCTAssertEqualObjects(ser.error.domain, NSXMLParserErrorDomain, @"Error domain should be NSXMLParserErrorDomain");
    
    xml = @"<xml/>";
    dict = [ser dictionaryFromString:xml format:IQSerializationFormatXMLRPC];
    XCTAssertNil(dict, @"Should fail");
    XCTAssertEqualObjects(ser.error.domain, IQSerializationErrorDomain, @"Error domain should be IQSerializationErrorDomain");
}

- (void)testXMLRPCParseParams
{
    NSString* xmlrpc = @"<params><param><value><struct><member><name>a</name><value><int>3</int></value></member><member><name>x</name><value><array><data><value><int>1</int></value><value><double>3.14</double></value><value><boolean>1</boolean></value><value><nil/></value></data></array></value></member><member><name>b</name><value><nil/></value></member><member><name>c</name><value><dateTime.iso8601>20121001T12:34:00</dateTime.iso8601></value></member></struct></value></param></params>";
    IQSerialization* ser = [IQSerialization new];
    NSArray* params = [ser arrayFromString:xmlrpc format:IQSerializationFormatXMLRPC];
    XCTAssertNotNil(params, @"Failed to parse: %@", ser.error);
    XCTAssertEqualObjects(params[0][@"a"], @3, @"Wrong value for 'a'");
    XCTAssertNil((id)params[0][@"b"], @"Wrong value for 'b'");
    XCTAssertEqualObjects([params[0][@"c"] description], @"2012-10-01 12:34:00 +0000", @"Wrong value for 'b'");
    XCTAssertEqualObjects(params[0][@"x"][0], @1, @"Wrong value for 'x[0]'");
    XCTAssertEqualObjects(params[0][@"x"][1], @3.14, @"Wrong value for 'x[1]'");
    XCTAssertEqualObjects(params[0][@"x"][2], @YES, @"Wrong value for 'x[2]'");
}

- (void)testXMLRPCParseMultipleParams
{
    NSString* xmlrpc = @"<params><param><value><int>42</int></value></param><param><value><int>1</int></value></param></params>";
    IQSerialization* ser = [IQSerialization new];
    id params = [ser arrayFromString:xmlrpc format:IQSerializationFormatXMLRPC];
    id expected = @[@42, @1];

    XCTAssertNotNil(params, @"Failed to parse: %@", ser.error);

    XCTAssertEqualObjects(params, expected);
}

- (void)testXMLRPCParseMethodResponse
{
    NSString* xmlrpc = @"<?xml version=\"1.0\"?><methodResponse><params><param><value><string>South Dakota</string></value></param></params></methodResponse>";
    IQSerialization* ser = [IQSerialization new];
    id response = [ser dictionaryFromString:xmlrpc format:IQSerializationFormatXMLRPC];
    XCTAssertNotNil(response, @"Failed to parse: %@", ser.error);
    XCTAssertEqualObjects(response, @{@"response" : @[ @"South Dakota" ]});
}

- (void)testXMLRPCParseFault
{
    NSString* xmlrpc = @"<?xml version=\"1.0\"?><methodResponse><fault><value><struct><member><name>faultCode</name><value><int>4</int></value></member><member><name>faultString</name><value><string>Too many parameters.</string></value></member></struct></value></fault></methodResponse>";
    IQSerialization* ser = [IQSerialization new];
    id response = [ser dictionaryFromString:xmlrpc format:IQSerializationFormatXMLRPC];
    XCTAssertNotNil(response, @"Failed to parse: %@", ser.error);
    id fault = @{@"faultCode" : @4, @"faultString" : @"Too many parameters."};
    XCTAssertEqualObjects(response, @{@"fault" : fault});
}

- (void)testXMLRPCParseMethodCall
{
    NSString* xmlrpc = @"<?xml version=\"1.0\"?><methodCall><methodName>examples.getStateName</methodName><params><param><value><i4>40</i4></value></param></params></methodCall>";
    IQSerialization* ser = [IQSerialization new];
    id request = [ser dictionaryFromString:xmlrpc format:IQSerializationFormatXMLRPC];
    id expected = @{
                    @"params" : @[ @40 ],
                    @"methodName" : @"examples.getStateName"
                    };
    XCTAssertNotNil(request, @"Failed to parse: %@", ser.error);
    XCTAssertEqualObjects(request, expected);
}

- (void)testXMLRPCParseIgnoredNulls {
    NSString* xmlrpc = @"<params><param><value><int>42</int></value></param><param><value><nil/></value></param></params>";
    IQSerialization* ser = [IQSerialization new];
    id dict = [ser arrayFromString:xmlrpc format:IQSerializationFormatXMLRPC];
    XCTAssertNotNil(dict, @"Failed to parse: %@", ser.error);

    XCTAssertEqualObjects(dict, @[ @42 ]);
}

- (void)testXMLRPCParseExplicitNulls {
    NSString* xmlrpc = @"<params><param><value><int>42</int></value></param><param><value><nil/></value></param></params>";
    IQSerialization* ser = [IQSerialization new];
    ser.ignoreNilValues = NO;
    id dict = [ser arrayFromString:xmlrpc format:IQSerializationFormatXMLRPC];
    XCTAssertNotNil(dict, @"Failed to parse: %@", ser.error);

    id expected = @[ @42, [NSNull null] ];
    XCTAssertEqualObjects(dict, expected);
}

- (void)testXMLRPCParseEmptyString1 {
    NSString* xmlrpc = @"<params><param><value><string></string></value></param></params>";
    IQSerialization* ser = [IQSerialization new];
    ser.ignoreNilValues = NO;
    id dict = [ser arrayFromString:xmlrpc format:IQSerializationFormatXMLRPC];
    XCTAssertNotNil(dict, @"Failed to parse: %@", ser.error);

    id expected = @[ @"" ];
    XCTAssertEqualObjects(dict, expected);
}

- (void)testXMLRPCParseEmptyString2 {
    NSString* xmlrpc = @"<params><param><value><string/></value></param></params>";
    IQSerialization* ser = [IQSerialization new];
    ser.ignoreNilValues = NO;
    id dict = [ser arrayFromString:xmlrpc format:IQSerializationFormatXMLRPC];
    XCTAssertNotNil(dict, @"Failed to parse: %@", ser.error);

    id expected = @[ @"" ];
    XCTAssertEqualObjects(dict, expected);
}

- (void)testXMLRPCParseEmptyString3 {
    NSString* xmlrpc = @"<params><param><value></value></param></params>";
    IQSerialization* ser = [IQSerialization new];
    ser.ignoreNilValues = NO;
    id dict = [ser arrayFromString:xmlrpc format:IQSerializationFormatXMLRPC];
    XCTAssertNotNil(dict, @"Failed to parse: %@", ser.error);

    id expected = @[ @"" ];
    XCTAssertEqualObjects(dict, expected);
}

- (void)testXMLRPCParseEmptyData {
    NSString* xmlrpc = @"<params><param><value><base64></base64></value></param></params>";
    IQSerialization* ser = [IQSerialization new];
    ser.ignoreNilValues = NO;
    id dict = [ser arrayFromString:xmlrpc format:IQSerializationFormatXMLRPC];
    XCTAssertNotNil(dict, @"Failed to parse: %@", ser.error);

    id expected = @[ [NSData dataWithBytes:nil length:0] ];
    XCTAssertEqualObjects(dict, expected);
}

- (void)testXMLRPCParseNil {
    NSString* xmlrpc = @"<params><param><value><nil/></value></param></params>";
    IQSerialization* ser = [IQSerialization new];
    ser.ignoreNilValues = NO;
    id dict = [ser arrayFromString:xmlrpc format:IQSerializationFormatXMLRPC];
    XCTAssertNotNil(dict, @"Failed to parse: %@", ser.error);

    id expected = @[ [NSNull null] ];
    XCTAssertEqualObjects(dict, expected);
}

- (void)testXMLRPCParseNilWithIgnore {
    NSString* xmlrpc = @"<params><param><value><nil/></value></param></params>";
    IQSerialization* ser = [IQSerialization new];
    id dict = [ser arrayFromString:xmlrpc format:IQSerializationFormatXMLRPC];
    XCTAssertNotNil(dict, @"Failed to parse: %@", ser.error);

    id expected = @[ ];
    XCTAssertEqualObjects(dict, expected);
}

- (void)testXMLRPCGenerateAndParse
{
    id params = @[ @42, @"Hello", @{ @"Key" : @1 }];
    IQSerialization* ser = [IQSerialization new];
    NSString* string = [ser stringFromObject:params format:IQSerializationFormatXMLRPC];
    XCTAssertNotNil(string, @"Failed to generate: %@", ser.error);

    id parsed = [ser arrayFromString:string format:IQSerializationFormatXMLRPC];
    XCTAssertEqualObjects(parsed, params, @"Object changed during write/parse cycle");
}

#if !TARGET_OS_IPHONE

- (void)testXMLRPCGenerateParams
{
    id params = @[ @42, @"Hello", @{ @"Key" : @1 }];
    IQSerialization* ser = [IQSerialization new];
    NSString* string = [ser stringFromObject:params format:IQSerializationFormatXMLRPC];
    XCTAssertNotNil(string, @"Failed to generate: %@", ser.error);
    id doc = [[NSXMLDocument alloc] initWithXMLString:string options:0 error:nil];
    XCTAssertNotNil(doc, @"Resulting XML was not wellformed");
    id root = [[[doc children] firstObject] name];
    XCTAssertEqualObjects(root, @"params");
}

- (void)testXMLRPCGenerateStandardDateTime
{
    id params = @[ [NSDate dateWithString:@"2014-05-21 13:36:00 +0200"] ];
    IQSerialization* ser = [IQSerialization new];
    NSString* string = [ser stringFromObject:params format:IQSerializationFormatXMLRPC];
    XCTAssertNotNil(string, @"Failed to generate: %@", ser.error);
    id doc = [[NSXMLDocument alloc] initWithXMLString:string options:0 error:nil];
    XCTAssertNotNil(doc, @"Resulting XML was not wellformed");
    id root = [[doc children] firstObject];
    id value = [[[[[[[[[root children] firstObject] children] firstObject] children] firstObject] children] firstObject] stringValue];
    XCTAssertEqualObjects(value, @"20140521T11:36:00");
}

- (void)testXMLRPCGenerateLocalDateTime
{
    id params = @[ [NSDate dateWithString:@"2014-05-21 13:36:00 +0200"] ];
    IQSerialization* ser = [IQSerialization new];
    ser.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"CET"];
    NSString* string = [ser stringFromObject:params format:IQSerializationFormatXMLRPC];
    XCTAssertNotNil(string, @"Failed to generate: %@", ser.error);
    id doc = [[NSXMLDocument alloc] initWithXMLString:string options:0 error:nil];
    XCTAssertNotNil(doc, @"Resulting XML was not wellformed");
    id root = [[doc children] firstObject];
    id value = [[[[[[[[[root children] firstObject] children] firstObject] children] firstObject] children] firstObject] stringValue];
    XCTAssertEqualObjects(value, @"20140521T13:36:00");
}

- (void)testXMLRPCGenerateTZExtendedDateTime
{
    id params = @[ [NSDate dateWithString:@"2014-05-21 13:36:00 +0200"] ];
    IQSerialization* ser = [IQSerialization new];
    ser.forceWriteTimezone = YES;
    NSString* string = [ser stringFromObject:params format:IQSerializationFormatXMLRPC];
    XCTAssertNotNil(string, @"Failed to generate: %@", ser.error);
    id doc = [[NSXMLDocument alloc] initWithXMLString:string options:0 error:nil];
    XCTAssertNotNil(doc, @"Resulting XML was not wellformed");
    id root = [[doc children] firstObject];
    id value = [[[[[[[[[root children] firstObject] children] firstObject] children] firstObject] children] firstObject] stringValue];
    XCTAssertEqualObjects(value, @"20140521T11:36:00+0000");
}

- (void)testXMLRPCGenerateTZExtendedLocalDateTime
{
    id params = @[ [NSDate dateWithString:@"2014-05-21 13:36:00 +0200"] ];
    IQSerialization* ser = [IQSerialization new];
    ser.forceWriteTimezone = YES;
    ser.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"CET"];
    NSString* string = [ser stringFromObject:params format:IQSerializationFormatXMLRPC];
    XCTAssertNotNil(string, @"Failed to generate: %@", ser.error);
    id doc = [[NSXMLDocument alloc] initWithXMLString:string options:0 error:nil];
    XCTAssertNotNil(doc, @"Resulting XML was not wellformed");
    id root = [[doc children] firstObject];
    id value = [[[[[[[[[root children] firstObject] children] firstObject] children] firstObject] children] firstObject] stringValue];
    XCTAssertEqualObjects(value, @"20140521T13:36:00+0200");
}

- (void)testXMLRPCGenerateIgnoredNulls {
    id object = @[ @42, [NSNull null] ];
    IQSerialization* ser = [IQSerialization new];
    NSString* xmlrpc = [ser stringFromObject:object format:IQSerializationFormatXMLRPC];
    XCTAssertNotNil(object, @"Failed to generate: %@", ser.error);
    id doc = [[NSXMLDocument alloc] initWithXMLString:xmlrpc options:0 error:nil];
    NSXMLElement* root = (NSXMLElement*)[[doc children] firstObject];
    XCTAssertEqual(root.childCount, 1);
}

- (void)testXMLRPCGenerateExplicitNulls {
    id object = @[ @42, [NSNull null] ];
    IQSerialization* ser = [IQSerialization new];
    ser.ignoreNilValues = NO;
    NSString* xmlrpc = [ser stringFromObject:object format:IQSerializationFormatXMLRPC];
    XCTAssertNotNil(object, @"Failed to generate: %@", ser.error);
    id doc = [[NSXMLDocument alloc] initWithXMLString:xmlrpc options:0 error:nil];
    NSXMLElement* root = (NSXMLElement*)[[doc children] firstObject];
    XCTAssertEqual(root.childCount, 2);
}

#endif
@end
