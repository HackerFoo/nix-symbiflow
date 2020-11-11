{ stdenv, requireFile, patchelf, procps, makeWrapper,
  ncurses, zlib, libX11, libXrender, libxcb, libXext, libXtst,
  libXi, glib, freetype, gtk2, bbe }:

stdenv.mkDerivation rec {
  name = "vivado-2017.2";

  buildInputs = [ patchelf procps ncurses makeWrapper bbe ];
  
  builder = ./builder.sh;
  inherit ncurses;

  src = requireFile {
    name = "Xilinx_Vivado_SDK_2017.2_0616_1.tar.gz";
    url = "https://www.xilinx.com/products/design-tools/vivado.html";
    sha256 = "06pb4wjz76wlwhhzky9vkyi4aq6775k63c2kw3j9prqdipxqzf9j";
  };

  libPath = stdenv.lib.makeLibraryPath
    [ stdenv.cc.cc ncurses zlib libX11 libXrender libxcb libXext libXtst libXi glib
      freetype gtk2 ];
  
  meta = {
    description = "Xilinx Vivado";
    homepage = "https://www.xilinx.com/products/design-tools/vivado.html";
    license = stdenv.lib.licenses.unfree;
  };
}
