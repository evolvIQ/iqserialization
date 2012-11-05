//
//  IQXMLRPCSerializationTests.m
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

#import "IQSerialization.h"
#import <SenTestingKit/SenTestingKit.h>

@interface IQXMLRPCSerializationTests : SenTestCase

@end

@implementation IQXMLRPCSerializationTests


- (void)testBadXMLRPCInput
{
    NSString* xml = @"<?xml";
    IQSerialization* ser = [IQSerialization new];
    NSDictionary* dict = [ser dictionaryFromString:xml format:IQSerializationFormatXMLRPC];
    STAssertNil(dict, @"Should fail");
    STAssertEqualObjects(ser.error.domain, NSXMLParserErrorDomain, @"Error domain should be NSXMLParserErrorDomain");
    
    xml = @"<xml/>";
    dict = [ser dictionaryFromString:xml format:IQSerializationFormatXMLRPC];
    STAssertNil(dict, @"Should fail");
    STAssertEqualObjects(ser.error.domain, IQSerializationErrorDomain, @"Error domain should be IQSerializationErrorDomain");
}

- (void)testXMLRPCParseParams
{
    NSString* xmlrpc = @"<params><param><value><struct><member><name>a</name><value><int>3</int></value></member><member><name>x</name><value><array><data><value><int>1</int></value><value><double>3.14</double></value><value><boolean>1</boolean></value><value><nil/></value></data></array></value></member><member><name>b</name><value><nil/></value></member><member><name>c</name><value><dateTime.iso8601>20121001T12:34:00</dateTime.iso8601></value></member></struct></value></param></params>";
    IQSerialization* ser = [IQSerialization new];
    ser.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
    NSArray* params = [ser arrayFromString:xmlrpc format:IQSerializationFormatXMLRPC];
    STAssertNotNil(params, @"Failed to parse: %@", ser.error);
    STAssertEqualObjects(params[0][@"a"], [NSNumber numberWithInt:3], @"Wrong value for 'a'");
    STAssertNil((id)params[0][@"b"], @"Wrong value for 'b'");
    STAssertEqualObjects([params[0][@"c"] description], @"2012-10-01 12:34:00 +0000", @"Wrong value for 'b'");
    STAssertEqualObjects(params[0][@"x"][0], [NSNumber numberWithInt:1], @"Wrong value for 'x[0]'");
    STAssertEqualObjects(params[0][@"x"][1], [NSNumber numberWithDouble:3.14], @"Wrong value for 'x[1]'");
    STAssertEqualObjects(params[0][@"x"][2], [NSNumber numberWithBool:YES], @"Wrong value for 'x[2]'");
    NSLog(@"params is %@", params);
}
@end
