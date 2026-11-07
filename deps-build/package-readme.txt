WinUAE Arm64 package (unofficial fork build)
============================================

This is an unofficial, personal build of WinUAE by Toni Wilen for Windows 11
on Arm64, made from the fork at https://github.com/Biangulum/WinUAE.
No support is provided. Please do not report problems with it to the
WinUAE author.

WinUAE is licensed under the GNU General Public License, version 2
(COPYING.txt). The complete source code of this build is the fork at the
commit named at the end of this file. Its deps-build\build-deps.ps1 fetches
the pinned sources of the third-party libraries below and builds them.

Third-party components (licence texts in licenses\):

  portaudio_arm64.dll             PortAudio 19.7.0          MIT-style
  OpenAL32.dll                    OpenAL Soft 1.25.2        LGPL 2.1
  plugins\CAPSImg_arm64.dll       SPS decoder library 5.1   SPS licence,
                                  (CAPSImg)                 non-commercial use only
  plugins\unrar_arm64.dll         UnRAR 7.3.1               UnRAR freeware licence
  plugins\FloppyBridge_arm64.dll  FloppyBridge 1.6.0.5      MPL 2.0 / GPL 2 or later
  linked into winuaearm64.exe     Lua 5.2.4, ENet 1.2       MIT

The other libraries linked into winuaearm64.exe come from upstream's
winuaeinclibs.zip, as in the official WinUAE builds.

