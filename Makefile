CONTRIBUTION = "lua-placeholders-$(shell git describe --tags --always).tar.gz"
PACKAGE_DIR = $(shell pwd)
CNF_LINE = -cnf-line TEXMFHOME={$(PACKAGE_DIR),$(shell kpsewhich --var-value TEXMFHOME)}
COMPILE = lualatex --interaction=nonstopmode --shell-escape $(CNF_LINE)
RM = rm
ifeq ($(OS),Windows_NT)
	RM = del
endif

retry: clean-all build clean

all: build clean

package: $(CONTRIBUTION)

build: doc/lua-placeholders-manual.pdf

clean:
	cd doc && latexmk -c lua-placeholders-manual 2> /dev/null && $(RM) -f *.atfi *.bbl *.run.xml
	cd doc/lua-placeholders-example && latexmk -c example 2> /dev/null

clean-all:
	cd doc && latexmk -C lua-placeholders-manual 2> /dev/null && $(RM) -f *.atfi *.bbl *.run.xml
	cd doc/lua-placeholders-example && latexmk -C example 2> /dev/null

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
	tar --transform 's,^\.,lua-placeholders,' -czvf $(CONTRIBUTION) ./README.md ./doc ./scripts ./tex
