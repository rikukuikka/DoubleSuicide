; Player Configuration for song.asm: tells the AKG player which features the
; song uses, so the code for everything else is left out (smaller and faster).
; Arkos Tracker generates this file when exporting a song ("export player
; configuration"); replace it together with song.asm. Converted to sjasmplus
; syntax (assignments in column 0), see tools/rasm2sjasm.py.

PLY_CFG_ConfigurationIsPresent = 1
PLY_CFG_UseHardwareSounds = 1
PLY_CFG_UseRetrig = 1
PLY_CFG_UseInstrumentLoopTo = 1
PLY_CFG_NoSoftNoHard = 1
PLY_CFG_HardOnly = 1
PLY_CFG_HardOnly_HardwareArpeggio = 1
PLY_CFG_HardOnly_Retrig = 1
