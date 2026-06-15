
# JDK8 := $(shell /usr/libexec/java_home -v 1.8)
GV=gv.sh
BIN=gv
TARGET := $(shell bash -c 'echo $$HOME')
UNAME_S := $(shell uname -s)

.PHONY: nothing install obf repo clean

nothing:
	@echo "usage: make ..."
	@echo ${TARGET}

# obf:
# 	@./version.sh --collect --out $(OUT)
# 	@echo "DONE!"

# repo:
# 	#@git add ...
# 	@git status --untracked-files=no
# 	@echo
# 	@./version.sh --print

gv:
	./${GV} --bash ./${GV}

install:
	@cp -v ./${GV} ${TARGET}/bin/${BIN}
	chmod +x ${TARGET}/bin/${BIN}
ifneq (,$(filter MINGW% MSYS% CYGWIN%,$(UNAME_S)))
	@printf '@echo off\r\n"C:\\Program Files\\Git\\bin\\bash.exe" "%%~dp0${BIN}" %%*\r\n' > ${TARGET}/bin/${BIN}.cmd
	@echo "created ${TARGET}/bin/${BIN}.cmd"
endif

# clean:
# 	rm -rf $(OUT) src/se/mitm/version 

