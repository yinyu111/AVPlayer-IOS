//
//  MetalView.h
//  AVPlayer
//
//  Created by 尹玉 on 2025/3/1.
//

#ifndef MetalView_h
#define MetalView_h

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// 渲染画面填充模式。
typedef NS_ENUM(NSInteger, MetalViewContentMode) {
    // 自动填充满，可能会变形。
    MetalViewContentModeStretch = 0,
    // 按比例适配，可能会有黑边。
    MetalViewContentModeFit = 1,
    // 根据比例裁剪后填充满。
    MetalViewContentModeFill = 2
};

@interface MetalView : UIView
@property (nonatomic, assign) MetalViewContentMode fillMode; // 画面填充模式。
- (void)renderPixelBuffer:(CVPixelBufferRef)pixelBuffer; // 渲染。
@end

NS_ASSUME_NONNULL_END

#endif /* MetalView_h */
