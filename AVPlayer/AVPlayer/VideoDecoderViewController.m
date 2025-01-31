//
//  VideoDecoderViewController.m
//  AVPlayer
//
//  Created by 尹玉 on 2025/1/31.
//

#import "VideoDecoderViewController.h"
#import "MP4Demuxer.h"
#import "VideoDecoder.h"

#define DecompressionMaxCount 5

@interface VideoDecoderFrame : NSObject
@property (nonatomic, strong) NSData *data;
@property (nonatomic, assign) Float64 time;
@end

@implementation VideoDecoderFrame
@end

@interface VideoDecoderViewController ()
@property (nonatomic, strong) DemuxerConfig *demuxerConfig;
@property (nonatomic, strong) MP4Demuxer *demuxer;
@property (nonatomic, strong) VideoDecoder *decoder;
@property (nonatomic, strong) NSMutableArray *yuvDataArray;
@property (nonatomic, strong) NSFileHandle *fileHandle;
@end

@implementation VideoDecoderViewController
#pragma mark - Property
- (DemuxerConfig *)demuxerConfig {
    if (!_demuxerConfig) {
        _demuxerConfig = [[DemuxerConfig alloc] init];
        _demuxerConfig.demuxerType = MediaVideo;
        NSString *videoPath = [[NSBundle mainBundle] pathForResource:@"input" ofType:@"mp4"];
        _demuxerConfig.asset = [AVAsset assetWithURL:[NSURL fileURLWithPath:videoPath]];
    }
    
    return _demuxerConfig;
}

- (MP4Demuxer *)demuxer {
    if (!_demuxer) {
        _demuxer = [[MP4Demuxer alloc] initWithConfig:self.demuxerConfig];
        _demuxer.errorCallBack = ^(NSError *error) {
            NSLog(@"MP4Demuxer error:%zi %@", error.code, error.localizedDescription);
        };
    }
    
    return _demuxer;
}

- (VideoDecoder *)decoder {
    if (!_decoder) {
        __weak typeof(self) weakSelf = self;
        _decoder = [[VideoDecoder alloc] init];
        _decoder.errorCallBack = ^(NSError *error) {
            NSLog(@"VideoDecoder error %zi %@",error.code,error.localizedDescription);
        };
        _decoder.pixelBufferOutputCallBack = ^(CVPixelBufferRef pixelBuffer, CMTime ptsTime) {
            // 解码数据回调。存储解码后的数据为 YUV 文件。
            [weakSelf savePixelBuffer:pixelBuffer time:ptsTime];
        };
    }
    
    return _decoder;
}

- (NSMutableArray *)yuvDataArray {
    if (!_yuvDataArray) {
        _yuvDataArray = [[NSMutableArray alloc] init];
    }
    
    return _yuvDataArray;
}

- (NSFileHandle *)fileHandle {
    if (!_fileHandle) {
        NSString *videoPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"output.yuv"];
        [[NSFileManager defaultManager] removeItemAtPath:videoPath error:nil];
        [[NSFileManager defaultManager] createFileAtPath:videoPath contents:nil attributes:nil];
        _fileHandle = [NSFileHandle fileHandleForWritingAtPath:videoPath];
    }
    
    return _fileHandle;
}

#pragma mark - Lifecycle
- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor whiteColor];
    self.title = @"Video Decoder";
    UIBarButtonItem *startBarButton = [[UIBarButtonItem alloc] initWithTitle:@"Start" style:UIBarButtonItemStylePlain target:self action:@selector(start)];
    self.navigationItem.rightBarButtonItems = @[startBarButton];
    
    // ffplay -f rawvideo -pix_fmt nv12 -video_size 1280x720 -i output.yuv

}

#pragma mark - Action
- (void)start {
    __weak typeof(self) weakSelf = self;
    NSLog(@"MP4Demuxer start");
    [self.demuxer startReading:^(BOOL success, NSError * _Nonnull error) {
        if (success) {
            // Demuxer 启动成功后，就可以从它里面获取解封装后的数据了。
            [weakSelf fetchAndDecodeDemuxedData];
        } else {
            NSLog(@"MP4Demuxer error: %zi %@",error.code,error.localizedDescription);
        }
    }];
}

#pragma mark - Private Method
- (void)fetchAndDecodeDemuxedData {
    // 异步地从 Demuxer 获取解封装后的 H.264/H.265 编码数据，送给解码器进行解码。
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        while (self.demuxer.hasVideoSampleBuffer) {
            CMSampleBufferRef videoBuffer = [self.demuxer copyNextVideoSampleBuffer];
            if (videoBuffer) {
                [self.decoder decodeSampleBuffer:videoBuffer];
                CFRelease(videoBuffer);
            }
        }
        [self.decoder flushWithCompleteHandler:^{
            for (NSInteger index = 0; index < self.yuvDataArray.count; index++) {
                VideoDecoderFrame *frame = self.yuvDataArray[index];
                [self.fileHandle writeData:frame.data];
            }
            [self.yuvDataArray removeAllObjects];
        }];
        if (self.demuxer.demuxerStatus == MP4DemuxerStatusCompleted) {
            NSLog(@"MP4Demuxer complete");
        }
    });
}

- (void)savePixelBuffer:(CVPixelBufferRef)pixelBuffer time:(CMTime)time{
    if (!pixelBuffer) {
        return;
    }
    
    // 取出 YUV 数据，按照 NV12 的 YUV 格式存储。
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    NSMutableData *mutableData = [NSMutableData new];
    for (size_t index = 0; index < CVPixelBufferGetPlaneCount(pixelBuffer); index++) {
        size_t bytesPerRowOfPlane = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, index);
        size_t height = CVPixelBufferGetHeightOfPlane(pixelBuffer, index);
        void *data = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, index);
        [mutableData appendBytes:data length:bytesPerRowOfPlane * height];
    }
    VideoDecoderFrame *newFrame = [VideoDecoderFrame new];
    newFrame.data = mutableData;
    newFrame.time = CMTimeGetSeconds(time);
    
    [self.yuvDataArray addObject:newFrame];
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
    // 以下排序性能太差，仅用于 Demo。
    if (self.yuvDataArray.count > DecompressionMaxCount) {
        NSArray *sortedArray = [self.yuvDataArray sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
            Float64 first = [(VideoDecoderFrame *) a time];
            Float64 second = [(VideoDecoderFrame *) b time];
            return first >= second;
        }];
        self.yuvDataArray = [[NSMutableArray alloc] initWithArray:sortedArray];
        VideoDecoderFrame *firstFrame = [self.yuvDataArray firstObject];
        [self.fileHandle writeData:firstFrame.data];
        [self.yuvDataArray removeObjectAtIndex:0];
    }
}

@end
