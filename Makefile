CFLAGS=-Weverything -Werror
CC=clang

RST2LATEX = rst2latex
PYGMENTS_THEME = pastie
PYGMENTS_STYLE = ${BUILD_DIR}/sty/pygments-${PYGMENTS_THEME}.sty
RST_FLAGS = \
	--section-numbering	\
	--language=en-AU \
	--syntax-highlight=short \
	--smart-quotes=alt \
	--hyperref-options="colorlinks=false" \
	--latex-preamble=" \
		\usepackage{csquotes} \
		\usepackage{sty/pygments-${PYGMENTS_THEME}} \
		\usepackage{fontspec} \
		\usepackage[authoryear,square,sort]{natbib} \
		\setcounter{secnumdepth}{2} \
	"
LATEX=lualatex -interaction=nonstopmode --shell-escape -8bit

# BIBINPUTS must refer to the directory of .bib files
BIBINPUTS ?= $(shell pwd)
BIBTEX = bibtex

BUILD_DIR := build

PDFS=$(patsubst %.rst,%.pdf,$(wildcard *.rst))

.PHONY: all
all: ${PDFS}

.PHONY: clean
clean:
	rm -rf "${BUILD_DIR}" ${PDFS}

${BUILD_DIR}/thesis-a-pre-report.pdf: \
	${BUILD_DIR}/thesis-a-pre-report.bbl \
	${BUILD_DIR}/thesis-a-pre-report.aux

${BUILD_DIR}/thesis-a-pre-report.bbl: \
	${BUILD_DIR}/thesis-a-pre-report.aux

${BUILD_DIR}/thesis-a-pre-report.aux: \
	${BUILD_DIR}/unswthesis.cls \
	${BUILD_DIR}/thesis-a-pre-report.tex \
	${BUILD_DIR}/abstract.tex \
	${BUILD_DIR}/abbreviations.tex \
	${BUILD_DIR}/thesis-details.tex \
	${BUILD_DIR}/crest.eps \
	${BUILD_DIR}/timeline.eps \
	${BUILD_DIR}/microkernel.eps

${BUILD_DIR}/thesis-a-pre-report.tex: \
	RST_FLAGS += \
		--documentclass="unswthesis" \
		--documentoptions="a4paper,oneside,singlespacing" \
		--template="unsw-thesis.tex"

# Build Rules
# ===========

${BUILD_DIR}/sty/pygments-%.css:
	@printf "\x1b[1;37m>>> $@ <<<\x1b[0m\n"
	@mkdir -p ${BUILD_DIR}/sty
	@pygmentize \
		-f html \
		-S $(patsubst ${BUILD_DIR}/sty/pygments-%.css,%,$@) \
		> $@

%.sty: %.css
	@printf "\x1b[1;37m>>> $< -> $@ <<<\x1b[0m\n"
	@./pygments_css2sty.py < $< > $@

%.tex: %.rst references.bib
	${RST2LATEX} ${RST_FLAGS} $< $@

${BUILD_DIR}/%.tex: %.rst
	@printf "\x1b[1;37m>>> $< -> $@ <<<\x1b[0m\n"
	@mkdir -p ${BUILD_DIR}
	@${RST2LATEX} ${RST_FLAGS} $< $@

${BUILD_DIR}/%.tex: %.tex
	@printf "\x1b[1;37m>>> $< -> $@ <<<\x1b[0m\n"
	@rm -f $@
	@cp -l $< $@

${BUILD_DIR}/%.aux: ${BUILD_DIR}/%.tex ${PYGMENTS_STYLE}
	@printf "\x1b[1;37m>>> $< -> $@ <<<\x1b[0m\n"
	@cd ${BUILD_DIR} && \
		${LATEX} $(patsubst ${BUILD_DIR}/%.tex,%,$<)

${BUILD_DIR}/%.bbl: ${BUILD_DIR}/%.aux
	@printf "\x1b[1;37m>>> $< -> $@ <<<\x1b[0m\n"
	@cd ${BUILD_DIR} && \
		${BIBTEX} $(patsubst ${BUILD_DIR}/%.aux,%,$<)

${BUILD_DIR}/%.pdf: ${BUILD_DIR}/%.tex ${PYGMENTS_STYLE}
	@printf "\x1b[1;37m>>> $< -> $@ <<<\x1b[0m\n"
	@cd ${BUILD_DIR} && \
		${LATEX} $(patsubst ${BUILD_DIR}/%.tex,%,$<) && \
		${LATEX} $(patsubst ${BUILD_DIR}/%.tex,%,$<)

%.pdf: ${BUILD_DIR}/%.pdf
	@printf "\x1b[1;37m>>> $< -> $@ <<<\x1b[0m\n"
	@rm -f $@
	@cp -l $< $@

${BUILD_DIR}/%.cls: %.cls
	@printf "\x1b[1;37m>>> $< -> $@ <<<\x1b[0m\n"
	@rm -f $@
	@cp -l $< $@

${BUILD_DIR}/%.eps: %.svg
	@printf "\x1b[1;37m>>> $< -> $@ <<<\x1b[0m\n"
	@mkdir -p ${BUILD_DIR}
	@inkscape -D -o $@ $<

${BUILD_DIR}/%.eps: %.eps
	@printf "\x1b[1;37m>>> $< -> $@ <<<\x1b[0m\n"
	@rm -f $@
	@cp -l $< $@
