CC ?= gcc
CFLAGS := -shared -fPIC -O2 $(shell pkg-config --cflags --libs gtk4)
TARGET := libswaync_helper.so
SRC := swaync_helper.c

all: $(TARGET)

$(TARGET): $(SRC)
	$(CC) $< $(CFLAGS) -o $@

clean:
	rm -f $(TARGET)

.PHONY: all clean
