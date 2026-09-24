

@echo off
:loop 
set /p "addr=Enter Address/Name: "

python dump-proc.py %addr% --save
goto loop 

pause 

