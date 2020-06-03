{ pkgs ? import <nixpkgs> {} }:

with pkgs;
with lib;
with import ./nix-fpgapkgs {};

rec {

  # toolchain
  vtr = stdenv.mkDerivation {
    name = "vtr-symbiflow";
    buildInputs = [
      bison
      flex
      cmake
      tbb
      xorg.libX11
      xorg.libXft
      fontconfig
      cairo
      pkgconfig
      gtk3
      clang-tools
      gperftools
      perl
      python27
      python3
      time
      pcre
      harfbuzz
      xorg.libpthreadstubs
      xorg.libXdmcp
      mount
      coreutils
    ];
    src = fetchGit {
      url = "https://github.com/SymbiFlow/vtr-verilog-to-routing.git";
      ref = "master+wip";
      rev = "7d6424bb0bf570844a765feb8472d3e1391a09c5";
    };
    enableParallelBuilding = true;
  };

  abc-verifier = let
    rev = "623b5e82513d076a19f864c01930ad1838498894";
  in
    pkgs.abc-verifier.overrideAttrs (oldAttrs: rec {
      src = fetchGit {
        url = "https://github.com/berkeley-abc/abc";
        inherit rev;
      };
    }) // {
      inherit rev; # this doesn't update otherwise
    };

  yosys = (pkgs.yosys.override {
    inherit abc-verifier;
  }).overrideAttrs (oldAttrs: rec {
    src = fetchGit {
      url = "https://github.com/SymbiFlow/yosys.git";
      ref = "master+wip";
      #rev = "8fe9c84e6c6a17e88ad623f6964bdde7be8f8481";
    };
    doCheck = false;
  });

  yosys-symbiflow-plugins = stdenv.mkDerivation {
    name = "yosys-symbiflow-plugins";
    src = fetchGit {
      url = "https://github.com/SymbiFlow/yosys-symbiflow-plugins.git";
    };
    phases = "unpackPhase buildPhase installPhase";
    plugins = "xdc fasm";
    buildPhase = ''
      for i in $plugins; do
        make -C ''${i}-plugin ''${i}.so
      done
    '';
    installPhase = ''
      mkdir $out
      for i in $plugins; do
        cp ''${i}-plugin/''${i}.so $out
      done
    '';
    buildInputs = [ yosys bison flex tk libffi readline ];
  };

  # SymbiFlow Python packages
  mkSFPy = attrs@{ name, ... }: python37Packages.buildPythonPackage ({
    src = fetchGit {
      url = "https://github.com/SymbiFlow/${name}.git";
    };
    doCheck = false;
  } // attrs);

  fasm = mkSFPy {
    name = "fasm";
    buildInputs = [ textx ];
  };

  python-sdf-timing = mkSFPy {
    name = "python-sdf-timing";
    propagatedBuildInputs = with python37Packages; [ pyjson ply pytestrunner ];
  };

  vtr-xml-utils = mkSFPy {
    name = "vtr-xml-utils";
    propagatedBuildInputs = with python37Packages; [ lxml pytestrunner ];
  };

  python-symbiflow-v2x = mkSFPy {
    name = "python-symbiflow-v2x";
    propagatedBuildInputs = with python37Packages; [ lxml pytestrunner pyjson vtr-xml-utils ];
  };

  python-prjxray = mkSFPy {
    name = "prjxray";
    propagatedBuildInputs = with pytho37Packages; [ ];
  };

  # third party Python packages
  textx = python37Packages.buildPythonPackage rec {
    pname = "textX";
    version = "1.8.0";
    src = python37Packages.fetchPypi {
      inherit pname version;
      sha256 = "1vhc0774yszy3ql5v7isxr1n3bqh8qz5gb9ahx62b2qn197yi656";
    };
    doCheck = false;
    propagatedBuildInputs = [ python37Packages.arpeggio ];
  };

  hilbertcurve = python37Packages.buildPythonPackage rec {
    pname = "hilbertcurve";
    version = "1.0.1";
    src = python37Packages.fetchPypi {
      inherit pname version;
      sha256 = "b1ddf58f529219d3b76e8b61ed03e2975a724aff4848b720397c7d5601f49521";
    };
    doCheck = false;
  };

  pycapnp = python37Packages.buildPythonPackage rec {
    pname = "pycapnp";
    version = "1.0.0b1";
    src = python37Packages.fetchPypi {
      inherit pname version;
      sha256 = "0sd1ggxbwi28d9by7wg8yp9av4wjh3wy5da6sldyk3m3ry3pwv65";
    };
    doCheck = false;
    propagatedBuildInputs = [ python37Packages.cython capnproto ];
  };

  tinyfpgab = python37Packages.buildPythonPackage rec {
    pname = "tinyfpgab";
    version = "1.1.0";
    src = python37Packages.fetchPypi {
      inherit pname version;
      sha256 = "1dmpcckz7ibkl30v58wc322ggbcw7myyakb4j6fscm6xav23k4bg";
    };
    doCheck = false;
    propagatedBuildInputs = [ python37Packages.pyserial ];
  };

  pyjson = python37Packages.buildPythonPackage rec {
    pname = "pyjson";
    version = "1.3.0";
    src = python37Packages.fetchPypi {
      inherit pname version;
      sha256 = "0a4nkmc9yjpc8rxkqvf3cl3w9hd8pcs6f7di738zpwkafrp36grl";
    };
    doCheck = false;
  };

  python-constraint = python37Packages.buildPythonPackage rec {
    pname = "python-constraint";
    version = "1.4.0";
    src = python37Packages.fetchPypi {
      inherit pname version;
      extension = "tar.bz2";
      sha256 = "13nbgkr1w0v1i59yh01zff9gji1fq6ngih56dvy2s0z0mwbny7ah";
    };
    doCheck = false;
  };

  # custom Python
  python37 = (pkgs.python37.withPackages (p: with p; [
    arpeggio
    cairosvg
    cytoolz
    fasm
    hilbertcurve
    intervaltree
    lxml
    matplotlib
    numpy
    pdfminer
    pip
    progressbar2
    pycapnp
    pyserial
    pytest
    python-constraint
    python-prjxray
    python-sdf-timing
    python-utils
    python-symbiflow-v2x
    scipy
    setuptools
    simplejson
    six
    sortedcontainers
    svgwrite
    textx
    tox
    virtualenv
    vtr-xml-utils
    yapf
    GitPython
  ])).override (args: { ignoreCollisions = true; });

  # SymbiFlow architecture definitions
  symbiflow-arch-defs = clangStdenv.mkDerivation {
    name = "symbiflow";
    buildInputs = [
      cmake
      git
      glib
      icestorm
      libiconv
      libxml2
      libxslt
      ncurses5
      nodejs
      openocd
      perl
      pkg-config
      python37
      python37Packages.flake8
      readline
      sqlite-interactive
      tcl
      tinyfpgab
      tinyprog
      verilog
      vtr
      wget
      xorg.libICE
      xorg.libSM
      xorg.libX11
      xorg.libXext
      xorg.libXrender
      xxd
      yosys
      zlib
    ];
    src = fetchgit {
      url = "https://github.com/SymbiFlow/symbiflow-arch-defs.git";
      branchName = "master";
      fetchSubmodules = true;
      sha256 = "0vn2vl89agvhkbgdqqxigx77v5rhn8i8wqwia3n4gslyhcgx1ybd";
    };
    YOSYS_SYMBIFLOW_PLUGINS = yosys-symbiflow-plugins;
    patches = [
      ./patches/symbiflow-arch-defs.patch
    ];
    postPatchHook = ''
      patchShebangs utils/quiet_cmd.sh
    '';
    configurePhase = ''
      export XRAY_VIVADO_SETTINGS=${vivado_settings}
      mkdir -p build
      pushd build
      cmake -DUSE_CONDA=FALSE -DYOSYS_DATADIR="${yosys}/share/yosys" -DVPR_CAPNP_SCHEMA_DIR="${vtr}/capnp" ..
      popd
    '';
    buildPhase = ''
      export VPR_NUM_WORKERS=$NIX_BUILD_CORES
      make -C build -j $NIX_BUILD_CORES xc7a200t-virt
    '';
    enableParallelBuilding = true;
    installPhase = "mkdir $out && cp -r build/* $out";

    # so genericBuild works from source directory in nix-shell
    shellHook = ''
      export phases="configurePhase buildPhase"
    '';
  };

  vivado_settings = "${vivado}/opt/Vivado/2017.2/.settings64-Vivado.sh";

  prjxray = stdenv.mkDerivation {
    name = "prjxray";
    srcs = [
      (fetchgit {
        url = "https://github.com/SymbiFlow/prjxray.git";
        fetchSubmodules = true;
        sha256 = "0m15i2j2ygakwwjgp3bhwjpc4r2qm2y230vkh3mk58scgvxr6h0a";
      })
      (fetchgit {
        url = "https://github.com/SymbiFlow/prjxray-db.git";
        sha256 = "1rrlvb0dpd0y24iqqlql6mx54kkw5plnll6smf7i2sh54w67adwp";
      })
    ];
    setSourceRoot = ''
      sourceRoot="prjxray"
    '';
    nativeBuildInputs = [ cmake ];
    propagatedBuildInputs = [
      python37
      vivado
    ];
    preConfigureHook = "export XRAY_VIVADO_SETTINGS=${vivado_settings}";
    configurePhase = ''
      mkdir -p build $out
      pushd build
      cmake .. -DCMAKE_INSTALL_PREFIX=$out
      popd
    '';
    enableParallelBuilding = true;
    buildPhase = "make -C build -j $NIX_BUILD_CORES";
    installPhase = ''
      make -C build install
      mkdir -p $out/build
      ln -s $out/bin $out/build/tools
      cp -r utils $out/utils
      cp -r ../prjxray-db $out/database
    '';

    # so genericBuild works from source directory in nix-shell
    shellHook = ''
      export phases="configurePhase buildPhase"
    '';
  };

  nextpnr-xilinx = stdenv.mkDerivation {
    name = "nextpnr-xilinx";
    src = fetchgit {
      url = "https://github.com/daveshah1/nextpnr-xilinx.git";
      fetchSubmodules = true;
      sha256 = "0pacjhz8rxrra6g7636fkmk2zkbvq7p9058hj4q90gc22dk9x2ji";
    };
    nativeBuildInputs = [ cmake ];
    buildInputs = [
      pkgs.yosys
      prjxray
      pypy3
      (boost.override { python = python3; enablePython = true; })
      python37
      eigen
    ];
    enableParallelBuilding = true;
    configurePhase = ''
      export XRAY_DIR=${prjxray}
      cmake -DARCH=xilinx -DBUILD_GUI=OFF .
    '';
    buildPhase = ''
      make -j $NIX_BUILD_CORES
      pypy3 xilinx/python/bbaexport.py --device xc7a35tcsg324-1 --bba xilinx/xc7a35t.bba
      ./bbasm xilinx/xc7a35t.bba xilinx/xc7a35t.bin -l
    '';
    shellHook = ''
      export XRAY_DIR=${prjxray}
      export phases="configurePhase buildPhase"
    '';
  };
}
