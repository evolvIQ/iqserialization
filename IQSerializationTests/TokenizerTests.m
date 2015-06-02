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

- (void)testSplitTwoSimpleXmlDocuments {
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
    XCTAssertEqual(array.count, 2, @"Expected 2 documents, found %d", (int)array.count);
    XCTAssertEqualObjects([[NSString alloc] initWithData:array[0] encoding:NSUTF8StringEncoding], xmlrpcpacket);
    XCTAssertEqualObjects([[NSString alloc] initWithData:array[1] encoding:NSUTF8StringEncoding], xmlrpcpacket);
}

- (void)testSplitHugeXmlRpcDocumentSet {
    NSString* xmlrpcpacket = @"<params><param><value><struct><member><name>a</name><value><int>3</int></value></member><member><name>x</name><value><array><data><value><int>1</int></value><value><double>3.14</double></value><value><boolean>1</boolean></value><value><nil/></value></data></array></value></member><member><name>b</name><value><nil/></value></member><member><name>c</name><value><dateTime.iso8601>20121001T12:34:00</dateTime.iso8601></value></member></struct></value></param></params>";
    NSString* concat = [xmlrpcpacket stringByAppendingString:@"  "];
    const int COUNT_EXP2 = 18;
    for(int i=0; i < COUNT_EXP2; ++i)
        concat = [concat stringByAppendingString:concat];
    NSInputStream* testData = STREAM(concat);
    [testData open];
    XCTAssertTrue(testData.hasBytesAvailable);
    [self measureBlock:^{
        IQSerialization* serialization = [IQSerialization new];
        IQStreamObjectTokenizer* tokenizer = [[IQStreamObjectTokenizer alloc] initWithStream:testData serialization:serialization format:IQSerializationFormatSimpleXML];
        tokenizer.delegate = self;
        [tokenizer run];
    }];
    XCTAssertEqual(array.count, 1<<COUNT_EXP2, @"Expected %d documents, found %d", 1<<COUNT_EXP2, (int)array.count);
    for(NSData* elem in array) {
        XCTAssertEqualObjects([[NSString alloc] initWithData:elem encoding:NSUTF8StringEncoding], xmlrpcpacket);
    }
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

- (void)testXmlDocumentsWithStartDepth {
    NSInputStream* testData = STREAM(@"  <logfile>  <logent val=\"x\"></logent>\r\n<logent val=\"y\"></logent><logent val=\"z\"></logent>");
    [testData open];
    XCTAssertTrue(testData.hasBytesAvailable);
    IQSerialization* serialization = [IQSerialization new];
    IQStreamObjectTokenizer* tokenizer = [[IQStreamObjectTokenizer alloc] initWithStream:testData serialization:serialization format:IQSerializationFormatSimpleXML];
    tokenizer.startDepth = 1;
    tokenizer.delegate = self;
    [tokenizer run];
    XCTAssertEqual(array.count, 3, @"Expected 3 documents, found %d", (int)array.count);
    XCTAssertEqualObjects([[NSString alloc] initWithData:array[0] encoding:NSUTF8StringEncoding], @"<logent val=\"x\"></logent>");
    XCTAssertEqualObjects([[NSString alloc] initWithData:array[1] encoding:NSUTF8StringEncoding], @"<logent val=\"y\"></logent>");
    XCTAssertEqualObjects([[NSString alloc] initWithData:array[2] encoding:NSUTF8StringEncoding], @"<logent val=\"z\"></logent>");
}

- (void)testXmlDocumentsWithStartDepthMinimalBuffer {
    NSInputStream* testData = STREAM(@"  <logfile>  <logent val=\"x\"></logent>\r\n<logent val=\"y\"></logent><logent val=\"z\"></logent>");
    [testData open];
    XCTAssertTrue(testData.hasBytesAvailable);
    IQSerialization* serialization = [IQSerialization new];
    serialization.readBufferSize = 1;
    IQStreamObjectTokenizer* tokenizer = [[IQStreamObjectTokenizer alloc] initWithStream:testData serialization:serialization format:IQSerializationFormatSimpleXML];
    tokenizer.startDepth = 1;
    tokenizer.delegate = self;
    [tokenizer run];
    XCTAssertEqual(array.count, 3, @"Expected 3 documents, found %d", (int)array.count);
    XCTAssertEqualObjects([[NSString alloc] initWithData:array[0] encoding:NSUTF8StringEncoding], @"<logent val=\"x\"></logent>");
    XCTAssertEqualObjects([[NSString alloc] initWithData:array[1] encoding:NSUTF8StringEncoding], @"<logent val=\"y\"></logent>");
    XCTAssertEqualObjects([[NSString alloc] initWithData:array[2] encoding:NSUTF8StringEncoding], @"<logent val=\"z\"></logent>");
}

- (void)testTwoXmlDocumentsWithDoctype {
    NSInputStream* testData = STREAM(@"<!doctype misc><root></root>\r\n<!doctype misc><root2/>");
    [testData open];
    XCTAssertTrue(testData.hasBytesAvailable);
    IQSerialization* serialization = [IQSerialization new];
    IQStreamObjectTokenizer* tokenizer = [[IQStreamObjectTokenizer alloc] initWithStream:testData serialization:serialization format:IQSerializationFormatSimpleXML];
    tokenizer.delegate = self;
    [tokenizer run];
    XCTAssertEqual(array.count, 2, @"Expected 2 documents, found %d", (int)array.count);
    XCTAssertEqualObjects([[NSString alloc] initWithData:array[0] encoding:NSUTF8StringEncoding], @"<!doctype misc><root></root>");
    XCTAssertEqualObjects([[NSString alloc] initWithData:array[1] encoding:NSUTF8StringEncoding], @"<!doctype misc><root2/>");
}

- (void)testTwoXmlDocumentsWithDoctypeElement {
    NSInputStream* testData = STREAM(@"<root/><!DOCTYPE doc SYSTEM \"001.ent\" [\n<!ELEMENT doc EMPTY>/n]>\n<doc></doc>");
    [testData open];
    XCTAssertTrue(testData.hasBytesAvailable);
    IQSerialization* serialization = [IQSerialization new];
    IQStreamObjectTokenizer* tokenizer = [[IQStreamObjectTokenizer alloc] initWithStream:testData serialization:serialization format:IQSerializationFormatSimpleXML];
    tokenizer.delegate = self;
    [tokenizer run];
    XCTAssertEqual(array.count, 2, @"Expected 2 documents, found %d", (int)array.count);
    XCTAssertEqualObjects([[NSString alloc] initWithData:array[0] encoding:NSUTF8StringEncoding], @"<root/>");
    XCTAssertEqualObjects([[NSString alloc] initWithData:array[1] encoding:NSUTF8StringEncoding], @"<!DOCTYPE doc SYSTEM \"001.ent\" [\n<!ELEMENT doc EMPTY>/n]>\n<doc></doc>");
}

- (void)testTwoXmlDocumentsWithCdata {
    NSInputStream* testData = STREAM(@"<root><![CDATA[ <root></root> ]]></root>\r\n<root2><![CDATA[ >> \" ]]></root2>");
    [testData open];
    XCTAssertTrue(testData.hasBytesAvailable);
    IQSerialization* serialization = [IQSerialization new];
    IQStreamObjectTokenizer* tokenizer = [[IQStreamObjectTokenizer alloc] initWithStream:testData serialization:serialization format:IQSerializationFormatSimpleXML];
    tokenizer.delegate = self;
    [tokenizer run];
    XCTAssertEqual(array.count, 2, @"Expected 2 documents, found %d", (int)array.count);
    XCTAssertEqualObjects([[NSString alloc] initWithData:array[0] encoding:NSUTF8StringEncoding], @"<root><![CDATA[ <root></root> ]]></root>");
    XCTAssertEqualObjects([[NSString alloc] initWithData:array[1] encoding:NSUTF8StringEncoding], @"<root2><![CDATA[ >> \" ]]></root2>");
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

- (void)testSplitTwoJsonDocumentsWithWhitespaceUsingDifferentBufferSizes
{
    [self measureBlock:^{

        for(NSUInteger bufsize = 1; bufsize <= 16384; bufsize *= 2) {
            array = [NSMutableArray array];
            eos = NO;

            NSInputStream* testData = STREAM(@"  {\"a\":3}  \t{\"b\":3}");
            [testData open];
            XCTAssertTrue(testData.hasBytesAvailable);
            IQSerialization* serialization = [IQSerialization new];
            serialization.readBufferSize = bufsize;
            IQStreamObjectTokenizer* tokenizer = [[IQStreamObjectTokenizer alloc] initWithStream:testData serialization:serialization format:IQSerializationFormatJSON];
            tokenizer.delegate = self;
            [tokenizer run];
            XCTAssertEqual(array.count, 2, @"(bufsize=%u) Expected 2 documents, found %d", (unsigned int)bufsize, (int)array.count);
            if(array.count != 2) break;
            XCTAssertEqualObjects([[NSString alloc] initWithData:array[0] encoding:NSUTF8StringEncoding], @"{\"a\":3}");
            XCTAssertEqualObjects([[NSString alloc] initWithData:array[1] encoding:NSUTF8StringEncoding], @"{\"b\":3}");
        }
    }];
}
- (void)testSplitTwoJsonDocumentsWithWhitespaceUsingDifferentSmallBufferSizes
{
    [self measureBlock:^{

        for(NSUInteger bufsize = 1; bufsize <= 128; ++bufsize) {
            array = [NSMutableArray array];
            eos = NO;

            NSInputStream* testData = STREAM(@"  {\"a\":3}  \t{\"b\":3}");
            [testData open];
            XCTAssertTrue(testData.hasBytesAvailable);
            IQSerialization* serialization = [IQSerialization new];
            serialization.readBufferSize = bufsize;
            IQStreamObjectTokenizer* tokenizer = [[IQStreamObjectTokenizer alloc] initWithStream:testData serialization:serialization format:IQSerializationFormatJSON];
            tokenizer.delegate = self;
            [tokenizer run];
            XCTAssertEqual(array.count, 2, @"(bufsize=%u) Expected 2 documents, found %d", (unsigned int)bufsize, (int)array.count);
            if(array.count != 2) break;
            XCTAssertEqualObjects([[NSString alloc] initWithData:array[0] encoding:NSUTF8StringEncoding], @"{\"a\":3}");
            XCTAssertEqualObjects([[NSString alloc] initWithData:array[1] encoding:NSUTF8StringEncoding], @"{\"b\":3}");
        }
    }];
}
@end
