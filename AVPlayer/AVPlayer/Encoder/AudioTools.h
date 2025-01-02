//
//  AudioTools.h
//  AVPlayer
//
//  Created by 尹玉 on 2024/12/25.
//

#ifndef AudioTools_h
#define AudioTools_h

@interface AudioTools : NSObject

// 按音频参数生成 AAC packet 对应的 ADTS 头数据。
+ (NSData *)adtsDataWithChannels:(NSInteger)channels sampleRate:(NSInteger)sampleRate rawDataLength:(NSInteger)rawDataLength;

@end

#endif /* AudioTools_h */
