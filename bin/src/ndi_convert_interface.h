#include <stdint.h>

#ifdef __cplusplus
#define EXTERNC extern "C" __declspec(dllexport)
#else
#define EXTERNC
#endif

EXTERNC void UYVYToRGBA(int width, int height, uint8_t *src, uint8_t *dest);
EXTERNC void BGRAToRGBA(int width, int height, uint8_t *src, uint8_t *dest);
EXTERNC void getDeviceProperties(int *major, int *minor);
