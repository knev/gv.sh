
JDK8 := $(shell /usr/libexec/java_home -v 1.8)
OUT= build

.PHONY: nothing obf clean

nothing:
	@echo "usage: make ..."

obf:
	@./version.sh --collect --out $(OUT)
	@echo "DONE!"

clean:
	rm -rf $(OUT) src/se/mitm/version 

