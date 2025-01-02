//
//  AudioEncoder.h
//  AVPlayer
//
//  Created by 尹玉 on 2024/12/25.
//

#ifndef AudioEncoder_h
#define AudioEncoder_h

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>

@interface AudioEncoder : NSObject
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithAudioBitrate:(NSInteger)audioBitrate;

@property (nonatomic, assign, readonly) NSInteger audioBitrate; // 音频编码码率。
@property (nonatomic, copy) void (^sampleBufferOutputCallBack)(CMSampleBufferRef sample); // 音频编码数据回调。
@property (nonatomic, copy) void (^errorCallBack)(NSError *error); // 音频编码错误回调。

- (void)encodeSampleBuffer:(CMSampleBufferRef)buffer; // 编码。
@end



#endif /* AudioEncoder_h */
