#!/usr/bin/python3
# -*- coding: UTF-8 -*-

import sys
import symbols

rom_name = "AW2.gba"
elf_name = "aw2.elf"

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
    try:
        offset = 0x1FFFFFF & parse_address(args[0])

    except IndexError:
        sys.exit(f"Usage: {sys.argv[0]} ADDRESS")

    #with open(elf_name, 'rb') as f:
        ##syms = { addr: name for addr, name in symbols.from_elf(f) }

    addr = offset + 0x08000000
    #name = syms[addr] if addr in syms else f'ProcScr_Unk_{offset + 0x08000000:08X}'
    proc_name = f'ProcScr_Unk'

    if len(args) > 1:
        proc_name = args[1]

    name = f'{proc_name}_{offset + 0x08000000:08X}'

    with open(rom_name, 'rb') as f:
        instructions, end_offset = read_instructions(f, offset)

    define_base_name = proc_name if len(args) > 1 else name
    defines, ordered_defines = collect_defines(define_base_name, instructions)

    print(f"struct ProcCmd CONST_DATA {name}[] = " + "{")

    for define, ptr in ordered_defines:
        print(f"#define {define} {format_define_value(ptr)}")

    for opc, arg, ptr in instructions:
        print(format_instruction(opc, arg, ptr, defines))

    print("};")
    print(f"// end at {end_offset+0x08000000:08X}")
    print() 

if __name__ == '__main__':
    main(sys.argv[1:])
