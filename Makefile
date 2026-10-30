ASM     = sjasmplus
SRCDIR  = src
OUTDIR  = build
TARGET  = $(OUTDIR)/DoubleSuicide.rom
SOURCES = $(wildcard $(SRCDIR)/*.asm)

# openMSX location: on Windows the default install path, elsewhere from PATH.
# Override from the command line, e.g. make run OPENMSX=/path/to/openmsx
ifeq ($(OS),Windows_NT)
OPENMSX ?= C:/Program Files/openMSX/openmsx
else
OPENMSX ?= openmsx
endif
OPENMSX_FLAGS ?= -machine C-BIOS_MSX1

.PHONY: all run clean

all: $(TARGET)

$(OUTDIR):
	mkdir -p $(OUTDIR)

# Rebuild when any source file changes, not only main.asm
$(TARGET): $(SOURCES) | $(OUTDIR)
	$(ASM) --raw=$(TARGET) $(SRCDIR)/main.asm

run: $(TARGET)
	"$(OPENMSX)" $(OPENMSX_FLAGS) -cart $(TARGET)

clean:
	rm -f $(OUTDIR)/*.rom
