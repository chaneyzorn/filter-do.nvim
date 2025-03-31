.PHONY: llscheck luacheck stylua

llscheck:
	VIMRUNTIME=`nlua -e 'io.write(os.getenv("VIMRUNTIME"))'` llscheck --configpath .luarc.json .

luacheck:
	luacheck lua plugin

stylua:
	stylua lua plugin
