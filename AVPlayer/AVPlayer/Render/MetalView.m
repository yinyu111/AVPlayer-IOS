//
//  MetalView.m
//  AVPlayer
//
//  Created by 尹玉 on 2025/3/1.
//

#import <Foundation/Foundation.h>
#import <MetalKit/MetalKit.h>
#import <AVFoundation/AVFoundation.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>

#import "MetalView.h"
#import "ShaderType.h"

// 颜色空间转换矩阵，BT.601 Video Range。
static const matrix_float3x3 ColorMatrix601VideoRange = (matrix_float3x3) {
    (simd_float3) {1.164,  1.164,  1.164},
    (simd_float3) {0.0,    -0.392,  2.017},
    (simd_float3) {1.596,  -0.813,   0.0},
};

// 颜色空间转换矩阵，BT.601 Full Range。
static const matrix_float3x3 ColorMatrix601FullRange = (matrix_float3x3) {
    (simd_float3) {1.0,    1.0,    1.0},
    (simd_float3) {0.0,    -0.343, 1.765},
    (simd_float3) {1.4,    -0.711, 0.0},
};

// 颜色空间转换矩阵，BT.709 Video Range。
static const matrix_float3x3 ColorMatrix709VideoRange = (matrix_float3x3) {
    (simd_float3) {1.164,  1.164, 1.164},
    (simd_float3) {0.0,   -0.213, 2.112},
    (simd_float3) {1.793, -0.533,   0.0},
};

// 颜色空间转换矩阵，BT.709 Full Range。
static const matrix_float3x3 ColorMatrix709FullRange = (matrix_float3x3) {
    (simd_float3) { 1.0,    1.0,    1.0},
    (simd_float3) {0.0,    -0.187, 1.856},
    (simd_float3) {1.575,    -0.468, 0.0},
};

@interface MetalView () <MTKViewDelegate>
@property (nonatomic, assign) CVPixelBufferRef pixelBuffer; // 外层输入的最后一帧数据。
@property (nonatomic, strong) dispatch_semaphore_t semaphore; // 处理 PixelBuffer 锁，防止外层输入线程与渲染线程同时操作 Crash。
@property (nonatomic, assign) CVMetalTextureCacheRef textureCache; // 纹理缓存，根据 pixelbuffer 获取纹理。
@property (nonatomic, strong) MTKView *mtkView; // Metal 渲染的 view。
@property (nonatomic, assign) vector_uint2 viewportSize; // 视口大小。
@property (nonatomic, strong) id<MTLRenderPipelineState> pipelineState; // 渲染管道，管理顶点函数和片元函数。
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue; // 渲染指令队列。
@property (nonatomic, strong) id<MTLBuffer> vertices; // 顶点缓存对象。
@property (nonatomic, assign) NSUInteger numVertices; // 顶点数量。
@property (nonatomic, strong) id<MTLBuffer> yuvMatrix; // YUV 数据矩阵对象。
@property (nonatomic, assign) BOOL updateFillMode; // 填充模式变更标记。
@property (nonatomic, assign) CGSize pixelBufferSize; // pixelBuffer 数据尺寸。
@property (nonatomic, assign) CGSize currentViewSize; // 当前视图大小。
@property (nonatomic, strong) dispatch_queue_t renderQueue; // 渲染线程。
@end

@implementation MetalView
#pragma mark - LifeCycle
//自定义的初始化方法，接受一个 CGRect 类型的参数 frame，用于指定视图的位置和大小。
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _currentViewSize = frame.size;
        _fillMode = MetalViewContentModeFit;
        _updateFillMode = YES;
        //  创建 Metal 渲染视图且添加到当前视图。
        //创建一个 MTKView 实例，它是 Metal 框架中用于渲染的视图，将其初始大小设置为当前视图的边界大小。
        self.mtkView = [[MTKView alloc] initWithFrame:self.bounds];
        //为 MTKView 设置默认的 Metal 设备
        self.mtkView.device = MTLCreateSystemDefaultDevice();
        //将 MTKView 的背景颜色设置为透明色
        self.mtkView.backgroundColor = [UIColor clearColor];
        //将 MTKView 添加到当前视图中
        [self addSubview:self.mtkView];
        //将当前实例设置为 MTKView 的代理，这样当前类就需要实现 MTKViewDelegate 协议中的方法来处理渲染相关的事件。
        self.mtkView.delegate = self;
        //将 framebufferOnly 属性设置为 YES，表示 MTKView 只使用帧缓冲区进行渲染，不进行其他额外的处理，这可以提高性能
        self.mtkView.framebufferOnly = YES;
        //将 MTKView 的可绘制区域的大小赋值给成员变量 viewportSize，用于后续的渲染操作。
        self.viewportSize = (vector_uint2) {self.mtkView.drawableSize.width, self.mtkView.drawableSize.height};
        
        // 创建渲染线程。
        //创建一个信号量，初始值为 1。信号量用于线程同步，确保同一时间只有一个线程可以访问某些资源。
        _semaphore = dispatch_semaphore_create(1);
        //创建一个串行调度队列，用于处理渲染任务。串行队列会按照任务添加的顺序依次执行任务，确保渲染操作的顺序性
        _renderQueue = dispatch_queue_create("com.KeyFrameKit.metalView.renderQueue", DISPATCH_QUEUE_SERIAL);
        
        // 创建纹理缓存。
        //函数创建一个 Core Video Metal 纹理缓存。纹理缓存用于在 Core Video 和 Metal 之间高效地传递纹理数据，第一个和第二个参数为 NULL 表示使用默认的配置，第三个参数指定使用 MTKView 的 Metal 设备，第四个参数为 NULL 表示使用默认的属性，最后一个参数是指向 _textureCache 的指针，用于存储创建的纹理缓存。
        CVMetalTextureCacheCreate(NULL, NULL, self.mtkView.device, NULL, &_textureCache);
    }
    
    return self;
}

- (void)layoutSubviews {
    // 视图自动调整布局，同步至 Metal 视图。
    [super layoutSubviews];
    self.mtkView.frame = self.bounds;
    _currentViewSize = self.bounds.size;
}

- (void)dealloc {
    // 释放最后一帧数据、纹理缓存。
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    if (_pixelBuffer) {
        CFRelease(_pixelBuffer);
        _pixelBuffer = NULL;
    }
    
    if (_textureCache) {
        CVMetalTextureCacheFlush(_textureCache, 0);
        CFRelease(_textureCache);
        _textureCache = NULL;
    }
    dispatch_semaphore_signal(_semaphore);
    [self.mtkView releaseDrawables];
}

#pragma mark - Public Method
//多线程环境下安全地更新成员变量
- (void)renderPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    if (!pixelBuffer) {
        return;
    }
    // 外层输入 BGRA、YUV 数据。
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    if (_pixelBuffer) {
        CFRelease(_pixelBuffer);
        _pixelBuffer = NULL;
    }
    _pixelBuffer = pixelBuffer;
    _pixelBufferSize = CGSizeMake(CVPixelBufferGetWidth(pixelBuffer), CVPixelBufferGetHeight(pixelBuffer));
    //调用 CFRetain 函数增加传入像素缓冲区的引用计数，确保在当前对象持有该像素缓冲区期间，它不会被意外释放
    CFRetain(pixelBuffer);
    dispatch_semaphore_signal(_semaphore);
}


- (void)setFillMode:(MetalViewContentMode)fillMode {
    // 更改视图填充模式。
    _fillMode = fillMode;
    _updateFillMode = YES;
}


#pragma mark - Private Method
//根据传入的 isYUV 参数选择合适的片段着色器函数，然后配置渲染管道描述符，创建渲染管道状态和命令队列
-(void)_setupPipeline:(BOOL)isYUV {
    // 根据本地 shader 文件初始化渲染管道与渲染指令队列。
    //方法会从默认的库中加载 Metal 着色器代码，返回一个实现了 MTLLibrary 协议的对象 defaultLibrary，该对象包含了编译好的着色器函数。
    id<MTLLibrary> defaultLibrary = [self.mtkView.device newDefaultLibrary];
    //从 defaultLibrary 中获取名为 vertexShader 的顶点着色器函数，返回一个实现了 MTLFunction 协议的对象 vertexFunction。
    id<MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"vertexShader"];
    id<MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:isYUV ? @"yuvSamplingShader" : @"rgbSamplingShader"];
    
    //创建一个 MTLRenderPipelineDescriptor 对象 pipelineStateDescriptor，用于描述渲染管道的状态
    MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    //将之前获取的顶点着色器函数 vertexFunction 赋值给渲染管道描述符的 vertexFunction 属性。
    pipelineStateDescriptor.vertexFunction = vertexFunction;
    pipelineStateDescriptor.fragmentFunction = fragmentFunction;
    //设置渲染管道的颜色附件的像素格式，使其与 MTKView 的颜色像素格式一致。
    pipelineStateDescriptor.colorAttachments[0].pixelFormat = self.mtkView.colorPixelFormat;
    //使用 self.mtkView.device 根据渲染管道描述符 pipelineStateDescriptor 创建一个新的渲染管道状态对象，并将其赋值给成员变量 self.pipelineState
    self.pipelineState = [self.mtkView.device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:NULL];
    //使用 self.mtkView.device 创建一个新的命令队列对象，并将其赋值给成员变量 self.commandQueue。命令队列用于管理和执行渲染命令
    self.commandQueue = [self.mtkView.device newCommandQueue];
}

//根据传入的颜色空间信息和颜色范围标识，初始化 YUV 到 RGB 转换所需的矩阵，并将该矩阵数据存储到 Metal 缓冲区中
- (void)_setupYUVMatrix:(BOOL)isFullRange colorSpace:(CFTypeRef)colorSpace{
    // 初始化 YUV 矩阵，判断 pixelBuffer 的颜色格式是 601 还是 709，创建对应的矩阵。
    ConvertMatrix matrix;
    //    if (colorSpace == kCVImageBufferYCbCrMatrix_ITU_R_601_4) {
    //        matrix.matrix = isFullRange ? kFColorMatrix601FullRange : kFColorMatrix601VideoRange;
    //    }else if (colorSpace == kCVImageBufferYCbCrMatrix_ITU_R_709_2) {
    //        matrix.matrix = isFullRange ? kFColorMatrix709FullRange : kFColorMatrix709VideoRange;
    //    }
        
    NSString *colorSpaceString = (__bridge NSString *)colorSpace;
    NSString *kCVImageBufferYCbCrMatrix_ITU_R_601_4_String = (__bridge NSString *)kCVImageBufferYCbCrMatrix_ITU_R_601_4;
    NSString *kCVImageBufferYCbCrMatrix_ITU_R_709_2_String = (__bridge NSString *)kCVImageBufferYCbCrMatrix_ITU_R_709_2;

    if ([colorSpaceString isEqualToString:kCVImageBufferYCbCrMatrix_ITU_R_601_4_String]) {
        matrix.matrix = isFullRange ? ColorMatrix601FullRange : ColorMatrix601VideoRange;
    } else if ([colorSpaceString isEqualToString:kCVImageBufferYCbCrMatrix_ITU_R_709_2_String]) {
        matrix.matrix = isFullRange ? ColorMatrix709FullRange : ColorMatrix709VideoRange;
    }
    
    matrix.fullRange = isFullRange;
    //self.mtkView.device 是 MTKView 所使用的 Metal 设备。
//    newBufferWithBytes: 方法用于创建一个新的 Metal 缓冲区对象。
//    &matrix 是指向 matrix 结构体的指针，表示要存储到缓冲区中的数据的起始地址。
//    sizeof(KFConvertMatrix) 表示要存储的数据的长度，即 KFConvertMatrix 结构体的大小。
//    MTLResourceStorageModeShared 是缓冲区的存储模式选项，表示该缓冲区可以在 CPU 和 GPU 之间共享，方便数据的读写操作
    self.yuvMatrix = [self.mtkView.device newBufferWithBytes:&matrix
                                                          length:sizeof(ConvertMatrix)
                                                         options:MTLResourceStorageModeShared];
}


//根据视图的填充模式（_fillMode）计算顶点数据，并将这些顶点数据存储到 Metal 缓冲区中
- (void)_updaterVertices {
    // 根据填充模式计算顶点数据。
    //初始化 heightScaling 和 widthScaling 为 1.0，这两个变量将用于后续计算顶点的缩放比例
    float heightScaling = 1.0;
    float widthScaling = 1.0;
    
    //检查 _currentViewSize 和 _pixelBufferSize 是否都不为零。如果都不为零，则进行后续的缩放因子计算
    if (!CGSizeEqualToSize(_currentViewSize, CGSizeZero) && !CGSizeEqualToSize(_pixelBufferSize, CGSizeZero)) {
        //使用 AVMakeRectWithAspectRatioInsideRect 函数计算一个包含在当前视图内，且保持像素缓冲区宽高比的矩形 insetRect。
        CGRect insetRect = AVMakeRectWithAspectRatioInsideRect(_pixelBufferSize, CGRectMake(0, 0, _currentViewSize.width, _currentViewSize.height));
        
        switch (_fillMode) {
            //拉伸模式，将 widthScaling 和 heightScaling 都设置为 1.0，即不进行缩放。
            case MetalViewContentModeStretch: {
                //图像或视频会被直接拉伸或压缩以完全填充整个视图区域，不考虑其原始的宽高比。这可能会导致图像或视频在显示时出现变形，例如原本是正方形的物体可能会被拉伸成矩形。
                widthScaling = 1.0;
                heightScaling = 1.0;
                break;
            }
            //适应模式，计算 insetRect 的宽度和高度与当前视图宽度和高度的比例，作为缩放因子。
            case MetalViewContentModeFit: {
                //图像或视频会保持其原始的宽高比，完整地显示在视图内，并且尽可能地填充视图。在这种模式下，图像或视频不会变形，但可能会在视图的上下或左右两侧出现空白区域。
                widthScaling = insetRect.size.width / _currentViewSize.width;
                heightScaling = insetRect.size.height / _currentViewSize.height;
                break;
            }
            //填充模式，计算当前视图高度与 insetRect 高度的比例，以及当前视图宽度与 insetRect 宽度的比例，作为缩放因子。
            case MetalViewContentModeFill: {
                //图像或视频会保持其原始的宽高比，并且完全填充整个视图区域。为了实现这一点，图像或视频可能会被裁剪一部分，即只显示图像或视频的一部分内容，以确保其能够填满整个视图而不出现空白区域。
                widthScaling = _currentViewSize.height / insetRect.size.height;
                heightScaling = _currentViewSize.width / insetRect.size.width;
                break;
            }
        }
    }
    
    
    //定义一个 Vertex 类型的数组 quadVertices，表示一个四边形的四个顶点。每个顶点包含一个四维位置向量和一个二维纹理坐标向量。位置向量的 x 和 y 分量根据计算得到的缩放因子进行缩放
    Vertex quadVertices[] =
    {
        { { -widthScaling, -heightScaling, 0.0, 1.0 },  { 0.f, 1.f } },
        { { widthScaling,  -heightScaling, 0.0, 1.0 },  { 1.f, 1.f } },
        { { -widthScaling, heightScaling,  0.0, 1.0 },  { 0.f, 0.f } },
        { {  widthScaling, heightScaling,  0.0, 1.0 },  { 1.f, 0.f } },
    };
    // MTLResourceStorageModeShared 属性可共享的，表示可以被顶点或者片元函数或者其他函数使用。
    //使用 self.mtkView.device 创建一个新的 Metal 缓冲区，并将 quadVertices 数组的数据存储到该缓冲区中
    //MTLResourceStorageModeShared 表示该缓冲区可以在 CPU 和 GPU 之间共享，方便数据的读写操作。
    self.vertices = [self.mtkView.device newBufferWithBytes:quadVertices
                                                 length:sizeof(quadVertices)
                                                options:MTLResourceStorageModeShared];
    // 获取顶点数量。
    //计算 quadVertices 数组中顶点的数量，并将结果存储到 self.numVertices 中
    self.numVertices = sizeof(quadVertices) / sizeof(Vertex);
}


//判断传入的 CVPixelBufferRef 类型的像素缓冲区中的 YUV 数据是否采用全范围（Full Range
- (BOOL)_pixelBufferIsFullRange:(CVPixelBufferRef)pixelBuffer {
    // 判断 YUV 数据是否为 full range。
    if (@available(iOS 15, *)) {
        CFDictionaryRef cfDicAttributes = CVPixelBufferCopyCreationAttributes(pixelBuffer);
        NSDictionary *dicAttributes = (__bridge_transfer NSDictionary*)cfDicAttributes;
        if (dicAttributes && [dicAttributes objectForKey:@"PixelFormatDescription"]) {
            NSDictionary *pixelFormatDescription = [dicAttributes objectForKey:@"PixelFormatDescription"];
            if (pixelFormatDescription && [pixelFormatDescription objectForKey:(__bridge NSString*)kCVPixelFormatComponentRange]) {
                NSString *componentRange = [pixelFormatDescription objectForKey:(__bridge NSString*)kCVPixelFormatComponentRange];
                return [componentRange isEqualToString:(__bridge NSString*)kCVPixelFormatComponentRange_FullRange];
            }
        }
    }else{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        OSType formatType = CVPixelBufferGetPixelFormatType(pixelBuffer);
        return formatType == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
#pragma clang diagnostic pop
    }
    
    return NO;
}


//将像素缓冲区中的图像数据渲染到屏幕上
//线程同步：使用信号量确保同一时间只有一个线程可以访问像素缓冲区。
//创建命令缓冲区和渲染命令编码器：为当前渲染过程创建必要的命令和编码工具。
//设置渲染参数：包括视口、渲染管道、顶点数据等。
//处理纹理数据：根据像素缓冲区的格式（YUV 或 RGB）获取相应的纹理，并传递给渲染命令编码器。
//处理 YUV 矩阵（如果是 YUV 格式）：初始化并传递 YUV 到 RGB 的转换矩阵。
//绘制图形：指定绘制的图元类型和顶点信息。
//结束编码、显示和提交命令：完成渲染过程。
//释放资源和信号量：释放像素缓冲区并释放信号量。
- (void)_drawInMTKView:(MTKView*)view {
    // 渲染数据。
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    if (_pixelBuffer) {
        // 为当前渲染的每个渲染传递创建一个新的命令缓冲区。
        id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
        // 获取渲染命令编码器 MTLRenderCommandEncoder 的描述符。
        // currentRenderPassDescriptor 描述符包含 currentDrawable 的纹理、视图的深度、模板和 sample 缓冲区和清晰的值。
        // MTLRenderPassDescriptor 描述一系列 attachments 的值，类似 OpenGL 的 FrameBuffer；同时也用来创建 MTLRenderCommandEncoder。
        MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;
        if (renderPassDescriptor) {
            // 根据描述创建 x 渲染命令编码器。
            id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
            // 设置绘制区域。
            [renderEncoder setViewport:(MTLViewport) {0.0, 0.0, self.viewportSize.x, self.viewportSize.y, -1.0, 1.0 }];
            BOOL isRenderYUV = CVPixelBufferGetPlaneCount(_pixelBuffer) > 1;
            
            // 根据是否为 YUV 初始化渲染管道。
            if (!self.pipelineState) {
                [self _setupPipeline:isRenderYUV];
            }
            // 设置渲染管道。
            [renderEncoder setRenderPipelineState:self.pipelineState];
            
            // 更新填充模式。
            if (_updateFillMode) {
                [self _updaterVertices];
                _updateFillMode = NO;
            }
            // 传递顶点缓存。
            [renderEncoder setVertexBuffer:self.vertices
                                    offset:0
                                   atIndex:VertexInputIndexVertices];
            CVPixelBufferRef pixelBuffer = _pixelBuffer;
            
            if (isRenderYUV) {
                // 获取 y、uv 纹理。
                id<MTLTexture> textureY = nil;
                id<MTLTexture> textureUV = nil;
                {
                    size_t width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0);
                    size_t height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0);
                    MTLPixelFormat pixelFormat = MTLPixelFormatR8Unorm;
                    
                    CVMetalTextureRef texture = NULL;
                    CVReturn status = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, _textureCache, pixelBuffer, NULL, pixelFormat, width, height, 0, &texture);
                    if (status == kCVReturnSuccess) {
                        textureY = CVMetalTextureGetTexture(texture);
                        CFRelease(texture);
                    }
                }
                
                {
                    size_t width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 1);
                    size_t height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 1);
                    MTLPixelFormat pixelFormat = MTLPixelFormatRG8Unorm;
                    
                    CVMetalTextureRef texture = NULL;
                    CVReturn status = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, _textureCache, pixelBuffer, NULL, pixelFormat, width, height, 1, &texture);
                    if (status == kCVReturnSuccess) {
                        textureUV = CVMetalTextureGetTexture(texture);
                        CFRelease(texture);
                    }
                }
                
                // 传递纹理。
                if (textureY != nil && textureUV != nil) {
                    [renderEncoder setFragmentTexture:textureY
                                              atIndex:FragmentTextureIndexTextureY];
                    [renderEncoder setFragmentTexture:textureUV
                                              atIndex:FragmentTextureIndexTextureUV];
                }
                
                // 初始化 YUV 矩阵。
                if (!self.yuvMatrix) {
                    CFTypeRef matrixKey = kCVImageBufferYCbCrMatrix_ITU_R_601_4;
                    if (@available(iOS 15, *)) {
                        matrixKey = CVBufferCopyAttachment(pixelBuffer, kCVImageBufferYCbCrMatrixKey, NULL);
                    }else{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                        matrixKey = CVBufferGetAttachment(pixelBuffer, kCVImageBufferYCbCrMatrixKey, NULL);
#pragma clang diagnostic pop
                    }
                    [self _setupYUVMatrix:[self _pixelBufferIsFullRange:pixelBuffer] colorSpace:matrixKey];
                    CFRelease(matrixKey);
                }
                // 传递 YUV 矩阵。
                [renderEncoder setFragmentBuffer:self.yuvMatrix
                                          offset:0
                                         atIndex:FragmentInputIndexMatrix];
            } else {
                // 生成 rgba 纹理。
                id<MTLTexture> textureRGB = nil;
                size_t width = CVPixelBufferGetWidth(pixelBuffer);
                size_t height = CVPixelBufferGetHeight(pixelBuffer);
                MTLPixelFormat pixelFormat = MTLPixelFormatBGRA8Unorm;
                
                CVMetalTextureRef texture = NULL;
                CVReturn status = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, _textureCache, pixelBuffer, NULL, pixelFormat, width, height, 0, &texture);
                if (status == kCVReturnSuccess) {
                    textureRGB = CVMetalTextureGetTexture(texture);
                    CFRelease(texture);
                }
                
                // 传递纹理。
                if (textureRGB) {
                    [renderEncoder setFragmentTexture:textureRGB
                                              atIndex:FragmentTextureIndexTextureRGB];
                }
            }
            
            // 绘制。
            [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangleStrip
                              vertexStart:0
                              vertexCount:self.numVertices];
            
            // 命令结束。
            [renderEncoder endEncoding];
            
            // 显示。
            [commandBuffer presentDrawable:view.currentDrawable];
            
            // 提交。
            [commandBuffer commit];
        }
        
        CFRelease(_pixelBuffer);
        _pixelBuffer = NULL;
    }
    dispatch_semaphore_signal(_semaphore);
}


#pragma mark - MTKViewDelegate
//MTKViewDelegate 协议中的一个回调方法，当 MTKView 的可绘制区域（drawable）大小即将发生变化时，系统会自动调用该方法。
- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {
    self.viewportSize = (vector_uint2) {size.width, size.height};
}

//MTKViewDelegate 协议中的一个回调方法，当 MTKView 需要进行绘制操作时，系统会调用该方法。其主要作用是将实际的绘制任务异步分发到自定义的渲染队列 _renderQueue 中执行
- (void)drawInMTKView:(nonnull MTKView *)view {
    // Metal 视图回调，有数据情况下渲染视图。
    __weak typeof(self) weakSelf = self;
    dispatch_async(_renderQueue, ^{
        [weakSelf _drawInMTKView:view];
    });
}

@end
