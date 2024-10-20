require "util/gba"

proc = {
	references = {
        AW2E = { -- AW2U (see rom header + 0xAC) 
        -- [849EB7C..849EB84]? -- break point on known proc data read on new campaign 
        -- 1c8f4 proc start? r0 ProcPtr, r1 root tree -- went to r14 a couple times? 
            -- calls 1d264 
            -- 200E414 points to sProcArray
            ptr_proc_pool = 0x200E390,  
            proc_pool_size = 0x21, -- maybe? since 0x200e414 is 0x84 bytes away divided by 4 
        -- [200e390]! hits 0x801C878 which seems to be ProcInit 
        -- 200e410, 200e414, 200e418,  
        -- 200e414 is sProcAllocListHead maybe? 
        -- 200e418 - 200e434 is gProcTreeRootArray
            ptr_proc_forest = 0x200e418, 
            proc_forest_size = 8, 
        -- [84C3138+0x40..84C3138+0x47]? // 8th entry in LoadBattleMap proc at 0x084C3138 
        -- hits 0x801CFC8 as InitSleep 
        -- [200d6e8+0x24]? ProcRam+0x24 as sleep timer 
        -- hits 0x801CFAC as UpdateSleep  
            ptr_sleep_handle = 0x801cfad, 
			names = {
				[0x8581500] = "Intro",
				[0x8581Cf8] = "Title",
				[0x849e818] = "Main Menu",
				[0x0849EB34] = "Campaign",
				[0x0849EC1C] = "War Room",
				[0x0849ECE0] = "Versus",
				[0x084C3138] = "Battle Maps",
				[0x0849EA94] = "Design Room",
				[0x0849EC8C] = "Link",
				[0x0849EAAC] = "Sound Room",
			}
        -- 
        
        }, 
		BE8E = {
			-- FE8U
			
			ptr_proc_forest  = 0x02026A70, -- gProcTreeRootArray
			proc_forest_size = 8,
			
			ptr_proc_pool    = 0x02024E68, -- sProcArray
			proc_pool_size   = 0x40,
			
			ptr_sleep_handle = 0x08003291, -- UpdateSleep
			
			names = {
			}
		},
		
		AE7E = {
			-- FE7U
			
			ptr_proc_forest  = 0x02026A30,
			proc_forest_size = 8,
			
			ptr_proc_pool    = 0, -- TODO
			proc_pool_size   = 0, -- TODO
			
			ptr_sleep_handle = -1, -- TODO
			
			names = {
				[0x8B924BC] = "Game Control",
				[0x8CE3C54] = "Main Menu Logic"
			}
		},
		
		AE7J = {
			-- FE7J
			
			ptr_proc_forest  = 0x02026A28,
			proc_forest_size = 8,
			
			ptr_proc_pool    = 0x02024E20,
			proc_pool_size   = 0x40,
			
			ptr_sleep_handle = -1, -- TODO
			
			names = {
				[0x8C01744] = "Game Control",
				[0x8C01DBC] = "Map Main Logic",
				[0x8C02630] = "Player Phase Logic",
				[0x8C02870] = "Move Range Gfx",
				[0x8C05464] = "[MAPTASK]",
				[0x8D64F4C] = "Moving Unit Gfx",
				[0x8DAD3A4] = "Main Menu Logic",
				[0x8C09BF4] = "Any Menu",
				[0x8C09C34] = "Menu Command",
				[0x8D8B2D8] = "Goal Box",
				[0x8D8B1A0] = "Terrain Box",
				[0x8D8B200] = "Minimug Box"
			}
		}
	},
	
	proc_instruction_formats = {
		[0x0000] = "END",
		[0x0001] = "NAME {narg}",
		[0x0002] = "CALL {larg}",
		[0x0003] = "SET_LOOP {larg}",
		[0x0004] = "SET_END {larg}",
		[0x0005] = "ADD_CHILD {larg}",
		[0x0006] = "ADD_CHILD_BLOCKING {larg}",
		[0x0007] = "<bugged instruction>",
		[0x0008] = "WAIT_FOR {larg}",
		[0x0009] = "END_ALL {larg}",
		[0x000A] = "BREAK_ALL_LOOP {larg}",
		[0x000B] = "LABEL {sarg}",
		[0x000C] = "GOTO {sarg}",
		[0x000D] = "JUMP {larg}",
		[0x000E] = "WAIT {sarg}",
		[0x000F] = "MARK {sarg}",
		[0x0010] = "HALT",
		[0x0011] = "UNIQUE_WEAK",
		[0x0012] = "???",
		[0x0013] = "NOP",
		[0x0014] = "WHILE {larg}",
		[0x0015] = "NOP2",
		[0x0016] = "CALL2 {larg}",
		[0x0017] = "UNIQUE_STRONG",
		[0x0018] = "CALL3 {larg}({sarg})",
		[0x0019] = "NOP3",
        
        -- aw2 exclusive below 
        [0x001A] = "unk1A",
        [0x001B] = "unk1B",
        [0x001C] = "unk1C",
        [0x001D] = "unk1D",
        [0x001E] = "unk1E",
        [0x001F] = "unk1F",
        [0x0020] = "unk20",
        [0x0021] = "unk21",
        [0x0022] = "unk22",
        [0x0023] = "unk23",
        [0x0024] = "unk24",
        [0x0025] = "Fade to white",
        [0x0026] = "Fade from white",
        [0x0027] = "unk27",
        [0x0028] = "unk28",
        [0x0029] = "unk29",
        [0x002A] = "unk2A",
        [0x002B] = "unk2B",
	},
	
	get_reference = function()
		return proc.references[gba.game_code]
	end,
	
	get_proc = function(index)
		if index < 0 or index >= proc.get_reference().proc_pool_size then
			return nil
		end
		
		return proc.get_reference().ptr_proc_pool + (0x6C * index)
	end,
	
	proc_read_name = function(pointer)
		local name = proc.get_reference().names[memory.readlong(pointer)]
		
		if name ~= nil then
			return name
		else
			local nameptr = memory.readlong(pointer+0x10)
			
            
            if gba.game_code == "AW2E" then 
                return "--" 
            end 
            
			if nameptr ~= 0 then
				return gba.read_cstring(nameptr)
			else
				return "----"
			end
		end
	end,
	
	proc_is_halted = function(pointer)
		return memory.readbyte(pointer+0x24) ~= 0 -- in aw2, +0x28 isn't set during sleep 
	end,
	
	proc_get_halt_count = function(pointer)
		return memory.readbyte(pointer+0x24) -- in aw2, +0x28 isn't set during sleep 
	end,
	
	proc_is_sleeping = function(pointer)
		return memory.readlong(pointer+0x0C) == proc.get_reference().ptr_sleep_handle
	end,
	
	proc_get_sleep_time = function(pointer)
		return memory.readshort(pointer+0x24)
	end,
	
	proc_get_start_code_ptr = function(pointer)
		return memory.readlong(pointer+0x00)
	end,
	
	proc_get_current_code_ptr = function(pointer)
		return memory.readlong(pointer+0x08) -- +0x08 in aw2, +0x04 is usually but not always proc_Script / +0x00 
	end, -- r0=0x849e818 - after war room, wrong name 
	
	proc_get_state_summary = function(pointer)
		local code_start   = proc.proc_get_start_code_ptr(pointer)
		local code_current = proc.proc_get_current_code_ptr(pointer)
		
		local activity_str = (function()
			if proc.proc_is_halted(pointer) then
				return "H:" .. proc.proc_get_halt_count(pointer)
			end
			
			if proc.proc_is_sleeping(pointer) then
				return "S:" .. proc.proc_get_sleep_time(pointer)
			end
			
			return "-"
		end)()
		
		return string.format("%X+%X (%s)", code_start, (code_current - code_start), activity_str)
	end,
	
	proc_get_next = function(pointer)
		return memory.readlong(pointer+0x20)
	end,
	
	proc_get_child = function(pointer)
		return memory.readlong(pointer+0x18)
	end,
	
	tree_iterator = function()
		return function(size, n)
			if n < size then
				n = n+1
				return n, memory.readlong(proc.get_reference().ptr_proc_forest + 4*n)
			end
		end, proc.get_reference().proc_forest_size, (-1)
	end,
	
	proc_iterator = function(pointer)
		return function(state, value)
			if value == nil then
				if state ~= 0 then
					return state
				end
			else
				local result = proc.proc_get_next(value)
				
				if result ~= 0 then
					return result
				end
			end
		end, pointer, nil
	end,
	
	child_iterator = function(pointer)
		return proc.proc_iterator(proc.proc_get_child(pointer))
	end
}
