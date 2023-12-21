CC = gcc
CFLAGS = -Wall -Wextra -std=c99
#LDFLAGS = -I./include
LDFLAGS += -L./lib -Wl,-rpath=./lib
LDFLAGS += -lwiiuse
LDFLAGS += -lm -lbluetooth -lX11 -lXtst
TARGET = wii
SRC = wii.c

all: $(TARGET)

$(TARGET): $(SRC)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

clean:
	rm -f $(TARGET)

wii_prod: $(SRC)
	$(CC) $(CFLAGS) -S $^ $(LDFLAGS) -D MODE=PRODUCTION_MODE

wii_cpp: wii.cpp
	$(CC) $(CFLAGS)  -o $@ $^ $(LDFLAGS) -lstdc++
