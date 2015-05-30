//
//  IQJSONSerialization.m
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
#import "IQObjectFactory.h"
#import "yajl_parse.h"
#import "yajl_gen.h"
#import <objc/objc.h>
#import <objc/objc-api.h>
#import <objc/runtime.h>

static int _yajlevent_null(void * ctx)
{
    _IQObjectFactory* s = (__bridge _IQObjectFactory*)ctx;
    return [s _setScalarValue:nil];
}

static int _yajlevent_boolean(void * ctx, int boolean)
{
    _IQObjectFactory* s = (__bridge _IQObjectFactory*)ctx;
    return [s _setScalarValue:[NSNumber numberWithBool:(boolean != NO)]];
}

int _yajlevent_integer(void * ctx, long long integerVal)
{
    _IQObjectFactory* s = (__bridge _IQObjectFactory*)ctx;
    return [s _setScalarValue:[NSNumber numberWithLongLong:integerVal]];
}

int _yajlevent_double(void * ctx, double doubleVal)
{
    _IQObjectFactory* s = (__bridge _IQObjectFactory*)ctx;
    return [s _setScalarValue:[NSNumber numberWithDouble:doubleVal]];
}

static int _yajlevent_string(void * ctx, const unsigned char * stringVal, size_t stringLen)
{
    _IQObjectFactory* s = (__bridge _IQObjectFactory*)ctx;
    NSString* string = [[NSString alloc] initWithBytes:(char*)stringVal length:stringLen encoding:s->encoding];
    return [s _setScalarValue:string];
}

static int _yajlevent_map_key(void * ctx, const unsigned char * stringVal, size_t stringLen)
{
    _IQObjectFactory* s = (__bridge _IQObjectFactory*)ctx;
    if(!s->object || s->key) {
        return [s _fail:@"Unexpected key"];
    }
    s->key = [[NSString alloc] initWithBytes:(char*)stringVal length:stringLen encoding:s->encoding];
    return YES;
}

static int _yajlevent_start_map(void * ctx)
{
    _IQObjectFactory* s = (__bridge _IQObjectFactory*)ctx;
    return [s _createChildObject];
}


static int _yajlevent_end_map(void * ctx)
{
    _IQObjectFactory* s = (__bridge _IQObjectFactory*)ctx;
    [s _popObject];
    return YES;
}

static int _yajlevent_start_array(void * ctx)
{
    _IQObjectFactory* s = (__bridge _IQObjectFactory*)ctx;
    return [s _createChildArray];
}

static int _yajlevent_end_array(void * ctx)
{
    _IQObjectFactory* s = (__bridge _IQObjectFactory*)ctx;
    [s _popObject];
    return YES;
}


BOOL _IQDeserializeJSONData(id object, NSData* jsonData, IQSerialization* serialization, IQSerializationFlags flags, NSError** outError)
{
    NSError* error = nil;
    @autoreleasepool {
        yajl_callbacks cb = {
            _yajlevent_null,
            _yajlevent_boolean,
            _yajlevent_integer,
            _yajlevent_double,
            NULL,
            _yajlevent_string,
            _yajlevent_start_map,
            _yajlevent_map_key,
            _yajlevent_end_map,
            _yajlevent_start_array,
            _yajlevent_end_array
        };
        _IQObjectFactory* serializer = [_IQObjectFactory new];
        serializer->object = object;
        serializer->isRoot = YES;
        serializer->explicitNull = !serialization.ignoreNilValues;
        serializer.ignoreUnknownProperties = serialization.ignoreUnknownProperties;
        
        serializer->dictionaryMode = [object isKindOfClass:[NSArray class]]
        || [object isKindOfClass:[NSDictionary class]]
        || [object isKindOfClass:[NSSet class]]
        || [object isKindOfClass:[NSOrderedSet class]];
        
        serializer->encoding = serialization.textEncoding;
        yajl_handle yajl = yajl_alloc(&cb, NULL, (__bridge void*)serializer);
        yajl_status stat = yajl_parse(yajl, jsonData.bytes, jsonData.length);
        if(stat != yajl_status_ok) {
            if(serializer->error) {
                error = serializer->error;
            } else {
                char* err = (char*)yajl_get_error(yajl, 0, jsonData.bytes, jsonData.length);
                if(!err) {
                    err = "Unknown error";
                }
                error = [NSError errorWithDomain:@"org.evolvIQ.IQJSONSerialization" code:1001 userInfo:
                                 [NSDictionary dictionaryWithObject:[NSString stringWithUTF8String:err] forKey:NSLocalizedDescriptionKey]];
            }
        }
        yajl_free(yajl);
    }
    if(error) {
        if(outError) {
            *outError = error;
        }
        return NO;
    }
    return YES;
}

// "print" function to append to a NSMutableData
static void _append_nsdata(void * ctx, const char * str, size_t len)
{
    NSMutableData* data = (__bridge NSMutableData*)ctx;
    [data appendBytes:str length:len];
}

// "print" function to append to a NSOutputStream
static void _append_stream(void * ctx, const char * str, size_t len)
{
    NSOutputStream* stream = (__bridge NSOutputStream*)ctx;
    [stream write:(unsigned char*)str maxLength:len];
}

static void _do_yajl_gen(id object, yajl_gen gen, IQSerialization* serialization)
{
    if(!object) {
        yajl_gen_null(gen);
    } else if ([object isKindOfClass:[NSNumber class]]) {
        const char* t = [object objCType];
        BOOL handled = NO;
        if(t && t[0] == 'c') {
            char val = [object charValue];
            if(val == 0 || val == 1) {
                yajl_gen_bool(gen, val);
                handled = YES;
            }
        } else if(t && (t[0] == 'd' || t[0] == 'f')) {
            yajl_gen_double(gen, [object doubleValue]);
            handled = YES;
        }
        if(!handled) {
            yajl_gen_integer(gen, [object longLongValue]);
        }
    } else if([object isKindOfClass:[NSString class]]) {
        yajl_gen_string(gen, (unsigned char*)[object UTF8String], [object lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
    } else if([object isKindOfClass:[NSArray class]] || [object isKindOfClass:[NSSet class]] || [object isKindOfClass:[NSOrderedSet class]]) {
        yajl_gen_array_open(gen);
        for(id value in object) {
            _do_yajl_gen(value, gen, serialization);
        }
        yajl_gen_array_close(gen);
    } else if([object isKindOfClass:[NSDictionary class]]) {
        yajl_gen_map_open(gen);
        for(NSString* key in object) {
            id value = [object objectForKey:key];
            if((!value || value == [NSNull null]) && serialization.ignoreNilValues) {
                continue;
            }
            yajl_gen_string(gen, (unsigned char*)[key UTF8String], [key lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
            _do_yajl_gen(value, gen, serialization);
        }
        yajl_gen_map_close(gen);
    } else {
        yajl_gen_map_open(gen);
        for(NSString* property in [serialization _propertiesForObject:object]) {
            id value = [object valueForKey:property];
            if((!value || value == [NSNull null]) && serialization.ignoreNilValues) {
                continue;
            }
            yajl_gen_string(gen, (unsigned char*)[property UTF8String], [property lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
            _do_yajl_gen(value, gen, serialization);
        }
        yajl_gen_map_close(gen);
    }
}

NSData* _IQJSONSerializeObject(id object, IQSerialization* serialization, IQSerializationFlags flags, NSError** outError)
{
    yajl_gen gen = yajl_gen_alloc(NULL);
    if(serialization.textEncoding == NSUTF8StringEncoding) {
        yajl_gen_config(gen, yajl_gen_validate_utf8, 1);
    }
    if(serialization.pretty) {
        yajl_gen_config(gen, yajl_gen_beautify, 1);
    }
    NSMutableData* data = [NSMutableData dataWithCapacity:1024];
    yajl_gen_config(gen, yajl_gen_print_callback, _append_nsdata, data);
    _do_yajl_gen(object, gen, serialization);
    yajl_gen_free(gen);
    
    return data;
}

@implementation NSDictionary (JSONSerialization)
+ (NSDictionary*) dictionaryWithJSONData:(NSData*)jsonData
{
    IQSerialization* ser = [IQSerialization new];
    NSDictionary* dict = [ser dictionaryFromData:jsonData format:IQSerializationFormatJSON];
    if(dict == nil) {
        [NSException raise:@"ParseError" format:@"%@", ser.error.userInfo[NSLocalizedDescriptionKey]];
    }
    return dict;
}

+ (NSDictionary*) dictionaryWithJSONString:(NSString*)jsonString
{
    IQSerialization* ser = [IQSerialization new];
    NSDictionary* dict = [ser dictionaryFromString:jsonString format:IQSerializationFormatJSON];
    if(dict == nil) {
        [NSException raise:@"ParseError" format:@"%@", ser.error.userInfo[NSLocalizedDescriptionKey]];
    }
    return dict;
}
@end

@implementation NSObject (JSONSerialization)
- (NSString*) JSONRepresentation
{
    return [[IQSerialization new] stringFromObject:self format:IQSerializationFormatJSON];
}
@end
