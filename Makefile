.PHONY: all_checks hardcode_string_check toc_check toc_update boot_sim missing_translation_check wbt_setup i18n_check i18n_fmt test test-ci test-file test-pattern test-only local check_untracked_files options-dump options-html help

all_checks: hardcode_string_check missing_translation_check i18n_check

# Show available make targets
help:
	@echo "Available targets:"
	@echo "  test                - Run all tests without coverage"
	@echo "  test-cov           - Run all tests with coverage"
	@echo "  test-only           - Run tests tagged with 'only'"
	@echo "  test-file FILE=...  - Run tests for a specific file"
	@echo "                        Example: make test-file FILE=RPGLootFeed_spec/Features/Currency_spec.lua"
	@echo "  test-pattern PATTERN=... - Run tests matching a pattern"
	@echo "                        Example: make test-pattern PATTERN=\"quantity mismatch\""
	@echo "  test-ci             - Run tests for CI (TAP output)"
	@echo "  all_checks          - Run all code quality checks"
	@echo "  hardcode_string_check - Check for hardcoded strings"
	@echo "  missing_translation_check - Check for missing translations"
	@echo "  i18n_fmt             - Organize/format translations"
	@echo "  i18n_check           - Check for missing locale keys"
	@echo "  generate_hidden_currencies - Generate hidden currencies list"
	@echo "  faction_icon_audit  - Find major faction texture kits missing an icon mapping"
	@echo "  asset_presence      - Check FileDataIDs ship to every flavor (FDIDS=\"1 2\")"
	@echo "  faction_icon_preview - Save icons/atlas members as PNGs (TARGETS=\"...\")"
	@echo "  wago_cache          - Show cached listfiles vs live builds"
	@echo "  wago_refresh        - Re-download listfiles (FLAVOR=\"Retail\" for one)"
	@echo "  wago_prune          - Delete listfiles for superseded builds"
	@echo "  lua_deps            - Install Lua dependencies"
	@echo "  check_untracked_files - Check for untracked git files"
	@echo "  boot_sim            - Simulate a client login to catch Lua load errors"
	@echo "  options-dump        - Serialize G_RLF.options to .scripts/.output/options_dump.json"
	@echo "  options-html        - Render options_dump.json to .scripts/.output/options.html"
	@echo "  watch               - Watch for changes and build"
	@echo "  dev                 - Build for development"
	@echo "  build               - Build for production"

# Variables
ROCKSBIN := $(HOME)/.luarocks/bin
WBT_REF ?= v1-beta
WBT_DIR := ../wow-build-tools

# Target for running the hardcoded string checker
hardcode_string_check: wbt_setup
	@uv run --no-project $(WBT_DIR)/scripts/i18n/hardcode_string_check.py \
	    --ignore-files IntegrationTest.lua SmokeTest.lua ConfigTest.lua \
		--addon-dir RPGLootFeed

# Target for running the hardcoded string checker
missing_locale_key_check: wbt_setup
	@uv run --no-project $(WBT_DIR)/scripts/i18n/check_for_missing_locale_keys.py \
		--addon-dir RPGLootFeed \
		--locale-dir RPGLootFeed/locale

# Target for running the missing translation checker
missing_translation_check: wbt_setup
	@uv run --project $(WBT_DIR)/scripts/i18n \
		$(WBT_DIR)/scripts/i18n/missing_translation_check.py \
		--locale-dir RPGLootFeed/locale

wbt_setup:
	@if [ ! -d "$(WBT_DIR)/scripts/i18n" ]; then \
		echo "Cloning wow-build-tools at ref $(WBT_REF)..."; \
		git clone --depth 1 -b "$(WBT_REF)" \
			https://github.com/McTalian-WoW-Addons/wow-build-tools "$(WBT_DIR)"; \
	else \
		echo "$(WBT_DIR) already set up."; \
	fi

i18n_check: wbt_setup
	@uv run --project $(WBT_DIR)/scripts/i18n \
		$(WBT_DIR)/scripts/i18n/check_for_missing_locale_keys.py \
		--addon-dir RPGLootFeed \
		--locale-dir RPGLootFeed/locale

i18n_fmt: wbt_setup
	@uv run --project $(WBT_DIR)/scripts/i18n \
		$(WBT_DIR)/scripts/i18n/organize_translations.py \
		--locale-dir RPGLootFeed/locale

generate_hidden_currencies:
	@uv run .scripts/get_wowhead_hidden_currencies.py RPGLootFeed/Features/Currency/HiddenCurrencies.lua

# Diff majorFactionTextureKitIconMap against live game data. Run after a patch.
faction_icon_audit:
	@uv run .scripts/wago_lookup.py audit

# Verify FileDataIDs ship to every supported flavor, e.g.
#   make asset_presence FDIDS="236681 894556"
asset_presence:
	@uv run .scripts/wago_lookup.py presence $(FDIDS)

# Save icons / atlas members as PNGs so the art can be eyeballed, e.g.
#   make faction_icon_preview TARGETS="7903180 majorfactions_icons_ritualsites512"
# Digits are FileDataIDs, anything else is an atlas member name.
faction_icon_preview:
	@uv run --with pillow .scripts/wago_lookup.py extract $(TARGETS)

# Show which flavor listfiles are cached and whether they match the live build.
wago_cache:
	@uv run .scripts/wago_lookup.py cache

# Re-download listfiles. All flavors by default, or one, e.g.
#   make wago_refresh FLAVOR="Retail"
# Listfiles are build-pinned by filename, so a new build re-downloads itself on
# next use; this is for forcing a refetch of the same build.
wago_refresh:
	@uv run .scripts/wago_lookup.py cache --refresh $(if $(FLAVOR),--flavor "$(FLAVOR)")

# Delete listfiles for builds that are no longer current.
wago_prune:
	@uv run .scripts/wago_lookup.py cache --prune

test:
	@$(ROCKSBIN)/busted RPGLootFeed_spec

test-only:
	@$(ROCKSBIN)/busted --tags=only RPGLootFeed_spec

# Run tests with coverage
test-cov:
	@rm -rf luacov-html && rm -rf luacov.*out && mkdir -p luacov-html && $(ROCKSBIN)/busted --coverage RPGLootFeed_spec && $(ROCKSBIN)/luacov && echo "\nCoverage report generated at luacov-html/index.html"

# Run tests for a specific file
# Usage: make test-file FILE=RPGLootFeed_spec/Features/Currency_spec.lua
test-file:
	@if [ -z "$(FILE)" ]; then \
		echo "Usage: make test-file FILE=path/to/test_file.lua"; \
		exit 1; \
	fi
	@$(ROCKSBIN)/busted --verbose "$(FILE)"

# Run tests matching a specific pattern
# Usage: make test-pattern PATTERN="quantity mismatch"
test-pattern:
	@if [ -z "$(PATTERN)" ]; then \
		echo "Usage: make test-pattern PATTERN=\"test description\""; \
		exit 1; \
	fi
	@$(ROCKSBIN)/busted --verbose --filter="$(PATTERN)" RPGLootFeed_spec

test-ci:
	@rm -rf luacov-html && rm -rf luacov.*out && mkdir -p luacov-html && $(ROCKSBIN)/busted --coverage -o=TAP RPGLootFeed_spec && $(ROCKSBIN)/luacov

# Serialize G_RLF.options to JSON for the AceConfig HTML renderer (Stage 1)
# Output: .scripts/.output/options_dump.json
options-dump:
	@mkdir -p .scripts/.output
	@$(ROCKSBIN)/busted --verbose .scripts/dump_options.lua

# Render G_RLF.options JSON to a self-contained HTML file (Stage 2)
# Run options-dump first if options_dump.json is missing.
# Output: .scripts/.output/options.html
options-html: options-dump
	@uv run .scripts/render_options.py

lua_deps:
	@luarocks install rpglootfeed-1-1.rockspec --local --force --lua-version 5.4
	@luarocks install busted --local --force --lua-version 5.4

check_untracked_files:
	@if [ -n "$$(git ls-files --others --exclude-standard -- RPGLootFeed/)" ]; then \
		echo "You have untracked files in RPGLootFeed/:"; \
		git ls-files --others --exclude-standard -- RPGLootFeed/; \
		echo ""; \
		echo "This may cause errors in game. Please stage or remove them."; \
		exit 1; \
	else \
		echo "No untracked files in RPGLootFeed/."; \
	fi

toc_check:
	@wow-build-tools toc check \
		-a RPGLootFeed \
		-x embeds.xml \
		--no-splash \
		-b -p

# Simulate a client login against a built package to catch Lua load errors
# before a player does. Builds first (skipping packaging) to resolve Libs/
# externals, since boot-sim needs those on disk to follow real Include
# chains -- then points boot-sim at the result rather than the source tree.
# Not passing -m RPGLootFeed_spec/_mocks/helper.lua: it requires("busted")
# transitively (WoWGlobals.lua), which boot-sim's plain-Lua subprocess
# doesn't have -- and isn't needed, boot-sim's built-in WoW API mocks
# already give a clean, meaningful result without it.
boot_sim:
	@wow-build-tools build -t ./RPGLootFeed -r ./.release --skipZip --skipUpload --skipChangelog --no-splash
	@wow-build-tools boot-sim -t ./.release/RPGLootFeed --no-splash

toc_update:
	@wow-build-tools toc update \
		-a RPGLootFeed \
		--no-splash \
		-b -p

watch: toc_check missing_locale_key_check check_untracked_files
	@wow-build-tools build watch -t RPGLootFeed -r ./.release --force-alpha

dev: toc_check missing_locale_key_check check_untracked_files
	@wow-build-tools build -d -t RPGLootFeed -r ./.release --skipChangelog

build: toc_check missing_locale_key_check check_untracked_files
	@wow-build-tools build -d -t RPGLootFeed -r ./.release
