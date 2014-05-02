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

/**
 * Apple Remote Desktop / Mac Authentication implementation using OpenSSL.
 */

#import "RFBSecurityARD.h"
#import "RFBSocket.h"
#import "HandleErrors.h"

//openssl libcrypto
#import <bn.h>
#import <dh.h>
#import <md5.h>
#import <evp.h> 

//Hold results of DH key agreement
typedef struct {
    unsigned char *publicKey;
	int pubKeyLen;
    unsigned char *privateKey;
	int privKeyLen;
    unsigned char *secretKey;
	int secKeyLen;
} DHResult;

#define SECURITY__ARD 30
#define RFBNAME @"Mac Authentication"
//C array size for plaintext to be encrypted
#define CRED_ARRAY_SIZE 128

@interface RFBSecurityARD()
@property (copy,nonatomic) NSString *username;
@property (copy,nonatomic) NSString *password;

@end

@implementation RFBSecurityARD
//override of abstract superclass
- (id)init {
	return [self initWithUsername:nil Password:nil];
}

- (id)initWithUsername:(NSString *)username Password:(NSString *)password {
	self = [super init];
	if (self) {
		_username = username;
		_password = password;
	}
	return self;
}

- (void)dealloc {
    DLogInf(@"RFBSecurityARD dealloc");
}

// The type and name identifies this authentication scheme to
// the rest of the RFB code.
+ (uint8_t)type {
	return SECURITY__ARD;
}

+ (NSString *)typeName {
	return RFBNAME;
}

//Perform ARD (Mac) Authentication on established RFBStream using credentials used to init this class
//Version is ignored since auth behaviour doesn't change between protocol versions
- (BOOL)performAuthWithSocket:(RFBSocket *)socket ForVersion:(VersionMsg *)serverVersion Error:(NSError **)error {
    //Error handling block
	HandleError he = [HandleErrors handleErrorBlock];
    
    //Check if required properties are present before starting auth process
    if (self.username.length == 0 || self.password.length == 0) {
        DLogErr(@"Username or password fields empty - profile decryption error?");
        he(error,SecurityErrorDomain,SecurityEncryptError,NSLocalizedString(@"Username or password fields empty - profile decryption error?", @"RFBSecurityARD username and password length check error text"));
        return NO;
    }
    
	// 1. Get Diffie-Hellman parameters from server
	NSData *genWrapped = [socket readReceived:2];
	const uint8_t *generator = [genWrapped bytes];      // DH base generator value
	uint16_t keyLength = [socket readShort];     // key length in bytes
	NSData *primeWrapped = [socket readReceived:keyLength];
	const uint8_t *prime = [primeWrapped bytes];  // predetermined prime modulus
	NSData *peerKeyWrapped = [socket readReceived:keyLength];
	const uint8_t *peerKey = [peerKeyWrapped bytes];// other party's public key
    
	if (genWrapped.length == 0 || keyLength == 0 || primeWrapped.length == 0 || peerKeyWrapped.length == 0) {
		DLogErr(@"genWrapped: %@, keyLength: %i, primeWrapped: %@, peerKeyWrapped: %@", genWrapped, keyLength, primeWrapped, peerKeyWrapped);
		return NO;
	}
	
	// 2. perform Diffie-Hellman key agreement
    
	//Convert C Strings into BIGNUM structs
	//C objects
	BIGNUM *bigPeerKey = NULL;
	BIGNUM *bigPrime = NULL;
	BIGNUM *bigGenerator = NULL;
	
	//Network received bytes should def. be in Big Endian format...
	bigPeerKey = BN_bin2bn(peerKey, (int)[peerKeyWrapped length], NULL);
	bigGenerator = BN_bin2bn(generator, (int)[genWrapped length], NULL);
	bigPrime = BN_bin2bn(prime, (int)[primeWrapped length], NULL);
	
	DHResult dh;
    //Malloc pointers in dh for receiving keys
    dh.publicKey = malloc(sizeof(unsigned char) * keyLength);
    dh.privateKey = malloc(sizeof(unsigned char) * keyLength);
    dh.secretKey = malloc(sizeof(unsigned char) * keyLength);
    
    //Perform DH agreement
	BOOL keyAgreed = [self performDHKeyAgreementWithPrime:bigPrime
													  Generator:bigGenerator
															Key:bigPeerKey
													  KeyLength:keyLength
													   DHResult:&dh
														  Error:error];
	
    //Handy cleanup block for required mem cleanups
    void (^cleanupVars)() = ^ void {
		BN_free(bigPeerKey);
		BN_free(bigPrime);
		BN_free(bigGenerator);
        free(dh.publicKey);
        free(dh.privateKey);
        free(dh.secretKey);
    };
    
	if (!keyAgreed) {
		DLogErr(@"RFBSecurityARD - Failed DH Key Agreement with error: %@", [*error localizedDescription]);
		//Cleanup
		cleanupVars();
		return NO;
	}
	 
	// 3. Get MD5 hash of the shared secret
	NSData *wrappedKey = [NSData dataWithBytes:dh.secretKey
										length:dh.secKeyLen]; 
	NSData *secretHash = [self performMD5OnData:wrappedKey
										  Error:error];
	
	// 4. ciphertext = AES128(shared, username[64]:password[64]);
	//Fill new C array with random bytes for security
	unsigned char creds[CRED_ARRAY_SIZE];
	if ((SecRandomCopyBytes(kSecRandomDefault, CRED_ARRAY_SIZE, creds)) != 0) {
		DLogErr(@"RFBSecurityARD - Failed to generate random bytes into creds");
        he(error,SecurityErrorDomain,SecurityEncryptError,NSLocalizedString(@"Failed to generate random numbers needed as part of ARD auth", @"RFBSecurityARD PRNG function error text"));
		cleanupVars();
		return NO;
	};
    
	//Convert username and password strings into C strings
	const unsigned char *userBytes = (unsigned char *)[self.username UTF8String];
	const unsigned char *passBytes = (unsigned char *)[self.password UTF8String];
	//Cap length at 63 as index is 0
	unsigned int userByteLength = (unsigned int)[self.username lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
	unsigned int passByteLength = (unsigned int)[self.password lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
	int userLength = (userByteLength < 63) ? userByteLength : 63;
	int passLength = (passByteLength < 63) ? passByteLength : 63;
	//Merge username and password into single array
	memcpy(creds, userBytes, (userLength * sizeof(unsigned char)));
	memcpy(creds + (CRED_ARRAY_SIZE/2), passBytes, (passLength * sizeof(unsigned char))); //Shift starting memory location
	//Add null bytes to indicate end of c string
	creds[userLength] = '\0';
	creds[(CRED_ARRAY_SIZE/2)+passLength] = '\0';
	
	NSData *credentials = [NSData dataWithBytes:creds
                                         length:CRED_ARRAY_SIZE];
	NSData *ciphertext = [self performAES128WithSecretKey:secretHash
											 ForPlaintext:credentials
													Error:error];

	// 5. send the ciphertext + DH public key
	if (!ciphertext || ciphertext.length != CRED_ARRAY_SIZE) {
		DLogErr(@"Failed to encrypt username and password... abort sending to server");
        he(error,SecurityErrorDomain,SecurityEncryptError,NSLocalizedString(@"Failed to encrypt user credentials for authentication", @"RFBSecurityARD ciphertext encryption error text"));
		cleanupVars();
		return NO;
	}
	
	//Bundle ciphertext and key into single packet before replying
    NSMutableData *authReply = [NSMutableData dataWithData:ciphertext];
    [authReply appendBytes:dh.publicKey length:dh.pubKeyLen];
    
    DLog(@"dh.pubKeyLen %i",dh.pubKeyLen);
    
    [socket writeBytes:authReply];
	
	//Remember to free all allocated BIGNUM's
    //Free dhResult struct pointers
    cleanupVars();
    
    //Read SecurityResult
    if ([socket readSecurityResult] == 1) { // failure
        //v3.7 Protocol failure behaviour for ARD, ie. no reason given by server when auth fails        
        he(error,SocketErrorDomain,SocketConnectError,NSLocalizedString(@"Security handshake with server failed. Incorrect username and password?", @"ARD Security Handshake Failed Error Text"));
        return NO;
    }
    
	return YES;
}

#pragma mark - Encryption methods for ARD Auth - Private
-(BOOL)performDHKeyAgreementWithPrime:(BIGNUM *)prime Generator:(BIGNUM *)generator Key:(BIGNUM *)peerKey KeyLength:(int)keyLength DHResult:(DHResult *)dhResult Error:(NSError **)error {
    //Error handling block
	HandleError he = [HandleErrors handleErrorBlock];
    
	//Cannot use method without preallocation
	if (dhResult == NULL || dhResult->publicKey == NULL || dhResult->privateKey == NULL || dhResult->secretKey == NULL) {
		he(error,SecurityErrorDomain,SecurityEncryptError,NSLocalizedString(@"No DHResult struct to return results with, or no memory allocated for pointers in struct", @"RFBSecurityARD DH result struct memory allocation error text"));
		return NO;
	} 
	
	//Create DH struct
	DH *dhOwnKey;
	if (!(dhOwnKey = DH_new())) {
        he(error,SecurityErrorDomain,SecurityEncryptError,NSLocalizedString(@"Could not create openssl DH struct", @"RFBSecurityARD DH struct creation error text"));
		return NO;
	}
	
	//Populate DH struct with copy of (so underlying BIGNUM's are freed in other method) required prime, generator
	dhOwnKey->p = BN_dup(prime);
	dhOwnKey->g = BN_dup(generator);
	
	// generate my public/private key pair using peer-supplied prime and generator
	if (!(DH_generate_key(dhOwnKey))) {
        NSString *errorMsg = NSLocalizedString(@"Could not generate keys using supplied prime:", @"RFBSecurityARD DH key generate error text 1");
        NSString *errorMsg2 = NSLocalizedString(@"GENERATOR:", @"RFBSecurityARD DH key generate error text 2");
		he(error,SecurityErrorDomain,SecurityEncryptError,[NSString stringWithFormat:@"%@ %s %@ %s", errorMsg, BN_bn2dec(prime), errorMsg2, BN_bn2dec(generator)]);
        DH_free(dhOwnKey);        
		return NO;
	}
	
    // allocate memory for secret key and double check own generated key pair are of the right length
	unsigned char *sharedSecret;
	int secretLength = DH_size(dhOwnKey);
    if (secretLength != keyLength) {
        he(error,SecurityErrorDomain,SecurityEncryptError,NSLocalizedString(@"Incorrect key size generated - please try again", @"RFBSecurityARD generated key size error text"));
        DH_free(dhOwnKey);        
        return NO;
    }
	if (!(sharedSecret = malloc(sizeof(unsigned char) * secretLength))) {
		he(error,SecurityErrorDomain,SecurityEncryptError,NSLocalizedString(@"Could not malloc sharedSecret with DH_size of DH struct", @"RFBSecurityARD secret key malloc error text"));
        DH_free(dhOwnKey);
		return NO;
	}
    
	// perform key agreement
	if ((DH_compute_key(sharedSecret, peerKey, dhOwnKey)) == -1) { //COmpute shared secret
		he(error,SecurityErrorDomain,SecurityEncryptError,NSLocalizedString(@"Failed to compute shared secret",@"RFBSecurityARD DH key agreement error text"));
		free(sharedSecret); //Free up allocated memory taken by shared secret
        DH_free(dhOwnKey);        
		return NO;
	}

	// Copy results and free stuff
	unsigned char *privKey, *pubKey;
	int privKeyLength = BN_num_bytes(dhOwnKey->priv_key);
	int pubKeyLength = BN_num_bytes(dhOwnKey->pub_key);
    
    //Check key lengths of generated private and public DH keys
    if (privKeyLength != keyLength || pubKeyLength != keyLength) {
        NSString *errorMsg = NSLocalizedString(@"Public/Private Key Lengths have been incorrectly generated: ",@"RFBSecurityARD DH private/public key error text");
		he(error,SecurityErrorDomain,SecurityEncryptError,[NSString stringWithFormat:@"%@ privLen: %i, pubLen: %i", errorMsg, privKeyLength, pubKeyLength]);
        free(sharedSecret);
        DH_free(dhOwnKey);
        return NO;
    }
    
    //Allocate memory for private and public keys
	if (!(privKey = malloc(sizeof(unsigned char) * privKeyLength))) {
		he(error,SecurityErrorDomain,SecurityEncryptError,NSLocalizedString(@"Could not allocate memory for bignum conversion of priv", @"RFBSecurityARD priv key malloc error text"));
		free(sharedSecret);
        DH_free(dhOwnKey);        
		return NO;
	}
	if (!(pubKey = malloc(sizeof(unsigned char) * pubKeyLength))) {
		he(error,SecurityErrorDomain,SecurityEncryptError,NSLocalizedString(@"Could not allocate memory for bignum conversion of pub", @"RFBSecurityARD priv key malloc error text"));
		free(privKey);
		free(sharedSecret);
        DH_free(dhOwnKey);        
		return NO;
	}
    
	//Convert stored priv and pub keys into big endian form
	if ((BN_bn2bin(dhOwnKey->priv_key, privKey)) <= 0 || (BN_bn2bin(dhOwnKey->pub_key, pubKey)) <= 0) {
		he(error,SecurityErrorDomain,SecurityEncryptError,NSLocalizedString(@"Could not convert keys into big endian form",@"RFBSecurityARD key conversion error text"));
		free(privKey);
		free(pubKey);
		free(sharedSecret);
        DH_free(dhOwnKey);        
		return NO;
	}
	
    //Duplicate string keys and free allocated pointers created in this method
    //Expect pointers to be pre-allocated with adequate memory already
    memcpy(dhResult->publicKey, pubKey, pubKeyLength);
    memcpy(dhResult->privateKey, privKey, privKeyLength);
    memcpy(dhResult->secretKey, sharedSecret, secretLength);
    dhResult->pubKeyLen = pubKeyLength;
    dhResult->privKeyLen = privKeyLength;
    dhResult->secKeyLen = secretLength;
	
    //TODO: malloc/free using OPENSSL_malloc/free for security?
	//Cleanup
    free(pubKey);
    free(privKey);
    free(sharedSecret);
	DH_free(dhOwnKey);
	
	return YES;
}

-(NSData *)performMD5OnData:(NSData *)wrappedData Error:(NSError **)error {
    //Error handling block
	HandleError he = [HandleErrors handleErrorBlock];
	
	if (!wrappedData) {
		he(error,SecurityErrorDomain,SecurityEncryptError,@"No data supplied for hashing!");
		return nil;
	}
	const unsigned char *unwrappedData = [wrappedData bytes];
	
	static int8_t digestLength = 16; //digest length must be 16 bytes of output
	unsigned char digest[digestLength];
	if (!(MD5(unwrappedData, (unsigned long)[wrappedData length], digest))) {
		he(error,SecurityErrorDomain,SecurityEncryptError,@"COuld not MD5 hash input data");
		return nil;
	}
		 
	//Wrap results and return
	return [NSData dataWithBytes:digest
						  length:digestLength];
}

-(NSData *)performAES128WithSecretKey:(NSData *)key ForPlaintext:(NSData *)text Error:(NSError **)error {
    //Error handling block
	HandleError handleError = [HandleErrors handleErrorBlock];
	
	if (!key || !text) {
		handleError(error,SecurityErrorDomain,SecurityEncryptError,@"Key or plaintext missing for encryption to take place");
		return nil;
	}
	const unsigned char *secretKey = [key bytes]; //symmetric
	const unsigned char *plaintext = [text bytes];
	
	//Check supplied Key is the same length as intended cipher
	const EVP_CIPHER *cipher = EVP_aes_128_ecb();
	int cipher_key_length = EVP_CIPHER_key_length(cipher);
	if ([key length] != cipher_key_length) {
		handleError(error,SecurityErrorDomain,SecurityEncryptError,[NSString stringWithFormat:@"Supplied key must be of length: %i", cipher_key_length]);
		return nil;
	}
	
	//Create EVP context
	EVP_CIPHER_CTX *context;
	if (!(context = EVP_CIPHER_CTX_new())) {
		handleError(error,SecurityErrorDomain,SecurityEncryptError,@"Could not initialise EVP context");
		return nil;
	}
	
	//Initialise encryption operation.  No IV as using AES_128_ECB, not CBC
	if ((EVP_EncryptInit_ex(context, cipher, NULL, secretKey, NULL)) != 1 ) {
		handleError(error,SecurityErrorDomain,SecurityEncryptError,@"Could not initialise encryption operation");
		EVP_CIPHER_CTX_free(context);
		return nil;
	}
	
	//Disable Padding
	//NOTE:  If the pad parameter is zero then no padding is performed, the total amount of data encrypted or decrypted must then be a multiple of the block size or an error will occur.
	EVP_CIPHER_CTX_set_padding(context, 0);
	
	//Encrypt plaintext
	int cipher_length, final_length;
	cipher_length = (int)[text length] + (EVP_CIPHER_block_size(cipher)-1); //Allow adequate room as per EVP man page
	unsigned char *ciphertext = malloc(sizeof(unsigned char) * cipher_length);
	if ((EVP_EncryptUpdate(context, ciphertext, &cipher_length, plaintext, (int)[text length])) != 1) {
		handleError(error,SecurityErrorDomain,SecurityEncryptError,@"Could not encrypt plaintext");
		free(ciphertext);
		EVP_CIPHER_CTX_free(context);
		return nil;
	}
	
	//Finalise encryption
    //Shouldn't add anything as padding disabled
	if ((EVP_EncryptFinal_ex(context, ciphertext, &final_length)) != 1) {
		handleError(error,SecurityErrorDomain,SecurityEncryptError,@"Could not finalise encryption of plaintext");
		free(ciphertext);
		EVP_CIPHER_CTX_free(context);
		return nil;
	}
	int ciphertextLen = final_length+cipher_length;
	
    //DLog(@"final_length %i, cipher_length %i", final_length, cipher_length);
    
	//Cleanup
	EVP_CIPHER_CTX_free(context);
	 
	//Return results
    return [NSData dataWithBytesNoCopy:ciphertext
                                length:ciphertextLen
                          freeWhenDone:YES];
}
@end
