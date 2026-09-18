#!/usr/bin/python3
# -*- coding: UTF-8 -*-

import sys
import os
import re
import symbols

script_dir = os.path.dirname(__file__)
rom_name = os.path.normpath(os.path.join(script_dir, "AW2.gba"))
elf_name = os.path.normpath(os.path.join(script_dir, "aw2.elf"))
procscr_path = os.path.normpath(os.path.join(script_dir, "procscr.txt"))
names_path = os.path.normpath(os.path.join(script_dir, "..", "util", "names", "AW2E.lua"))
decomp_names_path = os.path.normpath(os.path.join(script_dir, "..", "util", "names", "AW2E_decomp.lua"))

COMMANDS = {
    0x00: ("PROC_END", "none"),
    0x01: ("PROC_NAME", "ptr"),
    0x02: ("PROC_CALL", "ptr"),
    0x03: ("PROC_REPEAT", "ptr"),
    0x04: ("PROC_SET_END_CB", "ptr"),
    0x05: ("PROC_START_CHILD", "ptr"),
    0x06: ("PROC_START_CHILD_BLOCKING", "ptr"),
    0x07: ("PROC_START_MAIN", "both"),
    0x08: ("PROC_WHILE_EXISTS", "ptr"),
    0x09: ("PROC_END_EACH", "ptr"),
    0x0A: ("PROC_BREAK_EACH", "ptr"),
    0x0B: ("PROC_LABEL", "arg"),
    0x0C: ("PROC_GOTO", "arg"),
    0x0D: ("PROC_JUMP", "ptr"),
    0x0E: ("PROC_SLEEP", "sleep"),
    0x0F: ("PROC_MARK", "arg"),
    0x10: ("PROC_BLOCK", "none"),
    0x11: ("PROC_11", "none"),
    0x12: ("PROC_12", "both"),
    0x13: ("PROC_13", "both"),
    0x14: ("PROC_WHILE", "ptr"),
    0x15: ("PROC_15", "both"),
    0x16: ("PROC_CALL_2", "both"),
    0x17: ("PROC_END_DUPLICATES", "none"),
    0x18: ("PROC_CALL_ARG", "both"),
    0x19: ("PROC_19", "both"),
    0x1A: ("PROC_1A", "both"),
    0x1B: ("PROC_1B", "arg"),
    0x1C: ("PROC_1C", "both"),
    0x1D: ("PROC_1D", "arg"),
    0x1E: ("PROC_1E", "arg"),
    0x1F: ("PROC_1F", "both"),
    0x20: ("PROC_20", "both"),
    0x21: ("PROC_21", "both"),
    0x22: ("PROC_22", "both"),
    0x23: ("PROC_23", "both"),
    0x24: ("PROC_24", "both"),
    0x25: ("PROC_FADE_TO_WHITE", "arg"),
    0x26: ("PROC_FADE_FROM_WHITE", "arg"),
    0x27: ("PROC_27", "both"),
    0x28: ("PROC_28", "both"),
    0x29: ("PROC_29", "arg"),
    0x2A: ("PROC_2A", "none"),
    0x2B: ("PROC_2B", "both"),
}

DEFINE_SUFFIXES = {
    0x02: "",
    0x03: "_IDLE",
    0x04: "_CB",
    0x08: "_WHILE_EXISTS",
    0x14: "_WHILE",
    0x16: "_CALL_2",
    0x18: "_CALL_ARG",
    0x27: "_GOTO_IF_YES",
    0x28: "_GOTO_IF_NO",
}

def read_int(f, count, signed = False):
    return int.from_bytes(f.read(count), byteorder = 'little', signed = signed)

def parse_address(text):
    text = text.replace(',', '').replace('_', '')

    if text.lower().startswith("0x"):
        return int(text, base = 16)

    return int(text, base = 16)

def read_instructions(f, offset):
    instructions = []

    f.seek(offset)

    while True:
        opc = read_int(f, 2)
        arg = read_int(f, 2)
        ptr = read_int(f, 4)

        instructions.append((opc, arg, ptr))
        offset = offset + 8

        if opc in (0x00, 0x0D, 0x10) or opc not in COMMANDS:
            break

    return instructions, offset

def format_address(address):
    return f"0x{address:08X}"

def format_define_value(address):
    if address & 1:
        return f"{format_address(address - 1)}+1"

    return format_address(address)

def make_define_name(proc_name, opc, ptr):
    return f"{proc_name}{DEFINE_SUFFIXES[opc]}_{ptr:08X}"

def collect_defines(proc_name, instructions):
    defines = {}
    ordered_defines = []

    for opc, arg, ptr in instructions:
        if opc in DEFINE_SUFFIXES and ptr != 0:
            key = (opc, ptr)

            if key not in defines:
                defines[key] = make_define_name(proc_name, opc, ptr)
                ordered_defines.append((defines[key], ptr))

    return defines, ordered_defines

def is_generic_decomp_name(name):
    return (
        re.fullmatch(r"sub_[0-9A-Fa-f]+", name) is not None
        or re.fullmatch(r"gUnknown_[0-9A-Fa-f]+", name) is not None
        or re.fullmatch(r"_[0-9A-Fa-f]+", name) is not None
        or name == "NULL"
    )

def read_names(path):
    names = {}

    if not os.path.exists(path):
        return names

    with open(path, 'r') as f:
        for line in f:
            match = re.search(r'\[\s*0x([0-9A-Fa-f]+)\s*\]\s*=\s*"([^"]*)"', line)

            if match:
                names[int(match.group(1), base = 16)] = match.group(2)

    return names

def read_named_addresses(force = False):
    named = set()

    if not force:
        named.update(read_names(names_path).keys())

        for address, name in read_names(decomp_names_path).items():
            if not is_generic_decomp_name(name):
                named.add(address)

    return named

def lua_quote(text):
    return text.replace("\\", "\\\\").replace("\"", "\\\"")

def remove_lua_name_lines(lines, addresses):
    result = []

    for line in lines:
        match = re.search(r'\[\s*0x([0-9A-Fa-f]+)\s*\]', line)

        if match and int(match.group(1), base = 16) in addresses:
            continue

        result.append(line)

    return result

def add_names_to_lua(entries, force = False):
    named = read_named_addresses(force)
    new_entries = []
    force_addresses = set(address for address, name in entries) if force else set()

    for address, name in entries:
        if force or address not in named:
            named.add(address)
            new_entries.append((address, name))

    if len(new_entries) == 0:
        return

    with open(names_path, 'r') as f:
        lines = f.readlines()

    if force:
        lines = remove_lua_name_lines(lines, force_addresses)

    insert_at = None

    for i in range(len(lines) - 1, -1, -1):
        if lines[i].strip() == "}":
            insert_at = i
            break

    if insert_at is None:
        raise RuntimeError(f"Could not find closing table brace in {names_path}")

    if insert_at > 0 and lines[insert_at - 1].strip() != "":
        new_entries.insert(0, None)

    formatted = []

    for entry in new_entries:
        if entry is None:
            formatted.append("\n")
            continue

        address, name = entry
        formatted.append(f'\t[0x{address:08X}] = "{lua_quote(name)}",\n')

    lines[insert_at:insert_at] = formatted

    with open(names_path, 'w') as f:
        f.writelines(lines)

def format_dump(name, ordered_defines, instructions, defines, end_offset):
    lines = [f"struct ProcCmd CONST_DATA {name}[] = " + "{"]

    for define, ptr in ordered_defines:
        lines.append(f"#define {define} {format_define_value(ptr)}")

    for opc, arg, ptr in instructions:
        lines.append(format_instruction(opc, arg, ptr, defines))

    lines.append("};")
    lines.append(f"// end at {end_offset+0x08000000:08X}")
    lines.append("")

    return "\n".join(lines)

def save_dump_to_procscr(dump_text, address, force = False):
    if not force or not os.path.exists(procscr_path):
        with open(procscr_path, 'a') as f:
            f.write(dump_text)
            f.write("\n")
        return

    with open(procscr_path, 'r') as f:
        text = f.read()

    pattern = re.compile(
        r'struct ProcCmd CONST_DATA \S+_' + re.escape(f"{address:08X}") + r'\[\] = \{\n.*?\n\};\n// end at [0-9A-Fa-f]{8}\n?',
        re.DOTALL,
    )

    replacement = dump_text.rstrip() + "\n"

    if pattern.search(text):
        text = pattern.sub(replacement, text, count = 1)
    else:
        if len(text) > 0 and not text.endswith("\n"):
            text += "\n"
        text += "\n" + replacement

    with open(procscr_path, 'w') as f:
        f.write(text)

def format_symbol(opc, ptr, defines):
    if (opc, ptr) in defines:
        return defines[(opc, ptr)]

    return format_address(ptr)

def format_instruction(opc, arg, ptr, defines):
    mnemonic, kind = COMMANDS.get(opc, (f"PROC_{opc:02X}", "both"))
    sym = format_symbol(opc, ptr, defines)

    if opc == 0x0E:
        if arg == 0:
            return "    PROC_YIELD,"

        return f"    PROC_SLEEP({arg}),"

    if kind == "none":
        return f"    {mnemonic},"

    if kind == "arg":
        indent = "" if opc == 0x0B else "    "
        return f"{indent}{mnemonic}({arg}),"

    if kind == "ptr":
        return f"    {mnemonic}({sym}),"

    return f"    {mnemonic}({sym}, {arg}),"

def main(args):
    force = False
    save = False
    positional = []

    for arg in args:
        if arg in ("-o", "--overwrite"):
            force = True
        elif arg in ("-s", "--save"):
            save = True
        else:
            positional.append(arg)

    try:
        offset = 0x1FFFFFF & parse_address(positional[0])

    except IndexError:
        sys.exit(f"Usage: {sys.argv[0]} ADDRESS [NAME] [-o] [--save]")

    #with open(elf_name, 'rb') as f:
        ##syms = { addr: name for addr, name in symbols.from_elf(f) }

    addr = offset + 0x08000000
    #name = syms[addr] if addr in syms else f'ProcScr_Unk_{offset + 0x08000000:08X}'
    proc_name = f'ProcScr_Unk'

    if len(positional) > 1:
        proc_name = positional[1]

    name = f'{proc_name}_{offset + 0x08000000:08X}'

    with open(rom_name, 'rb') as f:
        instructions, end_offset = read_instructions(f, offset)

    define_base_name = proc_name if len(positional) > 1 else name
    defines, ordered_defines = collect_defines(define_base_name, instructions)
    dump_text = format_dump(name, ordered_defines, instructions, defines, end_offset)

    if len(positional) > 1:
        add_names_to_lua([(addr, proc_name)] + [(ptr, define) for define, ptr in ordered_defines], force)

    if save or force:
        save_dump_to_procscr(dump_text, addr, force)

    print(dump_text)

if __name__ == '__main__':
    main(sys.argv[1:])
