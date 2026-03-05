// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-au-host

#import <AudioToolbox/AudioToolbox.h>
#import "AudioUnitStateC.h"

@implementation AudioUnitStateC

/// Must notify the host that a parameter has been changed, blast out all parameters with this function
/// useful in the case of preset loading
+ (OSStatus)notifyAudioUnitListener:(AudioUnit)audioUnit {
    //  Get number of parameters in this unit (size in bytes really):
    UInt32 parameterListSize = 0;
    OSStatus status;

    status = AudioUnitGetPropertyInfo(audioUnit,
                                      kAudioUnitProperty_ParameterList,
                                      kAudioUnitScope_Global,
                                      0,
                                      &parameterListSize,
                                      NULL);

    if (noErr != status) {
        return status;
    }

    //  Get ids for the parameters:
    AudioUnitParameterID *parameterIDs = malloc(parameterListSize);
    status = AudioUnitGetProperty(audioUnit,
                                  kAudioUnitProperty_ParameterList,
                                  kAudioUnitScope_Global,
                                  0,
                                  parameterIDs,
                                  &parameterListSize);

    if (noErr != status) {
        free(parameterIDs);
        return status;
    }

    AudioUnitParameterInfo parameterInfo_t;
    UInt32 parameterInfoSize = sizeof(AudioUnitParameterInfo);
    UInt32 parametersCount = parameterListSize / sizeof(AudioUnitParameterID);

    for (UInt32 pIndex = 0; pIndex < parametersCount; pIndex++) {
        if (noErr == AudioUnitGetProperty(audioUnit,
                                          kAudioUnitProperty_ParameterInfo,
                                          kAudioUnitScope_Global,
                                          parameterIDs[pIndex],
                                          &parameterInfo_t,
                                          &parameterInfoSize)) {
            AudioUnitEvent ev;
            ev.mEventType = kAudioUnitEvent_ParameterValueChange;
            ev.mArgument.mParameter.mAudioUnit = audioUnit;
            ev.mArgument.mParameter.mParameterID = parameterIDs[pIndex];
            ev.mArgument.mParameter.mScope = kAudioUnitScope_Global;
            ev.mArgument.mParameter.mElement = 0;

            // Notify any listeners (i.e. the plugin's editor) that the parameter has been changed.
            AUEventListenerNotify(NULL, NULL, &ev);
        }
    }

    free(parameterIDs);

    return status;
}

@end
