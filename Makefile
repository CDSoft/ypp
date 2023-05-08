# This file is part of ypp.
#
# ypp is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# ypp is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with ypp.  If not, see <https://www.gnu.org/licenses/>.
#
# For further information about ypp you can visit
# http://cdelord.fr/ypp

PREFIX := $(firstword $(wildcard $(PREFIX) $(HOME)/.local))
BUILD = .build

SOURCES = $(sort $(wildcard src/*.lua))
SOURCES += $(BUILD)/src/_YPP_VERSION.lua

YPP_VERSION := $(shell git describe --tags 2>/dev/null || echo 0.0)

## Compile ypp
all: compile

## Clean the build directory
clean:
	rm -rf $(BUILD)

###############################################################################
# Help
###############################################################################

.PHONY: help welcome

BLACK     := $(shell tput -Txterm setaf 0)
RED       := $(shell tput -Txterm setaf 1)
GREEN     := $(shell tput -Txterm setaf 2)
YELLOW    := $(shell tput -Txterm setaf 3)
BLUE      := $(shell tput -Txterm setaf 4)
PURPLE    := $(shell tput -Txterm setaf 5)
CYAN      := $(shell tput -Txterm setaf 6)
WHITE     := $(shell tput -Txterm setaf 7)
BG_BLACK  := $(shell tput -Txterm setab 0)
BG_RED    := $(shell tput -Txterm setab 1)
BG_GREEN  := $(shell tput -Txterm setab 2)
BG_YELLOW := $(shell tput -Txterm setab 3)
BG_BLUE   := $(shell tput -Txterm setab 4)
BG_PURPLE := $(shell tput -Txterm setab 5)
BG_CYAN   := $(shell tput -Txterm setab 6)
BG_WHITE  := $(shell tput -Txterm setab 7)
NORMAL    := $(shell tput -Txterm sgr0)

CMD_COLOR    := ${YELLOW}
TARGET_COLOR := ${GREEN}
TEXT_COLOR   := ${CYAN}
TARGET_MAX_LEN := 16

## show this help massage
help: welcome
	@echo ''
	@echo 'Usage:'
	@echo '  ${CMD_COLOR}make${NORMAL} ${TARGET_COLOR}<target>${NORMAL}'
	@echo ''
	@echo 'Targets:'
	@awk '/^[a-zA-Z\-_0-9]+:/ { \
	    helpMessage = match(lastLine, /^## (.*)/); \
	    if (helpMessage) { \
	        helpCommand = substr($$1, 0, index($$1, ":")-1); \
	        helpMessage = substr(lastLine, RSTART + 3, RLENGTH); \
	        printf "  ${TARGET_COLOR}%-$(TARGET_MAX_LEN)s${NORMAL} ${TEXT_COLOR}%s${NORMAL}\n", helpCommand, helpMessage; \
	    } \
	} \
	{ lastLine = $$0 }' $(MAKEFILE_LIST)

welcome:
	@echo '${CYAN}ypp${NORMAL}'

####################################################################
# Compilation
####################################################################

## Compile ypp
compile: $(BUILD)/ypp
compile: $(BUILD)/ypp-lua
compile: $(BUILD)/ypp-luax
compile: $(BUILD)/ypp-pandoc

$(BUILD)/ypp: $(SOURCES)
	@mkdir -p $(dir $@)
	luax -q -o $@ $^

$(BUILD)/ypp-lua: $(SOURCES)
	@mkdir -p $(dir $@)
	luax -q -t lua -o $@ $^

$(BUILD)/ypp-luax: $(SOURCES)
	@mkdir -p $(dir $@)
	luax -q -t luax -o $@ $^

$(BUILD)/ypp-pandoc: $(SOURCES)
	@mkdir -p $(dir $@)
	luax -q -t pandoc -o $@ $^

$(BUILD)/src/_YPP_VERSION.lua: $(wildcard .git/refs/tags) $(wildcard .git/index)
	@mkdir -p $(dir $@)
	@(  set -eu;                                                \
	    echo "--@LOAD";                                         \
	    echo "return [[$(YPP_VERSION)]]";                       \
	) > $@.tmp
	@mv $@.tmp $@

####################################################################
# Installation
####################################################################

.PHONY: install

## Install ypp
install: $(PREFIX)/bin/ypp
install: $(PREFIX)/bin/ypp-lua
install: $(PREFIX)/bin/ypp-luax
install: $(PREFIX)/bin/ypp-pandoc

$(PREFIX)/bin/%: $(BUILD)/%
	install $^ $@

####################################################################
# Tests
####################################################################

.PHONY: test
.PHONY: ref

export BUILD
export YPP_CACHE := $(BUILD)/test/ypp_cache
export PLANTUML
export DITAA

# avoid being polluted by user definitions
export LUA_PATH := ./?.lua

## Run ypp tests
test: $(BUILD)/test/test.ok
test: $(BUILD)/test/test.d.ok

$(BUILD)/test/test.ok: $(BUILD)/test/test.md test/test_ref.md
	diff $^

$(BUILD)/test/test.d.ok: $(BUILD)/test/test.d test/test_ref.d
	diff $^

ref: ref-md
ref: ref-d

ref-md: $(BUILD)/test/test.md test/test_ref.md
	diff -q $^ || meld $^

ref-d: $(BUILD)/test/test.d test/test_ref.d
	diff -q $^ || meld $^

$(BUILD)/test/test.md: $(BUILD)/ypp-pandoc test/test.md
	@mkdir -p $(dir $@)
	$(BUILD)/ypp-pandoc \
	    -t svg \
	    --MT target1 --MT target2 --MD \
	    -p test -l test.lua \
	    test/test.md \
	    -o $@

-include $(BUILD)/test/test.d

####################################################################
# Documentation
####################################################################

.PHONY: doc

## Generate README.md
doc: README.md

README.md: $(BUILD)/doc/README.md
	pandoc --to gfm $< -o $@

$(BUILD)/doc/README.md: $(BUILD)/ypp doc/ypp.md
	@mkdir -p $(dir $@)
	$(BUILD)/ypp \
	    -t svg \
	    --MF $(BUILD)/doc/README.d --MD \
	    doc/ypp.md \
	    -o $@

-include $(BUILD)/doc/README.d
