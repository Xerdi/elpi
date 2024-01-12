CONTRIBUTION = "lua-placeholders-$(shell git describe --tags --always).tar.gz"

retry: clean-all build

all: build clean

package: $(CONTRIBUTION)

build: doc/lua-placeholders-manual.pdf

clean:
	cd doc && latexmk -c 2> /dev/null && rm -f *.atfi *.bbl *.run.xml
	cd doc/lua-placeholders-example && latexmk -c 2> /dev/null

clean-all:
	cd doc && latexmk -C 2> /dev/null && rm -f *.atfi *.bbl *.run.xml
	cd doc/lua-placeholders-example && latexmk -C 2> /dev/null

doc/lua-placeholders-example/example.pdf: doc/lua-placeholders-example/example.tex tex/lua-placeholders.sty scripts/$(wildcard *.lua)
	@echo "Creating example PDF"
	cd doc/lua-placeholders-example && \
	lualatex --interaction=nonstopmode --shell-escape example > /dev/null

doc/lua-placeholders-manual.pdf: doc/lua-placeholders-example/example.pdf doc/lua-placeholders-manual.tex tex/lua-placeholders.sty scripts/$(wildcard *.lua)
	@echo "Creating documentation PDF"
	cd doc && \
	lualatex --interaction=nonstopmode --shell-escape lua-placeholders-manual && \
	biber lua-placeholders-manual && \
	lualatex --interaction=nonstopmode --shell-escape lua-placeholders-manual && \
	lualatex --interaction=nonstopmode --shell-escape lua-placeholders-manual

$(CONTRIBUTION): doc/lua-placeholders-manual.pdf clean
	@echo "Creating package tarball"
	tar --transform 's,^\.,lua-placeholders,' -czvf $(CONTRIBUTION) ./README.md ./doc ./scripts ./tex
