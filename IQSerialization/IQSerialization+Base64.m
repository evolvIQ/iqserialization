//
//  IQSerialization+Base64.m
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

#import "IQSerialization+Base64.h"



@implementation NSData (Base64Encoding)
+ (NSData*)dataWithBase64String:(NSString*)string
{
    return [NSData dataWithBase64Data:[string dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES]];
}

+ (NSData*)dataWithBase64Data:(NSData*)inputData;
{
    static int _rev_b64_index[] = {-1,-1,-1,-1,-1,-1,-1,-1,-1,-3,-3,-1,-1,-3,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
        -1,-1,-1,-1,-1,-3,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,62,-1,-1,-1,63,52,53,54,55,56,57,58,59,60,61,-1,-1,-1,-2,-1,
        -1,-1,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,-1,-1,-1,-1,-1,-1,26,27,28,29,30,
        31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
        -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
        -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
        -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
        -1,-1,-1,-1,-1,-1,-1,-1,-1,-1};
    if(inputData == nil) return nil;
    if(inputData.length == 0) return [NSData data];
    
    const char* input = inputData.bytes;
    NSUInteger length = inputData.length;
    const char* inputend = input + length;
    
    NSMutableData* outputData = [NSMutableData dataWithLength:length * 3 / 4];
    char* output = outputData.mutableBytes;
    char* outbuf = output;
    
#define B64_NEXT_CHAR \
valid = NO; \
while(input < inputend) { \
c = _rev_b64_index[*input++]; \
if(c >= 0) { valid = YES; break; } \
else if(c == -1) {return nil;} \
} if(!valid) { c = 0; end = YES;}
    
    for(; input < inputend;) {
        int c, valid, end = NO;
        B64_NEXT_CHAR
        *output = (c & 0x3f) << 2;
        B64_NEXT_CHAR
        *output++ |= (c & 0x30) >> 4;
        if(end) break;
        *output = (c & 0xf) << 4;
        B64_NEXT_CHAR
        if(end) break;
        *output++ |= (c & 0x3c) >> 2;
        *output = (c & 0x3) << 6;
        B64_NEXT_CHAR
        if(end) break;
        *output++ |= (c & 0x3f);
    }
    
#undef B64_NEXT_CHAR
    
    [outputData setLength:output-outbuf];
    return outputData;
}

- (NSString*)base64String
{
    NSData* data = [self base64Data];
    if(!data) return nil;
    return [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
}

- (NSData*)base64Data
{
    static char _b64_index[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    //static int _b64_index[] = {'A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z','a','b','c','d','e','f','g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v','w','x','y','z','0','1','2','3','4','5','6','7','8','9','+','/'};
    
    if(self.length == 0) return [NSData data];
    
    const char* input = self.bytes;
    NSUInteger length = self.length;
    const char* inputend = input + length;
    
    NSUInteger outLength = ((length + 2) / 3) * 4+3;
    outLength += (outLength + 75) / 76;
    NSMutableData* data = [NSMutableData dataWithLength:outLength];
    char* output = data.mutableBytes;
    char* outbuf = output;
    
#define B64_NEXT_CHAR \
if(input == inputend) break; \
c = *input++;
    
#define B64_OUT_CHAR \
if(cl++ == 76) {*output++ = '\n'; cl = 0;} \
*output++ = _b64_index[r];
    
    int r = 0, cl = 0;
    for (;input < inputend;) {
        char c = *input++;
        r = (c & 0xfc) >> 2;
        B64_OUT_CHAR
        r = (c & 0x3) << 4;
        
        BOOL end1 = input >= inputend;
        c = end1 ? 0 : *input++;
        r |= (c & 0xf0) >> 4;
        B64_OUT_CHAR
        if(end1) {
            *output++ = '=';
            *output++ = '=';
            break;
        }
        r = (c & 0xf) << 2;
        
        BOOL end2 = input >= inputend;
        c = end2 ? 0 : *input++;
        r |= (c & 0xc0) >> 6;
        B64_OUT_CHAR
        r = (c & 0x03f);
        if(end2) {
            *output++ = '=';
            break;
        }
        B64_OUT_CHAR
    }
    
#undef B64_OUT_CHAR
    [data setLength:output-outbuf];
    return data;
}
@end
