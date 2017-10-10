@echo off
REM Credits to https://stackoverflow.com/a/935681/5129091
set VTYPE=%1
set "RESTVAR="
shift
:loop1
if "%1"=="" goto after_loop
if "%RESTVAR%"=="" (
    set RESTVAR=%RESTVAR% %1
) else (
    set RESTVAR=%RESTVAR% %1
)
shift
goto loop1

:after_loop
set RESTVAR="%RESTVAR%"
call coffee -cb .

git add . -A
git add . -u

call npm run precompile
echo ^> npm version %VTYPE% -m%RESTVAR% --force
call npm version %VTYPE% -m%RESTVAR% --force
call npm run oncompile
call npm publish