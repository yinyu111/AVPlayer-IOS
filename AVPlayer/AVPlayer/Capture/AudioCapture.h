//
//  AudioCapture.h
//  AVPlayer
//
//  Created by 尹玉 on 2024/8/29.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import "AudioConfig.h"

#ifndef AudioCapture_h

@interface AudioCapture : NSObject
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithConfig:(AudioConfig *)config;

@property (nonatomic, strong, readonly) AudioConfig *config;
@property (nonatomic, copy) void (^sampleBufferOutputCallBack)(CMSampleBufferRef sample); // 音频采集数据回调。
@property (nonatomic, copy) void (^errorCallBack)(NSError *error); // 音频采集错误回调。

- (void)startRunning; // 开始采集音频数据。
- (void)stopRunning; // 停止采集音频数据。
@end

#define AudioCapture_h


#endif /* AudioCapture_h */
