#!/usr/bin/env python3
"""Convert the Arkos Tracker 2 AKG player sources (RASM syntax) to sjasmplus.

The original PlayerAkg.asm / PlayerAkg_SoundEffects.asm use a few RASM-only
features that sjasmplus does not understand:

- macros whose parameter is substituted into label names with {param},
  including arithmetic such as {{channelNumber} + 7};
- REPEAT n, counter ... REND loops that do the same with a counter;
- IFDEF/IFNDEF test symbols set with `name = 1`, while sjasmplus IFDEF only
  sees DEFINEs; they become IF exist / IF !exist;
- `name = value` and directives must not be indented / must be, respectively;
- trailing commas in db/dw lists;
- labels are case-sensitive and limited in length;
- the Disark helper macros (dkws, dkwe, dkps, dkpe, dkbs, dkbe, dknr3), which
  only emit marker labels for the Disark source converter and generate no code.

This script expands the channel macros and REPEAT loops textually, strips the
Disark markers, and leaves everything else unchanged (conditional assembly
stays in place, so the Player Configuration flags still work).

Usage: rasm2sjasm.py <input.asm> <output.asm>
"""
import re
import sys

DISARK = ("dkws", "dkwe", "dkps", "dkpe", "dkbs", "dkbe", "dknr3")
DISARK_RE = re.compile(r"^(%s)\b(\s*\(void\))?:?" % "|".join(DISARK), re.IGNORECASE)


def substitute(lines, name, value):
    """Replace {name} and a bare `name` word, then evaluate {integer expr}."""
    out = []
    for line in lines:
        line = line.replace("{%s}" % name, str(value))
        code, sep, comment = line.partition(";")
        code = re.sub(r"\b%s\b" % name, str(value), code)
        # {1 + 7} style arithmetic left after the substitution.
        while True:
            m = re.search(r"\{([0-9+\-* ()]+)\}", code)
            if not m:
                break
            code = code[:m.start()] + str(eval(m.group(1))) + code[m.end():]
        out.append(code + sep + comment)
    return out


def strip_disark(lines):
    out = []
    skip_block = False
    for line in lines:
        s = line.strip()
        low = s.lower()
        # IFNDEF dkxx / MACRO dkxx ... ENDM / ENDIF definition blocks.
        if re.match(r"ifndef\s+(%s)\b" % "|".join(DISARK), low):
            skip_block = True
            continue
        if skip_block:
            if low.startswith("endif"):
                skip_block = False
            continue
        if re.match(r"disarkcounter\s*=", low):
            continue
        m = DISARK_RE.match(line)
        if m:
            rest = line[m.end():]
            if rest.strip() == "" or rest.strip().startswith(";"):
                continue                      # marker on its own line
            line = " " * m.end() + rest       # marker in front of an instruction
        out.append(line)
    return out


def expand(lines):
    # Collect "MACRO name param ... ENDM" definitions.
    macros = {}
    body = []
    i = 0
    while i < len(lines):
        m = re.match(r"^\s*MACRO\s+(\w+)\s+(\w+)", lines[i], re.IGNORECASE)
        if m:
            name, param = m.group(1), m.group(2)
            j = i + 1
            while not re.match(r"^\s*ENDM\b", lines[j], re.IGNORECASE):
                j += 1
            macros[name.lower()] = (param, lines[i + 1:j])
            body.append("        ; (macro %s expanded below at each use)" % name)
            i = j + 1
            continue
        body.append(lines[i])
        i += 1

    def run(src):
        out = []
        i = 0
        while i < len(src):
            line = src[i]
            m = re.match(r"^\s*REPEAT\s+(\d+)\s*,\s*(\w+)", line, re.IGNORECASE)
            if m:
                count, var = int(m.group(1)), m.group(2)
                depth, j = 1, i + 1
                while True:
                    if re.match(r"^\s*REPEAT\b", src[j], re.IGNORECASE):
                        depth += 1
                    elif re.match(r"^\s*REND\b", src[j], re.IGNORECASE):
                        depth -= 1
                        if depth == 0:
                            break
                    j += 1
                block = src[i + 1:j]
                for n in range(1, count + 1):
                    out.extend(run(substitute(block, var, n)))
                i = j + 1
                continue
            m = re.match(r"^\s*(\w+)\s+(\d+)\s*(;.*)?$", line)
            if m and m.group(1).lower() in macros:
                param, mbody = macros[m.group(1).lower()]
                out.append("        ; --- %s %s ---" % (m.group(1), m.group(2)))
                out.extend(run(substitute(mbody, param, int(m.group(2)))))
                i += 1
                continue
            out.append(line)
            i += 1
        return out

    return run(body)


def fix_assignments(lines):
    """sjasmplus only takes `name = expr` (DEFL) in the label column, and RASM
    chains `label: equ x : name = name + 1` on one line: move each assignment
    to its own line, starting in column 0."""
    out = []
    assign = re.compile(r"^\s*(\w+)\s*=\s*[^=]")
    directive = re.compile(r"^(IF|IFDEF|IFNDEF|ELSE|ELSEIF|ENDIF)\b", re.IGNORECASE)
    for line in lines:
        code, sep, comment = line.partition(";")
        parts = code.split(" : ") if " equ " in code.lower() else [code]
        if len(parts) > 1 and all(assign.match(p) for p in parts[1:]):
            out.append(parts[0].rstrip() + (" " + sep + comment if sep else ""))
            out.extend(p.strip() for p in parts[1:])
            continue
        # RASM accepts a trailing comma in data lists ("dw 1, 2,  ;...").
        if re.match(r"^\s*(db|dw|defb|defw)\b", code, re.IGNORECASE) and code.rstrip().endswith(","):
            code = code.rstrip()[:-1] + " "
            line = code + sep + comment
        if assign.match(code):
            line = line.lstrip()
        elif directive.match(line):
            line = "        " + line      # column 0 would make it a label
        # sjasmplus IFDEF only sees DEFINEs; RASM's tests symbols (flags set
        # with `name = 1`), which sjasmplus spells `IF exist name`.
        line = re.sub(r"^(\s*)IFNDEF\s+(\w+)", r"\1IF !exist \2", line, flags=re.IGNORECASE)
        line = re.sub(r"^(\s*)IFDEF\s+(\w+)", r"\1IF exist \2", line, flags=re.IGNORECASE)
        out.append(line)
    return out


# sjasmplus rejects labels this long; shorten the offending name.
RENAMES = {
    "PitchTrackIntegerAfterAddOrSubJumpInstrAndAddress": "PitchTrackIntAfterAddOrSubJpInstrAndAddr",
}


def fix_names(lines):
    """Apply RENAMES, and make every reference use the case of the symbol's
    definition: RASM labels are case-insensitive, sjasmplus labels are not
    (e.g. PLY_AKG_SaveSP is defined as PLY_AKG_SaveSp in the ROM buffer)."""
    for old, new in RENAMES.items():
        lines = [l.replace(old, new) for l in lines]
    defined = {}
    for line in lines:
        m = re.match(r"^(\w+)\s*(:|\s+equ\b|\s*=|\s|$)", line, re.IGNORECASE)
        if m:
            defined.setdefault(m.group(1).lower(), m.group(1))
    out = []
    for line in lines:
        code, sep, comment = line.partition(";")
        code = re.sub(r"\b\w+\b",
                      lambda m: defined.get(m.group(0).lower(), m.group(0))
                      if m.group(0).lower().startswith("ply_") else m.group(0),
                      code)
        out.append(code + sep + comment)
    return out


def main():
    src, dst = sys.argv[1], sys.argv[2]
    with open(src, encoding="latin-1") as f:
        lines = f.read().replace("\r\n", "\n").split("\n")
    lines = fix_names(fix_assignments(expand(strip_disark(lines))))
    header = [
        "; Converted from RASM to sjasmplus syntax by tools/rasm2sjasm.py.",
        "; Do not edit by hand: change the converter or the original instead.",
        "",
    ]
    with open(dst, "w", encoding="latin-1") as f:
        f.write("\n".join(header + lines))


if __name__ == "__main__":
    main()
