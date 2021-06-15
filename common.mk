mkfile_path := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# Build directory
# ===============

BUILD_DIR ?= build

${BUILD_DIR}:
	@printf "===>> Create directory: %s\n" "$@"
	@mkdir -p "$@"

${BUILD_DIR}/%.eps: %.eps
	@printf "===>> Copy EPS: %s -> %s\n" "$<" "$@"
	@rm -f "$@"
	@mkdir -p $(dir $@)
	@cp -l "$<" "$@"

${BUILD_DIR}/%.tex: %.tex
	@printf "===>> Copy TEX: %s -> %s\n" "$<" "$@"
	@rm -f "$@"
	@mkdir -p $(dir $@)
	@cp -l "$<" "$@"

${BUILD_DIR}/%.bib: %.bib
	@printf "===>> Copy BIB: %s -> %s\n" "$<" "$@"
	@rm -f "$@"
	@mkdir -p $(dir $@)
	@cp -l "$<" "$@"

${BUILD_DIR}/%.cls: %.cls
	@printf "===>> Copy CLS: %s -> %s\n" "$<" "$@"
	@rm -f "$@"
	@mkdir -p $(dir $@)
	@cp -l "$<" "$@"

%.pdf: ${BUILD_DIR}/%.pdf ${BUILD_DIR}/%.tex
	@printf "===>> Copy PDF: %s -> %s\n" "$<" "$@"
	@rm -f $@
	@cp -l $< $@

# Pygments theme generation
# =========================

PYGMENTS_THEME ?= pastie
PYGMENTS_STYLE ?= sty/${PYGMENTS_THEME}-pygments
PYGMENTS_PATH  ?= ${BUILD_DIR}/${PYGMENTS_STYLE}.sty

%-pygments.css:
	@printf "===>> Pygments CSS: %s\n" "$@"
	@mkdir -p $(dir $@)
	@pygmentize \
		-f html \
		-S $(patsubst %-pygments.css,%,$(notdir $@)) \
		> $@

%-pygments.sty: %-pygments.css
	@printf "===>> Pygments style: %s -> %s\n" "$<" "$@"
	@${mkfile_path}/pygments_css2sty.py < $< > $@

# LaTeX
# =====

LATEX=lualatex -interaction=nonstopmode --shell-escape -8bit

# BIBINPUTS must refer to the directory of .bib files
ifdef BIBINPUTS
BIBINPUTS := ${BIBINPUTS}:$(realpath ${BUILD_DIR})
else
BIBINPUTS := $(realpath ${BUILD_DIR})
endif
BIBTEX = bibtex

%.aux: %.tex ${PYGMENTS_PATH}
	@printf "===>> LaTeX: %s -> %s\n" "$<" "$@"
	echo "${BIBINPUTS}"
	@cd $(dir $<) && \
		${LATEX} $(patsubst %.tex,%,$(notdir $<))

%.bbl: %.aux
	@printf "===>> BibTex: %s -> %s\n" "$<" "$@"
	@cd $(dir $<) && \
		${BIBTEX} $(patsubst %.aux,%,$(notdir $<))

%.pdf: %.tex
	@printf "===>> LaTeX: %s -> %s\n" "$<" "$@"
	echo "${BIBINPUTS}"
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
	\usepackage[dvipsnames]{xcolor} \
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
	@printf "===>> reStructuredText: %s -> %s\n" "$<" "$@"
	@${RST2LATEX} ${RST_FLAGS} $< $@

# SVGs via Inkscape
# =================

${BUILD_DIR}/%.eps: %.svg ${BUILD_DIR}
	@printf "===>> Inkscape: %s -> %s\n" "$<" "$@"
	@inkscape -D -E $@ -f $<
