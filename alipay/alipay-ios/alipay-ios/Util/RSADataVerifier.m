//
//  AlixPayDataVerifier.m
//  SafepayService
//
//  Created by wenbi on 11-4-11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "RSADataVerifier.h"
#import "openssl_wrapper.h"
#import "NSDataEx.h"
#import "base64.h"

@implementation RSADataVerifier

- (id)initWithPublicKey:(NSString *)publicKey {
	if (self = [super init]) {
		_publicKey = [publicKey copy];
	}
	return self;
}


- (NSString *)formatPublicKey:(NSString *)publicKey {
	
	NSMutableString *result = [NSMutableString string];
	
	[result appendString:@"-----BEGIN PUBLIC KEY-----\n"];
	
	int count = 0;
	
	for (int i = 0; i < [publicKey length]; ++i) {
		
		unichar c = [publicKey characterAtIndex:i];
		if (c == '\n' || c == '\r') {
			continue;
		}
		[result appendFormat:@"%c", c];
		if (++count == 76) {
			[result appendString:@"\n"];
			count = 0;
		}
		
	}
	
	[result appendString:@"\n-----END PUBLIC KEY-----\n"];
	
	return result;
	
}

- (NSString *)algorithmName {
	return @"RSA";
}

- (BOOL)verifyString:(NSString *)string withSign:(NSString *)signString {
	
//	const char *message = [string cStringUsingEncoding:NSUTF8StringEncoding];
//    int messageLength = strlen(message);
//	
//    unsigned char *signature = (unsigned char *)[signString UTF8String];
//	unsigned int signatureLength = (unsigned int)strlen((char *)signature);
//	char *encodedPath = (char *)[_pathForPEMFile cStringUsingEncoding:NSUTF8StringEncoding];

	NSString *documentPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
	NSString *path = [documentPath stringByAppendingPathComponent:@"AlixPay-RSAPublicKey"];
	
	//
	// 把密钥写入文件
	//
	NSString *formatKey = [self formatPublicKey:_publicKey];
	[formatKey writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
	
	BOOL ret;
	rsaVerifyString(string, signString, path, &ret);
	return ret;
	
}

@end
