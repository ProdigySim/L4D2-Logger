all: logger logger-plugin.smx

logger: logger.c
	gcc -o logger logger.c

logger-plugin.smx: logger-plugin.sp
	spcomp logger-plugin.sp

clean:
	-@rm logger logger-plugin.smx
