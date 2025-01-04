//
//  MP4Muxer.h
//  AVPlayer
//
//  Created by 尹玉 on 2025/1/3.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import "MuxerConfig.h"

NS_ASSUME_NONNULL_BEGIN

@interface  MP4Muxer : NSObject
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithConfig:(MuxerConfig *)config;

@property (nonatomic, strong, readonly) MuxerConfig *config;
@property (nonatomic, copy) void (^errorCallBack)(NSError *error); // 封装错误回调。

- (void)startWriting; // 开始写入封装数据。
- (void)cancelWriting; // 取消写入封装数据。
- (void)appendSampleBuffer:(CMSampleBufferRef)sampleBuffer; // 添加封装数据。
- (void)stopWriting:(void (^)(BOOL success, NSError *error))completeHandler; // 停止写入封装数据。
@end



NS_ASSUME_NONNULL_END
