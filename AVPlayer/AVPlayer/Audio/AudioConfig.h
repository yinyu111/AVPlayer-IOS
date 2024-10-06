//
//  AudioConfig.h
//  AVPlayer
//
//  Created by 尹玉 on 2024/8/29.
//

#import <Foundation/Foundation.h>

#ifndef AudioConfig_h

@interface AudioConfig : NSObject
+ (instancetype)defaultConfig;

@property (nonatomic, assign) NSUInteger sampleRate; // 采样率，default: 44100。
@property (nonatomic, assign) NSUInteger bitDepth; // 量化位深，default: 16。
@property (nonatomic, assign) NSUInteger channels; // 声道数，default: 2。
@end

#define AudioConfig_h


#endif /* AudioConfig_h */
