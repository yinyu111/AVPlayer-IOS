//
//  VideoCapture.h
//  AVPlayer
//
//  Created by 尹玉 on 2025/1/14.
//

#ifndef VideoCapture_h
#define VideoCapture_h


#import <Foundation/Foundation.h>
#import "VideoCaptureConfig.h"

NS_ASSUME_NONNULL_BEGIN

@interface VideoCapture : NSObject
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithConfig:(VideoCaptureConfig *)config;

@property (nonatomic, strong, readonly) VideoCaptureConfig *config;
@property (nonatomic, strong, readonly) AVCaptureVideoPreviewLayer *previewLayer; // 视频预览渲染 layer。
@property (nonatomic, copy) void (^sampleBufferOutputCallBack)(CMSampleBufferRef sample); // 视频采集数据回调。
@property (nonatomic, copy) void (^sessionErrorCallBack)(NSError *error); // 视频采集会话错误回调。
@property (nonatomic, copy) void (^sessionInitSuccessCallBack)(void); // 视频采集会话初始化成功回调。

- (void)startRunning; // 开始采集。
- (void)stopRunning; // 停止采集。
- (void)changeDevicePosition:(AVCaptureDevicePosition)position; // 切换摄像头。

@end

NS_ASSUME_NONNULL_END

#endif /* VideoCapture_h */

