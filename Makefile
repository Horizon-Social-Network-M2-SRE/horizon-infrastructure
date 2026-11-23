# Thin wrapper around scripts/stack.sh (use `bash scripts/stack.sh <target>` where make is missing).
.PHONY: help env up up-local test down logs ps clean

help:
	@bash scripts/stack.sh help

env up up-local test down logs ps clean:
	@bash scripts/stack.sh $@
