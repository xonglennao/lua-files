gcc -s -O3 -shared -o ../../bin/libexif.dll -g -Wall libexif/*.c libexif/*/*.c -I. -D__WATCOMC__

cd ../.. && linux/bin/luajit libexif.lua
