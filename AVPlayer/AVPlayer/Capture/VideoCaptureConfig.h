//
//  VideoCaptureConfig.h
//  AVPlayer
//
//  Created by 尹玉 on 2025/1/14.
//

#ifndef VideoCaptureConfig_h
#define VideoCaptureConfig_h

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, VideoCaptureMirrorType) {
    VideoCaptureMirrorNone = 0,
    VideoCaptureMirrorFront = 1 << 0,
    VideoCaptureMirrorBack = 1 << 1,
    VideoCaptureMirrorAll = (VideoCaptureMirrorFront | VideoCaptureMirrorBack),
};

@interface VideoCaptureConfig : NSObject
@property (nonatomic, copy) AVCaptureSessionPreset preset; // 视频采集参数，比如分辨率等，与画质相关。
@property (nonatomic, assign) AVCaptureDevicePosition position; // 摄像头位置，前置/后置摄像头。
@property (nonatomic, assign) AVCaptureVideoOrientation orientation; // 视频画面方向。
@property (nonatomic, assign) NSInteger fps; // 视频帧率。
@property (nonatomic, assign) OSType pixelFormatType; // 颜色空间格式。
@property (nonatomic, assign) VideoCaptureMirrorType mirrorType; // 镜像类型。
@end

NS_ASSUME_NONNULL_END

#endif /* VideoCaptureConfig_h */
