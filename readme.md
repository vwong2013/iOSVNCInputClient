## iOSVNCInputClient
---
iOSVNCInputClient is a VNC input only client for devices running iOS 5.1 and above.  It is designed to simulate mouse and keyboard input on a iOS device, over a (local) network to a connected remote computer using the RFB protocol.

### Features
---
*  VNC "None", VNC password and Apple Remote Desktop (OS X) authentication supported using the OpenSSL toolkit
*  iOS standard keyboard remote computer input
*  Mouse input by simulating trackpad.  Left, right, simultaneous left and right click, left click hold (for dragging) and vertical scroll wheel supported.
*  Automatic VNC server service discovery via Bonjour zero-configuration networking over IP.
*  IP v4 and v6 address support.
*  iOS 7 64bit compatible.

### Building
---
Download GCDAsyncSocket from [here](https://github.com/robbiehanson/CocoaAsyncSocket/) and copy files into the '3rdParty/CocaAsyncSocket' folder.  Only the TCP version of GCDAsyncSocket is required.

Download OpenSSL [source](https://www.openssl.org/source/), compile and copy libcrypto.a into '3rdParty/OpenSSL' folder.  Copy contents of the 'include' folder from the OpenSSL source into the '3rdParty/OpenSSL/include' folder.  An easy way to compile OpenSSL is via the [OpenSSL-for-iOS](https://github.com/x2on/OpenSSL-for-iPhone) project.

The project should already be setup to look for those files in the locations mentioned above, so no further configuration should be necessary for building the app.

### Usage
---
Windows users will require a 3rd party VNC server app (e.g. TightVNC) to be able to use this app to connect to their PC.  OSX users have to enable Screen Sharing.  Linux users need to launch whatever VNC server app is included in their distro, eg. vino for Ubuntu users.

*  Tap on 'Add VNC Server' to setup a connection profile for the computer / device running a VNC server that you wish to remotely control.  
*  Tap on 'Search for Servers' to search the immediate local network on which the iOS device running this app is connected to for computers / devices on the network that are running a VNC server service.  Selecting a device will take you to the same 'Add VNC Server' page, but with the server details pre filled.
*  Saved connection profiles are displayed in the main app screen under 'Saved Devices'.  Tapping on the profile will initiate the connection to the remote computer in that profile.
*  Edit profiles by tapping on the 'Edit' button in the app's home screen, then tapping on the profile to be modified.  The '-' icon deletes the selected profile.
*  Once connected, the app will stay connected to the remote computer unless it is either terminated, or the back button is pressed to go back to the home screen.

### Known Issues 
---
* In some rare occasions, Apple Remote Desktop authentication will fail with a incorrect login error even if login details are correct.  This is caused by OpenSSL not generating the correct DH public/private key lengths.  For now, workaround is to re-attempt the authentication by going back to the app's home screen and then trying again.  It should authenticate fine in the second attempt.  
* Service Discovery may not work with Windows-based VNC server apps
* You must press "Return" after editing a field in a Profile before clicking on "Save" for changes to be saved.
* Profile password sometimes fails to be decrypted

### Misc Notes
---
*  Target valid architectures is set to armv7 and armv7s aka 32-bit only for iOS 5 compatibility (64-bit silvers cannot be opened on iOS 5)

 
### Roadmap
---
*  Fix known issues
*  Remove GCDAsyncSocket and use Foundation/CF Api's, or modify code to take proper advantage of GCDAyncSocket's delegate-protocol usage method.
*  Add special key (i.e. Alt, Ctrl, Windows key, Command key, etc) support for keyboard input
*  Implement more secure encryption method for stored server profile credentials
*  Tweak mouse scaling
*  Remove device specific view controllers where possible (Had to implement these as storyboards did not recognise property outlets)
*  General code cleanup and optimisation

### Why
---
I needed a VNC input only client app for iOS devices for another project but could not find open source apps / libraries online that either weren't outdated/abandoned or under restrictive (GPLv2) licensing.  (After I wrote this app, I discovered [TinyVNC](https://github.com/sergeystoma/tinyvnc)... oh well)

For Android however I did find an app called [Valence](http://cafbit.com/valence/) that was very close to my needs.  My other project was based on running on iOS however, so I decided to use Valence as a guide, along with reading the [VNC RFB 3.8 protocol specification](www.realvnc.com/docs/rfbproto.pdf) to create this app.  

RFB protocol object model is based on Valence, but modified, with underlying methods rewritten from scratch.

### Changelog
---

* 2014-Apr-14 Minor bug fixes, updated Known Issues, minor code cleanup
* 2014-Jan-24	Initial Public Release

### Licensing
---
iOSVNCInputClient is licensed under the [Apache 2.0 License](http://www.apache.org/licenses/LICENSE-2.0).

This product includes software developed by the OpenSSL Project for use in the OpenSSL Toolkit. [http://www.openssl.org/](http://www.openssl.org/)

This product includes cryptographic software written by Eric Young (eay@cryptsoft.com)

OpenSSL licenses: [https://www.openssl.org/source/license.html](https://www.openssl.org/source/license.html), Apache-style.

[CocoaAsyncSocket](https://github.com/robbiehanson/CocoaAsyncSocket/wiki/License) originally by Robbie Hanson, public domain.

**The following files are included in the provided source code for convenience.  See respective source files for full license text.**

BDHost is by [Brian Dunagan](http://bdunagan.com/2009/11/28/iphone-tip-no-nshost/), MIT License.

keysymdef.h is copyright The Open Group and Digital Equipment Corporation, MIT-style license.