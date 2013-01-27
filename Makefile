all: logger-plugin.smx logger.bin

logger.bin: logger.c
	gcc -lsqlite3 -o logger.bin logger.c

logger-plugin.smx: logger-plugin.sp
	spcomp logger-plugin.sp

clean:
	-@rm logger-plugin.smx logger.bin
