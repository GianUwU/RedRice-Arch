CXX ?= g++
CXXFLAGS := -shared -fPIC -std=c++26 -O2 -DWLR_USE_UNSTABLE $(shell pkg-config --cflags hyprland)
TARGET := hypr-zstack.so
SRC := src/main.cpp

all: $(TARGET)

$(TARGET): $(SRC)
	$(CXX) $(CXXFLAGS) $< -o $@

clean:
	rm -f $(TARGET) hypr-zstack-v*.so

.PHONY: all clean
