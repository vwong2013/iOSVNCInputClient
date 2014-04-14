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

#import "ProfileSaverFetcher.h"
#import "ServerProfile.h"
#import "Des.h"

#import "ErrorHandlingMacros.h"
#import "HandleErrors.h"

#define SAVE_DIR NSDocumentDirectory
#define URL_MASK NSUserDomainMask
//See props in ServerProfile class
#define PROFILE_DICT_KEYS @"ServerName, ServerVersion, Address, Port, Username, Password, ARD35, MacAuth"

@implementation ProfileSaverFetcher
#pragma mark - Private Methods
+(NSFileManager *)fMg {
	return [NSFileManager defaultManager];
}

//Assemble save URL
+(NSURL *)saveURL {
	NSURL *saveURL = [[[self fMg] URLsForDirectory:SAVE_DIR inDomains:URL_MASK] objectAtIndex:0];
	if (saveURL)
		return saveURL;
	return nil; //if path not found
}

//Desired list of properties from URL
+(NSArray *)desiredURLProps {
	return @[NSURLIsRegularFileKey, NSURLIsReadableKey, NSURLIsWritableKey,NSURLLocalizedNameKey,NSURLNameKey,NSURLTypeIdentifierKey];
}

//Check if URL is 'valid' and return resource values for purposes of app
+(NSDictionary *)savedProfileURLResourceKeys:(NSURL *)url {
	NSError *error = nil;
	NSNumber *regFile, *writable, *readable = nil;
	
	NSDictionary *resourceValues = [url resourceValuesForKeys:[self desiredURLProps]
														error:&error];
	
	if (!resourceValues || error) {
		DLogErr(@"Could not check file attributes for URL %@, error: %@, %@", [url path], [error localizedDescription], [error localizedFailureReason]);
		return nil;
	}
	
	regFile = [resourceValues objectForKey:NSURLIsRegularFileKey];
	writable = [resourceValues objectForKey:NSURLIsWritableKey];
	readable = [resourceValues objectForKey:NSURLIsReadableKey];
	
	if (![regFile boolValue] || ![writable boolValue] || ![readable boolValue]) {
		DLogWar(@"URL %@ is either not a regular file, readable or writeable", [url path]);
		return nil;
	}
	
	return resourceValues;
}

//Compare profile against all existing saved profile
+(BOOL)isProfileAlreadySaved:(ServerProfile *)pendingProfile Error:(NSError **)error {
    //Get list of all saved profile
    NSArray *savedURLs = [[self class] fetchSavedProfilesURLList:error];
    
    if (!savedURLs)
        return YES; //Assumes profile "saved" if failed to retrieve save list
    if (savedURLs.count == 0)
        return NO;
    
    //Hash pending profile
    NSUInteger pendingHash = [pendingProfile hash];
    
    //Enumerate through list and compare
    __block NSError *blockError = nil;
    __block BOOL matchFound = NO;
    [savedURLs enumerateObjectsUsingBlock:^(NSURL *savedUrl, NSUInteger idx, BOOL *stop) {
        ServerProfile *savedProfile = [[self class] readSavedProfileFromURL:savedUrl Error:&blockError];
        NSUInteger savedHash = [savedProfile hash];
        if (savedHash == pendingHash) {
            matchFound = YES;
            *stop = YES;
        }
    }];
    
    return matchFound;
}

#pragma mark - Public Methods
//Save/Update Profile Into File
+(BOOL)saveServerProfile:(ServerProfile *)serverProfile ToURL:(NSURL *)targetUrl Error:(NSError **)error {
	//Get error handling block
	HandleError handleE = [HandleErrors handleErrorBlock];
	
	//Create save URL
	NSURL *profileURL = targetUrl;
    if (!targetUrl) {
        NSNumber *saveTimestamp = [NSNumber numberWithDouble:[NSDate timeIntervalSinceReferenceDate]];
        profileURL = [[[self class] saveURL] URLByAppendingPathComponent:[saveTimestamp stringValue]];
    }
    
	if (!profileURL) {
        NSString *errorMsg = NSLocalizedString(@"Failed to form URL for saving server profile", @"ProfileSF create save url error text");
		handleE(error, FileErrorDomain, FileSaveError, [NSString stringWithFormat:@"%@", errorMsg]);
		return NO;
	}
	
	//Check if existing profile already saved
	if ([[self class] isProfileAlreadySaved:serverProfile Error:error] && !targetUrl) {
		handleE(error, FileErrorDomain, FileDuplicateError, NSLocalizedString(@"Server profile with same servername/address/username/password already exists",@"ProfileSF duplicate save profile error text"));
		return NO;
	}
	
	//Encrypt certain fields
	NSString *encryptedPassword = [Des encryptText:serverProfile.password
                                             WithKey:nil];
	if (encryptedPassword.length == 0 && serverProfile.password.length != 0) {
		handleE(error, SecurityErrorDomain, SecurityEncryptError, [NSString stringWithFormat:@"Could not encrypt with fallback key"]);
		return NO;
	}
	
	//Extract rest of values from profile object
	NSArray *profileProps = @[serverProfile.serverName, serverProfile.serverVersion, serverProfile.address, [NSNumber numberWithInt:serverProfile.port], serverProfile.username, encryptedPassword, [NSNumber numberWithBool:serverProfile.ard35Compatibility], [NSNumber numberWithBool:serverProfile.macAuthentication]];
	NSArray *profileKeys = [PROFILE_DICT_KEYS componentsSeparatedByString:@", "];
	NSDictionary *plistDict = [NSDictionary dictionaryWithObjects:profileProps
														  forKeys:profileKeys];
	
	//Turn into NSData blob
	NSError *dataErr = nil;
	NSData *plistData = [NSPropertyListSerialization dataWithPropertyList:plistDict
																   format:NSPropertyListXMLFormat_v1_0
																  options:0
																	error:&dataErr];
	if (!plistData || dataErr) {
		*error = dataErr;
		return NO;
	}

	//Save file
	if ([plistData writeToURL:profileURL
				   atomically:YES])
		return YES;
	else {
		handleE(error, FileErrorDomain, FileSaveError, [NSString stringWithFormat:@"Failed to save server profile to URL %@", profileURL]);
		return NO;
	}
}

//Restore Profile From File
+(ServerProfile *)readSavedProfileFromURL:(NSURL *)url Error:(NSError **)error {
	//Get error handling block
	HandleError handleError = [HandleErrors handleErrorBlock];
	
	//Check if URL valid
	if (![[self fMg] fileExistsAtPath:[url path]]) {
		handleError(error, FileErrorDomain, FileExistReadError, [NSString stringWithFormat:@"Saved Server Profile does not exist at: %@", [url path]]);
		return nil;
	}
	
	//Retrieve data from url
	NSData *plistData = [[self fMg] contentsAtPath:[url path]];
	//NSPropertyListFormat plistFormat;
	NSError *dictError = nil;;
	NSDictionary *plistDict = [NSPropertyListSerialization propertyListWithData:plistData
																		options:NSPropertyListMutableContainersAndLeaves
                                                                         format:NULL//&plistFormat
																		  error:&dictError];
	if (!plistDict) {
		*error = dictError;
		return nil;
	}
	
	//Decrypt certain fields
	NSString *password = [Des decryptText:[plistDict objectForKey:@"Password"]
                                  WithKey:nil];
	if (!password || password.length == 0) {
		handleError(error, SecurityErrorDomain, SecurityDecryptError, [NSString stringWithFormat:@"Could not decrypt: %@", [plistDict objectForKey:@"Password"]]);
		return nil;
	}
	
	//Restore details to new Profile
	ServerProfile *serverProfile = [[ServerProfile alloc] initWithAddress:[plistDict objectForKey:@"Address"]
													Port:[[plistDict objectForKey:@"Port"] intValue]
												Username:[plistDict objectForKey:@"Username"]
												Password:password
											  ServerName:[plistDict objectForKey:@"ServerName"]
										   ServerVersion:[plistDict objectForKey:@"ServerVersion"]
												   ARD35:[[plistDict objectForKey:@"ARD35"] boolValue]
												 MacAuth:[[plistDict objectForKey:@"MacAuth"] boolValue]];
	
	if (!serverProfile) {
		handleError(error, FileErrorDomain, FileReadError, [NSString stringWithFormat:@"Could not restore saved Profile with dict: %@", plistDict]);
		return nil;
	}
	
	return serverProfile;
}

//Delete Profile Given URL
+(BOOL)deleteSavedProfileFromURL:(NSURL*)url Error:(NSError **)error {
	//Get error handling block
	HandleError handleError = [HandleErrors handleErrorBlock];
	
	//Perform deletion
	if ([[self fMg] removeItemAtURL:url
							  error:error]) {
		if ([[self fMg] fileExistsAtPath:[url path]]) {
			handleError(error, FileErrorDomain, FileExistReadError, [NSString stringWithFormat:@"Server Profile delete encountered error: %@", [*error localizedDescription]]);
			return NO; //File still present, means delete failed
		}
		
		return YES;  //return YES if deletion successful, ie. file no longer found at url
	}
	
	return NO; //Default if save fails
}

//Read Contents of Directory For Saved Profiles
+(NSArray *)fetchSavedProfilesURLList:(NSError **)error {
	//Assume first retrieved dir is the one we want to grab stuff from
	NSURL *savedURL = [[self class] saveURL];
	NSArray *savedDirContents = [[self fMg] contentsOfDirectoryAtURL:savedURL
										  includingPropertiesForKeys:[self desiredURLProps]
															 options:NSDirectoryEnumerationSkipsHiddenFiles
															   error:error];
	return savedDirContents; //No error checking since nil is returned anyways if it bombs out, + error gets filled in
}

//Parse Given Filename for Title and Subtitle
+(NSDictionary *)fetchTitleAndSubtitleFromURL:(NSURL *)url {
	//Check if URL valid
	if (![[self fMg] fileExistsAtPath:[url path]]) {
		return nil;
	}
	
	//Retrieve data from url
	NSData *plistData = [[self fMg] contentsAtPath:[url path]];
	NSDictionary *plistDict = [NSPropertyListSerialization propertyListWithData:plistData
																		options:NSPropertyListMutableContainersAndLeaves
                                                                         format:NULL
																		  error:nil];
	if (!plistDict) {
		return nil;
	}
    
    //Parse xml and retrieve name and address
    NSString *title = [plistDict objectForKey:@"ServerName"];
	NSString *subtitle = [plistDict objectForKey:@"Address"];
    
    if (!title || title.length == 0) 
        return nil;
    if (!subtitle || subtitle.length == 0)
        return nil;
    
	return @{PROFILE_TITLE_KEY:title, PROFILE_SUBTITLE_KEY:subtitle};
}
@end
