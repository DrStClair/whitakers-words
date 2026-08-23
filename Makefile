# Makefile for Whitaker's words

GPRBUILD                                := gprbuild
GPRBUILD_OPTIONS                        := -j4

# Build flags are commonly found in the environment, but if they are
# set on our Make command line, forward them to GNAT projects.
export ADAFLAGS                         ?=
export LDFLAGS                          ?=

# For each library, a static archive is built by default but a
# non-empty shared object version selects a relocatable library
export latin_utils_soversion            :=
export support_utils_soversion          :=
export words_engine_soversion           :=

# Directory where dictionnary files are created and searched for.
# This variable is expected to be overridden at build time, with some
# architecture-specific value like $(prefix)/share/whitakers-words).
# At run time, another directory can be selected via the
# WHITAKERS_WORDS_DATADIR environment variable.
datadir                                 := .
# During (re)builds, the tools must read and test the fresh data and
# ignore any previous version already installed in $(datadir).
export WHITAKERS_WORDS_DATADIR := .

generated_sources := src/latin_utils/latin_utils-config.adb

PROGRAMMES := makedict makeefil makeewds makeinfl makestem meanings wakedict \
  words

.PHONY: all
all: commands tools data

# This target is more efficient than separate gprbuild runs because
# the dependency graph is only constructed once.
.PHONY: commands
commands: $(generated_sources)
	$(GPRBUILD) -p $(GPRBUILD_OPTIONS) commands.gpr

# Targets delegated to gprbuild are declared phony even if they build
# concrete files, because Make ignores all about Ada depenencies.
.PHONY: $(PROGRAMMES)
$(PROGRAMMES): $(generated_sources)
	$(GPRBUILD) -p $(GPRBUILD_OPTIONS) commands.gpr $@

TOOLS := check dictflag dictord dictpage fil2dict fixord invert \
	invstems linedict linefile listdict listord number oners page2htm \
	patch slash sorter uniqpage
  
# Builds the sorter tool used to generate STEMLIST
.PHONY: $(TOOLS)
$(TOOLS): $(generated_sources)
	$(GPRBUILD) -p $(GPRBUILD_OPTIONS) tools.gpr $@

.PHONY: tools
tools: $(generated_sources)
	$(GPRBUILD) -p $(GPRBUILD_OPTIONS) tools.gpr

# Executable targets are phony (see above), so we tell Make to only
# check that they exist but ignore the timestamp.  This is not
# perfect, but at least Make
# * updates the output data if the input data changes
# * builds the generator if it does not exist yet

DICTFILE.GEN STEMLIST_generated.GEN: DICTLINE.GEN | wakedict
	echo g | bin/wakedict $<
	mv STEMLIST.GEN STEMLIST_generated.GEN

STEMLIST.GEN: DICTLINE.GEN STEMLIST_generated.GEN | sorter
	rm -f -- $@
	bin/sorter < stemlist-sort.txt
	mv -f -- STEMLIST_new.GEN $@
	rm -f STEMLIST_generated.GEN
	rm -f WORK.WRK

EWDSFILE.GEN: EWDSLIST.GEN | makeefil
	bin/makeefil

EWDSLIST.GEN: DICTLINE.GEN | makeewds
	echo g | bin/makeewds $<
	LC_COLLATE=C sort -o $@ $@

INFLECTS.SEC: INFLECTS.LAT | makeinfl
	bin/makeinfl $<

STEMFILE.GEN INDXFILE.GEN: STEMLIST.GEN | makestem
	echo g | bin/makestem $<

GENERATED_DATA_FILES := DICTFILE.GEN STEMLIST.GEN EWDSFILE.GEN \
  EWDSLIST.GEN INFLECTS.SEC STEMLIST.GEN INDXFILE.GEN

.PHONY: data
data: $(GENERATED_DATA_FILES)

#Remove working file from makeewds
.PHONY: clean_data
clean_data:
	rm -f $(GENERATED_DATA_FILES) CHECKEWD.WRK

#Remove all but executable files
.PHONY: clean_build
clean_build: clean_data
	rm -fr lib obj
	rm -f WORK.WRK STEMLIST_generated.GEN STEMLIST_new.GEN $(generated_sources)

#Remove everything generated including executable files
.PHONY: clean
clean: clean_build
	rm -fr bin

$(generated_sources): %: %.in Makefile
	sed 's|@datadir@|$(datadir)|' $< > $@

.PHONY: test
test: all
	cd test && ./run-tests.sh

# This Makefile does not support parallelism (but gprbuild does).
.NOTPARALLEL:
