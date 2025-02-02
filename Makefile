CONTRIBUTION = "lua-placeholders-$(shell git describe --tags --always).tar.gz"
PACKAGE_DIR = ${CURDIR}
CNF_LINE = -cnf-line shell_escape_commands=git
COMPILE = lualatex --interaction=nonstopmode --shell-restricted $(CNF_LINE)
RM = rm
ifeq ($(OS),Windows_NT)
	RM = del
endif

.PHONY: doc/lua-placeholders-manual.pdf doc/lua-placeholders-example/example.pdf

all: build clean

package: $(CONTRIBUTION)

build: doc/lua-placeholders-manual.pdf

clean:
	cd doc && latexmk -c lua-placeholders-manual
	cd doc/lua-placeholders-example && latexmk -c example

clean-all:
	cd doc && latexmk -C lua-placeholders-manual
	cd doc/lua-placeholders-example && latexmk -C example

doc/lua-placeholders-example/example.pdf: doc/lua-placeholders-example/example.tex tex/lua-placeholders.sty $(wildcard scripts/*.lua)
	@echo "Creating example PDF"
	cd doc/lua-placeholders-example && \
	$(COMPILE) example

doc/lua-placeholders-manual.pdf: doc/lua-placeholders-example/example.pdf doc/lua-placeholders-manual.tex tex/lua-placeholders.sty $(wildcard scripts/*.lua)
	@echo "Creating documentation PDF"
	cd doc && \
	$(COMPILE) lua-placeholders-manual && \
	biber lua-placeholders-manual && \
	$(COMPILE) lua-placeholders-manual && \
	$(COMPILE) lua-placeholders-manual

$(CONTRIBUTION): doc/lua-placeholders-manual.pdf clean
	@echo "Creating package tarball"
	tar --transform 's,^\.,lua-placeholders,' \
		--exclude=doc/.latexmkrc \
		-czvf $(CONTRIBUTION) ./README.md ./doc ./scripts ./tex
