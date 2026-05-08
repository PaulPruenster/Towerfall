CC = gcc
CFLAGS = -Wall -Wextra -std=c99
CPPFLAGS = -I./include

X11_LIBS ?= $(shell pkg-config --libs x11 xtst 2>/dev/null || echo "-lX11 -lXtst")
BLUETOOTH_LIB ?= $(firstword $(wildcard /lib/x86_64-linux-gnu/libbluetooth.so /lib/x86_64-linux-gnu/libbluetooth.so.* /usr/lib/x86_64-linux-gnu/libbluetooth.so /usr/lib/x86_64-linux-gnu/libbluetooth.so.*))
CJSON_LIB ?= $(firstword $(wildcard /lib/x86_64-linux-gnu/libcjson.so /lib/x86_64-linux-gnu/libcjson.so.* /usr/lib/x86_64-linux-gnu/libcjson.so /usr/lib/x86_64-linux-gnu/libcjson.so.*))

ifeq ($(BLUETOOTH_LIB),)
$(error Could not find libbluetooth. Install BlueZ runtime/development files or set BLUETOOTH_LIB=/path/to/libbluetooth.so)
endif

ifeq ($(CJSON_LIB),)
$(error Could not find libcjson. Install cJSON runtime/development files or set CJSON_LIB=/path/to/libcjson.so)
endif

LDLIBS = -L./lib -lwiiuse -lm $(X11_LIBS) $(BLUETOOTH_LIB) $(CJSON_LIB)

TARGET = wii
SRC = wii.c

all: $(TARGET)

$(TARGET): $(SRC)
	$(CC) $(CFLAGS) $(CPPFLAGS) -o $@ $^ $(LDLIBS)

clean:
	rm -f $(TARGET) wii_prod

wii_prod: $(SRC)
	$(CC) $(CFLAGS) $(CPPFLAGS) -D MODE=PRODUCTION_MODE -o $@ $^ $(LDLIBS)
