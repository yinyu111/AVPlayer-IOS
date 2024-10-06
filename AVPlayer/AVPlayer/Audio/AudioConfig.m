//
//  AudioConfig.m
//  AVPlayer
//
//  Created by 尹玉 on 2024/8/29.
//

#import <Foundation/Foundation.h>
#import "AudioConfig.h"

@implementation AudioConfig

+ (instancetype)defaultConfig {
    AudioConfig *config = [[self alloc] init];
    config.sampleRate = 44100;
    config.bitDepth = 16;
    config.channels = 2;

    return config;
}

@end
