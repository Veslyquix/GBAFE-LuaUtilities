python should be installed in your cmd.exe already 

open cmd.exe here by typing cmd.exe in the folder or by adding a shortcut 
eg. cmd.exe shortcut properties: start in `C:\Users\User\Desktop\GBAFE-LuaUtilities\proc_dump` 

`pip install pyelftools` if you haven't yet 


Click dump.bat and enter an address. It will write to the end of procscr.txt 

Terminal usage: 
dump-proc.py 0x0849EB7C
`dump-proc.py 0x0849EB7C`

save to new file: 
dump-proc.py 0x0849EB7C > procscr.txt 

append to existing file: 
dump-proc.py 0x0849EC1C >> procscr.txt
