
# JDK8 := $(shell /usr/libexec/java_home -v 1.8)
GV=gv.sh
BIN=gv
UNAME_S := $(shell uname -s)

# Resolve the install root as a POSIX path. On Windows $HOME differs between Git
# Bash (/c/Users/<user>) and the MSYS2 shell (/home/<user>), so `make install`
# could land in two different places depending on which shell runs make.
# %USERPROFILE% is the same Windows value in both runtimes; cygpath turns it into
# a POSIX path. macOS/Linux: $HOME is already correct.
ifneq (,$(filter MINGW% MSYS% CYGWIN%,$(UNAME_S)))
ifeq (,$(USERPROFILE))
$(error %USERPROFILE% is empty -- run native make from Git Bash, or msys64 make from the MSYS2 shell; do NOT run msys64 make from Git Bash (the two msys-2.0.dll runtimes mismarshal the environment))
endif
TARGET := $(shell cygpath -u "$$USERPROFILE")
else
TARGET := $(HOME)
endif

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
	@printf '%s\r\n' '@echo off' '"C:\Program Files\Git\bin\bash.exe" "%~dp0${BIN}" %*' > ${TARGET}/bin/${BIN}.cmd
	@echo "created ${TARGET}/bin/${BIN}.cmd"
endif

# clean:
# 	rm -rf $(OUT) src/se/mitm/version 

