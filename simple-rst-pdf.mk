# This is enough of a makefile for simple-looking rST PDFs
mkfile_path := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

PDFS := $(patsubst %.rst,%.pdf,$(wildcard *.rst))

.PHONY: all
all: ${PDFS}

.PHONY: clean
clean:
	rm -rf ${BUILD_DIR} ${PDFS}

include ${mkfile_path}/common.mk

RST_LATEX_PREAMBLE += \usepackage[margin=25mm]{geometry}
RST_FLAGS += --use-latex-docinfo
