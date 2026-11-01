@echo off
set "MSVC=C:/Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC\14.44.35207"
set "SDK=C:/Program Files (x86)\Windows Kits\10"
set "SDKVER=10.0.26100.0"
set "PATH=%MSVC%\bin\Hostx64\x64;%PATH%"
set "INCLUDE=%MSVC%\include;%SDK%\Include\%SDKVER%\ucrt;%SDK%\Include\%SDKVER%\um;%SDK%\Include\%SDKVER%\shared;%SDK%\Include\%SDKVER%\winrt;%SDK%\Include\%SDKVER%\cppwinrt"
set "LIB=%MSVC%\lib\x64;%SDK%\Lib\%SDKVER%\ucrt\x64;%SDK%\Lib\%SDKVER%\um\x64"
cd /d E:/makecode-arcade-libretro
cl /nologo /TP /EHsc /utf-8 /c -DNOMINMAX -DWIN32_LEAN_AND_MEAN -D_CRT_SECURE_NO_WARNINGS ^
  -IE:/makecode-arcade-libretro/src -IE:/makecode-arcade-libretro/third_party/libretro ^
  -IE:/makecode-arcade-libretro/third_party/quickjs -IE:/makecode-arcade-libretro/third_party/lzma ^
  -IE:/makecode-arcade-libretro/third_party/miniz -IE:/makecode-arcade-libretro/build/gen ^
  -IE:/makecode-arcade-libretro/third_party/hermes/external ^
  -IE:/makecode-arcade-libretro/third_party/hermes/include ^
  -IE:/makecode-arcade-libretro/build/hermes_build/include ^
  -IE:/makecode-arcade-libretro/build/hermes_build/lib/config ^
  -IE:/makecode-arcade-libretro/third_party/hermes/external/llvh/include ^
  -IE:/makecode-arcade-libretro/third_party/hermes/API/jsi/jsi/.. ^
  -IE:/makecode-arcade-libretro/third_party/hermes/API/hermes/.. ^
  -IE:/makecode-arcade-libretro/third_party/hermes/public ^
  -FoNUL src\core.cpp > compile_core.log 2>&1
type compile_core.log
