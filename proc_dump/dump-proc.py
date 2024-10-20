#!/usr/bin/python3
# -*- coding: UTF-8 -*-

import sys
import symbols

rom_name = "AW2.gba"
elf_name = "aw2.elf"

def read_int(f, count, signed = False):
    return int.from_bytes(f.read(count), byteorder = 'little', signed = signed)

def main(args):
    try:
        offset = 0x1FFFFFF & int(args[0].replace(',', ''), base = 0)

    except IndexError:
        sys.exit(f"Usage: {sys.argv[0]} OFFSET")

    #with open(elf_name, 'rb') as f:
        ##syms = { addr: name for addr, name in symbols.from_elf(f) }

    addr = offset + 0x08000000
    #name = syms[addr] if addr in syms else f'ProcScr_Unk_{offset + 0x08000000:08X}'
    name = f'ProcScr_Unk'

    if len(args) > 1:
        name = args[1]

    name = f'{name}_{offset + 0x08000000:08X}'

    print(f"struct ProcCmd CONST_DATA {name}[] = " + "{")

    with open(rom_name, 'rb') as f:
        f.seek(offset)

        while True:
            offset = offset + 8

            opc = read_int(f, 2)
            arg = read_int(f, 2)
            ptr = read_int(f, 4)

            #sym = syms[ptr] if ptr in syms else f"0x{ptr:08X}"
            sym = f"0x{ptr:08X}"

            if opc == 0x00:
                print("    PROC_END,")
                break

            if opc == 0x01:
                print(f"    PROC_NAME({sym}),")
                continue

            if opc == 0x02:
                print(f"    PROC_CALL({sym}),")
                continue

            if opc == 0x03:
                print(f"    PROC_REPEAT({sym}),")
                continue

            if opc == 0x04:
                print(f"    PROC_SET_END_CB({sym}),")
                continue

            if opc == 0x05:
                print(f"    PROC_START_CHILD({sym}),")
                continue

            if opc == 0x06:
                print(f"    PROC_START_CHILD_BLOCKING({sym}),")
                continue

            if opc == 0x07:
                print(f"    PROC_START_MAIN({sym}, {arg}),") # uses arg 
                continue

            if opc == 0x08:
                print(f"    PROC_WHILE_EXISTS({sym}),") #not 100% confident on params 
                continue

            if opc == 0x09:
                print(f"    PROC_END_EACH({sym}),")#not 100% confident on params 
                continue

            if opc == 0x0A:
                print(f"    PROC_BREAK_EACH({sym}),")#not 100% confident on params
                continue

            if opc == 0x0B:
                print(f"PROC_LABEL({arg}),")
                continue

            if opc == 0x0C:
                print(f"    PROC_GOTO({arg}),")
                continue

            if opc == 0x0D:
                print(f"    PROC_JUMP({sym}),")
                break

            if opc == 0x0E:
                if arg == 0:
                    print("    PROC_YIELD,")
                else:
                    print(f"    PROC_SLEEP({arg}),")
                continue

            if opc == 0x0F:
                print(f"    PROC_MARK({arg}),") #not 100% confident on params
                continue

            if opc == 0x10:
                print("    PROC_BLOCK,") #not 100% confident on params
                break

            if opc == 0x11:
                print("    PROC_11,")
                continue

            if opc == 0x12:
                print(f"    PROC_12({sym}, {arg}),")
                continue

            if opc == 0x13:
                print(f"    PROC_13({sym}, {arg}),")
                continue

            if opc == 0x14:
                print(f"    PROC_WHILE({sym}),")
                continue

            if opc == 0x15:
                print(f"    PROC_15({sym}, {arg}),")
                continue

            if opc == 0x16:
                print(f"    PROC_CALL_2({sym}, {arg}),")
                continue

            if opc == 0x17:
                print("    PROC_END_DUPLICATES,")
                continue

            if opc == 0x18:
                print(f"PROC_CALL_ARG({sym}, {arg}),")
                continue

            if opc == 0x19:
                print(f"    PROC_19({sym}, {arg}),")
                continue

            if opc == 0x1A:
                print(f"    PROC_1A({sym}, {arg}),")
                continue

            if opc == 0x1B:
                print(f"    PROC_1B({arg}),")
                continue

            if opc == 0x1C:
                print(f"    PROC_1C({sym}, {arg}),")
                continue

            if opc == 0x1D:
                print(f"    PROC_1D({arg}),")
                continue

            if opc == 0x1E:
                print(f"    PROC_1E({arg}),")
                continue

            if opc == 0x1F:
                print(f"    PROC_1F({sym}, {arg}),")
                continue

            if opc == 0x20:
                print(f"    PROC_20({sym}, {arg}),")
                continue

            if opc == 0x21:
                print(f"    PROC_21({sym}, {arg}),")
                continue

            if opc == 0x22:
                print(f"    PROC_22({sym}, {arg}),")
                continue

            if opc == 0x23:
                print(f"    PROC_23({sym}, {arg}),")
                continue

            if opc == 0x24:
                print(f"    PROC_24({sym}, {arg}),")
                continue

            if opc == 0x25:
                print(f"    PROC_FADE_TO_WHITE({arg}),")
                continue

            if opc == 0x26:
                print(f"    PROC_FADE_FROM_WHITE({arg}),")
                continue

            if opc == 0x27:
                print(f"    PROC_27({sym}, {arg}),")
                continue

            if opc == 0x28:
                print(f"    PROC_28({sym}, {arg}),")
                continue

            if opc == 0x29:
                print(f"    PROC_29({arg}),")
                continue

            if opc == 0x2A:
                print("    PROC_2A,")
                continue

            if opc == 0x2B:
                print(f"    PROC_2B({sym}, {arg}),")
                continue

            break

    print("};")
    print(f"// end at {offset+0x08000000:08X}")
    print() 

if __name__ == '__main__':
    main(sys.argv[1:])
