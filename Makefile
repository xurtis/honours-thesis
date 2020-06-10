CFLAGS=-Weverything -Werror
CC=clang

RST2LATEX = rst2latex
PYGMENTS_THEME = pastie
PYGMENTS_STYLE = sty/pygments-${PYGMENTS_THEME}.sty
RST_FLAGS = \
	--section-numbering	\
	--language=en-AU \
	--use-latex-docinfo \
	--topic-abstract \
	--documentclass="article" \
	--documentoptions="a4paper" \
	--use-latex-citations \
	--syntax-highlight=short \
	--smart-quotes=alt \
	--latex-preamble=" \
		\usepackage[a4paper, margin=25mm]{geometry} \
		\usepackage{multicol} \
		\usepackage{amsmath} \
		\usepackage{mathtools} \
		\usepackage{centernot} \
		\usepackage{xfrac} \
		\usepackage[utf8]{inputenc} \
		\usepackage[backend=biber, style=authoryear, citestyle=authoryear]{biblatex} \
		\usepackage{sty/pygments-${PYGMENTS_THEME}} \
		\usepackage{fontspec} \
		\usepackage{svg} \
		\renewcommand{\familydefault}{\sfdefault} \
		\setmonofont{Fira Mono}[Contextuals=Alternate, Scale=MatchLowercase] \
		\setsansfont{Fira Sans}[Contextuals=Alternate, Scale=MatchLowercase] \
	"
LATEX=lualatex
LATEX_FLAGS=\
	-interaction=nonstopmode

PDFS=$(patsubst %.rst,%.pdf,$(wildcard **/*.rst))
TEXS=$(patsubst %.rst,%.tex,$(wildcard **/*.rst))
DOT_PNGS=$(patsubst %.dot,%.png,$(wildcard **/*.dot))

.PHONY: clean
all: ${PDFS} ${DOT_PNGS}

.PHONY: clean
clean:
	git clean -fX $(wildcard **/)
	rm -rf ${PDFS} ${TEXS} ${DOT_PNGS}

# Build Rules
# ===========

sty/pygments-%.css:
	mkdir -p sty
	pygmentize \
		-f html \
		-S $(patsubst sty/pygments-%.css,%,$@) \
		> $@

sty/pygments-%.sty: sty/pygments-%.css
	./pygments_css2sty.py < $< > $@

%.tex: %.rst
	${RST2LATEX} ${RST_FLAGS} $< $@

%.pdf: %.tex ${PYGMENTS_STYLE} ${DOT_PNGS}
	${LATEX} ${LATEX_FLAGS} -jobname=$(patsubst %.pdf,%,$@) $<
	biber $(patsubst %.tex,%.bcf,$<)
	${LATEX} ${LATEX_FLAGS} -jobname=$(patsubst %.pdf,%,$@) $<

# Dotfile diagrams
%.png: %.dot
	dot -Tpng $^ > $@
