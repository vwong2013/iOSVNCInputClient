/*  
 Copyright 2013 V Wong <vwong122013 (at) gmail.com>
 Licensed under the Apache License, Version 2.0 (the "License"); you may not
 use this file except in compliance with the License. You may obtain a copy of
 the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
 WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
 License for the specific language governing permissions and limitations under
 the License.
 */

//  Wrapper for OpenSSL DES functions.

#import <Foundation/Foundation.h>

@interface Des : NSObject

#pragma mark - de/encrypt 64bit blocks - Public Methods
//Decrypt/Encrypt a 64-bit block of data with provided key.  ECB method (each block encrypted with same key).
+(NSData *)encryptBlock:(NSData *)msgBlock
					Key:(NSData *)key
				Encrypt:(BOOL)encrypt;

//Wrapper for spliting the msg into blocks for encryption/decryption
+(NSData *)encryptBlockForMessage:(NSData *)message
					MessageOffset:(NSUInteger)offset
							  Key:(NSData *)key
						  Encrypt:(BOOL)encrypt;

#pragma mark - de/encrypt data of variable length - Public Methods
//Encrypt plaintext (C String) with key and return ciphertext
//Key must be a DES_cblock key (length 8 bytes) wrapped in a NSData object
//Message is padded with zeros if not a multiple of 8 (64bits)
+ (NSData *)encryptMessage:(NSData *)plaindata
				   withKey:(NSData *)key;

//Decrypt ciphertext with key and return plaintext (C String)
//Key must be a DES_cblock key (length 8 bytes) wrapped in a NSData object
//Message is padded with zeros if not a multiple of 8 (64bits)
+ (NSData *)decryptMessage:(NSData *)cipherdata
					withKey:(NSData *)key;

//Wrapper for encrypting Challenge from VNC Auth with supplied VNC password string from user
//Password is converted into a key with the bits of each byte reversed, as per VNC Open source code
+ (NSData *)encryptChallenge:(NSData *)challenge
				withPassword:(NSString *)password;

#pragma mark - Convenience Methods For Strings - Public
+ (NSString *)encryptText:(NSString *)plaintext
					  WithKey:(NSData *)key;

+ (NSString *)decryptText:(NSString *)ciphertext
					  WithKey:(NSData *)key;
@end
