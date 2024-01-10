CONTRIBUTION = "elpi-$(shell git describe --tags --always).tar.gz"

retry: clean-all build

all: build clean

package: $(CONTRIBUTION)

build: doc/elpi-manual.pdf

clean:
	cd doc && latexmk -c 2> /dev/null && rm -f *.atfi *.bbl *.run.xml
	cd doc/elpi-example && latexmk -c 2> /dev/null

clean-all:
	cd doc && latexmk -C 2> /dev/null && rm -f *.atfi *.bbl *.run.xml
	cd doc/elpi-example && latexmk -C 2> /dev/null

doc/elpi-example/example.pdf: doc/elpi-example/example.tex tex/elpi.sty scripts/$(wildcard *.lua)
	@echo "Creating example PDF"
	cd doc/elpi-example && \
	lualatex --interaction=nonstopmode --shell-escape example > /dev/null

doc/elpi-manual.pdf: doc/elpi-example/example.pdf doc/elpi-manual.tex tex/elpi.sty scripts/$(wildcard *.lua)
	@echo "Creating documentation PDF"
	cd doc && \
	lualatex --interaction=nonstopmode --shell-escape elpi-manual && \
	biber elpi-manual && \
	lualatex --interaction=nonstopmode --shell-escape elpi-manual && \
	lualatex --interaction=nonstopmode --shell-escape elpi-manual

$(CONTRIBUTION): doc/elpi-manual.pdf clean
	@echo "Creating package tarball"
	tar --transform 's,^\.,elpi,' -czvf $(CONTRIBUTION) ./README.md ./doc ./scripts ./tex
