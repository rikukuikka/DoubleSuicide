ASM     = sjasmplus
SRCDIR  = src
OUTDIR  = build
TARGET  = $(OUTDIR)/DoubleSuicide.rom
SOURCES = $(wildcard $(SRCDIR)/*.asm $(SRCDIR)/*/*.asm)

# openMSX location: on Windows the default install path, elsewhere from PATH.
# Override from the command line, e.g. make run OPENMSX=/path/to/openmsx
ifeq ($(OS),Windows_NT)
OPENMSX ?= C:/Program Files/openMSX/openmsx
else
OPENMSX ?= openmsx
endif
OPENMSX_FLAGS ?= -machine C-BIOS_MSX1

.PHONY: all run clean arkos

all: $(TARGET)

$(OUTDIR):
	mkdir -p $(OUTDIR)

# Rebuild when any source file changes, not only main.asm
$(TARGET): $(SOURCES) | $(OUTDIR)
	$(ASM) --raw=$(TARGET) $(SRCDIR)/main.asm

run: $(TARGET)
	"$(OPENMSX)" $(OPENMSX_FLAGS) -cart $(TARGET)

# Regenerate the sjasmplus version of the Arkos Tracker player from the
# original RASM sources in third_party/arkos (only needed after updating them).
arkos:
	python3 tools/rasm2sjasm.py third_party/arkos/PlayerAkg.asm $(SRCDIR)/arkos/PlayerAkg.asm
	python3 tools/rasm2sjasm.py third_party/arkos/PlayerAkg_SoundEffects.asm $(SRCDIR)/arkos/PlayerAkg_SoundEffects.asm

clean:
	rm -f $(OUTDIR)/*.rom
