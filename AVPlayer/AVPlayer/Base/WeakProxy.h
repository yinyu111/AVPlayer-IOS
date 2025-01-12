//
//  WeakProxy.h
//  AVPlayer
//
//  Created by 尹玉 on 2025/1/9.
//

#import <Foundation/Foundation.h>

@interface WeakProxy : NSProxy
- (instancetype)initWithTarget:(id)target;
+ (instancetype)proxyWithTarget:(id)target;
@property (nonatomic, weak, readonly) id target;
@end
