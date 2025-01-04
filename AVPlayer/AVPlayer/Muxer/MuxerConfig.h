//
//  MuxerConfig.h
//  AVPlayer
//
//  Created by 尹玉 on 2025/1/3.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "MediaBase.h"

#ifndef MuxerConfig_h
#define MuxerConfig_h

@interface MuxerConfig : NSObject
@property (nonatomic, strong) NSURL *outputURL; // 封装文件输出地址。
@property (nonatomic, assign) MediaType muxerType; // 封装文件类型。
@property (nonatomic, assign) CGAffineTransform preferredTransform; // 图像的变换信息。比如：视频图像旋转。
@end


#endif /* MuxerConfig_h */
