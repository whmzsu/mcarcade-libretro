@echo off
set "MSVC=C:/Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC\14.44.35207"
set "SDK=C:/Program Files (x86)\Windows Kits\10"
set "SDKVER=10.0.26100.0"
set "PATH=%MSVC%\bin\Hostx64\x64;%SDK%\bin\%SDKVER%\x64;C:/Program Files\CMake\bin;%LOCALAPPDATA%\Microsoft\WinGet\Packages\Ninja-build.Ninja_Microsoft.Winget.Source_8wekyb3d8bbwe;%PATH%"
set "INCLUDE=%MSVC%\include;%SDK%\Include\%SDKVER%\ucrt;%SDK%\Include\%SDKVER%\um;%SDK%\Include\%SDKVER%\shared;%SDK%\Include\%SDKVER%\winrt;%SDK%\Include\%SDKVER%\cppwinrt"
set "LIB=%MSVC%\lib\x64;%SDK%\Lib\%SDKVER%\ucrt\x64;%SDK%\Lib\%SDKVER%\um\x64"
cd /d E:/makecode-arcade-libretro
cmake -B build-host -S third_party/hermes -G Ninja -DCMAKE_BUILD_TYPE=Release ^
  -DHERMES_ENABLE_TOOLS=ON -DHERMES_BUILD_HERMESC_ONLY=ON ^
  -DHERMES_ENABLE_TEST_SUITE=OFF -DHERMES_ENABLE_DEBUGGER=OFF ^
  -DHERMES_ENABLE_NAPI=OFF -DHERMES_ENABLE_CORE_EXTENSIONS=OFF ^
  -DHERMESVM_ALLOW_JIT=0 ^
  -DCMAKE_MAKE_PROGRAM="C:/Users/whmzs/AppData/Local/Microsoft/WinGet/Packages/Ninja-build.Ninja_Microsoft.Winget.Source_8wekyb3d8bbwe/ninja.exe" %*
