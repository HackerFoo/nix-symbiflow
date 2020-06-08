{
  pkgs ? import <nixpkgs> {},
  use-prebuilt-symbiflow ? true, # set to false to build symbiflow-arch-defs
  use-vivado ? false             # set to true to install and use Vivado, only works on Linux
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
      cmake
      flex
      pkg-config
    ];
    buildInputs = [
      cairo
      clang-tools
      coreutils
      fontconfig
      gperftools
      gtk3
      harfbuzz
      mount
      pcre
      perl
      python27
      python3
      tbb
      time
      xorg.libX11
      xorg.libXdmcp
      xorg.libXft
      xorg.libpthreadstubs
    ];
    patches = [ ./patches/vtr.patch ];
    src = fetchGit {
      url = "https://github.com/SymbiFlow/vtr-verilog-to-routing.git";
      ref = "master+wip";
      rev = "7d6424bb0bf570844a765feb8472d3e1391a09c5";
    };
    postInstall =
      if stdenv.isDarwin
      then
        ''
          for i in vpr genfasm; do
            install_name_tool -add_rpath ${tbb}/lib $out/bin/$i
          done
        ''
      else
        "";
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

  # custom Python
  python = pkgs.python37.override {
    packageOverrides = import ./python-overlay.nix {
      inherit pkgs;
      pythonPackages = python37Packages;
    };
  };

  # SymbiFlow architecture definitions
  symbiflow-arch-defs = clangStdenv.mkDerivation {
    name = "symbiflow";
    buildInputs = let
      python-with-packages = python.withPackages (p: with p; [
        GitPython
        arpeggio
        cairosvg
        colorclass
        cytoolz
        fasm
        flake8
        hilbertcurve
        intervaltree
        lxml
        matplotlib
        numpy
        pandas
        pdfminer
        pip
        progressbar2
        pycapnp
        pyjson
        pyserial
        pytest
        python-constraint
        python-prjxray
        python-sdf-timing
        python-symbiflow-v2x
        python-utils
        scipy
        setuptools
        simplejson
        six
        sortedcontainers
        svgwrite
        terminaltables
        textx
        tinyfpgab
        tox
        tqdm
        virtualenv
        vtr-xml-utils
        yapf
      ]);
    in
      [
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
        python-with-packages
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
      patch -d third_party/prjxray -p1 < ${ ./patches/prjxray.patch }
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

  vivado_settings = writeScript "settings64.sh"
    (if use-vivado
     then ''
       export XILINX_VIVADO=${vivado}/opt/Vivado/2017.2
       if [ -n "''${PATH}" ]; then
         export PATH=${vivado}/opt/Vivado/2017.2/bin:$PATH
       else
         export PATH=${vivado}/opt/Vivado/2017.2/bin
       fi
    '' else ''
       echo "Vivado not installed"
    '');

  prjxray = stdenv.mkDerivation {
    name = "prjxray";
    srcs = [
      (fetchgit {
        name = "prjxray";
        url = "https://github.com/SymbiFlow/prjxray.git";
        fetchSubmodules = true;
        rev = "46e98b0fca895da2c6b1633ad78d65c74cb5597f";
        sha256 = "0imx71ywwansagp4gq4kziy0xbyjkyc01yr5sq0rl2pvdx0d1spc";
      })
      (fetchgit {
        name = "prjxray-db";
        url = "https://github.com/SymbiFlow/prjxray-db.git";
        rev = "20adf09d395fbd8c3ab90a5bd7e3cdf3e8db33b3";
        sha256 = "1rrlvb0dpd0y24iqqlql6mx54kkw5plnll6smf7i2sh54w67adwp";
      })
    ];
    patches = [ ./patches/prjxray.patch ];
    setSourceRoot = ''
      sourceRoot="prjxray"
    '';
    nativeBuildInputs = [ cmake ];
    buildInputs = let
      python-with-packages = python.withPackages (p: with p; [
        fasm
        intervaltree
        #junit-xml
        numpy
        openpyxl
        ordered-set
        parse
        progressbar2
        pyjson5
        pytest
        python-sdf-timing
        pyyaml
        scipy
        simplejson
        sympy
        textx
        yapf
      ]);
    in
      [
        python-with-packages
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
      python37
      (boost.override { python = python37; enablePython = true; })
      eigen
    ] ++ optional cc.isClang [
      llvmPackages.openmp
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
          python xilinx/python/bbaexport.py --device $device --bba share/$device.bba
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

  mac-lscpu = writeScriptBin "lscpu" ''
        #!${pkgs.stdenv.shell}
        sysctl -a | grep machdep.cpu
  '';

  fpga-tool-perf = stdenv.mkDerivation rec {
    name = "fpga-tool-perf";
    src = fetchgit {
      url = "https://github.com/SymbiFlow/fpga-tool-perf.git";
      fetchSubmodules = true;
      rev = "3374aaad113e0947dfab7f6872a70e454525251b";
      sha256 = "00d328s0a7b58fq5vhsc9ddx9hr4s234kh0d22gf38mm2n1l10k2";
    };
    buildInputs = let
      python-with-packages = python.withPackages (p: with p; [
        asciitable
        colorclass
        edalize
        fasm
        intervaltree
        jinja2
        lxml
        pandas
        pytest
        python-constraint
        python-prjxray
        simplejson
        terminaltables
        textx
        tqdm
        # TODO symbiflow-xc-fasm2bels
      ]);
    in
      [
        getopt
        nextpnr-xilinx
        prjxray
        python-with-packages
        vtr
        yosys
      ] ++ optional stdenv.isDarwin [
        mac-lscpu
      ];
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
