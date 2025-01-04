//
//  MuxerConfig.m
//  AVPlayer
//
//  Created by 尹玉 on 2025/1/3.
//

#import "MuxerConfig.h"

@implementation MuxerConfig

- (instancetype)init {
    self = [super init];
    if (self) {
        _muxerType = MediaAV;
        _preferredTransform = CGAffineTransformIdentity;
    }
    return self;
}

@end

