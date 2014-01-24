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

#ifndef ErrorHandlingMacros_h
#define ErrorHandlingMacros_h

//Error domains
#define SocketErrorDomain @"vwong2013.socketError"
#define FileErrorDomain @"vwong2013.fileError"
#define SecurityErrorDomain @"vwong2013.securityError"
#define ObjectErrorDomain @"vwong2013.objectError"

//Error codes
#define SocketReadError 100
#define SocketConnectError 110
#define SocketSecurityError 120

#define FileSaveError 200
#define FileReadError 210
#define FileExistReadError 211
#define FileDuplicateError 220

#define SecurityDecryptError 300
#define SecurityEncryptError 310

#define ObjectInitError 400
#define ObjectMethodReturnError 410
#define ObjectNotFoundError 420

#endif
