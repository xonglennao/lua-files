gcc lpeg.c -o ../../bin/lpeg.dll -shared -ansi -llua51 -L../../bin -I. -I../lua -O2 -DNDEBUG \
	-Wall -Wextra -pedantic \
   -Waggregate-return \
	-Wbad-function-cast \
	-Wcast-align \
   -Wcast-qual \
	-Wdeclaration-after-statement \
	-Wdisabled-optimization \
   -Wmissing-prototypes \
   -Wnested-externs \
   -Wpointer-arith \
   -Wshadow \
	-Wsign-compare \
	-Wstrict-prototypes \
	-Wundef \
   -Wwrite-strings \
	#  -Wunreachable-code \
