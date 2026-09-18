python should be installed in your cmd.exe already 

open cmd.exe here by typing cmd.exe in the folder or by adding a shortcut 
eg. cmd.exe shortcut properties: start in `C:\Users\User\Desktop\GBAFE-LuaUtilities\proc_dump` 

`pip install pyelftools` if you haven't yet 


Click dump.bat and enter an address, optionally followed by a proc name. It will write to the end of procscr.txt.
Add `-o` to replace an existing procscr.txt block and AW2E.lua names for that address.

Example:
86140D4 NewspaperBG -o

Terminal usage: 
dump-proc.py 0849EB7C
`dump-proc.py 0849EB7C`

named dump:
dump-proc.py 86140D4 NewspaperBG --save

overwrite an existing named dump:
dump-proc.py 86140D4 NewspaperBG -o

save to new file: 
dump-proc.py 0849EB7C > procscr.txt 

append to existing file: 
dump-proc.py 0849EC1C >> procscr.txt
