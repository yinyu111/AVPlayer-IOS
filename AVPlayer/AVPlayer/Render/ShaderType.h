//
//  ShaderType.h
//  AVPlayer
//
//  Created by 尹玉 on 2025/3/1.
//

#ifndef ShaderType_h
#define ShaderType_h


#include <simd/simd.h>

// 存储数据的自定义结构，用于桥接 OC 和 Metal 代码（顶点）。
typedef struct {
    // 顶点坐标，4 维向量。
    vector_float4 position;
    // 纹理坐标。
    vector_float2 textureCoordinate;
} Vertex;

// 存储数据的自定义结构，用于桥接 OC 和 Metal 代码（顶点）。
typedef struct {
    // YUV 矩阵。
    matrix_float3x3 matrix;
    // 是否为 full range。
    bool fullRange;
} ConvertMatrix;

// 自定义枚举，用于桥接 OC 和 Metal 代码（顶点）。
// 顶点的桥接枚举值 KFVertexInputIndexVertices。
typedef enum VertexInputIndex {
    VertexInputIndexVertices = 0,
} VertexInputIndex;

// 自定义枚举，用于桥接 OC 和 Metal 代码（片元）。
// YUV 矩阵的桥接枚举值 KFFragmentInputIndexMatrix。
typedef enum FragmentBufferIndex {
    FragmentInputIndexMatrix = 0,
} MetalFragmentBufferIndex;

// 自定义枚举，用于桥接 OC 和 Metal 代码（片元）。
// YUV 数据的桥接枚举值 FragmentTextureIndexTextureY、FragmentTextureIndexTextureUV。
typedef enum FragmentYUVTextureIndex {
    FragmentTextureIndexTextureY = 0,
    FragmentTextureIndexTextureUV = 1,
} FragmentYUVTextureIndex;

// 自定义枚举，用于桥接 OC 和 Metal 代码（片元）。
// RGBA 数据的桥接枚举值 FragmentTextureIndexTextureRGB。
typedef enum FragmentRGBTextureIndex {
    FragmentTextureIndexTextureRGB = 0,
} FragmentRGBTextureIndex;



#endif /* ShaderType_h */
