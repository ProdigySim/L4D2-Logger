all: logger-plugin.smx

logger-plugin.smx: logger-plugin.sp
	spcomp logger-plugin.sp

clean:
	-@rm logger-plugin.smx
