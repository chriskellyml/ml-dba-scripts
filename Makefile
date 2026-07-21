# Define variables for source scripts and destination directory
SRC_DIR := scripts
DEST_DIR := /usr/local/bin

# List of scripts to install (with relative paths)
SCRIPTS := \
    logs/mllog.sh

# Default rule
.PHONY: all help
all: help

help:
	@echo "Available targets:"
	@echo "  make copy-database FROM=<source> TO=<destination> [options]"
	@echo "  sudo make install"
	@echo "  sudo make clean"
	@echo ""
	@echo "copy-database options:"
	@echo "  FROM       Source database name (required)"
	@echo "  TO         Destination database name (default: <FROM>-clone)"
	@echo "  LIMIT      Documents per CoRB page (default: 1000000)"
	@echo "  THREADS    CoRB worker threads (default: 4)"
	@echo "  BATCH      Documents per transaction (default: 1)"
	@echo "  PAGELIM    Stop after this many pages, for testing (default: unlimited)"
	@echo "  HOST       MarkLogic host (default: localhost)"
	@echo "  PORT       REST/XCC App Server port (default: 8000)"
	@echo "  USER       MarkLogic username (required)"
	@echo "  PASS       MarkLogic password (required)"
	@echo ""
	@echo "Example:"
	@echo "  make copy-database FROM=foo TO=bar LIMIT=1000000 THREADS=4 BATCH=30 HOST=localhost PORT=8000 USER=admin PASS=admin"

# Install rule
.PHONY: install
install:
	@echo "Installing scripts to $(DEST_DIR)..."
	@for script in $(SCRIPTS); do \
		src_path="$(SRC_DIR)/$$script"; \
		dest_path="$(DEST_DIR)/$$(basename $$script .sh)"; \
		echo "Installing $$src_path to $$dest_path..."; \
		install -m 755 "$$src_path" "$$dest_path"; \
	done
	@echo "Installation complete."

# Clean rule (optional)
.PHONY: clean
clean:
	@echo "Removing installed scripts..."
	@for script in $(SCRIPTS); do \
		dest_path="$(DEST_DIR)/$$(basename $$script .sh)"; \
		echo "Removing $$dest_path..."; \
		rm -f "$$dest_path"; \
	done
	@echo "Cleanup complete."

.PHONY: copy-database
copy-database:
	@test -n "$(FROM)" || (echo "FROM is required" >&2; exit 2)
	@test -n "$(USER)" || (echo "USER is required" >&2; exit 2)
	@test -n "$(PASS)" || (echo "PASS is required" >&2; exit 2)
	@FROM='$(FROM)' TO='$(TO)' LIMIT='$(or $(LIMIT),1000000)' \
		THREADS='$(or $(THREADS),4)' BATCH='$(or $(BATCH),1)' \
		PAGELIM='$(PAGELIM)' \
		HOST='$(or $(HOST),localhost)' PORT='$(or $(PORT),8000)' \
		USER='$(USER)' PASS='$(PASS)' ./copy-database.sh
