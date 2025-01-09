//
//  AudioDemuxerViewController.m
//  AVPlayer
//
//  Created by 尹玉 on 2025/1/6.
//

#import "AudioDemuxerViewController.h"
#import "MP4Demuxer.h"
#import "AudioTools.h"

#import "AudioDecoder.h"

@interface AudioDemuxerViewController ()
@property (nonatomic, strong) DemuxerConfig *demuxerConfig;
@property (nonatomic, strong) MP4Demuxer *demuxer;
@property (nonatomic, strong) AudioDecoder *decoder;
@property (nonatomic, strong) NSFileHandle *fileHandle;
@end

@implementation AudioDemuxerViewController
#pragma mark - Property
- (DemuxerConfig *)demuxerConfig {
    if (!_demuxerConfig) {
        _demuxerConfig = [[DemuxerConfig alloc] init];
        // 只解封装音频。
        _demuxerConfig.demuxerType = MediaAudio;
        // 待解封装的资源。
        NSString *assetPath = [[NSBundle mainBundle] pathForResource:@"input" ofType:@"mp4"];
        _demuxerConfig.asset = [AVAsset assetWithURL:[NSURL fileURLWithPath:assetPath]];
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

- (AudioDecoder *)decoder {
    if (!_decoder) {
        __weak typeof(self) weakSelf = self;
        _decoder = [[AudioDecoder alloc] init];
        _decoder.errorCallBack = ^(NSError *error) {
            NSLog(@"AudioDecoder error:%zi %@", error.code, error.localizedDescription);
        };
        // 解码数据回调。在这里把解码后的音频 PCM 数据存储为文件。
        _decoder.sampleBufferOutputCallBack = ^(CMSampleBufferRef sampleBuffer) {
            if (sampleBuffer) {
                CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
                size_t totolLength;
                char *dataPointer = NULL;
                CMBlockBufferGetDataPointer(blockBuffer, 0, NULL, &totolLength, &dataPointer);
                if (totolLength == 0 || !dataPointer) {
                    return;
                }
                
                [weakSelf.fileHandle writeData:[NSData dataWithBytes:dataPointer length:totolLength]];
            }
        };
    }
    
    return _decoder;
}

- (NSFileHandle *)fileHandle {
    if (!_fileHandle) {
        NSString *audioPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"output.pcm"];
        [[NSFileManager defaultManager] removeItemAtPath:audioPath error:nil];
        [[NSFileManager defaultManager] createFileAtPath:audioPath contents:nil attributes:nil];
        _fileHandle = [NSFileHandle fileHandleForWritingAtPath:audioPath];
    }

    return _fileHandle;
}

#pragma mark - Lifecycle
- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupUI];
    
    // 完成音频解封装后，可以将 App Document 文件夹下面的 output.aac 文件拷贝到电脑上，使用 ffplay 播放：
    // ffplay -i output.aac
    // 完成音频解码后，可以将 App Document 文件夹下面的 output.pcm 文件拷贝到电脑上，使用 ffplay 播放：
    // ffplay -ar 44100 -ch_layout stereo -f s16le -i output.pcm
}

- (void)dealloc {
    if (_fileHandle) {
        [_fileHandle closeFile];
        _fileHandle = nil;
    }
}


#pragma mark - Setup
- (void)setupUI {
    self.edgesForExtendedLayout = UIRectEdgeAll;//设置当前视图控制器的布局边缘，UIRectEdgeAll 表示视图将延伸到所有方向，包括顶部和底部，这在有导航栏或标签栏的情况下很有用。
    self.extendedLayoutIncludesOpaqueBars = YES;//设置一个布尔值，表示当使用 edgesForExtendedLayout 属性时，是否应该考虑不透明的状态栏或导航栏。设置为 YES 表示布局应该延伸到不透明的栏。
    self.title = @"Audio Demuxer";//设置当前视图控制器的标题为 “Audio Capture”，这个标题通常显示在导航栏的中心。
    self.view.backgroundColor = [UIColor whiteColor];//设置当前视图控制器的根视图的背景颜色为白色。
    
    
    // Navigation item.
    //    创建一个新的 UIBarButtonItem 实例，用作开始按钮。
    //    initWithTitle:@"Start" 设置按钮的标题为 “Start”。
    //    style:UIBarButtonItemStylePlain 设置按钮样式为普通（没有特殊的背景或边框）。
    //    target:self 指定按钮动作的目标是当前视图控制器。
    //    action:@selector(start) 指定当按钮被点击时，将调用当前视图控制器的 start 方法。
    UIBarButtonItem *startBarButton = [[UIBarButtonItem alloc] initWithTitle:@"Start" style:UIBarButtonItemStylePlain target:self action:@selector(start)];
    //设置导航项的右侧按钮项数组。
//    [startBarButton, stopBarButton] 创建一个包含两个按钮的数组。
//    self.navigationItem.rightBarButtonItems 将这个数组赋值给当前视图控制器的导航项的右侧按钮项，这样按钮就会显示在导航栏的右侧。
    self.navigationItem.rightBarButtonItems = @[startBarButton];

}

#pragma mark - Action
- (void)start {
    NSLog(@"MP4Demuxer start");
    __weak typeof(self) weakSelf = self;
    [self.demuxer startReading:^(BOOL success, NSError * _Nonnull error) {
        if (success) {
            // Demuxer 启动成功后，就可以从它里面获取解封装后的数据了。
            [weakSelf fetchAndSaveDemuxedData];
        } else {
            NSLog(@"MP4Demuxer error: %zi %@", error.code, error.localizedDescription);
        }
    }];
}

#pragma mark - Utility
- (void)fetchAndSaveDemuxedData {
    // 异步地从 Demuxer 获取解封装后的 AAC 编码数据。
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        while (self.demuxer.hasAudioSampleBuffer) {
            CMSampleBufferRef audioBuffer = [self.demuxer copyNextAudioSampleBuffer];
            if (audioBuffer) {
                //[self saveSampleBuffer:audioBuffer];
                [self decodeSampleBuffer:audioBuffer];
                CFRelease(audioBuffer);
            }
        }
        if (self.demuxer.demuxerStatus == MP4DemuxerStatusCompleted) {
            NSLog(@"MP4Demuxer complete");
        }
    });
}

- (void)decodeSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    // 获取解封装后的 AAC 编码裸数据。
    CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t totolLength;
    char *dataPointer = NULL;
    CMBlockBufferGetDataPointer(blockBuffer, 0, NULL, &totolLength, &dataPointer);
    if (totolLength == 0 || !dataPointer) {
        return;
    }
    
    // 目前 AudioDecoder 的解码接口实现的是单包（packet，1 packet 有 1024 帧）解码。而从 Demuxer 获取的一个 CMSampleBuffer 可能包含多个包，所以这里要拆一下包，再送给解码器。
    NSLog(@"SampleNum: %ld", CMSampleBufferGetNumSamples(sampleBuffer));
    for (NSInteger index = 0; index < CMSampleBufferGetNumSamples(sampleBuffer); index++) {
        // 1、获取一个包的数据。
        size_t sampleSize = CMSampleBufferGetSampleSize(sampleBuffer, index);
        CMSampleTimingInfo timingInfo;
        CMSampleBufferGetSampleTimingInfo(sampleBuffer, index, &timingInfo);
        char *sampleDataPointer = malloc(sampleSize);
        memcpy(sampleDataPointer, dataPointer, sampleSize);
        
        // 2、将数据封装到 CMBlockBuffer 中。
        CMBlockBufferRef packetBlockBuffer;
        OSStatus status = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault,
                                                              sampleDataPointer,
                                                              sampleSize,
                                                              NULL,
                                                              NULL,
                                                              0,
                                                              sampleSize,
                                                              0,
                                                              &packetBlockBuffer);
        
        if (status == noErr) {
            // 3、将 CMBlockBuffer 封装到 CMSampleBuffer 中。
            CMSampleBufferRef packetSampleBuffer = NULL;
            const size_t sampleSizeArray[] = {sampleSize};
            status = CMSampleBufferCreateReady(kCFAllocatorDefault,
                                               packetBlockBuffer,
                                               CMSampleBufferGetFormatDescription(sampleBuffer),
                                               1,
                                               1,
                                               &timingInfo,
                                               1,
                                               sampleSizeArray,
                                               &packetSampleBuffer);
            CFRelease(packetBlockBuffer);
            
            // 4、解码这个包的数据。
            if (packetSampleBuffer) {
                [self.decoder decodeSampleBuffer:packetSampleBuffer];
                CFRelease(packetSampleBuffer);
            }
        }
        dataPointer += sampleSize;
    }
}



//- (void)saveSampleBuffer:(CMSampleBufferRef)sampleBuffer {
//    // 将解封装后的数据存储为 AAC 文件。
//    if (sampleBuffer) {
//        // 获取解封装后的 AAC 编码裸数据。
//        AudioStreamBasicDescription streamBasicDescription = *CMAudioFormatDescriptionGetStreamBasicDescription(CMSampleBufferGetFormatDescription(sampleBuffer));
//        CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
//        size_t totolLength;
//        char *dataPointer = NULL;
//        CMBlockBufferGetDataPointer(blockBuffer, 0, NULL, &totolLength, &dataPointer);
//        if (totolLength == 0 || !dataPointer) {
//            return;
//        }
//        
//        // 将 AAC 编码裸数据存储为 AAC 文件，这时候需要在每个包前增加 ADTS 头信息。
//        for (NSInteger index = 0; index < CMSampleBufferGetNumSamples(sampleBuffer); index++) {
//            size_t sampleSize = CMSampleBufferGetSampleSize(sampleBuffer, index);
//            [self.fileHandle writeData:[AudioTools adtsDataWithChannels:streamBasicDescription.mChannelsPerFrame sampleRate:streamBasicDescription.mSampleRate rawDataLength:sampleSize]];
//            [self.fileHandle writeData:[NSData dataWithBytes:dataPointer length:sampleSize]];
//            dataPointer += sampleSize;
//        }
//    }
//}




@end

