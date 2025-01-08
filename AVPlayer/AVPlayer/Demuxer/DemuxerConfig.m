//
//  DemuxerConfig.m
//  AVPlayer
//
//  Created by 尹玉 on 2025/1/6.
//

#import "DemuxerConfig.h"

@implementation DemuxerConfig

- (instancetype)init {
    self = [super init];
    if (self) {
        _demuxerType = MediaAV;
    }
    
    return self;
}

@end
