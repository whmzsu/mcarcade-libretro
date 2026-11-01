@echo off
set "MSVC=C:/Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC\14.44.35207"
set "PATH=%MSVC%\bin\Hostx64\x64;%PATH%"
where cl
cl 2>&1
echo RC=%ERRORLEVEL%
