//
//  VideoEncoder.h
//  AVPlayer
//
//  Created by 尹玉 on 2025/1/22.
//

#ifndef VideoEncoder_h
#define VideoEncoder_h

#import <Foundation/Foundation.h>
#import "VideoEncoderConfig.h"

NS_ASSUME_NONNULL_BEGIN

@interface VideoEncoder : NSObject
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithConfig:(VideoEncoderConfig*)config;

@property (nonatomic, strong, readonly) VideoEncoderConfig *config; // 视频编码配置参数。
@property (nonatomic, copy) void (^sampleBufferOutputCallBack)(CMSampleBufferRef sampleBuffer); // 视频编码数据回调。
@property (nonatomic, copy) void (^errorCallBack)(NSError *error); // 视频编码错误回调。

- (void)encodePixelBuffer:(CMSampleBufferRef)sampleBuffer ptsTime:(CMTime)timeStamp; // 编码。
- (void)refresh; // 刷新重建编码器。
- (void)flush; // 清空编码缓冲区。
- (void)flushWithCompleteHandler:(void (^)(void))completeHandler; // 清空编码缓冲区并回调完成。
@end

NS_ASSUME_NONNULL_END

#endif /* VideoEncoder_h */
