// Read-only probe of UVC extension unit controls (GET_INFO/LEN/CUR/MIN/MAX/DEF only).
// Build: clang -framework IOKit -framework CoreFoundation uvc-probe.c -o uvc-probe
#include <stdio.h>
#include <stdlib.h>
#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/IOCFPlugIn.h>
#include <IOKit/usb/IOUSBLib.h>

enum { GET_CUR = 0x81, GET_MIN = 0x82, GET_MAX = 0x83, GET_LEN = 0x85, GET_INFO = 0x86, GET_DEF = 0x87 };

static IOUSBDeviceInterface **dev;

static int get(uint8_t req, int unit, int sel, void *buf, uint16_t len) {
    IOUSBDevRequest r = {
        .bmRequestType = USBmakebmRequestType(kUSBIn, kUSBClass, kUSBInterface),
        .bRequest = req, .wValue = sel << 8, .wIndex = unit << 8, .wLength = len, .pData = buf};
    return (*dev)->DeviceRequest(dev, &r) == kIOReturnSuccess ? (int)r.wLenDone : -1;
}

static void hex(const char *label, uint8_t req, int unit, int sel, int len) {
    uint8_t buf[256] = {0};
    int n = get(req, unit, sel, buf, len);
    printf(" %s=", label);
    if (n < 0) { printf("--"); return; }
    for (int i = 0; i < n; i++) printf("%02x", buf[i]);
}

int main(void) {
    long vid = 0x1532, pid = 0x0E08;
    CFMutableDictionaryRef match = IOServiceMatching(kIOUSBDeviceClassName);
    CFDictionarySetValue(match, CFSTR(kUSBVendorID), CFNumberCreate(NULL, kCFNumberLongType, &vid));
    CFDictionarySetValue(match, CFSTR(kUSBProductID), CFNumberCreate(NULL, kCFNumberLongType, &pid));
    io_service_t svc = IOServiceGetMatchingService(kIOMainPortDefault, match);
    if (!svc) { fprintf(stderr, "Camera not found\n"); return 1; }
    IOCFPlugInInterface **plug; SInt32 score;
    IOCreatePlugInInterfaceForService(svc, kIOUSBDeviceUserClientTypeID, kIOCFPlugInInterfaceID, &plug, &score);
    (*plug)->QueryInterface(plug, CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID), (LPVOID *)&dev);
    (*plug)->Release(plug);

    struct { int unit, sels[16], n; } units[] = {
        {2, {1, 2, 3, 4, 5, 6}, 6},
        {6, {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 14, 15}, 14}};
    for (int u = 0; u < 2; u++)
        for (int i = 0; i < units[u].n; i++) {
            int sel = units[u].sels[i];
            uint8_t lenb[2] = {0}, info = 0;
            int ok = get(GET_LEN, units[u].unit, sel, lenb, 2);
            get(GET_INFO, units[u].unit, sel, &info, 1);
            int len = lenb[0] | lenb[1] << 8;
            printf("XU%d sel%-2d len=%-3d info=%02x%s%s", units[u].unit, sel, ok < 0 ? -1 : len, info,
                   info & 1 ? " GET" : "", info & 2 ? " SET" : "");
            if (ok >= 0 && len > 0 && len <= 64) {
                hex("cur", GET_CUR, units[u].unit, sel, len);
                hex("min", GET_MIN, units[u].unit, sel, len);
                hex("max", GET_MAX, units[u].unit, sel, len);
                hex("def", GET_DEF, units[u].unit, sel, len);
            }
            printf("\n");
        }
    (*dev)->Release(dev);
    return 0;
}
