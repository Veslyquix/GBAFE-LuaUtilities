

@echo off
:loop 
set /p "addr=Enter Address/Name: "

dump-proc.py %addr% --save
goto loop 

pause 

