//
//  MediaBase.h
//  AVPlayer
//
//  Created by 尹玉 on 2025/1/3.
//

#ifndef MediaBase_h
#define MediaBase_h

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, MediaType) {
    MediaNone = 0,
    MediaAudio = 1 << 0, // 仅音频。
    MediaVideo = 1 << 1, // 仅视频。
    MediaAV = MediaAudio | MediaVideo,  // 音视频都有。
};

#endif /* MediaBase_h */
