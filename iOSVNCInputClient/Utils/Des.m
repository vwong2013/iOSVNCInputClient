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

#import "Des.h"

#import "NSData+HexString.h"

//Openssl libcrypto
#import <des.h>
//#import <rand.h>

@implementation Des
#pragma mark - de/encrypt 64bit blocks - Public Methods
//Encrypt/Decrypt block using supplied key.  ECB method (each block encrypted with same key).
+(NSData *)encryptBlock:(NSData *)msgBlock /* 8 byte blocks */
					Key:(NSData *)key  /* 64 bits */
				Encrypt:(BOOL)encrypt; {
    
	//Stop if input data > 8 bytes in length
	if (msgBlock.length != sizeof(DES_cblock)) {
		DLogErr(@"Cannot encrypt/decrypt data blocks larger than DES_cblock type (8 bytes)");
		return nil;
	}
	
	//Set DES key
	DES_cblock *desKey = malloc(sizeof(DES_cblock));
	memcpy(desKey, [key bytes], sizeof(DES_cblock)); //Grab only the first 8 bytes as required
	
	DES_key_schedule keysched;
	int checkResult = DES_set_key_checked(desKey, &keysched);
	if (checkResult == -1) { //Optional... Works fine regardless of whether odd parity or not
		DLogWar(@"Supplied key is not of odd parity: %i", checkResult);
		DES_set_odd_parity(desKey);
		checkResult = DES_set_key_checked(desKey, &keysched);
		DLogWar(@"Check result after manually setting parity to odd: %i", checkResult);
	} else if (checkResult != 0) {
		DLogErr(@"Supplied key is weak: %i", checkResult);
		return nil;
	}
	
	//Encrypt/decrypt.  YES = DES_ENCRYPT, NO = DES_DECRYPT
	unsigned char outputM[sizeof(DES_cblock)];
	DES_ecb_encrypt((DES_cblock *)[msgBlock bytes], (DES_cblock *)outputM, &keysched, encrypt);
	
	//Cleanup
	free(desKey);
	
	return [NSData dataWithBytes:outputM
						  length:msgBlock.length];
}

//Wrapper for spliting the msg into blocks for encryption/decryption
+(NSData *)encryptBlockForMessage:(NSData *)message
					MessageOffset:(NSUInteger)offset
							  Key:(NSData *)key
						  Encrypt:(BOOL)encrypt {
	
	//Extract message given offset, padding with zeros if required
	NSData *msgSubset = [[self class] msgBlockForMsg:message
                                              Offset:offset];
	
	//Encrypt/Decrypt block
	NSData *cipherSubset = [[self class] encryptBlock:msgSubset
                                                  Key:key
                                              Encrypt:encrypt];
    
	if (!cipherSubset)
        cipherSubset = [NSData new];
    
	return cipherSubset;
}

#pragma mark - Private Methods
//Extract 64-bit (8 byte) block of message, padding with zeros if not enough elements in remaining msg up to 8 bytes
+(NSData *)msgBlockForMsg:(NSData *)message
                   Offset:(NSUInteger)offset {
    static const NSUInteger blockSize = 8; //bytes
	
    NSUInteger readLength = offset+blockSize;
    if (readLength <= message.length) {
        return [message subdataWithRange:NSMakeRange(offset, blockSize)];
    } else {
        //Read remaining data that is < 8 bytes in length
        NSInteger rangeLength = message.length-offset;
        
        NSMutableData *subset = [[message subdataWithRange:NSMakeRange(offset, rangeLength)] mutableCopy];
        [subset setLength:blockSize]; //Pad 0's to blockSize (these don't get included in the original msg)
        return subset;
    }
}

#pragma mark - de/encrypt data of variable length - Public Methods
//Encrypt plaintext (C String) with key and return ciphertext
//Key must be a DES_cblock key (length 8 bytes) wrapped in a NSData object
//Message is padded with zeros if not a multiple of 8 (64bits)
+ (NSData *)encryptMessage:(NSData *)plaindata
				   withKey:(NSData *)key {
	//Return empty NSData object if message or key are blank / length == 0
	if (!plaindata || plaindata.length == 0 || !key || key.length == 0)
		return [NSData new];
    
	//Encrypt each 8 byte block of the message.
	NSMutableData *ciphertext = [NSMutableData dataWithCapacity:plaindata.length]; //Extended automatically if padding req.
	for (uint i = 0; i < plaindata.length; i += 8) {
		[ciphertext appendData: [[self class] encryptBlockForMessage:plaindata
                                                       MessageOffset:i
                                                                 Key:key
                                                             Encrypt:YES]];
	}
	
	return ciphertext;
}

//Decrypt ciphertext with key and return plaintext (C String)
//Key must be a DES_cblock key (length 8 bytes) wrapped in a NSData object
//Message is padded with zeros if not a multiple of 8 (64bits)
+ (NSData *)decryptMessage:(NSData *)cipherdata
				   withKey:(NSData *)key {
	//Return blank NSData object if message or key are blank / length == 0
	if (!cipherdata || cipherdata.length == 0 || !key || key.length == 0)
		return [NSData new];
	   
    //Note: couldn't use NSData's appendData as could not append c string null term after rebuilding string
    unsigned char plaintextBytes[cipherdata.length+1]; //+1 size for null term
	for (uint i = 0; i < cipherdata.length; i += 8) {
        NSData *decryptedBlock = [[self class] encryptBlockForMessage:cipherdata
                                                        MessageOffset:i
                                                                  Key:key
                                                              Encrypt:NO];
        
        //Copy decrypted bytes into buffer
        memccpy(plaintextBytes + i, [decryptedBlock bytes], (unsigned int)[decryptedBlock length], ((unsigned int)[decryptedBlock length] * sizeof(unsigned char)));
	}
	
    //Append null term to end of c string
    plaintextBytes[cipherdata.length] = '\0';
    
    //Wrap in NSData
    NSData *plaintext = [NSData dataWithBytes:plaintextBytes
                                       length:sizeof(plaintextBytes)];
    
	return plaintext;
}

//Wrapper for encrypting Challenge from VNC Auth with supplied VNC password string from user
//Password is converted into a key with the bits of each byte reversed, as per VNC Open source code
+ (NSData *)encryptChallenge:(NSData *)challenge
				withPassword:(NSString *)password {
	return [self encryptMessage:challenge
						withKey:[[self class] passwordToKey:password]];
}

/**
 * Convert string into data object, and reverse the bits in each byte of the data,
 * up to 8 bytes (length of DES key).
 *
 * As mentioned in VNC Open source code, d3des.c:
 * "the bytebit[] array has been reversed so that the most significant bit in each byte of the
 * key is ignored, not the least significant."
 */
+ (NSData *)passwordToKey:(NSString *)password {
	//Return blank NSdata if pwd length == 0
	if (!password || password.length == 0)
		return [NSData new];
	
	NSData *pwdData = [password dataUsingEncoding:NSUTF8StringEncoding];
	const char *pwdBytes = [pwdData bytes];
	
	static const uint8_t keySize = 8;
	static const uint8_t bitsSize = 8;
    static const uint8_t bitMask[bitsSize] = {0x80,0x40,0x20,0x10,0x08,0x04,0x02,0x01};
    
    uint8_t key[keySize] = {0,0,0,0,0,0,0,0}; //zero padding
    for (uint i=0; i < keySize; i++) {
        if (i >= pwdData.length)
            break; //stop early if pwdData is shorter than keySize
        
        uint8_t preFlipB = pwdBytes[i];
        uint8_t postFlipB = 0;
        //Do bit reversals
        for (uint j=0; j < bitsSize; j++) {
            uint8_t masked = (preFlipB & bitMask[j]); //Check if bit present.
            if (masked != 0)
                postFlipB |= bitMask[(bitsSize-1)-j]; //Reverse bit.  -1 b/c array index = 0.
        }
        //Assign result to testKey
        key[i] = postFlipB;
    }
	
	NSData *wrappedKey = [NSData dataWithBytes:key
										length:sizeof(key)];
    //DLog(@"wrappedKey %@", wrappedKey);
    
	return wrappedKey;
}

#pragma mark - Convenience Methods For String De/Encryption - Public
//DES length key for encrypting saved pwds... generate a new one before using
+ (NSData *)FALLBACK_CRYPT_KEY {
	DES_cblock defaultKey = {0xC7, 0xF2, 0xCE, 0xBC, 0xAE, 0xF1, 0x38, 0x64};

/*
	DES_cblock key;
	DES_cblock seed = {0xFE, 0xDC, 0xBA, 0x98, 0x76, 0x54, 0x32, 0x10};
	RAND_seed(seed, sizeof(DES_cblock));
	
    DES_random_key(&key);
*/
		
	return [NSData dataWithBytes:defaultKey
						  length:sizeof(DES_cblock)];
}

#pragma mark - Convenience Methods For Strings - Public
//Key must be a DES_cblock key (length 8 bytes) wrapped in a NSData object
+ (NSString *)encryptText:(NSString *)plaintext WithKey:(NSData *)key {
	if (!key)
		key = [[self class] FALLBACK_CRYPT_KEY];
	if (key.length != sizeof(DES_cblock))
        return @"";
    
    NSData *plainData = [NSData dataWithBytes:[plaintext cStringUsingEncoding:NSUTF8StringEncoding]
                                       length:[plaintext lengthOfBytesUsingEncoding:NSUTF8StringEncoding]];

	return [NSData hexString:[[self class] encryptMessage:plainData
                                                  withKey:key]];
}

//Key must be a DES_cblock key (length 8 bytes) wrapped in a NSData object
+ (NSString *)decryptText:(NSString *)ciphertext WithKey:(NSData *)key {
	if (!key)
		key = [[self class] FALLBACK_CRYPT_KEY];
	if (key.length != sizeof(DES_cblock))
        return @"";

	NSData *plainData = [[self class] decryptMessage:[NSData dataFromHexString:ciphertext]
                                             withKey:key];
	const char *plainBytes = [plainData bytes];
    
	if (plainBytes == nil) {
        DLogErr(@"DecryptText error - Decrypt failed or none to decrypt");
		return @""; //Decrypt failed or none to decrypt
    }
	
	NSString *plaintext = [NSString stringWithUTF8String:plainBytes];
    if (!plaintext || plaintext.length == 0) {
        DLogErr(@"DecryptText error - failed to wrap c string as NSString");
        DLog(@"plainBytes %s",plainBytes);        
        return @""; //failed to wrap c string as NSString
    }
    
	return plaintext;
}

@end
