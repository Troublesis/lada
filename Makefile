# Default variables
PYTHON ?= uv run
MODULE = python -m lada.cli.main

INPUT ?= data/sample.mp4
OUTPUT ?= data/output.mp4
DEVICE ?= mps
CODEC ?= h264_videotoolbox
CRF ?= 22
FPS ?=30

run:
	$(PYTHON) $(MODULE) \
		--input $(INPUT) \
		--device $(DEVICE) \
		--codec $(CODEC) \
		--crf $(CRF)

fps:
	ffmpeg \
	-i $(INPUT) \
	-vsync cfr \
	-r $(FPS) \
	$(OUTPUT)
