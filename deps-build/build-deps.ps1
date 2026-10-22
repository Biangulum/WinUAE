<#
  Builds the third-party runtime libraries of the WinUAE fork for native ARM64.

  Copyright 2026 Drazen Hudoletnjak

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License version 2 as
  published by the Free Software Foundation.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
  GNU General Public License for more details.

  Every library is fetched at a pinned commit into deps\src\<name>, built in
  deps\build\<name>, and its runtime files are installed into deps\bin\arm64\
  (DLLs WinUAE loads from the executable folder) or deps\bin\arm64\plugins\
  (plugin DLLs). Directory.Build.Paths.targets copies deps\bin\arm64\ into
  out\ after every ARM64 build of winuae. The third-party sources are not
  part of this repository; only the files in deps-build\ are.

  Usage:
    powershell -ExecutionPolicy Bypass -File deps-build\build-deps.ps1
    powershell -ExecutionPolicy Bypass -File deps-build\build-deps.ps1 -Only capsimg
#>

[CmdletBinding()]
param(
	# Components to build (default: all).
	[string[]]$Only
)

$ErrorActionPreference = 'Stop'

$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Deps = Join-Path $Root 'deps'
$SrcDir = Join-Path $Deps 'src'
$BuildDir = Join-Path $Deps 'build'
$BinDir = Join-Path $Deps 'bin\arm64'
$PluginDir = Join-Path $BinDir 'plugins'
$LibDir = Join-Path $Deps 'lib\arm64'

# --- toolchain --------------------------------------------------------------

$VsWhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$VsPath = & $VsWhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.ARM64 -property installationPath
if (-not $VsPath) { throw 'Visual Studio with the ARM64 C++ build tools was not found.' }
$CMake = Join-Path $VsPath 'Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe'
$CMakeGenerator = 'Visual Studio 18 2026'
if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') {
	$VcVars = Join-Path $VsPath 'VC\Auxiliary\Build\vcvarsarm64.bat'
} else {
	$VcVars = Join-Path $VsPath 'VC\Auxiliary\Build\vcvarsamd64_arm64.bat'
}

function Invoke-Native([string]$Exe, [string[]]$Arguments) {
	& $Exe @Arguments
	if ($LASTEXITCODE -ne 0) { throw "$Exe failed with exit code $LASTEXITCODE" }
}

# Runs a command line in a cmd.exe with the ARM64 compiler environment.
function Invoke-VcCmd([string]$WorkDir, [string]$CommandLine) {
	cmd.exe /c "call `"$VcVars`" >nul && cd /d `"$WorkDir`" && $CommandLine"
	if ($LASTEXITCODE -ne 0) { throw "Build command failed with exit code $LASTEXITCODE" }
}

# Fetches $Url at $Commit (full SHA) into deps\src\$Name; reuses a matching checkout.
function Get-Source([string]$Name, [string]$Url, [string]$Commit) {
	$dir = Join-Path $SrcDir $Name
	if (Test-Path (Join-Path $dir '.git')) {
		$head = (git -C $dir rev-parse HEAD).Trim()
		if ($head -eq $Commit) { return $dir }
		Invoke-Native git @('-C', $dir, 'fetch', '-q', '--depth', '1', 'origin', $Commit)
	} else {
		New-Item -ItemType Directory -Force $dir | Out-Null
		Invoke-Native git @('-C', $dir, 'init', '-q')
		Invoke-Native git @('-C', $dir, 'remote', 'add', 'origin', $Url)
		Invoke-Native git @('-C', $dir, 'fetch', '-q', '--depth', '1', 'origin', $Commit)
	}
	Invoke-Native git @('-C', $dir, '-c', 'advice.detachedHead=false', 'checkout', '-q', '--force', 'FETCH_HEAD')
	$head = (git -C $dir rev-parse HEAD).Trim()
	if ($head -ne $Commit) { throw "$Name checkout is $head, expected $Commit" }
	return $dir
}

# Downloads $Url into deps\dl, checks its SHA-256 and extracts it into a fresh
# deps\src\$Name; returns the extracted folder (the archive's top-level folder
# when it has exactly one).
function Get-Archive([string]$Name, [string]$Url, [string]$Sha256) {
	$dlDir = Join-Path $Deps 'dl'
	New-Item -ItemType Directory -Force $dlDir | Out-Null
	$file = Join-Path $dlDir ([IO.Path]::GetFileName($Url))
	if (-not (Test-Path $file) -or (Get-FileHash -Algorithm SHA256 $file).Hash -ne $Sha256) {
		Invoke-Native curl.exe @('-sfL', '-o', $file, $Url)
	}
	$hash = (Get-FileHash -Algorithm SHA256 $file).Hash
	if ($hash -ne $Sha256) { throw "$file has SHA-256 $hash, expected $Sha256" }
	$dir = Join-Path $SrcDir $Name
	New-CleanDir $dir
	Invoke-Native tar.exe @('-xf', $file, '-C', $dir)
	$top = @(Get-ChildItem $dir)
	if ($top.Count -eq 1 -and $top[0].PSIsContainer) { return $top[0].FullName }
	return $dir
}

function New-CleanDir([string]$Path) {
	if (Test-Path $Path) { Remove-Item -Recurse -Force $Path }
	New-Item -ItemType Directory -Force $Path | Out-Null
}

function Install-File([string]$From, [string]$ToDir, [string]$Name) {
	New-Item -ItemType Directory -Force $ToDir | Out-Null
	Copy-Item -Force $From (Join-Path $ToDir $Name)
	Write-Host "  installed $(Join-Path $ToDir $Name)"
}

# --- components -------------------------------------------------------------

# PortAudio v19.7.0 (MIT-style licence). WinUAE delay-loads portaudio_arm64.dll
# by ordinal through deps\lib\arm64\portaudio_arm64.lib; the CMake .def template
# keeps the same ordinals. ASIO is left out (its SDK is not freely licensed).
function Build-PortAudio {
	$src = Get-Source 'portaudio' 'https://github.com/PortAudio/portaudio.git' '147dd722548358763a8b649b3e4b41dfffbcfbb6'
	$build = Join-Path $BuildDir 'portaudio'
	New-CleanDir $build
	Invoke-Native $CMake @('-S', $src, '-B', $build, '-G', $CMakeGenerator, '-A', 'ARM64',
		'-DPA_USE_ASIO=OFF', '-DPA_DLL_LINK_WITH_STATIC_RUNTIME=ON', '-DPA_LIBNAME_ADD_SUFFIX=OFF',
		'-DPA_BUILD_STATIC=OFF', '-DCMAKE_POLICY_VERSION_MINIMUM=3.5')
	Invoke-Native $CMake @('--build', $build, '--config', 'Release')
	Install-File (Join-Path $build 'Release\portaudio.dll') $BinDir 'portaudio_arm64.dll'
}

# SPS decoder library 5.1 (CAPSImg, SPS licence: non-commercial use only),
# the original source as imported into FrodeSolheim/capsimg. That source was
# already ported to Unix, so it is compiled unchanged with the MSVC shims in
# deps-build\capsimg (MIT), which also provide DllMain and the export list.
function Build-CapsImg {
	$src = Get-Source 'capsimg' 'https://github.com/FrodeSolheim/capsimg.git' '229374e931033f4970de8a042e2bb5b86ef3b318'
	$shim = Join-Path $PSScriptRoot 'capsimg'
	$build = Join-Path $BuildDir 'capsimg'
	New-CleanDir $build
	$sources = @(
		'Codec\CTRawCodec.cpp', 'Codec\CTRawCodecDecompressor.cpp', 'Codec\DiskEncoding.cpp',
		'Core\BaseFile.cpp', 'Core\BitBuffer.cpp', 'Core\CRC.cpp', 'Core\DiskFile.cpp', 'Core\MemoryFile.cpp',
		'CAPSImg\CapsAPI.cpp', 'CAPSImg\CapsFDCEmulator.cpp', 'CAPSImg\CapsFile.cpp', 'CAPSImg\CapsFormatMFM.cpp',
		'CAPSImg\CapsImage.cpp', 'CAPSImg\CapsImageStd.cpp', 'CAPSImg\CAPSImg.cpp', 'CAPSImg\CapsLoader.cpp',
		'CAPSImg\DiskImage.cpp', 'CAPSImg\DiskImageFactory.cpp', 'CAPSImg\stdafx.cpp',
		'CAPSImg\StreamCueImage.cpp', 'CAPSImg\StreamImage.cpp'
	) | ForEach-Object { "`"$(Join-Path $src $_)`"" }
	$includes = @($shim, "$src\CAPSImg", "$src\Core", "$src\Device", "$src\LibIPF", "$src\Codec") |
		ForEach-Object { "/I`"$_`"" }
	Invoke-VcCmd $build "cl /nologo /c /O2 /MT /W3 /wd4996 `"$shim\shim_dirent.c`" `"$shim\shim_dllmain.c`""
	Invoke-VcCmd $build ("cl /nologo /c /O2 /MT /EHsc /W3 /wd4996 /MP /DNDEBUG /D_USRDLL /DCAPSIMG_EXPORTS /FImsvc_compat.h " +
		($includes -join ' ') + ' ' + ($sources -join ' '))
	Invoke-VcCmd $build "link /nologo /DLL /OPT:REF /OPT:ICF /DEF:`"$shim\capsimg.def`" /OUT:CAPSImg.dll *.obj kernel32.lib"
	Install-File (Join-Path $build 'CAPSImg.dll') $PluginDir 'CAPSImg_arm64.dll'
}

# UnRAR 7.3.1 DLL (UnRAR freeware licence). Its Visual Studio project has no
# ARM64 configuration, so the project's sources and settings are compiled
# directly. WinUAE looks for unrar.dll and, in an ARM64 build, unrar_arm64.dll.
function Build-UnRAR {
	$src = Get-Archive 'unrar' 'https://www.rarlab.com/rar/unrarsrc-7.3.1.tar.gz' '634900842A3737D9CC15BBCC71D4C74CC713437E0BCA296A573424FE5F2660AB'
	$build = Join-Path $BuildDir 'unrar'
	New-CleanDir $build
	$sources = @(
		'archive', 'arcread', 'blake2s', 'cmddata', 'consio', 'crc', 'crypt', 'dll', 'encname', 'errhnd',
		'extinfo', 'extract', 'filcreat', 'file', 'filefn', 'filestr', 'find', 'getbits', 'global', 'hash',
		'headers', 'isnt', 'largepage', 'match', 'motw', 'options', 'pathfn', 'qopen', 'rar', 'rarvm',
		'rawread', 'rdwrfn', 'rijndael', 'rs', 'rs16', 'scantree', 'secpassword', 'sha1', 'sha256', 'smallfn',
		'strfn', 'strlist', 'system', 'threadpool', 'timefn', 'ui', 'unicode', 'unpack', 'volume'
	) | ForEach-Object { "`"$(Join-Path $src "$_.cpp")`"" }
	Invoke-VcCmd $build "rc /nologo /fo dll.res `"$src\dll.rc`""
	Invoke-VcCmd $build ("cl /nologo /c /O2 /MT /EHsc /GR- /W3 /wd4007 /wd4996 /MP /DRARDLL /DUNRAR /DSILENT " + ($sources -join ' '))
	Invoke-VcCmd $build ("link /nologo /DLL /OPT:REF /OPT:ICF /DEF:`"$src\dll.def`" /OUT:unrar.dll *.obj dll.res " +
		'kernel32.lib user32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib')
	Install-File (Join-Path $build 'unrar.dll') $PluginDir 'unrar_arm64.dll'
}

# Lua 5.2.4 (MIT) as the static luastatic.lib. deps\include carries the
# unmodified Lua 5.2.2 headers; 5.2.4 only adds bug fixes. WinUAE includes
# them without extern "C" on Windows, so Lua is compiled as C++.
function Build-Lua {
	$src = Get-Archive 'lua' 'https://www.lua.org/ftp/lua-5.2.4.tar.gz' 'B9E2E4AAD6789B3B63A056D442F7B39F0ECFCA3AE0F1FC0AE4E9614401B69F4B'
	$build = Join-Path $BuildDir 'lua'
	New-CleanDir $build
	$sources = Get-ChildItem (Join-Path $src 'src\*.c') |
		Where-Object { $_.Name -notin @('lua.c', 'luac.c') } |
		ForEach-Object { "`"$($_.FullName)`"" }
	Invoke-VcCmd $build ("cl /nologo /c /O2 /MT /TP /EHsc /W3 /wd4996 /MP /DLUA_COMPAT_ALL " + ($sources -join ' '))
	Invoke-VcCmd $build 'lib /nologo /OUT:luastatic.lib *.obj'
	Install-File (Join-Path $build 'luastatic.lib') $LibDir 'luastatic.lib'
}

# ENet 1.2 (MIT) as the static enet.lib, used for the serial port over UDP.
# deps\include\enet matches ENet 1.2 exactly (apart from added __cdecl), so the
# wire protocol stays compatible with the x86/x64 builds.
function Build-ENet {
	$src = Get-Archive 'enet' 'http://enet.bespin.org/download/enet-1.2.tar.gz' '7045AC79846F2B546BBD7948F1D1EA03A019CC1E30CBD2DA71FADE9D40D43EA0'
	$build = Join-Path $BuildDir 'enet'
	New-CleanDir $build
	$sources = @('callbacks', 'host', 'list', 'packet', 'peer', 'protocol', 'win32') |
		ForEach-Object { "`"$(Join-Path $src "$_.c")`"" }
	Invoke-VcCmd $build ("cl /nologo /c /O2 /MT /W3 /wd4996 /wd4244 /wd4267 /DWIN32 /I`"$src\include`" " + ($sources -join ' '))
	Invoke-VcCmd $build 'lib /nologo /OUT:enet.lib *.obj'
	Install-File (Join-Path $build 'enet.lib') $LibDir 'enet.lib'
}

# OpenAL Soft 1.25.2 (LGPL 2.1, used as a separate DLL). Installs the import
# library as deps\lib\arm64\OpenAL32.lib and OpenAL32.dll next to the exe.
function Build-OpenAL {
	$src = Get-Source 'openal-soft' 'https://github.com/kcat/openal-soft.git' 'b2c48f7718ef3fcf67921a8b6534c4914e328970'
	$build = Join-Path $BuildDir 'openal-soft'
	New-CleanDir $build
	Invoke-Native $CMake @('-S', $src, '-B', $build, '-G', $CMakeGenerator, '-A', 'ARM64',
		'-DALSOFT_UTILS=OFF', '-DALSOFT_EXAMPLES=OFF', '-DALSOFT_TESTS=OFF', '-DALSOFT_INSTALL=OFF',
		'-DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded')
	Invoke-Native $CMake @('--build', $build, '--config', 'Release', '--target', 'OpenAL')
	Install-File (Join-Path $build 'Release\OpenAL32.dll') $BinDir 'OpenAL32.dll'
	Install-File (Join-Path $build 'Release\OpenAL32.lib') $LibDir 'OpenAL32.lib'
}

# FloppyBridge 1.6.0.4 (MPL 2.0 / GPL 2 or later), the revision upstream's
# tools\build-floppybridge.sh pins for Unix. Its Visual Studio project has no
# ARM64 configuration, so the project's sources and settings are compiled
# directly. The ARM64 WinUAE build looks for FloppyBridge_arm64.dll.
function Build-FloppyBridge {
	$src = Get-Source 'floppybridge' 'https://github.com/RobSmithDev/FloppyDriveBridge.git' '710fa15cb200303f8c4bde1c931786175f301a68'
	$build = Join-Path $BuildDir 'floppybridge'
	New-CleanDir $build
	$sources = @(
		'floppybridge\ArduinoFloppyBridge.cpp', 'floppybridge\ArduinoInterface.cpp', 'floppybridge\CommonBridgeTemplate.cpp',
		'floppybridge\ftdi.cpp', 'floppybridge\GreaseWeazleBridge.cpp', 'floppybridge\GreaseWeazleInterface.cpp',
		'floppybridge\pll.cpp', 'floppybridge\RotationExtractor.cpp', 'floppybridge\SerialIO.cpp',
		'floppybridge\SupercardProBridge.cpp', 'floppybridge\SuperCardProInterface.cpp',
		'windows\bridgeProfileEditor.cpp', 'windows\bridgeProfileListEditor.cpp', 'windows\FloppyBridge.cpp'
	) | ForEach-Object { "`"$(Join-Path $src $_)`"" }
	Invoke-VcCmd $build "rc /nologo /fo Resource.res `"$src\windows\Resource.rc`""
	Invoke-VcCmd $build ('cl /nologo /c /O2 /MT /EHsc /W3 /MP /std:c++17 /permissive- ' +
		'/DNOMINMAX /DWIN32 /DNDEBUG /DFLOPPYBRIDGE_EXPORTS /D_WINDOWS /D_USRDLL /DUNICODE /D_UNICODE ' +
		"/I`"$src\floppybridge`" /I`"$src\windows`" " + ($sources -join ' '))
	Invoke-VcCmd $build ('link /nologo /DLL /OPT:REF /OPT:ICF /OUT:FloppyBridge.dll *.obj Resource.res ' +
		'kernel32.lib user32.lib gdi32.lib comctl32.lib comdlg32.lib shell32.lib advapi32.lib ole32.lib')
	Install-File (Join-Path $build 'FloppyBridge.dll') $PluginDir 'FloppyBridge_arm64.dll'
}

# --- main -------------------------------------------------------------------

$Components = [ordered]@{
	portaudio = { Build-PortAudio }
	capsimg   = { Build-CapsImg }
	unrar     = { Build-UnRAR }
	lua       = { Build-Lua }
	enet      = { Build-ENet }
	openal    = { Build-OpenAL }
	floppybridge = { Build-FloppyBridge }
}

# "-Only a,b" arrives as one string when the script is run with -File.
$selected = if ($Only) { $Only -split ',' | ForEach-Object { $_.Trim() } } else { $Components.Keys }
foreach ($name in $selected) {
	if (-not $Components.Contains($name)) { throw "Unknown component '$name'. Known: $($Components.Keys -join ', ')" }
	Write-Host "=== $name"
	& $Components[$name]
}
Write-Host 'Done.'
