# IQSerialization - Data serialization as it should be

[![Travis CI status](https://travis-ci.org/evolvIQ/iqserialization.svg?branch=master)](https://travis-ci.org/evolvIQ/iqserialization)
[![License](https://img.shields.io/github/license/evolvIQ/IQSerialization.svg)](https://github.com/evolvIQ/IQSerialization/blob/master/LICENSE)
![Platforms](https://img.shields.io/badge/platforms-OS%20X%20%7C%20iOS-lightgrey.svg)

IQSerialization is an Objective-C library for iOS and Mac OS X that supports serializing your objects into a
variety of standard formats for storage or communication.

**This project is currently under active development and the APIs are not yet stable.**

The aims of this project is to provide:

* Serialization for typed classes to allow for static type checking
* Pluggable replacement of serialization formats
* High performance, low overhead suitable for mobile applications

The following formats are implemented:

* JSON - Uses the yajl parser.

* XML-RPC - Written in pure Objective-C using `NSXMLParser`
  
In addition, the following features are provided:

* Convienient Base64 encoding/decoding API is provided as a category on the `NSData` class.
* Splitting of streams into documents based by tokenizations. Useful when sending multiple objects over a single stream, such as JSON-RPC/XML-RPC over a web socket or when reading XML-based log files.

## How to use it

### Note
> There is API documentation in the form of Doxygen comments, but I have yet to find a good way to generate a good documentation site automatically from this. There used to be documentation online but it required too much manual labor to be feasible, and I have now removed it. Suggestions are welcome!

Add IQSerialization.xcodeproj as to your project and set up the include directories. In your code, 

    #import <IQSerialization/IQSerialization.h>
    
    ....
    
    NSDictionary* dict = [NSDictionary dictionaryWithJSONString:@"..."];
    
One of the aims of this library is to provide serialization support for your own classes.
