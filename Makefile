all: logger logger-plugin.smx

logger:
	gcc -o logger logger.c

logger-plugin.smx:
	spcomp logger-plugin.sp

clean:
	rm logger logger-plugin.smx
