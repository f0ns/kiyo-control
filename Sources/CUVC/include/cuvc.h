#ifndef CUVC_H
#define CUVC_H

#include <stdint.h>

typedef struct cuvc_device cuvc_device;

/// Opens the first USB device matching vid/pid. Does not claim the device, so
/// other apps can keep streaming from the camera. Returns NULL when not found.
cuvc_device *cuvc_open(uint16_t vid, uint16_t pid);
void cuvc_close(cuvc_device *dev);

/// Sends a UVC class request to `unit` on VideoControl `interface`.
/// Requests with the high bit set (GET_*) read into `data`, others write from it.
/// Returns an IOReturn code (0 on success) and stores the byte count in `transferred`.
int32_t cuvc_request(cuvc_device *dev, uint8_t request, uint8_t unit, uint8_t selector,
                     uint8_t interface, void *data, uint16_t length, uint16_t *transferred);

#endif
