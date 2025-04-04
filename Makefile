
# JDK8 := $(shell /usr/libexec/java_home -v 1.8)
GV=gv.sh
BIN=gv
TARGET=/c/Users/dev

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

install:
	@cp -v ./${GV} ${TARGET}/bin/${BIN}
	chmod +x ${TARGET}/bin/${BIN}

# clean:
# 	rm -rf $(OUT) src/se/mitm/version 

