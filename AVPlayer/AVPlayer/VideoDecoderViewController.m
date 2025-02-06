//
//  VideoDecoderViewController.m
//  AVPlayer
//
//  Created by 尹玉 on 2025/1/31.
//

#import "VideoDecoderViewController.h"
#import "MP4Demuxer.h"
#import "VideoDecoder.h"
#import <CoreVideo/CoreVideo.h>

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
            static int frameNumber = 0;
            
            // 解码数据回调。存储解码后的数据为 YUV 文件。
            [weakSelf savePixelBuffer:pixelBuffer time:ptsTime];
            
//            NSData *rgbaData = convertPixelBufferToRGBAData(pixelBuffer);
//            // 或者使用手动转换（如果是 NV12 格式）
//            // NSData *rgbaData = convertNV12PixelBufferToRGBAData(pixelBuffer);
//
//            // 将 RGBA 数据保存到文件
//            NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
//            NSString *filePath = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"output_%d.rgba", frameNumber]];
//            [rgbaData writeToFile:filePath atomically:YES];
            
            frameNumber++;
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
    
    // 完成音频解码后，可以将 App Document 文件夹下面的 output.yuv 文件拷贝到电脑上，使用 ffplay 播放：
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
    size_t width = CVPixelBufferGetWidth(pixelBuffer);
    size_t height = CVPixelBufferGetHeight(pixelBuffer);
    NSLog(@"Pixel buffer resolution: %zu x %zu", width, height);
    
    
    OSType pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer);
    
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
        NSMutableData *mutableData = [NSMutableData new];
        
        if (pixelFormat == kCVPixelFormatType_420YpCbCr8Planar) {
            NSLog(@"kCVPixelFormatType_420YpCbCr8Planar: %u", (unsigned int)pixelFormat);
            // 处理 Y 平面
            size_t yBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
            size_t yWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0);
            size_t yHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0);
            void *yData = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
            for (size_t y = 0; y < yHeight; y++) {
                [mutableData appendBytes:(char *)yData + y * yBytesPerRow length:yWidth];
            }
            
            // 处理 U 平面
            size_t uBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1);
            size_t uWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, 1);
            size_t uHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 1);
            void *uData = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
            for (size_t y = 0; y < uHeight; y++) {
                [mutableData appendBytes:(char *)uData + y * uBytesPerRow length:uWidth];
            }
            
            // 处理 V 平面
            size_t vBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 2);
            size_t vWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, 2);
            size_t vHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 2);
            void *vData = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 2);
            for (size_t y = 0; y < vHeight; y++) {
                [mutableData appendBytes:(char *)vData + y * vBytesPerRow length:vWidth];
            }
        } else if (pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange) {
            NSLog(@"kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange: %u", (unsigned int)pixelFormat);
            // 原有的 NV12 处理逻辑
            // 处理 Y 平面
            size_t yBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
            size_t yWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0);
            size_t yHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0);
            void *yData = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
            for (size_t y = 0; y < yHeight; y++) {
                [mutableData appendBytes:(char *)yData + y * yBytesPerRow length:yWidth];
            }

            // 处理 UV 平面
            size_t uvBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1);
            size_t uvWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, 1);
            size_t uvHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 1);
            void *uvData = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
            for (size_t y = 0; y < uvHeight; y++) {
                [mutableData appendBytes:(char *)uvData + y * uvBytesPerRow length:uvWidth];
            }
        } else if (pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) {
            NSLog(@"kCVPixelFormatType_420YpCbCr8BiPlanarFullRange: %u", (unsigned int)pixelFormat);
            // 锁定像素缓冲区以进行读写操作
                    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
                    
                    // 处理 Y 平面
                    size_t yBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
                    size_t yWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0);
                    size_t yHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0);
                    void *yData = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
                    for (size_t y = 0; y < yHeight; y++) {
                        [mutableData appendBytes:(char *)yData + y * yBytesPerRow length:yWidth];
                    }
                    
                    // 处理 UV 平面
                    size_t uvBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1);
                    size_t uvWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, 1);
                    size_t uvHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 1);
                    void *uvData = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
                    for (size_t y = 0; y < uvHeight; y++) {
                        [mutableData appendBytes:(char *)uvData + y * uvBytesPerRow length:uvWidth * 2];
                        // 注意：UV 平面每个元素占 2 字节（U 和 V 交织），所以长度乘以 2
                    }
                    
                    // 解锁像素缓冲区
                    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        } else {
            NSLog(@"Unsupported pixel format: %u", (unsigned int)pixelFormat);
            return;
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
            if (first < second) {
                return NSOrderedAscending;
            } else if (first > second) {
                return NSOrderedDescending;
            } else {
                return NSOrderedSame;
            }
        }];
        self.yuvDataArray = [[NSMutableArray alloc] initWithArray:sortedArray];
        VideoDecoderFrame *firstFrame = [self.yuvDataArray firstObject];
        [self.fileHandle writeData:firstFrame.data];
        [self.yuvDataArray removeObjectAtIndex:0];
    }
}

void checkPixelBufferFormat(CVPixelBufferRef pixelBuffer) {
    // 获取像素格式
    OSType pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer);
    
    switch (pixelFormat) {
        case kCVPixelFormatType_32BGRA:
            NSLog(@"Pixel buffer format is 32BGRA");
            break;
        case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
            NSLog(@"Pixel buffer format is NV12 (420YpCbCr8BiPlanarVideoRange)");
            break;
        case kCVPixelFormatType_420YpCbCr8Planar:
            NSLog(@"Pixel buffer format is I420 (420YpCbCr8Planar)");
            break;
        case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange:
            NSLog(@"Pixel buffer format is 420f");
            break;
        // 可以根据需要添加更多的格式判断
        default:
            NSLog(@"Unknown pixel buffer format: %u", (unsigned int)pixelFormat);
            break;
    }
}

NSData *convertPixelBufferToRGBAData(CVPixelBufferRef pixelBuffer) {
    // 创建 CIContext
    CIContext *context = [CIContext contextWithOptions:nil];
    
    // 将 CVPixelBufferRef 转换为 CIImage
    CIImage *ciImage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
    
    // 获取图像的尺寸
    CGRect extent = [ciImage extent];
    size_t width = CGRectGetWidth(extent);
    size_t height = CGRectGetHeight(extent);
    
    // 创建一个用于存储 RGBA 数据的缓冲区
    size_t bytesPerRow = width * 4;
    size_t bufferSize = bytesPerRow * height;
    void *rgbaBuffer = malloc(bufferSize);
    
    // 使用 CIContext 将 CIImage 渲染到 RGBA 缓冲区
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        [context render:ciImage toBitmap: rgbaBuffer
               rowBytes: bytesPerRow
                 bounds: extent
               format: kCIFormatRGBA8
            colorSpace: colorSpace];
        CGColorSpaceRelease(colorSpace);
    
    // 将 RGBA 缓冲区的数据封装成 NSData
    NSData *rgbaData = [NSData dataWithBytes: rgbaBuffer length: bufferSize];
    
    // 释放缓冲区
    free(rgbaBuffer);
    
    return rgbaData;
}


@end

