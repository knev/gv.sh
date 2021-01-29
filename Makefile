
JDK8 := $(shell /usr/libexec/java_home -v 1.8)
OUT= build

.PHONY: nothing obf repo clean

nothing:
	@echo "usage: make ..."

obf:
	@./version.sh --collect --out $(OUT)
	@echo "DONE!"

repo:
	#@git add ...
	@git status --untracked-files=no
	@echo
	@./version.sh --print

clean:
	rm -rf $(OUT) src/se/mitm/version 

