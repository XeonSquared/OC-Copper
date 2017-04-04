all: uc-rsctl.lua basestack.lua

uc-rsctl.lua: postprocess.lua ecomponents/base ecomponents/relib ecomponents/app-rsctrl
	cat ecomponents/base ecomponents/relib ecomponents/app-rsctrl | lua postprocess.lua > uc-rsctl.lua

basestack.lua: postprocess.lua ecomponents/base ecomponents/relib
	cat ecomponents/base ecomponents/relib | lua postprocess.lua > basestack.lua

clean: .PHONY
	rm -f uc-rsctl.lua basestack.lua
