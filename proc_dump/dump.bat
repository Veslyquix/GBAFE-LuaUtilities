

@echo off
:loop 
set /p "addr=Enter Address: "

dump-proc.py %addr%
dump-proc.py %addr% >> procscr.txt
goto loop 

pause 

