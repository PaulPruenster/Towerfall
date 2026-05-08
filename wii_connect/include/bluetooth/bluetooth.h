#ifndef WII_CONNECT_BLUEZ_COMPAT_BLUETOOTH_H
#define WII_CONNECT_BLUEZ_COMPAT_BLUETOOTH_H

#if defined(__has_include_next)
#if __has_include_next(<bluetooth/bluetooth.h>)
#include_next <bluetooth/bluetooth.h>
#define WII_CONNECT_USES_SYSTEM_BLUEZ_HEADER 1
#endif
#endif

#ifndef WII_CONNECT_USES_SYSTEM_BLUEZ_HEADER

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
	uint8_t b[6];
} __attribute__((packed)) bdaddr_t;

int ba2str(const bdaddr_t *ba, char *str);
int str2ba(const char *str, bdaddr_t *ba);
void bacpy(bdaddr_t *dst, const bdaddr_t *src);
int bacmp(const bdaddr_t *ba1, const bdaddr_t *ba2);
void baswap(bdaddr_t *dst, const bdaddr_t *src);

#ifdef __cplusplus
}
#endif

#endif

#endif
