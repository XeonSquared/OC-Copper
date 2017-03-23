all: uc-rsctl.lua

uc-rsctl.lua: postprocess.lua ecomponents/base ecomponents/relib ecomponents/app-rsctrl
	cat ecomponents/base ecomponents/relib ecomponents/app-rsctrl | lua postprocess.lua > uc-rsctl.lua

clean: .PHONY
	rm -f uc-rsctl.lua
