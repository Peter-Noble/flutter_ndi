$env:Path += 'C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC\14.37.32822\bin\Hostx64\x64'
nvcc -o ndi_convert.dll -shared .\src\ndi_convert.cu -lcudart
# dumpbin /exports .\ndi_convert.dll