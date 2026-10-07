#include "cuvc.h"
#include <stdlib.h>
#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/IOCFPlugIn.h>
#include <IOKit/usb/IOUSBLib.h>

struct cuvc_device {
    IOUSBDeviceInterface **intf;
};

cuvc_device *cuvc_open(uint16_t vid, uint16_t pid) {
    long v = vid, p = pid;
    CFMutableDictionaryRef match = IOServiceMatching(kIOUSBDeviceClassName);
    CFNumberRef vn = CFNumberCreate(NULL, kCFNumberLongType, &v);
    CFNumberRef pn = CFNumberCreate(NULL, kCFNumberLongType, &p);
    CFDictionarySetValue(match, CFSTR(kUSBVendorID), vn);
    CFDictionarySetValue(match, CFSTR(kUSBProductID), pn);
    CFRelease(vn);
    CFRelease(pn);

    io_service_t svc = IOServiceGetMatchingService(kIOMainPortDefault, match);
    if (!svc) return NULL;

    IOCFPlugInInterface **plug = NULL;
    SInt32 score;
    kern_return_t kr = IOCreatePlugInInterfaceForService(svc, kIOUSBDeviceUserClientTypeID,
                                                         kIOCFPlugInInterfaceID, &plug, &score);
    IOObjectRelease(svc);
    if (kr != KERN_SUCCESS || !plug) return NULL;

    IOUSBDeviceInterface **intf = NULL;
    (*plug)->QueryInterface(plug, CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID), (LPVOID *)&intf);
    (*plug)->Release(plug);
    if (!intf) return NULL;

    cuvc_device *dev = malloc(sizeof *dev);
    dev->intf = intf;
    return dev;
}

void cuvc_close(cuvc_device *dev) {
    if (!dev) return;
    (*dev->intf)->Release(dev->intf);
    free(dev);
}

int32_t cuvc_request(cuvc_device *dev, uint8_t request, uint8_t unit, uint8_t selector,
                     uint8_t interface, void *data, uint16_t length, uint16_t *transferred) {
    IOUSBDevRequest r = {
        .bmRequestType = USBmakebmRequestType((request & 0x80) ? kUSBIn : kUSBOut, kUSBClass, kUSBInterface),
        .bRequest = request,
        .wValue = (uint16_t)(selector << 8),
        .wIndex = (uint16_t)(unit << 8 | interface),
        .wLength = length,
        .pData = data,
    };
    IOReturn rc = (*dev->intf)->DeviceRequest(dev->intf, &r);
    if (transferred) *transferred = (uint16_t)r.wLenDone;
    return rc;
}
