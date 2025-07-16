CC = gcc
CFLAGS = -Wall -Wextra -std=c99 
LDFLAGS = -I./include -I/usr/include
LDFLAGS += -L./lib
LDFLAGS += -lwiiuse
LDFLAGS += -lm -lbluetooth -lX11 -lXtst -lcjson

TARGET = wii
SRC = wii.c

all: $(TARGET)

$(TARGET): $(SRC)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

clean:
	rm -f $(TARGET) wii_prod

wii_prod: $(SRC)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS) -D MODE=PRODUCTION_MODE