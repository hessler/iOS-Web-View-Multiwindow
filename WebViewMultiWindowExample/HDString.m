//----------------------------------------------------------------------
//
//  HDString.m
//  WebViewMultiWindowExample
//
//  Copyright (c) 2013 Hessler Design. All rights reserved.
//
//----------------------------------------------------------------------

#import "HDString.h"

@implementation HDString

+ (NSString *) encodedString:(NSString *)string
{
    return (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)string, NULL, (CFStringRef)@"!*'();:@&=+$,/?%#[]", kCFStringEncodingUTF8 ));
}

@end
