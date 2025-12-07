// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-au-host

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

@interface AudioUnitStateC : NSObject

+ (OSStatus)notifyAudioUnitListener:(AudioUnit)audioUnit;

@end
