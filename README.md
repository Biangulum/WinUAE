> **Unofficial fork.** This repository is an unofficial fork of
> [WinUAE](https://www.winuae.net/) by Toni Wilen. The upstream project is
> available at [github.com/tonioni/WinUAE](https://github.com/tonioni/WinUAE).
>
> Goals of this fork: building with Visual Studio 2026, x64 builds and native
> Arm64 (Windows on Arm) builds.
>
> The code is licensed under the GNU General Public License, version 2
> (see [COPYING](COPYING)).
>
> This is a personal test fork, maintained for my own use; no support is
> provided. Please do not report bugs found in this fork to the original author.

## Building this fork for Arm64

Ready-made packages are built by the "Fork ARM64 package" workflow in
GitHub Actions on every push to `vs2026-arm64`.

To build locally (Visual Studio 2026 with the C++ and ARM64 build tools, git):

1. Extract [winuaeinclibs.zip](https://download.abime.net/winuae/files/b/winuaeinclibs.zip)
   into `deps\` (giving `deps\include` and `deps\lib`). Nothing is needed in
   `C:\dev` or `D:\Amiga`: `Directory.Build.props` redirects those paths.
2. Build the Arm64 runtime libraries (PortAudio, CAPSImg, UnRAR, FloppyBridge,
   OpenAL Soft, Lua, ENet) from source, see [deps-build](deps-build/README.md):
   `powershell -ExecutionPolicy Bypass -File deps-build\build-deps.ps1`
3. Build `winuae_arm64.slnf` (FullRelease, ARM64) in Visual Studio, or
   `msbuild winuae_arm64.slnf -p:Configuration=FullRelease -p:Platform=ARM64`.
   The emulator and its DLLs end up in `out\`.

The generated sources are in the repository. To regenerate them, or to build
the CPU tester generator, use `generators.proj` (see the comments in it):
`msbuild generators.proj -p:Platform=ARM64`.

The rest of this file is upstream's README.

# WinUAE

Optional GDB debugging is described in
[the shared debugging guide](README_unix.md#gdb-debugging).

1) Requirements: Windows 7 32-bit/64-bit or newer.

2) Visual Studio 2017 Community with the following feature:
	"Desktop Development with C++" with follow option:
	-"Support Windows XP for C++"
	-"Windows 8.1 SDK UCRT SDK"
	-"Windows 10 SDK 10.0.17763.0"

3) Download and Install the Windows Driver Kit (WDK). 16299 (1709) or newer.
		
	Download Link -> https://docs.microsoft.com/en-us/windows-hardware/drivers/other-wdk-downloads
	
4) Download the zip packages include and lib "winuaeinclibs.zip" and create the directory "c:\dev" and extract all. When finished you have "c:\dev\include" and \"c:\dev\lib" 
	 	 
	Download Link -> https://download.abime.net/winuae/files/b/winuaeinclibs.zip
		
5) Download WinUAE source packages and extract all (anywhere you want).

	Download Link -> https://github.com/tonioni/WinUAE/archive/<version>.zip
	or (preferably) use git client.

6) Download the zip package aros.rom.cpp.zip and extract into WinUAE source directory.

	Download Link -> https://download.abime.net/winuae/files/b/aros.rom.cpp.zip	
				
7) Download and Install Nasm (Assembler Compiler) and put it in PATH

	https://www.nasm.us/

8) In Visual Studio click on "File"->"Open"->"Project/Solution" select the folder <source directory>\od-win32\winuae_msvc15\winuae_msvc.sln (Ignore error message "Unsupported" and click ok)

9) In The solution 'winuae_msvc' you can unload or delete the following projects (and all others not needed in step 12):
	-uaeunp
	-consolewrapper
	-decompess
	-fdrawcmd
	-ipctester
	-resourcedll
	-singlefilehelper
	-wix

10) Change to 32-bit Release mode.

11) Build following projects in following order:
	build68k
	genlinetoscr
	genblitter
	gencpu
	gencomp
	prowizard
	unpackers
		
12) Switch to Test (debug build) or FullRelease (full optimized) and select either 32-bit or 64-bit. Compile.

Finished. In "D:\Amiga\" you find winuae.exe and winuae64.exe
