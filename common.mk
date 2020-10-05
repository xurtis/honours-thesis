mkfile_path := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# Build directory
# ===============

BUILD_DIR ?= build

${BUILD_DIR}:
	@printf "\x1b[1;37m>>> Create: $@ <<<\x1b[0m\n"
	@mkdir -p ${BUILD_DIR}

${BUILD_DIR}/%.eps: %.eps
	@printf "\x1b[1;37m>>> Copy: $< -> $@ <<<\x1b[0m\n"
	@rm -f $@
	@cp -l $< $@

${BUILD_DIR}/%.tex: %.tex
	@printf "\x1b[1;37m>>> Copy: $< -> $@ <<<\x1b[0m\n"
	@rm -f $@
	@cp -l $< $@

${BUILD_DIR}/%.bib: %.bib
	@printf "\x1b[1;37m>>> Copy: $< -> $@ <<<\x1b[0m\n"
	@rm -f $@
	@cp -l $< $@

${BUILD_DIR}/%.cls: %.cls
	@printf "\x1b[1;37m>>> Copy: $< -> $@ <<<\x1b[0m\n"
	@rm -f $@
	@cp -l $< $@

%.pdf: ${BUILD_DIR}/%.pdf ${BUILD_DIR}/%.tex
	@printf "\x1b[1;37m>>> Copy PDF: $< -> $@ <<<\x1b[0m\n"
	@rm -f $@
	@cp -l $< $@

# Pygments theme generation
# =========================

PYGMENTS_THEME ?= pastie
PYGMENTS_STYLE ?= sty/${PYGMENTS_THEME}-pygments
PYGMENTS_PATH  ?= ${BUILD_DIR}/${PYGMENTS_STYLE}.sty

%-pygments.css:
	@printf "\x1b[1;37m>>> Pygments CSS: $@ <<<\x1b[0m\n"
	@mkdir -p $(dir $@)
	@pygmentize \
		-f html \
		-S $(patsubst %-pygments.css,%,$(notdir $@)) \
		> $@

%-pygments.sty: %-pygments.css
	@printf "\x1b[1;37m>>> Pygments style: $< -> $@ <<<\x1b[0m\n"
	@${mkfile_path}/pygments_css2sty.py < $< > $@

# LaTeX
# =====

LATEX=lualatex -interaction=nonstopmode --shell-escape -8bit

# BIBINPUTS must refer to the directory of .bib files
BIBINPUTS ?= $(shell pwd)
BIBTEX = bibtex

%.aux: %.tex ${PYGMENTS_PATH}
	@printf "\x1b[1;37m>>> LaTeX: $< -> $@ <<<\x1b[0m\n"
	@cd $(dir $<) && \
		${LATEX} $(patsubst %.tex,%,$(notdir $<))

%.bbl: %.aux
	@printf "\x1b[1;37m>>> BibTex: $< -> $@ <<<\x1b[0m\n"
	@cd $(dir $<) && \
		${BIBTEX} $(patsubst %.aux,%,$(notdir $<))

%.pdf: %.tex
	@printf "\x1b[1;37m>>> LaTeX: $< -> $@ <<<\x1b[0m\n"
	@cd $(dir $<) && \
		${LATEX} $(patsubst %.tex,%,$(notdir $<)) && \
		${LATEX} $(patsubst %.tex,%,$(notdir $<))

${BUILD_DIR}/%.pdf: ${BUILD_DIR}/%.tex

# reStructuredText
# ================

RST2LATEX = rst2latex
RST_LATEX_PREAMBLE= \
	\usepackage{csquotes} \
	\usepackage{${PYGMENTS_STYLE}} \
	\usepackage{fontspec} \
	\usepackage[authoryear,square,sort]{natbib} \
	\setcounter{secnumdepth}{2}
RST_FLAGS = \
	--section-numbering	\
	--language=en-AU \
	--syntax-highlight=short \
	--smart-quotes=alt \
	--hyperref-options="colorlinks=false" \
	--latex-preamble='${RST_LATEX_PREAMBLE}'

${BUILD_DIR}/%.tex: %.rst ${BUILD_DIR} ${PYGMENTS_PATH}
	@printf "\x1b[1;37m>>> reStructuredText: $< -> $@ <<<\x1b[0m\n"
	@${RST2LATEX} ${RST_FLAGS} $< $@

# SVGs via Inkscape
# =================

${BUILD_DIR}/%.eps: %.svg ${BUILD_DIR}
	@printf "\x1b[1;37m>>> Inkscape: $< -> $@ <<<\x1b[0m\n"
	@inkscape -D -o $@ $<
