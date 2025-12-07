// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-au-host

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AudioUnitFactoryPresets : NSObject

+ (OSStatus)loadFactoryPreset:(AudioUnit)audioUnit
                        named:(NSString *)name;

@end

NS_ASSUME_NONNULL_END
