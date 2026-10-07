// Dump the UVC VideoControl descriptors of a USB camera (read-only).
// Build: clang -framework IOKit -framework CoreFoundation uvc-dump.c -o uvc-dump
#include <stdio.h>
#include <stdlib.h>
#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/IOCFPlugIn.h>
#include <IOKit/usb/IOUSBLib.h>

static const char *ct_names[] = {
    "Scanning Mode", "Auto-Exposure Mode", "Auto-Exposure Priority", "Exposure Time (Absolute)",
    "Exposure Time (Relative)", "Focus (Absolute)", "Focus (Relative)", "Iris (Absolute)",
    "Iris (Relative)", "Zoom (Absolute)", "Zoom (Relative)", "PanTilt (Absolute)",
    "PanTilt (Relative)", "Roll (Absolute)", "Roll (Relative)", "Reserved",
    "Reserved", "Focus, Auto", "Privacy", "Focus, Simple",
    "Window", "Region of Interest"};
static const char *pu_names[] = {
    "Brightness", "Contrast", "Hue", "Saturation", "Sharpness", "Gamma",
    "White Balance Temperature", "White Balance Component", "Backlight Compensation",
    "Gain", "Power Line Frequency", "Hue, Auto", "White Balance Temperature, Auto",
    "White Balance Component, Auto", "Digital Multiplier", "Digital Multiplier Limit",
    "Analog Video Standard", "Analog Video Lock Status", "Contrast, Auto"};

static void print_bits(const uint8_t *bm, int size, const char **names, int nnames) {
    for (int i = 0; i < size * 8; i++)
        if (bm[i / 8] & (1 << (i % 8)))
            printf("      bit %2d  %s\n", i, i < nnames ? names[i] : "(vendor/unknown)");
}

int main(int argc, char **argv) {
    long vid = argc > 1 ? strtol(argv[1], NULL, 16) : 0x1532;
    long pid = argc > 2 ? strtol(argv[2], NULL, 16) : 0x0E08;

    CFMutableDictionaryRef match = IOServiceMatching(kIOUSBDeviceClassName);
    CFDictionarySetValue(match, CFSTR(kUSBVendorID), CFNumberCreate(NULL, kCFNumberLongType, &vid));
    CFDictionarySetValue(match, CFSTR(kUSBProductID), CFNumberCreate(NULL, kCFNumberLongType, &pid));
    io_service_t svc = IOServiceGetMatchingService(kIOMainPortDefault, match);
    if (!svc) { fprintf(stderr, "Device %04lx:%04lx not found\n", vid, pid); return 1; }

    IOCFPlugInInterface **plug; SInt32 score;
    if (IOCreatePlugInInterfaceForService(svc, kIOUSBDeviceUserClientTypeID, kIOCFPlugInInterfaceID, &plug, &score)) {
        fprintf(stderr, "Cannot create plugin\n"); return 1;
    }
    IOUSBDeviceInterface **dev;
    (*plug)->QueryInterface(plug, CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID), (LPVOID *)&dev);
    (*plug)->Release(plug);

    IOUSBConfigurationDescriptorPtr cfg;
    if ((*dev)->GetConfigurationDescriptorPtr(dev, 0, &cfg)) { fprintf(stderr, "No config descriptor\n"); return 1; }

    const uint8_t *p = (const uint8_t *)cfg, *end = p + USBToHostWord(cfg->wTotalLength);
    int in_vc = 0;
    for (; p < end && p[0]; p += p[0]) {
        uint8_t len = p[0], type = p[1];
        if (type == 0x04) {  // interface
            in_vc = (p[5] == 0x0E && p[6] == 0x01);
            printf("Interface %d alt %d class %02x/%02x%s\n", p[2], p[3], p[5], p[6], in_vc ? "  [VideoControl]" : "");
            continue;
        }
        if (type != 0x24 || !in_vc) continue;
        switch (p[2]) {
        case 0x01: printf("  VC Header  UVC %x.%02x\n", p[4], p[3]); break;
        case 0x02:
            printf("  Input Terminal id=%d type=0x%04x\n", p[3], p[4] | p[5] << 8);
            if ((p[4] | p[5] << 8) == 0x0201 && len >= 15) print_bits(p + 15, p[14], ct_names, 22);
            break;
        case 0x03: printf("  Output Terminal id=%d source=%d\n", p[3], p[7]); break;
        case 0x04: printf("  Selector Unit id=%d\n", p[3]); break;
        case 0x05:
            printf("  Processing Unit id=%d source=%d\n", p[3], p[4]);
            print_bits(p + 8, p[7], pu_names, 19);
            break;
        case 0x06: {
            const uint8_t *g = p + 4;
            printf("  Extension Unit id=%d guid={%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x} numControls=%d\n",
                   p[3], g[3], g[2], g[1], g[0], g[5], g[4], g[7], g[6], g[8], g[9], g[10], g[11], g[12], g[13], g[14], g[15], p[20]);
            int nin = p[21], csize = p[22 + nin];
            printf("      controls bitmap:");
            for (int i = 0; i < csize; i++) printf(" %02x", p[23 + nin + i]);
            printf("\n      selectors:");
            for (int i = 0; i < csize * 8; i++) if (p[23 + nin + i / 8] & (1 << (i % 8))) printf(" %d", i + 1);
            printf("\n");
            break;
        }
        default: printf("  VC subtype 0x%02x\n", p[2]);
        }
    }
    (*dev)->Release(dev);
    return 0;
}
