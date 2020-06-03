{ stdenv, requireFile, patchelf, procps, makeWrapper,
  ncurses, zlib, libX11, libXrender, libxcb, libXext, libXtst,
  libXi, glib, freetype, gtk2 }:

stdenv.mkDerivation rec {
  name = "vivado-2019.2";

  buildInputs = [ patchelf procps ncurses makeWrapper ];

  builder = ./builder.sh;
  inherit ncurses;

  src = requireFile {
    name = "Xilinx_Vivado_2019.2_1106_2127.tar.gz";
    url = "https://www.xilinx.com/support/download.html";
    sha256 = "b06781cfb2945ba948f04a359e86d6666c642be776562767c59f7515ca9a0e96";
  };

  libPath = stdenv.lib.makeLibraryPath
    [ stdenv.cc.cc ncurses zlib libX11 libXrender libxcb libXext libXtst libXi glib
      freetype gtk2 ];

  meta = {
    description = "Xilinx Vivado";
    homepage = "https://www.xilinx.com/support/download.html";
    license = stdenv.lib.licenses.unfree;
  };
}
