# ARM64 runtime dependencies

Upstream WinUAE ships its third-party DLLs (sound backends, disk image
plugins, ...) as prebuilt x86/x64 binaries, which a native ARM64 process
cannot load. `build-deps.ps1` builds ARM64 versions from source.

```powershell
powershell -ExecutionPolicy Bypass -File deps-build\build-deps.ps1
powershell -ExecutionPolicy Bypass -File deps-build\build-deps.ps1 -Only capsimg
```

Requirements: Visual Studio 2026 with the ARM64 C++ build tools, and git.

| Folder | Content | In git |
|---|---|---|
| `deps\src\<name>\` | third-party source, fetched at a pinned commit | no |
| `deps\build\<name>\` | intermediate build files | no |
| `deps\bin\arm64\` | runtime DLLs loaded from the executable folder | no |
| `deps\bin\arm64\plugins\` | plugin DLLs | no |
| `deps-build\` | this script and the build shims | yes |

After every ARM64 build of winuae, `Directory.Build.Paths.targets` copies
`deps\bin\arm64\` into `out\`.

## Components

| Name | Output | Source (pinned) | Licence |
|---|---|---|---|
| `portaudio` | `portaudio_arm64.dll` | [PortAudio](https://github.com/PortAudio/portaudio) v19.7.0 | MIT-style |
| `capsimg` | `plugins\CAPSImg_arm64.dll` | [FrodeSolheim/capsimg](https://github.com/FrodeSolheim/capsimg) `229374e` (SPS 5.1 source) | SPS licence, non-commercial |
| `unrar` | `plugins\unrar_arm64.dll` | [UnRAR](https://www.rarlab.com/rar_add.htm) 7.3.1 source | UnRAR freeware licence |
| `lua` | `deps\lib\arm64\luastatic.lib` | [Lua](https://www.lua.org/) 5.2.4 | MIT |
| `enet` | `deps\lib\arm64\enet.lib` | [ENet](http://enet.bespin.org/) 1.2 | MIT |
| `openal` | `OpenAL32.dll`, `deps\lib\arm64\OpenAL32.lib` | [OpenAL Soft](https://github.com/kcat/openal-soft) 1.25.2 | LGPL 2.1 |
| `floppybridge` | `plugins\FloppyBridge_arm64.dll` | [FloppyDriveBridge](https://github.com/RobSmithDev/FloppyDriveBridge) `710fa15` (1.6.0.4) | MPL 2.0 / GPL 2 or later |

Archives are checked against a pinned SHA-256, git sources against a pinned
commit. All DLLs use the static C runtime, so no Visual C++ redistributable
is needed.

The static libraries (`lua`, `enet`, `openal`) are optional:
`Directory.Build.Paths.targets` links each one only when it exists in
`deps\lib\arm64\` and then defines `ARM64_WITH_LUA` / `ARM64_WITH_ENET` /
`ARM64_WITH_OPENAL`, which keep `od-win32\sysconfig.h` from disabling Lua
scripting, the serial port over UDP and OpenAL sound on ARM64. Without them
the ARM64 build behaves like upstream's.

Notes:

- **portaudio**: WinUAE imports PortAudio by ordinal; the CMake `.def`
  template keeps the ordinals of the import library in `deps\lib\arm64`.
  Built without ASIO, whose SDK is not freely licensed.
- **capsimg**: the SPS 5.1 source was already ported to Unix and does not
  build with MSVC as is. It is compiled unchanged, with the files in
  `deps-build\capsimg\` (MIT licensed, so they can be combined with the SPS
  licence): `unistd.h`, `dirent.h` and `config.h` stand-ins, a `DllMain`
  that initialises the library on load like the original Windows DLL, and
  the export list. If you redistribute the resulting DLL, the SPS licence
  requires the complete source, including these files.
- **unrar**, **floppybridge**: their Visual Studio projects have no ARM64
  configuration; the script compiles the projects' sources with the same
  settings.
- **lua**: `deps\include` carries the unmodified Lua 5.2.2 headers; 5.2.4 is
  the last 5.2 bug-fix release. WinUAE includes them without `extern "C"` on
  Windows, so Lua is compiled as C++, like upstream's `luastatic.lib`.
- **enet**: `deps\include\enet` matches ENet 1.2 (apart from an added
  `__cdecl`), so the protocol stays compatible with the x86/x64 builds.
  Only an http download exists; the archive is pinned by SHA-256.
- **floppybridge**: the ARM64 build of `floppybridge\floppybridge_lib.cpp`
  loads `FloppyBridge_arm64.dll` (upstream would look for
  `FloppyBridge_x64.dll` in any 64-bit build).

The build scripts in this folder are under the GNU GPL version 2, like the
rest of the fork; the shims in `capsimg\` are under the MIT licence stated in
each file.
