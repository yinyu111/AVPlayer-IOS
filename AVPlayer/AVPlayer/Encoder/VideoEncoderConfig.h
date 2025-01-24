//
//  VideoEncoderConfig.h
//  AVPlayer
//
//  Created by 尹玉 on 2025/1/22.
//

#ifndef VideoEncoderConfig_h
#define VideoEncoderConfig_h

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface VideoEncoderConfig : NSObject
@property (nonatomic, assign) CGSize size; // 分辨率。
@property (nonatomic, assign) NSInteger bitrate; // 码率。
@property (nonatomic, assign) NSInteger fps; // 帧率。
@property (nonatomic, assign) NSInteger gopSize; // GOP 帧数。
@property (nonatomic, assign) BOOL openBFrame; // 编码是否使用 B 帧。
@property (nonatomic, assign) CMVideoCodecType codecType; // 编码器类型。
@property (nonatomic, assign) NSString *profile; // 编码 profile。
@end

NS_ASSUME_NONNULL_END


#endif /* VideoEncoderConfig_h */
