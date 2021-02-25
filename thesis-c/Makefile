BUILD_DIR := build
PDFS := thesis-c.pdf

.PHONY: all
all: ${PDFS}

include ../common.mk

.PHONY: clean
clean:
	rm -rf ${BUILD_DIR} ${PDFS}

${BUILD_DIR}/thesis-c.pdf: \
	${BUILD_DIR}/thesis-c.bbl \
	${BUILD_DIR}/thesis-c.aux

${BUILD_DIR}/thesis-c.bbl: \
	${BUILD_DIR}/thesis-c.aux

${BUILD_DIR}/thesis-c.aux: \
	${BUILD_DIR}/unswthesis.cls \
	${BUILD_DIR}/thesis-c.tex \
	${BUILD_DIR}/abstract.tex \
	${BUILD_DIR}/abbreviations.tex \
	${BUILD_DIR}/thesis-details.tex \
	${BUILD_DIR}/crest.eps \
	${BUILD_DIR}/timeline.eps \
	${BUILD_DIR}/microkernel.eps

${BUILD_DIR}/thesis-c.tex: \
	RST_FLAGS += \
		--documentclass="unswthesis" \
		--documentoptions="a4paper,oneside,singlespacing" \
		--template="unsw-thesis.tex"
