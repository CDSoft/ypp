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

## Compile ypp
all: compile

## Clean the build directory
clean:
	rm -rf $(BUILD)

# include makex to install ypp dependencies
include makex.mk

###############################################################################
# Help
###############################################################################

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

$(BUILD)/ypp: $(SOURCES) | $(LUAX)
	@mkdir -p $(dir $@)
	$(LUAX) -q -o $@ $^

$(BUILD)/ypp-lua: $(SOURCES) | $(LUAX)
	@mkdir -p $(dir $@)
	$(LUAX) -q -t lua -o $@ $^

$(BUILD)/ypp-luax: $(SOURCES) | $(LUAX)
	@mkdir -p $(dir $@)
	$(LUAX) -q -t luax -o $@ $^

$(BUILD)/ypp-pandoc: $(SOURCES) | $(LUAX)
	@mkdir -p $(dir $@)
	$(LUAX) -q -t pandoc -o $@ $^

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

$(BUILD)/test/test.ok: $(BUILD)/test/test.md test/test_ref.md
	diff $^

ref: $(BUILD)/test/test.md test/test_ref.md
	diff -q $^ || meld $^

$(BUILD)/test/test.md: $(BUILD)/ypp-pandoc test/test.md | $(PANDOC) $(PLANTUML) $(DITAA)
	@mkdir -p $(dir $@)
	$(BUILD)/ypp-pandoc \
	    -t svg \
	    --MT target1 --MT target2 --MD \
	    -l test/test.lua \
	    test/test.md \
	    -o $@

-include $(BUILD)/test/test.d

####################################################################
# Documentation
####################################################################

.PHONY: doc

## Generate README.md
doc: README.md

README.md: $(BUILD)/doc/README.md | $(PANDOC)
	$(PANDOC) --to gfm $< -o $@

$(BUILD)/doc/README.md: $(BUILD)/ypp doc/ypp.md
	@mkdir -p $(dir $@)
	$(BUILD)/ypp \
	    -t svg \
	    --MF $(BUILD)/doc/README.d --MD \
	    doc/ypp.md \
	    -o $@

-include $(BUILD)/doc/README.d
