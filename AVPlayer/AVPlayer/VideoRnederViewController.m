//
//  VideoRnederViewController.m
//  AVPlayer
//
//  Created by 尹玉 on 2025/3/2.
//

#import <Foundation/Foundation.h>

#import "VideoRenderViewController.h"
#import "VideoCapture.h"
#import "MetalView.h"

@interface VideoRenderViewController ()
@property (nonatomic, strong) VideoCaptureConfig *videoCaptureConfig;
@property (nonatomic, strong) VideoCapture *videoCapture;
@property (nonatomic, strong) MetalView *metalView;
@end

@implementation VideoRenderViewController
#pragma mark - Property
- (VideoCaptureConfig *)videoCaptureConfig {
    if (!_videoCaptureConfig) {
        _videoCaptureConfig = [[VideoCaptureConfig alloc] init];
    }
    
    return _videoCaptureConfig;
}

- (VideoCapture *)videoCapture {
    if (!_videoCapture) {
        _videoCapture = [[VideoCapture alloc] initWithConfig:self.videoCaptureConfig];
        __weak typeof(self) weakSelf = self;
        _videoCapture.sampleBufferOutputCallBack = ^(CMSampleBufferRef sampleBuffer) {
            // 视频采集数据回调。将采集回来的数据给渲染模块渲染。
            [weakSelf.metalView renderPixelBuffer:CMSampleBufferGetImageBuffer(sampleBuffer)];
        };
        _videoCapture.sessionErrorCallBack = ^(NSError* error) {
            NSLog(@"VideoCapture Error:%zi %@", error.code, error.localizedDescription);
        };
    }
    
    return _videoCapture;
}

#pragma mark - Lifecycle
- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self requestAccessForVideo];
    [self setupUI];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    self.metalView.frame = self.view.bounds;
}

#pragma mark - Action
- (void)changeCamera {
    [self.videoCapture changeDevicePosition:self.videoCapture.config.position == AVCaptureDevicePositionBack ? AVCaptureDevicePositionFront : AVCaptureDevicePositionBack];
}

#pragma mark - Private Method
- (void)requestAccessForVideo {
    __weak typeof(self) weakSelf = self;
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    switch (status) {
        case AVAuthorizationStatusNotDetermined:{
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
        case AVAuthorizationStatusAuthorized:{
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
    self.title = @"Video Render";
    self.view.backgroundColor = [UIColor whiteColor];
    
    // Navigation item.
    UIBarButtonItem *cameraBarButton = [[UIBarButtonItem alloc] initWithTitle:@"Camera" style:UIBarButtonItemStylePlain target:self action:@selector(changeCamera)];
    self.navigationItem.rightBarButtonItems = @[cameraBarButton];
    
    // 渲染 view。
    _metalView = [[MetalView alloc] initWithFrame:self.view.bounds];
    _metalView.fillMode = MetalViewContentModeFill;
    [self.view addSubview:self.metalView];
}

@end
