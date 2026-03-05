// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-au-host

#import <AudioToolbox/AudioToolbox.h>
#import "AudioUnitFactoryPresets.h"

@implementation AudioUnitFactoryPresets

+ (OSStatus)loadFactoryPreset:(AudioUnit)audioUnit
                        named:(NSString *)name {
    OSStatus status;

    // Retrieve the list of factory presets
    CFArrayRef array;
    UInt32 dataSize = sizeof(CFArrayRef);

    status = AudioUnitGetProperty(
        audioUnit,
        kAudioUnitProperty_FactoryPresets,
        kAudioUnitScope_Global,
        0,
        &array,
        &dataSize);

    if (status != noErr) {
        return status;
    }

    long count = CFArrayGetCount(array);
    int index = -1;

    // find the index of the preset
    for (int i = 0; i < count; i++) {
        AUPreset *preset = (AUPreset *)CFArrayGetValueAtIndex(array, i);

        if (CFStringCompare(preset->presetName, (__bridge CFStringRef)name, 0) == kCFCompareEqualTo) {
            index = i;
            break;
        }
    }

    if (index < 0) {
        CFRelease(array);
        return kAudioUnitErr_InvalidPropertyValue;
    }

    AUPreset *preset = (AUPreset *)CFArrayGetValueAtIndex(array, index);

    status = AudioUnitSetProperty(
        audioUnit,
        kAudioUnitProperty_PresentPreset,
        kAudioUnitScope_Global,
        0,
        preset,
        sizeof(AUPreset));

    if (status == noErr) {
        AudioUnitParameter aup;
        aup.mAudioUnit = audioUnit;
        aup.mParameterID = kAUParameterListener_AnyParameter;
        aup.mScope = kAudioUnitScope_Global;
        aup.mElement = 0;
        AUParameterListenerNotify(NULL, NULL, &aup);
    }

    CFRelease(array);

    return status;
}

@end
