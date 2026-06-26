
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

# Run this from a self-consistent shell (one POSIX runtime): the MSYS2 shell on
# Windows, or a normal shell on macOS/Linux. Do NOT run it from Git Bash with
# msys64 `make` on PATH -- mixing the two msys-2.0.dll runtimes corrupts sed's
# regex backreferences and garbles the stamped version.
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

