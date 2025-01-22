# Define variables for source scripts and destination directory
SRC_DIR := scripts
DEST_DIR := /usr/local/bin

# List of scripts to install (with relative paths)
SCRIPTS := \
    logs/mllog.sh

# Default rule (optional, just prints help)
.PHONY: all
all:
	@echo "Run 'sudo make install' to install scripts."

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
