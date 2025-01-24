//
//  VideoEncoderConfig.m
//  AVPlayer
//
//  Created by 尹玉 on 2025/1/22.
//

#import <VideoToolBox/VideoToolBox.h>
#import "VideoEncoderConfig.h"

@implementation VideoEncoderConfig

- (instancetype)init {
    self = [super init];
    if (self) {
        _size = CGSizeMake(1080, 1920);
        _bitrate = 5000 * 1024;
        _fps = 30;
        _gopSize = _fps * 5;
        _openBFrame = YES;
        
        BOOL supportHEVC = NO;
        if (@available(iOS 11.0, *)) {
            if (&VTIsHardwareDecodeSupported) {
                supportHEVC = VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC);
            }
        }
        
        _codecType = supportHEVC ? kCMVideoCodecType_HEVC : kCMVideoCodecType_H264;
        _profile = supportHEVC ? (__bridge NSString *) kVTProfileLevel_HEVC_Main_AutoLevel : AVVideoProfileLevelH264HighAutoLevel;
    }
    
    return self;
}

@end

