//
//  AudioCaptureViewController.m
//  AVPlayer
//
//  Created by 尹玉 on 2024/10/4.
//

#import <AVFoundation/AVFoundation.h>
#import "AudioCaptureViewController.h"
#import "AudioCapture.h"
#import "AudioEncoder.h"
#import "AudioTools.h"
#import "MP4Muxer.h"

@interface AudioCaptureViewController ()
@property (nonatomic, strong) AudioConfig *audioConfig;
@property (nonatomic, strong) AudioCapture *audioCapture;
@property (nonatomic, strong) AudioEncoder *audioEncoder;
@property (nonatomic, strong) MuxerConfig *muxerConfig;
@property (nonatomic, strong) MP4Muxer *muxer;
@end

@implementation AudioCaptureViewController
#pragma mark - Property
- (AudioConfig *)audioConfig {
    if (!_audioConfig) {
        _audioConfig = [AudioConfig defaultConfig];
    }
    
    return _audioConfig;
}

- (AudioCapture *)audioCapture {
    if (!_audioCapture) {
        __weak typeof(self) weakSelf = self;
        _audioCapture = [[AudioCapture alloc] initWithConfig:self.audioConfig];
        _audioCapture.errorCallBack = ^(NSError* error) {
            NSLog(@"AudioCapture error: %zi %@", error.code, error.localizedDescription);
        };
        // 音频采集数据回调。在这里将 PCM 数据写入文件。
        _audioCapture.sampleBufferOutputCallBack = ^(CMSampleBufferRef sampleBuffer) {
//            if (sampleBuffer) {
//                // 1、获取 CMBlockBuffer，这里面封装着 PCM 数据。
//                CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
//                size_t lengthAtOffsetOutput, totalLengthOutput;
//                char *dataPointer;
//                
//                // 2、从 CMBlockBuffer 中获取 PCM 数据存储到文件中。
//                CMBlockBufferGetDataPointer(blockBuffer, 0, &lengthAtOffsetOutput, &totalLengthOutput, &dataPointer);
//                [weakSelf.fileHandle writeData:[NSData dataWithBytes:dataPointer length:totalLengthOutput]];
//            }
            [weakSelf.audioEncoder encodeSampleBuffer:sampleBuffer];
        };
    }
    
    return _audioCapture;
}

- (AudioEncoder *)audioEncoder {
    if (!_audioEncoder) {
        __weak typeof(self) weakSelf = self;
        _audioEncoder = [[AudioEncoder alloc] initWithAudioBitrate:96000];
        _audioEncoder.errorCallBack = ^(NSError* error) {
            NSLog(@"AudioEcoder error:%zi %@", error.code, error.localizedDescription);
        };
        

        // 音频编码数据回调。这里编码的 AAC 数据送给封装器。
        // 与之前将编码后的 AAC 数据存储为 AAC 文件不同的是，这里编码后送给封装器的 AAC 数据是没有添加 ADTS 头的，因为我们这里封装的是 M4A 格式，不需要 ADTS 头。
        _audioEncoder.sampleBufferOutputCallBack = ^(CMSampleBufferRef sampleBuffer) {
            [weakSelf.muxer appendSampleBuffer:sampleBuffer];
        };
    }
    
    return _audioEncoder;
}

- (MuxerConfig *)muxerConfig {
    if (!_muxerConfig) {
        _muxerConfig = [[MuxerConfig alloc] init];
        NSString *audioPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"test.m4a"];
        NSLog(@"M4A file path: %@", audioPath);
        [[NSFileManager defaultManager] removeItemAtPath:audioPath error:nil];
        _muxerConfig.outputURL = [NSURL fileURLWithPath:audioPath];
        _muxerConfig.muxerType = MediaAudio;
    }
    
    return _muxerConfig;
}


- (MP4Muxer *)muxer {
    if (!_muxer) {
        _muxer = [[MP4Muxer alloc] initWithConfig:self.muxerConfig];
        _muxer.errorCallBack = ^(NSError* error) {
            NSLog(@"MP4Muxer error:%zi %@", error.code, error.localizedDescription);
        };
    }
    
    return _muxer;
}

#pragma mark - Lifecycle
- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupAudioSession];
    [self setupUI];
    
    // 完成音频采集后，可以将 App Document 文件夹下面的 test.pcm 文件拷贝到电脑上，使用 ffplay 播放：
    // ffplay -ar 44100 -channels 2 -f s16le -i test.pcm
    // ffplay -i test.aac
    // ffplay -i test.m4a
}

#pragma mark - Setup
- (void)setupUI {
    self.edgesForExtendedLayout = UIRectEdgeAll;//设置当前视图控制器的布局边缘，UIRectEdgeAll 表示视图将延伸到所有方向，包括顶部和底部，这在有导航栏或标签栏的情况下很有用。
    self.extendedLayoutIncludesOpaqueBars = YES;//设置一个布尔值，表示当使用 edgesForExtendedLayout 属性时，是否应该考虑不透明的状态栏或导航栏。设置为 YES 表示布局应该延伸到不透明的栏。
    self.title = @"Audio Capture";//设置当前视图控制器的标题为 “Audio Capture”，这个标题通常显示在导航栏的中心。
    self.view.backgroundColor = [UIColor whiteColor];//设置当前视图控制器的根视图的背景颜色为白色。
    
    
    // Navigation item.
    //    创建一个新的 UIBarButtonItem 实例，用作开始按钮。
    //    initWithTitle:@"Start" 设置按钮的标题为 “Start”。
    //    style:UIBarButtonItemStylePlain 设置按钮样式为普通（没有特殊的背景或边框）。
    //    target:self 指定按钮动作的目标是当前视图控制器。
    //    action:@selector(start) 指定当按钮被点击时，将调用当前视图控制器的 start 方法。
    UIBarButtonItem *startBarButton = [[UIBarButtonItem alloc] initWithTitle:@"Start" style:UIBarButtonItemStylePlain target:self action:@selector(start)];
    UIBarButtonItem *stopBarButton = [[UIBarButtonItem alloc] initWithTitle:@"Stop" style:UIBarButtonItemStylePlain target:self action:@selector(stop)];
    //设置导航项的右侧按钮项数组。
//    [startBarButton, stopBarButton] 创建一个包含两个按钮的数组。
//    self.navigationItem.rightBarButtonItems 将这个数组赋值给当前视图控制器的导航项的右侧按钮项，这样按钮就会显示在导航栏的右侧。
    self.navigationItem.rightBarButtonItems = @[startBarButton, stopBarButton];

}

- (void)setupAudioSession {
    NSError *error = nil;
    
    // 1、获取音频会话实例。
    AVAudioSession *session = [AVAudioSession sharedInstance];

    // 2、设置分类和选项。
    //    设置音频会话的分类为 AVAudioSessionCategoryPlayAndRecord，这意味着应用程序将同时播放和录制音频。
    //    使用 withOptions 参数设置音频会话的选项，这里指定了 AVAudioSessionCategoryOptionMixWithOthers（允许与其他音频应用同时播放）和 AVAudioSessionCategoryOptionDefaultToSpeaker（默认使用扬声器播放）。
    //    将错误引用传递给 error 参数，以便在设置过程中发生错误时可以捕获。
    [session setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionMixWithOthers | AVAudioSessionCategoryOptionDefaultToSpeaker error:&error];
    if (error) {
        NSLog(@"AVAudioSession setCategory error.");
        error = nil;
        return;
    }
    
    // 3、设置模式。
    //    设置音频会话的模式为 AVAudioSessionModeVideoRecording，这可能会影响音频会话的优先级和行为。
    //    同样，检查是否有错误发生，并相应处理。
    [session setMode:AVAudioSessionModeVideoRecording error:&error];
    if (error) {
        NSLog(@"AVAudioSession setMode error.");
        error = nil;
        return;
    }

    // 4、激活会话。
    [session setActive:YES error:&error];
    if (error) {
        NSLog(@"AVAudioSession setActive error.");
        error = nil;
        return;
    }
}

#pragma mark - Action
- (void)start {
    // 启动采集器。
    [self.audioCapture startRunning];
    // 启动封装器。
    [self.muxer startWriting];
}

- (void)stop {
    // 停止采集器。
    [self.audioCapture stopRunning];
    [self.muxer stopWriting:^(BOOL success, NSError * _Nonnull error) {
        NSLog(@"MP4Muxer %@", success ? @"success" : [NSString stringWithFormat:@"error %zi %@", error.code, error.localizedDescription]);
    }];
}

@end

