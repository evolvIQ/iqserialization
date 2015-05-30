//
//  IQStreamObjecTokenizerTests.m
//  IQSerialization
//
//  Created by Rickard Lyrenius on 30/05/15.
//  Copyright (c) 2015 EvolvIQ. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>
#import <IQSerialization/IQStreamObjectTokenizer.h>

#define STREAM(x) [NSInputStream inputStreamWithData:[(x) dataUsingEncoding:NSUTF8StringEncoding]];

@interface TokenizerTests : XCTestCase <IQStreamObjectDelegate> {
    NSMutableArray* array;
    BOOL eos;
}

@end

@implementation TokenizerTests

- (void)setUp {
    [super setUp];
    array = [NSMutableArray new];
    eos = NO;
}

- (void)tearDown {
    array = nil;
    [super tearDown];
}

- (void)stream:(NSStream *)stream containsDocumentWithData:(NSData *)data {
    [array addObject:data];
}

- (void)endOfStream:(NSStream *)stream {
    eos = YES;
}

- (void)waitForEndOfStream {
    while(!eos) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
    }
}

- (void)testSplitSingleXmlRpcDocument {
    NSString* xmlrpcpacket = @"<params><param><value><struct><member><name>a</name><value><int>3</int></value></member><member><name>x</name><value><array><data><value><int>1</int></value><value><double>3.14</double></value><value><boolean>1</boolean></value><value><nil/></value></data></array></value></member><member><name>b</name><value><nil/></value></member><member><name>c</name><value><dateTime.iso8601>20121001T12:34:00</dateTime.iso8601></value></member></struct></value></param></params>";
    NSInputStream* testData = STREAM(xmlrpcpacket);
    [testData open];
    XCTAssertTrue(testData.hasBytesAvailable);
    IQSerialization* serialization = [IQSerialization new];
    IQStreamObjectTokenizer* tokenizer = [[IQStreamObjectTokenizer alloc] initWithStream:testData serialization:serialization format:IQSerializationFormatXMLRPC];
    tokenizer.delegate = self;
    [tokenizer run];
    XCTAssertEqual(array.count, 1, @"Expected 1 document, found %d", (int)array.count);
    XCTAssertEqualObjects([[NSString alloc] initWithData:array[0] encoding:NSUTF8StringEncoding], xmlrpcpacket);
}

- (void)testTwoXmlDocuments {
    NSInputStream* testData = STREAM(@"<root></root><root2/>");
    [testData open];
    XCTAssertTrue(testData.hasBytesAvailable);
    IQSerialization* serialization = [IQSerialization new];
    IQStreamObjectTokenizer* tokenizer = [[IQStreamObjectTokenizer alloc] initWithStream:testData serialization:serialization format:IQSerializationFormatSimpleXML];
    tokenizer.delegate = self;
    [tokenizer run];
    XCTAssertEqual(array.count, 2, @"Expected 2 documents, found %d", (int)array.count);
    XCTAssertEqualObjects([[NSString alloc] initWithData:array[0] encoding:NSUTF8StringEncoding], @"<root></root>");
    XCTAssertEqualObjects([[NSString alloc] initWithData:array[1] encoding:NSUTF8StringEncoding], @"<root2/>");
}

- (void)testSplitTwoXmlRpcDocuments {
    NSString* xmlrpcpacket = @"<params><param><value><struct><member><name>a</name><value><int>3</int></value></member><member><name>x</name><value><array><data><value><int>1</int></value><value><double>3.14</double></value><value><boolean>1</boolean></value><value><nil/></value></data></array></value></member><member><name>b</name><value><nil/></value></member><member><name>c</name><value><dateTime.iso8601>20121001T12:34:00</dateTime.iso8601></value></member></struct></value></param></params>";
    NSInputStream* testData = STREAM([xmlrpcpacket stringByAppendingString:xmlrpcpacket]);
    [testData open];
    XCTAssertTrue(testData.hasBytesAvailable);
    IQSerialization* serialization = [IQSerialization new];
    IQStreamObjectTokenizer* tokenizer = [[IQStreamObjectTokenizer alloc] initWithStream:testData serialization:serialization format:IQSerializationFormatSimpleXML];
    tokenizer.delegate = self;
    [tokenizer run];
    XCTAssertEqual(array.count, 2, @"Expected 1 document, found %d", (int)array.count);
    XCTAssertEqualObjects([[NSString alloc] initWithData:array[0] encoding:NSUTF8StringEncoding], xmlrpcpacket);
    XCTAssertEqualObjects([[NSString alloc] initWithData:array[1] encoding:NSUTF8StringEncoding], xmlrpcpacket);
}

- (void)testTwoXmlDocumentsWithLeadingComments {
    NSInputStream* testData = STREAM(@"<!-- First document begins here--><root></root><!-- Second document begins here --><root2/>");
    [testData open];
    XCTAssertTrue(testData.hasBytesAvailable);
    IQSerialization* serialization = [IQSerialization new];
    IQStreamObjectTokenizer* tokenizer = [[IQStreamObjectTokenizer alloc] initWithStream:testData serialization:serialization format:IQSerializationFormatSimpleXML];
    tokenizer.delegate = self;
    [tokenizer run];
    XCTAssertEqual(array.count, 2, @"Expected 2 documents, found %d", (int)array.count);
    XCTAssertEqualObjects([[NSString alloc] initWithData:array[0] encoding:NSUTF8StringEncoding], @"<!-- First document begins here--><root></root>");
    XCTAssertEqualObjects([[NSString alloc] initWithData:array[1] encoding:NSUTF8StringEncoding], @"<!-- Second document begins here --><root2/>");
}

- (void)testTwoXmlDocumentsWithWhitespace {
    NSInputStream* testData = STREAM(@"  <root></root>\r\n<root2/>");
    [testData open];
    XCTAssertTrue(testData.hasBytesAvailable);
    IQSerialization* serialization = [IQSerialization new];
    IQStreamObjectTokenizer* tokenizer = [[IQStreamObjectTokenizer alloc] initWithStream:testData serialization:serialization format:IQSerializationFormatSimpleXML];
    tokenizer.delegate = self;
    [tokenizer run];
    XCTAssertEqual(array.count, 2, @"Expected 2 documents, found %d", (int)array.count);
    XCTAssertEqualObjects([[NSString alloc] initWithData:array[0] encoding:NSUTF8StringEncoding], @"<root></root>");
    XCTAssertEqualObjects([[NSString alloc] initWithData:array[1] encoding:NSUTF8StringEncoding], @"<root2/>");
}

- (void)testTwoXmlDocumentsWithAngleBracketComments {
    NSInputStream* testData = STREAM(@"<root><!-- Weird <> comment --></root><root2/>");
    [testData open];
    XCTAssertTrue(testData.hasBytesAvailable);
    IQSerialization* serialization = [IQSerialization new];
    IQStreamObjectTokenizer* tokenizer = [[IQStreamObjectTokenizer alloc] initWithStream:testData serialization:serialization format:IQSerializationFormatSimpleXML];
    tokenizer.delegate = self;
    [tokenizer run];
    XCTAssertEqual(array.count, 2, @"Expected 2 documents, found %d", (int)array.count);
    XCTAssertEqualObjects([[NSString alloc] initWithData:array[0] encoding:NSUTF8StringEncoding], @"<root><!-- Weird <> comment --></root>");
    XCTAssertEqualObjects([[NSString alloc] initWithData:array[1] encoding:NSUTF8StringEncoding], @"<root2/>");
}
- (void)testSplitSingleJsonDocument
{
    NSInputStream* testData = STREAM(@"{\"a\":[true,2,\"3\",[4,1.0,-1,-1.0],[],{}]}");
    [testData open];
    XCTAssertTrue(testData.hasBytesAvailable);
    IQSerialization* serialization = [IQSerialization new];
    IQStreamObjectTokenizer* tokenizer = [[IQStreamObjectTokenizer alloc] initWithStream:testData serialization:serialization format:IQSerializationFormatJSON];
    tokenizer.delegate = self;
    [tokenizer run];
    XCTAssertEqual(array.count, 1, @"Expected 1 document, found %d", (int)array.count);
    XCTAssertEqualObjects([[NSString alloc] initWithData:array[0] encoding:NSUTF8StringEncoding], @"{\"a\":[true,2,\"3\",[4,1.0,-1,-1.0],[],{}]}");
}
- (void)testSplitTwoJsonDocuments
{
    NSInputStream* testData = STREAM(@"{\"a\":3}{\"b\":3}");
    [testData open];
    XCTAssertTrue(testData.hasBytesAvailable);
    IQSerialization* serialization = [IQSerialization new];
    IQStreamObjectTokenizer* tokenizer = [[IQStreamObjectTokenizer alloc] initWithStream:testData serialization:serialization format:IQSerializationFormatJSON];
    tokenizer.delegate = self;
    [tokenizer run];
    XCTAssertEqual(array.count, 2, @"Expected 2 documents, found %d", (int)array.count);
    XCTAssertEqualObjects([[NSString alloc] initWithData:array[0] encoding:NSUTF8StringEncoding], @"{\"a\":3}");
    XCTAssertEqualObjects([[NSString alloc] initWithData:array[1] encoding:NSUTF8StringEncoding], @"{\"b\":3}");
}
- (void)testSplitTwoJsonDocumentsWithEscaped
{
    NSInputStream* testData = STREAM(@"{\"a}\":3}{\"b\\\"}\":3}");
    [testData open];
    XCTAssertTrue(testData.hasBytesAvailable);
    IQSerialization* serialization = [IQSerialization new];
    IQStreamObjectTokenizer* tokenizer = [[IQStreamObjectTokenizer alloc] initWithStream:testData serialization:serialization format:IQSerializationFormatJSON];
    tokenizer.delegate = self;
    [tokenizer run];
    XCTAssertEqual(array.count, 2, @"Expected 2 documents, found %d", (int)array.count);
    XCTAssertEqualObjects([[NSString alloc] initWithData:array[0] encoding:NSUTF8StringEncoding], @"{\"a}\":3}");
    XCTAssertEqualObjects([[NSString alloc] initWithData:array[1] encoding:NSUTF8StringEncoding], @"{\"b\\\"}\":3}");
}
- (void)testSplitTwoJsonDocumentsWithWhitespace
{
    NSInputStream* testData = STREAM(@"  {\"a\":3}  \t{\"b\":3}");
    [testData open];
    XCTAssertTrue(testData.hasBytesAvailable);
    IQSerialization* serialization = [IQSerialization new];
    IQStreamObjectTokenizer* tokenizer = [[IQStreamObjectTokenizer alloc] initWithStream:testData serialization:serialization format:IQSerializationFormatJSON];
    tokenizer.delegate = self;
    [tokenizer run];
    XCTAssertEqual(array.count, 2, @"Expected 2 documents, found %d", (int)array.count);
    XCTAssertEqualObjects([[NSString alloc] initWithData:array[0] encoding:NSUTF8StringEncoding], @"{\"a\":3}");
    XCTAssertEqualObjects([[NSString alloc] initWithData:array[1] encoding:NSUTF8StringEncoding], @"{\"b\":3}");
}
@end
