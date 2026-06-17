ASM     = sjasmplus
SRCDIR  = src
OUTDIR  = build
TARGET  = $(OUTDIR)/wow.rom

.PHONY: all run clean

all: $(OUTDIR) $(TARGET)

$(OUTDIR):
	mkdir -p $(OUTDIR)

$(TARGET): $(SRCDIR)/main.asm 
	$(ASM) --raw=$(TARGET) $(SRCDIR)/main.asm

run: $(TARGET)
	C:/Program Files/openMSX/openmsx -machine C-BIOS_MSX1 -cart $(TARGET)

clean:
	rm -f $(OUTDIR)/*.rom
