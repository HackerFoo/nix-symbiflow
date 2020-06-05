{
  pkgs ? import <nixpkgs> {},
  use-prebuilt-symbiflow ? true
}:

with pkgs;
with lib;

rec {

  inherit (import ./nix-fpgapkgs {}) vivado;

  # toolchain
  vtr = stdenv.mkDerivation {
    name = "vtr-symbiflow";
    nativeBuildInputs = [
      bison
      flex
      cmake
      pkg-config
    ];
    buildInputs = [
      tbb
      xorg.libX11
      xorg.libXft
      fontconfig
      cairo
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

  pythonPackages = pkgs: with pkgs; rec {
    # SymbiFlow Python packages
    mkSFPy = attrs@{ name, ref ? "master", user ? "SymbiFlow", ... }: buildPythonPackage ({
      src = fetchGit {
        url = "https://github.com/${user}/${name}.git";
        inherit ref;
      };
      doCheck = false;
    } // attrs);

    fasm = mkSFPy {
      name = "fasm";
      buildInputs = [ textx ];
    };

    python-sdf-timing = mkSFPy {
      name = "python-sdf-timing";
      propagatedBuildInputs = [ pyjson ply pytestrunner ];
    };

    vtr-xml-utils = mkSFPy {
      name = "vtr-xml-utils";
      propagatedBuildInputs = [ lxml pytestrunner ];
    };

    python-symbiflow-v2x = mkSFPy {
      name = "python-symbiflow-v2x";
      propagatedBuildInputs = [ lxml pytestrunner pyjson vtr-xml-utils ];
    };

    python-prjxray = mkSFPy {
      name = "prjxray";
    };

    edalize = mkSFPy {
      name = "edalize";
      ref = "symbiflow";
      patches = [ ./patches/edalize.patch ];
      propagatedBuildInputs = [ pytest jinja2 ];
    };

    # symbiflow-xc-fasm2bels = mkSFPy {
    #   name = "symbiflow-xc-fasm2bels";
    #   user = "antmicro";
    #   ref = "add-fasm2bels";
    #   nativeBuildInputs = [ git python-prjxray ];
    # };

    # third party Python packages
    textx = buildPythonPackage rec {
      pname = "textX";
      version = "1.8.0";
      src = fetchPypi {
        inherit pname version;
        sha256 = "1vhc0774yszy3ql5v7isxr1n3bqh8qz5gb9ahx62b2qn197yi656";
      };
      doCheck = false;
      propagatedBuildInputs = [ arpeggio ];
    };

    hilbertcurve = buildPythonPackage rec {
      pname = "hilbertcurve";
      version = "1.0.1";
      src = fetchPypi {
        inherit pname version;
        sha256 = "b1ddf58f529219d3b76e8b61ed03e2975a724aff4848b720397c7d5601f49521";
      };
      doCheck = false;
    };

    pycapnp = buildPythonPackage rec {
      pname = "pycapnp";
      version = "1.0.0b1";
      src = fetchPypi {
        inherit pname version;
        sha256 = "0sd1ggxbwi28d9by7wg8yp9av4wjh3wy5da6sldyk3m3ry3pwv65";
      };
      doCheck = false;
      propagatedBuildInputs = [ cython capnproto ];
    };

    tinyfpgab = buildPythonPackage rec {
      pname = "tinyfpgab";
      version = "1.1.0";
      src = fetchPypi {
        inherit pname version;
        sha256 = "1dmpcckz7ibkl30v58wc322ggbcw7myyakb4j6fscm6xav23k4bg";
      };
      doCheck = false;
      propagatedBuildInputs = [ pyserial ];
    };

    pyjson = buildPythonPackage rec {
      pname = "pyjson";
      version = "1.3.0";
      src = fetchPypi {
        inherit pname version;
        sha256 = "0a4nkmc9yjpc8rxkqvf3cl3w9hd8pcs6f7di738zpwkafrp36grl";
      };
      doCheck = false;
    };

    python-constraint = buildPythonPackage rec {
      pname = "python-constraint";
      version = "1.4.0";
      src = fetchPypi {
        inherit pname version;
        extension = "tar.bz2";
        sha256 = "13nbgkr1w0v1i59yh01zff9gji1fq6ngih56dvy2s0z0mwbny7ah";
      };
      doCheck = false;
    };

    asciitable = buildPythonPackage rec {
      pname = "asciitable";
      version = "0.8.0";
      src = fetchPypi {
        inherit pname version;
        sha256 = "04mnd8zyphsdk5il6khsx38yxm0c1g10hkz5jbxg70i15hzgcbyw";
      };
      doCheck = false;
    };

    jinja2 = buildPythonPackage rec {
      pname = "Jinja2";
      version = "2.11.2";
      src = fetchPypi {
        inherit pname version;
        sha256 = "1c1v3djnr0ymp5xpy1h3h60abcaqxdlm4wsqmls9rxby88av5al9";
      };
      doCheck = false;
      propagatedBuildInputs = [ markupsafe ];
    };
  };

  # custom Python
  python37 = (pkgs.python37.withPackages (p: with p; (attrValues (pythonPackages p)) ++ [
    arpeggio
    cairosvg
    cytoolz
    fasm
    flake8
    intervaltree
    lxml
    matplotlib
    numpy
    pdfminer
    pip
    progressbar2
    pyserial
    pytest
    python-utils
    scipy
    setuptools
    simplejson
    six
    sortedcontainers
    svgwrite
    tox
    virtualenv
    yapf
    GitPython
    terminaltables
    tqdm
    colorclass
    pandas
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
      readline
      sqlite-interactive
      tcl
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
    postPatch = ''
      patchShebangs utils/quiet_cmd.sh
    '';
    configurePhase = ''
      export XRAY_VIVADO_SETTINGS=${vivado_settings}
      mkdir -p build
      pushd build
      cmake -DUSE_CONDA=FALSE -DCMAKE_INSTALL_PREFIX=$out -DYOSYS_DATADIR="${yosys}/share/yosys" -DVPR_CAPNP_SCHEMA_DIR="${vtr}/capnp" ..
      popd
    '';
    buildPhase = ''
      export VPR_NUM_WORKERS=$NIX_BUILD_CORES
      make -C build -j $NIX_BUILD_CORES all
    '';
    enableParallelBuilding = true;
    installPhase = "make -C build -j $NIX_BUILD_CORES install";

    # so genericBuild works from source directory in nix-shell
    shellHook = ''
      export phases="configurePhase buildPhase"
    '';
  };

  vivado_settings = writeScript "settings64.sh" ''
    export XILINX_VIVADO=${vivado}/opt/Vivado/2017.2
    if [ -n "''${PATH}" ]; then
      export PATH=${vivado}/opt/Vivado/2017.2/bin:$PATH
    else
      export PATH=${vivado}/opt/Vivado/2017.2/bin
    fi
  '';

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
    preConfigure = "export XRAY_VIVADO_SETTINGS=${vivado_settings}";
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
    DEVICES = [
      "xc7a35tcsg324-1"
      "xc7a35tcpg236-1"
      "xc7z010clg400-1"
      "xc7z020clg484-1"
    ];

    configurePhase = ''
      export XRAY_DIR=${prjxray}
      cmake -DARCH=xilinx -DBUILD_GUI=OFF -DCMAKE_INSTALL_PREFIX=$out .
    '';
    postBuild = ''
      # Compute data files for nextpnr-xilinx
      mkdir -p share
      for device in $DEVICES; do
          echo "Exporting arch for $device"
          pypy3 xilinx/python/bbaexport.py --device $device --bba share/$device.bba
          ./bbasm share/$device.bba share/$device.bin -l
      done
    '';
    postInstall = ''
      mkdir -p $out/share
      cp -r share $out/share/nextpnr-xilinx
    '';
    shellHook = ''
      export XRAY_DIR=${prjxray}
      export phases="configurePhase buildPhase"
    '';
  };

  symbiflow-arch-defs-install = if use-prebuilt-symbiflow then symbiflow-arch-defs-download else symbiflow-arch-defs;
  symbiflow-arch-defs-download = stdenv.mkDerivation {
    name = "symbiflow-arch-defs-install";
    src = fetchTarball {
      url = "https://storage.googleapis.com/symbiflow-arch-defs/artifacts/prod/foss-fpga-tools/symbiflow-arch-defs/presubmit/install/206/20200526-034850/symbiflow-arch-defs-install-97519a47.tar.xz";
      sha256 = "0jvb556k2q92sym94y696b5hcr84ab6mfdn52qb1v5spk7fd77db";
    };
    phases = [ "unpackPhase" "patchPhase" "installPhase" ];
    patchPhase = ''
      sed -i -E -e "s|^plugin -i +([a-zA-Z0-9]+)|plugin -i $::env(YOSYS_SYMBIFLOW_PLUGINS)/\1.so|" share/symbiflow/scripts/xc7/synth.tcl
    '';
    installPhase = ''
      mkdir $out
      cp -r * $out/
    '';
  };

  fpga-tool-perf = stdenv.mkDerivation rec {
    name = "fpga-tool-perf";
    src = fetchgit {
      url = "https://github.com/SymbiFlow/fpga-tool-perf.git";
      fetchSubmodules = true;
      sha256 = "0hssyzym3rfsnj5m4anr5qg3spk8n904l68c1xplng38n6wpi59h";
    };
    nativeBuildInputs = [ python37 vtr nextpnr-xilinx yosys getopt prjxray ];
    YOSYS_SYMBIFLOW_PLUGINS = yosys-symbiflow-plugins;
    env_script = ''
        mkdir -p env/conda/{bin,pkgs}
        touch env/conda/bin/activate
        source env.sh
        rm -f env/conda/pkgs/nextpnr-xilinx
        ln -s ${nextpnr-xilinx} env/conda/pkgs/nextpnr-xilinx
    '';
    shellHook = ''
      export YOSYS_SYMBIFLOW_PLUGINS
      export PYTHONPATH=${prjxray}
      export VIVADO_SETTINGS=${vivado_settings}
      export XRAY_DATABASE_DIR=${prjxray}/database
      export XRAY_FASM2FRAMES="${prjxray}/utils/fasm2frames.py"
      export XRAY_TOOLS_DIR="${prjxray}/bin"
      export SYMBIFLOW="${symbiflow-arch-defs-install}"

      if [ "''${PWD##*/}" == "fpga-tool-perf" ]; then
        read -p "Run env script (y/N) " RESPONSE
        RESPONSE=''${RESPONSE,,} # tolower
        if [[ "''${RESPONSE}" =~ ^(yes|y)$ ]]; then
          ${env_script}
        fi
      fi
    '';
  };
}
