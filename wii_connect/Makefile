CC = gcc
CFLAGS = -Wall -Wextra -std=c99 
LDFLAGS = -I$(shell pwd)/include
LDFLAGS += -L$(shell pwd)/lib
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
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS) -D MODE=PRODUCTION_MODE