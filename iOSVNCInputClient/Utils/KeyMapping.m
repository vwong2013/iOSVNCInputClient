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

#import "KeyMapping.h"

#define XK_MISCELLANY //Needs to be before importing keysymdef for TTY keys in keysymdef.h to function
#include "keysymdef.h"

@implementation KeyMapping

//TODO: Implement larger character set?
+ (UInt32)unicharToX11KeySym:(unichar)ch;
{
    UInt32 mappedKeyValue;
    
    // Latin-1 characters
    if (((ch >= 0x20) && (ch <= 0x7E)) || ((ch >= 0xA0) && (ch <= 0xFF))) {
        mappedKeyValue = ch;
    } else if (ch == 0x08) {    // backspace
        mappedKeyValue = XK_BackSpace;
    } else if (ch == 0x0A) {    // linefeed
        //FIXME: Not sure if will keep this config but will do so for now.  Needed to Return to work in OS X
        //mappedKeyValue = XK_Linefeed;
        mappedKeyValue = XK_Return;
    } else if (ch == 0x0D) {    // carriage return
        mappedKeyValue = XK_Return;
    } else if (ch == 0x0F) {    // delete
        mappedKeyValue = XK_Delete;
    }else {
        // Deal with unichars from extensions of keysym as per below paragraph from keysymdef.h:
		/*
		 * For any future extension of the keysyms with characters already
		 * found in ISO 10646 / Unicode, the following algorithm shall be
		 * used. The new keysym code position will simply be the character's
		 * Unicode number plus 0x01000000. The keysym values in the range
		 * 0x01000100 to 0x0110ffff are reserved to represent Unicode
		 * characters in the range U+0100 to U+10FFFF.
		 */
        mappedKeyValue = ch | 0x01000000;
    }
    
    return mappedKeyValue;
}

@end
