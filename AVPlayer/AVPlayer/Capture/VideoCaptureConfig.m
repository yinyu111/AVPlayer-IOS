//
//  VideoCaptureConfig.m
//  AVPlayer
//
//  Created by 尹玉 on 2025/1/14.
//

#import "VideoCaptureConfig.h"

@implementation VideoCaptureConfig

- (instancetype)init {
    self = [super init];
    if (self) {
        _preset = AVCaptureSessionPreset1920x1080;
        _position = AVCaptureDevicePositionFront;
        _orientation = AVCaptureVideoOrientationPortrait;
        _fps = 30;
        _mirrorType = VideoCaptureMirrorFront;

        // 设置颜色空间格式：
        // 1、一般采集图像用于后续的编码时，这里设置 kCVPixelFormatType_420YpCbCr8BiPlanarFullRange 即可。
        // 2、如果想支持 HDR 时（iPhone12 及之后设备才支持），这里设置为：kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange。
        _pixelFormatType = kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange;
    }
    
    return self;
}

@end
