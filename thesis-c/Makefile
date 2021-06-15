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
	${BUILD_DIR}/extra.bib \
	${BUILD_DIR}/crest.eps \
	${BUILD_DIR}/image/graphs/correct-charge.low-count/low-period\:12500.eps \
	${BUILD_DIR}/image/graphs/irq-bounded.low-count/high-extra-refills\:0/high-budget\:240/low-period\:12500/timer-both\:True.eps \
	${BUILD_DIR}/image/graphs/shared-resource.high-response.eps \
	${BUILD_DIR}/image/irq-scs.eps \
	${BUILD_DIR}/image/irq-sporadic.eps \
	${BUILD_DIR}/image/preempt-sporadic.eps \
	${BUILD_DIR}/image/preempt-sporadic-fixed.eps \
	${BUILD_DIR}/image/resource-sporadic-bounded.eps \
	${BUILD_DIR}/image/resource-sporadic.eps \
	${BUILD_DIR}/image/response-time.eps \
	${BUILD_DIR}/image/slack-time.eps \
	${BUILD_DIR}/image/sched-timing.eps \
	${BUILD_DIR}/image/syscall-charge.eps \
	${BUILD_DIR}/image/preempt-charge.eps \
	${BUILD_DIR}/image/irq-charge.eps \
	${BUILD_DIR}/image/seL4-charge.eps \
	${BUILD_DIR}/image/irq-execution.eps \
	${BUILD_DIR}/image/sliding-window.eps \
	${BUILD_DIR}/image/sc-send-rsc.eps \
	${BUILD_DIR}/image/sc-reply-rsc.eps \
	${BUILD_DIR}/image/rsc-send-rsc.eps \
	${BUILD_DIR}/image/rsc-nbsend-rsc.eps \
	${BUILD_DIR}/image/rsc-reply-rsc.eps \
	${BUILD_DIR}/microkernel.eps

${BUILD_DIR}/thesis-c.tex: \
	RST_FLAGS += \
		--documentclass="unswthesis" \
		--documentoptions="a4paper,oneside,singlespacing" \
		--template="unsw-thesis.tex"
