.PHONY: gen_doc llscheck luacheck stylua

gen_doc:
	nvim -u scripts/gen_doc/minimal_init.lua -l scripts/gen_doc/main.lua

llscheck:
	VIMRUNTIME=`nlua -e 'io.write(os.getenv("VIMRUNTIME"))'` llscheck --configpath .luarc.json .

luacheck:
	luacheck lua plugin scripts

stylua:
	stylua lua plugin scripts
