//
//  KFRemuxerViewController.m
//  KFAVDemo
//  微信搜索『gzjkeyframe』关注公众号『关键帧Keyframe』获得最新音视频技术文章和进群交流。
//  Created by [公众号：关键帧Keyframe].
//

#import "VideoRemuxerViewController.h"
#import "MP4Demuxer.h"
#import "MP4Muxer.h"

@interface VideoRemuxerViewController ()
@property (nonatomic, strong) DemuxerConfig *demuxerConfig;
@property (nonatomic, strong) MP4Demuxer *demuxer;
@property (nonatomic, strong) MuxerConfig *muxerConfig;
@property (nonatomic, strong) MP4Muxer *muxer;
@end

@implementation VideoRemuxerViewController
#pragma mark - Property
- (DemuxerConfig *)demuxerConfig {
    if (!_demuxerConfig) {
        _demuxerConfig = [[DemuxerConfig alloc] init];
        _demuxerConfig.demuxerType = MediaAV;
        NSString *videoPath = [[NSBundle mainBundle] pathForResource:@"input" ofType:@"mp4"];
        _demuxerConfig.asset = [AVAsset assetWithURL:[NSURL fileURLWithPath:videoPath]];
    }
    
    return _demuxerConfig;
}

- (MP4Demuxer *)demuxer {
    if (!_demuxer) {
        _demuxer = [[MP4Demuxer alloc] initWithConfig:self.demuxerConfig];
        _demuxer.errorCallBack = ^(NSError *error) {
            NSLog(@"KFMP4Demuxer error:%zi %@", error.code, error.localizedDescription);
        };
    }
    
    return _demuxer;
}

- (MuxerConfig *)muxerConfig {
    if (!_muxerConfig) {
        _muxerConfig = [[MuxerConfig alloc] init];
        NSString *videoPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"output.mp4"];
        NSLog(@"MP4 file path: %@", videoPath);
        [[NSFileManager defaultManager] removeItemAtPath:videoPath error:nil];
        _muxerConfig.outputURL = [NSURL fileURLWithPath:videoPath];
        _muxerConfig.muxerType = MediaAV;
    }
    
    return _muxerConfig;
}

- (MP4Muxer *)muxer {
    if (!_muxer) {
        _muxer = [[MP4Muxer alloc] initWithConfig:self.muxerConfig];
    }
    
    return _muxer;
}

#pragma mark - Lifecycle
- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor whiteColor];
    self.title = @"Video Remuxer";
    UIBarButtonItem *startBarButton = [[UIBarButtonItem alloc] initWithTitle:@"Start" style:UIBarButtonItemStylePlain target:self action:@selector(start)];
    self.navigationItem.rightBarButtonItems = @[startBarButton];
}

#pragma mark - Action
- (void)start {
    __weak typeof(self) weakSelf = self;
    NSLog(@"MP4Demuxer start");
    [self.demuxer startReading:^(BOOL success, NSError * _Nonnull error) {
        if (success) {
            // Demuxer 启动成功后，就可以从它里面获取解封装后的数据了。
            [weakSelf fetchAndRemuxData];
        }else{
            NSLog(@"Demuxer error: %zi %@", error.code, error.localizedDescription);
        }
    }];
}

#pragma mark - Utility
- (void)fetchAndRemuxData {
    // 异步地从 Demuxer 获取解封装后的 H.264/H.265 编码数据，再重新封装。
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self.muxer startWriting];
        int videoCount = 0;
        int audioCount = 0;
        while (self.demuxer.hasVideoSampleBuffer || self.demuxer.hasAudioSampleBuffer) {
            CMSampleBufferRef videoBuffer = [self.demuxer copyNextVideoSampleBuffer];
            if (videoBuffer) {
                [self.muxer appendSampleBuffer:videoBuffer];
                videoCount++;
                NSLog(@"videoCount:%d", videoCount);
                CFRelease(videoBuffer);
            }
            
            CMSampleBufferRef audioBuffer = [self.demuxer copyNextAudioSampleBuffer];
            if (audioBuffer) {
                [self.muxer appendSampleBuffer:audioBuffer];
                audioCount++;
                NSLog(@"audioCount:%d", audioCount);
                CFRelease(audioBuffer);
            }
        }
        if (self.demuxer.demuxerStatus == MP4DemuxerStatusCompleted) {
            NSLog(@"KFMP4Demuxer complete");
            [self.muxer stopWriting:^(BOOL success, NSError * _Nonnull error) {
                NSLog(@"KFMP4Muxer complete:%d", success);
            }];
        }
    });
}

@end

