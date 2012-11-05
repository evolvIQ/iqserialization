//
//  main.m
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
#import "IQSerialization.h"
#import "IQSerialization+Base64.h"
#include <mach/mach_time.h>

int main(int argc, const char * argv[])
{
#if 1
    NSData* data = [NSData dataWithContentsOfFile:@"/Users/rickard/Documents/iliad/customization/Prevex/Resources/Videos/prevex_roadies_at_your_service.mp4"];
    double len = data.length, dt;
    NSData* outData;
    printf("Loaded\n");
    int i;
    uint64_t start, end;
    static mach_timebase_info_data_t tb;
    mach_timebase_info(&tb);
    
    
    outData = [data base64Data];
    start = mach_absolute_time();
    for(i=0; i<20; i++) {
        @autoreleasepool {
            outData = [data base64Data];
        }
        if(outData == nil) abort();
    }
    end = mach_absolute_time();
    
    dt = (end-start)*tb.numer/(1e9*i*tb.denom);
    printf("Time to encode: %f ms (%f MB/s)\n", dt*1000, len / (1024*1024*dt));
    
    start = mach_absolute_time();
    for(i=0; i<20; i++) {
        @autoreleasepool {
            data = [NSData dataWithBase64Data:outData];
        }
        if(data == nil) abort();
    }
    end = mach_absolute_time();
    
    dt = (end-start)*tb.numer/(1e9*i*tb.denom);
    printf("Time to encode: %f ms (%f MB/s)\n", dt*1000, len / (1024*1024*dt));
#else
    if(argc < 2) {
        fprintf(stderr, "Expected name of JSON file as argument\n");
        return -1;
    }
    @autoreleasepool {
        NSString* fileName = [NSString stringWithUTF8String:argv[1]];
        if(![[NSFileManager defaultManager] fileExistsAtPath:fileName]) {
            fprintf(stderr, "JSON file '%s' does not exist\n", [fileName UTF8String]);
            return -1;
        }
        static mach_timebase_info_data_t tb;
        mach_timebase_info(&tb);
        NSMutableArray* arr = [NSMutableArray array];
        NSData* data = [NSData dataWithContentsOfFile:fileName];
        [NSDictionary dictionaryWithJSONData:data];
        printf("Will start to parse now\n");
        uint64_t start = mach_absolute_time();
        int i = 0;
        for(i=0; i<10; i++) {
            NSDictionary* dic = [NSDictionary dictionaryWithJSONData:data];
            //printf("it %d\n", i);
            [arr addObject:dic];
        }
        uint64_t end = mach_absolute_time();
        printf("Time to parse: %f ms\n", (end-start)*tb.numer/(1e6*i*tb.denom));
    }
    return 0;
#endif
}

