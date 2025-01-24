//
//  VideoMuxerViewController.m
//  AVPlayer
//
//  Created by 尹玉 on 2025/1/24.
//

#import "VideoMuxerViewController.h"
#import "VideoCapture.h"
#import "VideoEncoder.h"
#import "MP4Muxer.h"

@interface VideoMuxerViewController ()
@property (nonatomic, strong) VideoCaptureConfig *videoCaptureConfig;
@property (nonatomic, strong) VideoCapture *videoCapture;
@property (nonatomic, strong) VideoEncoderConfig *videoEncoderConfig;
@property (nonatomic, strong) VideoEncoder *videoEncoder;
@property (nonatomic, strong) MuxerConfig *muxerConfig;
@property (nonatomic, strong) MP4Muxer *muxer;
@property (nonatomic, assign) BOOL isWriting;
@end

@implementation VideoMuxerViewController
#pragma mark - Property
- (VideoCaptureConfig *)videoCaptureConfig {
    if (!_videoCaptureConfig) {
        _videoCaptureConfig = [[VideoCaptureConfig alloc] init];
        // 这里我们采集数据用于编码，颜色格式用了默认的：kCVPixelFormatType_420YpCbCr8BiPlanarFullRange。
    }
    return _videoCaptureConfig;
}

- (VideoCapture *)videoCapture {
    if (!_videoCapture) {
        _videoCapture = [[VideoCapture alloc] initWithConfig:self.videoCaptureConfig];
        __weak typeof(self) weakSelf = self;
        _videoCapture.sessionInitSuccessCallBack = ^() {
            dispatch_async(dispatch_get_main_queue(), ^{
                // 预览渲染。
                [weakSelf.view.layer insertSublayer:weakSelf.videoCapture.previewLayer atIndex:0];
                weakSelf.videoCapture.previewLayer.backgroundColor = [UIColor blackColor].CGColor;
                weakSelf.videoCapture.previewLayer.frame = weakSelf.view.bounds;
            });
        };
        _videoCapture.sampleBufferOutputCallBack = ^(CMSampleBufferRef sampleBuffer) {
            if (weakSelf.isWriting && sampleBuffer) {
                // 编码。
                [weakSelf.videoEncoder encodePixelBuffer:sampleBuffer ptsTime:CMSampleBufferGetPresentationTimeStamp(sampleBuffer)];
            }
        };
        _videoCapture.sessionErrorCallBack = ^(NSError* error) {
            NSLog(@"VideoCapture Error:%zi %@", error.code, error.localizedDescription);
        };
    }
    
    return _videoCapture;
}

- (VideoEncoderConfig *)videoEncoderConfig {
    if (!_videoEncoderConfig) {
        _videoEncoderConfig = [[VideoEncoderConfig alloc] init];
    }
    
    return _videoEncoderConfig;
}

- (VideoEncoder *)videoEncoder {
    if (!_videoEncoder) {
        _videoEncoder = [[VideoEncoder alloc] initWithConfig:self.videoEncoderConfig];
        __weak typeof(self) weakSelf = self;
        _videoEncoder.sampleBufferOutputCallBack = ^(CMSampleBufferRef sampleBuffer) {
            // 视频编码数据回调。
            if (weakSelf.isWriting) {
                // 当标记封装写入中时，将编码的 H.264/H.265 数据送给封装器。
                [weakSelf.muxer appendSampleBuffer:sampleBuffer];
            }
        };
    }
    return _videoEncoder;
}

- (MuxerConfig *)muxerConfig {
    if (!_muxerConfig) {
        _muxerConfig = [[MuxerConfig alloc] init];
        NSString *videoPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"test.mp4"];
        NSLog(@"MP4 file path: %@", videoPath);
        [[NSFileManager defaultManager] removeItemAtPath:videoPath error:nil];
        _muxerConfig.outputURL = [NSURL fileURLWithPath:videoPath];
        _muxerConfig.muxerType = MediaVideo;
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
    
    // 启动后即开始请求视频采集权限并开始采集。
    [self requestAccessForVideo];
    [self setupUI];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    self.videoCapture.previewLayer.frame = self.view.bounds;
}

- (void)dealloc {
    
}

#pragma mark - Action
- (void)start {
    if (!self.isWriting) {
        // 启动封装，
        [self.muxer startWriting];
        // 标记开始封装写入。
        self.isWriting = YES;
        NSLog(@"开始拍摄");
    }
}

- (void)stop {
    if (self.isWriting) {
        __weak typeof(self) weakSelf = self;
        [self.videoEncoder flushWithCompleteHandler:^{
            weakSelf.isWriting = NO;
            [weakSelf.muxer stopWriting:^(BOOL success, NSError * _Nonnull error) {
                NSLog(@"muxer stop %@", success ? @"success" : @"failed");
            }];
        }];
        NSLog(@"结束拍摄");
    }
}

- (void)onCameraSwitchButtonClicked:(UIButton *)button {
    [self.videoCapture changeDevicePosition:self.videoCapture.config.position == AVCaptureDevicePositionBack ? AVCaptureDevicePositionFront : AVCaptureDevicePositionBack];
}

- (void)changeCamera {
    [self.videoCapture changeDevicePosition:self.videoCapture.config.position == AVCaptureDevicePositionBack ? AVCaptureDevicePositionFront : AVCaptureDevicePositionBack];
}

-(void)handleDoubleTap:(UIGestureRecognizer *)sender {
    [self.videoCapture changeDevicePosition:self.videoCapture.config.position == AVCaptureDevicePositionBack ? AVCaptureDevicePositionFront : AVCaptureDevicePositionBack];
}

#pragma mark - Private Method
- (void)requestAccessForVideo{
    __weak typeof(self) weakSelf = self;
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    switch (status) {
        case AVAuthorizationStatusNotDetermined: {
            // 许可对话没有出现，发起授权许可。
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
                if (granted) {
                    [weakSelf.videoCapture startRunning];
                } else {
                    // 用户拒绝。
                }
            }];
            break;
        }
        case AVAuthorizationStatusAuthorized: {
            // 已经开启授权，可继续。
            [weakSelf.videoCapture startRunning];
            break;
        }
        default:
            break;
    }
}

- (void)setupUI {
    self.edgesForExtendedLayout = UIRectEdgeAll;
    self.extendedLayoutIncludesOpaqueBars = YES;
    self.title = @"Video Muxer";
    self.view.backgroundColor = [UIColor whiteColor];
    
    // 添加手势。
    UITapGestureRecognizer *singleTapGesture = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(singleTap:)];
    singleTapGesture.numberOfTapsRequired = 1;
    singleTapGesture.numberOfTouchesRequired = 1;
    [self.view addGestureRecognizer:singleTapGesture];
    
    UITapGestureRecognizer *doubleTapGesture = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(handleDoubleTap:)];
    doubleTapGesture.numberOfTapsRequired = 2;
    doubleTapGesture.numberOfTouchesRequired = 1;
    [self.view addGestureRecognizer:doubleTapGesture];
    
    [singleTapGesture requireGestureRecognizerToFail:doubleTapGesture];

    
    // Navigation item.
    UIBarButtonItem *startBarButton = [[UIBarButtonItem alloc] initWithTitle:@"Start" style:UIBarButtonItemStylePlain target:self action:@selector(start)];
    UIBarButtonItem *stopBarButton = [[UIBarButtonItem alloc] initWithTitle:@"Stop" style:UIBarButtonItemStylePlain target:self action:@selector(stop)];
    UIBarButtonItem *cameraBarButton = [[UIBarButtonItem alloc] initWithTitle:@"Camera" style:UIBarButtonItemStylePlain target:self action:@selector(changeCamera)];
    self.navigationItem.rightBarButtonItems = @[stopBarButton, startBarButton, cameraBarButton];
}




@end
