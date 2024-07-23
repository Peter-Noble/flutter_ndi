#include "cuda_runtime.h"
#include "device_launch_parameters.h"
#include <math.h>
#include <stdint.h>
#include <iostream>

#include "ndi_convert_interface.h"

#ifdef __cplusplus
#define EXTERNC extern "C" __declspec(dllexport)
#else
#define EXTERNC
#endif

#define THREADS 256

__device__ uint8_t clampUint8(int v)
{
    if (v > 255)
        return 255;
    if (v < 0)
        return 0;
    return (uint8_t)v;
}

__global__ void kernelUYVYToRGBA(uint8_t *d_src, uint8_t *d_dest, int pixcount)
{
    int pix = blockIdx.x * blockDim.x + threadIdx.x;

    if (pix >= pixcount)
        return;
    int i = pix * 2;

    int y, u, v;
    y = d_src[i + 1] - 16;

    if (pix % 2 == 0)
    {
        u = d_src[i];
        v = d_src[i + 2];
    }
    else
    {
        v = d_src[i];
        u = d_src[i - 2];
    }
    u -= 128;
    v -= 128;

    uint8_t r = clampUint8((int)roundf(1.164 * y + 1.596 * v));
    uint8_t g = clampUint8((int)roundf(1.164 * y - 0.392 * u - 0.813 * v));
    uint8_t b = clampUint8((int)roundf(1.164 * y + 2.017 * u));

    int offset = pix * 4;
    d_dest[offset] = r;
    d_dest[offset + 1] = g;
    d_dest[offset + 2] = b;
    d_dest[offset + 3] = 255;
}

EXTERNC void UYVYToRGBA(int width, int height, uint8_t *src, uint8_t *dest)
{
    uint8_t *d_src;
    uint8_t *d_dest;
    size_t srcSize = sizeof(uint8_t) * width * height * 2;
    size_t destSize = sizeof(uint8_t) * width * height * 4;
    int pixcount = width * height;

    cudaMalloc(&d_src, srcSize);
    cudaMemcpy(d_src, src, srcSize, cudaMemcpyHostToDevice);

    cudaMalloc(&d_dest, destSize);
    int blockCount = (int)ceil(pixcount / (double)THREADS);

    kernelUYVYToRGBA<<<blockCount, THREADS>>>(d_src, d_dest, pixcount);
    cudaDeviceSynchronize();

    cudaMemcpy(dest, d_dest, destSize, cudaMemcpyDeviceToHost);

    cudaFree(d_src);
    cudaFree(d_dest);
}

__global__ void kernelBGRAToRGBA(uint8_t *d_src, uint8_t *d_dest, int pixcount)
{
    int pix = blockIdx.x * blockDim.x + threadIdx.x;

    if (pix >= pixcount)
        return;
    int pixb = pix * 4;

    d_dest[pixb] = d_src[pixb + 2];
    d_dest[pixb + 1] = d_src[pixb + 1];
    d_dest[pixb + 2] = d_src[pixb];
    d_dest[pixb + 3] = d_src[pixb + 3];
    // d_dest[pixb] = (uint8_t)255;
    // d_dest[pixb + 1] = (uint8_t)255;
    // d_dest[pixb + 2] = (uint8_t)0;
    // d_dest[pixb + 3] = (uint8_t)255;
}

EXTERNC void BGRAToRGBA(int width, int height, uint8_t *src, uint8_t *dest)
{
    uint8_t *d_src;
    uint8_t *d_dest;
    size_t srcSize = sizeof(uint8_t) * width * height * 4;
    size_t destSize = sizeof(uint8_t) * width * height * 4;
    int pixcount = width * height;

    cudaMalloc(&d_src, srcSize);
    cudaMemcpy(d_src, src, srcSize, cudaMemcpyHostToDevice);

    cudaMalloc(&d_dest, destSize);
    int blockCount = (int)ceil(pixcount / (double)THREADS);

    kernelBGRAToRGBA<<<blockCount, THREADS>>>(d_src, d_dest, pixcount);
    cudaDeviceSynchronize();

    cudaMemcpy(dest, d_dest, destSize, cudaMemcpyDeviceToHost);

    cudaFree(d_src);
    cudaFree(d_dest);
}

EXTERNC void getDeviceProperties(int *major, int *minor)
{
    cudaDeviceProp deviceProp;
    cudaGetDeviceProperties(&deviceProp, 0);
    major[0] = deviceProp.major;
    minor[0] = deviceProp.minor;
}
