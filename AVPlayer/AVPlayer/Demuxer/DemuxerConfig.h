//
//  DemuxerConfig.h
//  AVPlayer
//
//  Created by 尹玉 on 2025/1/6.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import "MediaBase.h"

NS_ASSUME_NONNULL_BEGIN

@interface  DemuxerConfig : NSObject
@property (nonatomic, strong) AVAsset *asset; // 待解封装的资源。
@property (nonatomic, assign) MediaType demuxerType; // 解封装类型。
@end

NS_ASSUME_NONNULL_END
