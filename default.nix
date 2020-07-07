{
  sources ? import ./nix/sources.nix,
  pkgs ? import sources.nixpkgs {},
  use-prebuilt-symbiflow ? false, # set to true to use prebuilt symbiflow-arch-defs
  use-vivado ? true               # set to true to install and use Vivado, only works on Linux
}:

with builtins;
with pkgs;
with lib;

rec {

  inherit (import ./nix-fpgapkgs { inherit pkgs; }) vivado migen;

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
    src = sources.vtr;
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

  abc-verifier = attrs@{ rev, ... }:
    pkgs.abc-verifier.overrideAttrs (oldAttrs: rec {
      src = fetchGit ({
        url = "https://github.com/berkeley-abc/abc";
      } // attrs);
    }) // {
      inherit rev; # this doesn't update otherwise
    };

  yosys-symbiflow = yosys-with-symbiflow-plugins {
    yosys = (pkgs.yosys.override {
      abc-verifier = abc-verifier {
        rev = "623b5e82513d076a19f864c01930ad1838498894";
      };
    }).overrideAttrs (oldAttrs: rec {
      src = sources.yosys-symbiflow;
      doCheck = false;
    });
  };

  yosys-git = (pkgs.yosys.override {
    abc-verifier = abc-verifier {
      url = "https://github.com/YosysHQ/abc.git";
      ref = "yosys-experimental";
      rev = "341db25668f3054c87aa3372c794e180f629af5d";
    };
  }).overrideAttrs (oldAttrs: rec {
    src = fetchGit {
      url = "https://github.com/YosysHQ/yosys.git";
      rev = "0835a86e30fc2a934f5e6c96b28c90b59654ed92";
    };
    doCheck = false;
  });

  yosys-with-symbiflow-plugins = { yosys }: stdenv.mkDerivation {
    inherit (yosys) name; # HACK keep path the same size to allow bbe replacement
    src = sources.yosys-symbiflow-plugins;
    phases = "unpackPhase buildPhase installPhase";
    plugins = "xdc fasm";
    buildPhase = ''
      for i in $plugins; do
        make -C ''${i}-plugin ''${i}.so
      done
    '';
    installPhase = ''
      mkdir -p $out/bin $out/share/yosys/plugins
      cp -rs ${yosys}/share $out/
      cp -s ${yosys}/bin/{yosys-filterlib,yosys-smtbmc} $out/bin/
      sed "s|${yosys}|''${out}|g" ${yosys}/bin/yosys-config > $out/bin/yosys-config
      ${bbe}/bin/bbe -e "s|${yosys}|''${out}|g" ${yosys}/bin/yosys > $out/bin/yosys
      chmod +x $out/bin/{yosys,yosys-config}
      for i in $plugins; do
        make -C ''${i}-plugin install PLUGINS_DIR=$out/share/yosys/plugins
      done
    '';
    buildInputs = [ yosys bison flex tk libffi readline ];
  };

  # custom Python
  python = pkgs.python37.override {
    packageOverrides = import ./python-overlay.nix {
      inherit pkgs prjxray migen;
      pythonPackages = python37Packages;
    };
  };

  # SymbiFlow architecture definitions
  symbiflow-arch-defs = clangStdenv.mkDerivation rec {
    name = "symbiflow";
    yosys = yosys-symbiflow;
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
      fetchSubmodules = true;
      rev = "5b56d66daa1a79e8b948f3ef0f0c0ec0697dba13";
      sha256 = "11p26rrnqsljxd0g1dnskv0n8m206r6rfn17fp0kl9p3j2ha85nd";
    };
    postPatch = ''
      patchShebangs utils
      patchShebangs third_party/prjxray/utils
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
      export XRAY_VIVADO_SETTINGS=${vivado_settings}
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

  inherit (sources) prjxray-db;

  prjxray = stdenv.mkDerivation {
    name = "prjxray";
    src = fetchgit {
      url = "https://github.com/SymbiFlow/prjxray.git";
      fetchSubmodules = true;
      rev = "35ead5e40f6a9fdc4d338e4471d8de2bd47ef787";
      sha256 = "05h2pw0nkq9zhsaw2zblma2im8ywd5nvcwn8wjdl4jpva1av0yyj";
    };
    patches = [ ./patches/prjxray.patch ];
    postPatch = ''
      patchShebangs utils
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
    buildPhase = ''
      make -C build -j $NIX_BUILD_CORES ''${TARGET:-all}
    '';
    installPhase = ''
      make -C build install
      mkdir -p $out/build
      ln -s $out/bin $out/build/tools
      cp -r utils $out/utils
      ln -s ${prjxray-db} $out/database
    '';

    # so genericBuild works from source directory in nix-shell
    shellHook = ''
      export phases="patchPhase configurePhase buildPhase"
    '';
  };

  nextpnr-xilinx = stdenv.mkDerivation {
    name = "nextpnr-xilinx";
    src = fetchgit {
      url = "https://github.com/daveshah1/nextpnr-xilinx.git";
      fetchSubmodules = true;
      rev = "7e46c6a3703d029c9776d57b64e4ba94f7bc8264";
      sha256 = "0pacjhz8rxrra6g7636fkmk2zkbvq7p9058hj4q90gc22dk9x2ji";
    };
    nativeBuildInputs = [ cmake ];
    buildInputs = [
      yosys-git
      prjxray
      python37
      (boost.override { python = python37; enablePython = true; })
      eigen
    ] ++ optional stdenv.cc.isClang [
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
    phases = [ "unpackPhase" "installPhase" ];
    installPhase = ''
      mkdir $out
      cp -r * $out/
      patchShebangs $out/bin
    '';
  };

  mac-lscpu = writeScriptBin "lscpu" ''
        #!${pkgs.stdenv.shell}
        sysctl -a | grep machdep.cpu
  '';

  no-lscpu = writeScriptBin "lscpu" ''
        #!${pkgs.stdenv.shell}
        echo "lscpu not available"
  '';

  fpga-tool-perf = let
    src = fetchgit {
      url = "https://github.com/HackerFoo/fpga-tool-perf.git";
      branchName = "nextpnr-vexriscv";
      fetchSubmodules = true;
      rev = "978d76d47a29013e49a295badd9ccb5b296bdf67";
      sha256 = "1k1dy580d1iqvd2r02r022c5l85l3m4qp47q6yq7hx7g8gr315wl";
    };
    mkTest = { projectName, toolchain, board }: stdenv.mkDerivation rec {
      name = "fpga-tool-perf-${projectName}-${toolchain}-${board}";
      inherit src;
      yosys = if hasPrefix "vpr" toolchain then yosys-symbiflow else yosys-git; # https://github.com/SymbiFlow/yosys/issues/79
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
        yapf
        symbiflow-xc-fasm2bels
      ]);
      buildInputs = [
        getopt
        nextpnr
        icestorm
        nextpnr-xilinx
        prjxray
        python-with-packages
        symbiflow-arch-defs-install
        vtr
        yosys
      ] ++ optional stdenv.isLinux [
        no-lscpu
      ] ++ optional stdenv.isDarwin [
        mac-lscpu
      ];
      buildPhase = ''
        export PYTHONPATH=${prjxray}
        export VIVADO_SETTINGS=${vivado_settings}
        export XRAY_DATABASE_DIR=${prjxray-db}
        export XRAY_FASM2FRAMES="-m prjxray.fasm2frames"
        export XRAY_TOOLS_DIR="${prjxray}/bin"
        export SYMBIFLOW="${symbiflow-arch-defs-install}"
        mkdir -p env/conda/pkgs
        rm -f env/conda/pkgs/nextpnr-xilinx
        ln -s ${nextpnr-xilinx} env/conda/pkgs/nextpnr-xilinx
        source $VIVADO_SETTINGS
        python3 fpgaperf.py --project ${projectName} --toolchain ${toolchain} --board ${board} --out-dir $out --verbose
      '';
      installPhase = ''
        mkdir -p $out/nix-support
        echo "file json $out/meta.json" > $out/nix-support/hydra-build-products
        find $out \
            -type f \
          ! -name meta.json \
          ! -name hydra-build-products \
            -printf "file data %p\n" >> $out/nix-support/hydra-build-products
      '';
    };
    projectNames = map (n: head (match "([^.]*).json" n)) (attrNames (readDir (src + "/project/")));
  in
    listToAttrs (map (projectName:
      let
        projectInfo = fromJSON (readFile (src + "/project/${projectName}.json"));
      in
        {
          name = projectName;
          value = mapAttrs (toolchain: boards:
            mapAttrs (board: dont-care: {
              name = board;
              value = mkTest { inherit projectName toolchain board; };
            }) boards)
            projectInfo.toolchains;
        }) projectNames);

  symbiflow-examples = stdenv.mkDerivation rec {
    name = "symbiflow-examples";
    src = sources.symbiflow-examples;
    yosys = yosys-symbiflow;
    python-with-packages = python.withPackages (p: with p; [
      lxml
      simplejson
      intervaltree
      python-constraint
      python-prjxray
      fasm
      textx
    ]);
   buildInputs =  [
      symbiflow-arch-defs-install
      yosys
      vtr
      python-with-packages
      prjxray
    ];
    shellHook = ''
      export XRAY_DATABASE_DIR=${prjxray-db}
      export XRAY_FASM2FRAMES="-m prjxray.fasm2frames"
      export XRAY_TOOLS_DIR="${prjxray}/bin"
      #export SYMBIFLOW="${symbiflow-arch-defs-install}"
    '';
  };

  litex-buildenv = let
    riscvPkgs = bits: import <nixpkgs> {
      crossSystem = {
        config = "riscv${bits}-none-elf";
        libc = "newlib";
        platform = systems.platforms.riscv-multiplatform "${bits}";
      };
    };
    with-litex-buildenv = attrs@{ name, platform, cpu, target, bits }:
      (riscvPkgs bits).stdenv.mkDerivation rec {
        name = "litex-buildenv-${attrs.name}";
        src = fetchgit {
          url = "https://github.com/timvideos/litex-buildenv.git";
          rev = "bbe77980b3006f0c656dab3b9fa886eb0c86f59b";
          sha256 = "0c8js5mvj2fdpfqcwz5w90yn091223an09573jxd2x9r08krsi4y";
          leaveDotGit = true;
          deepClone = true;
        };
        python-with-packages = python.withPackages (p:
          with p.litexPackages;
          [
            litex
            liteeth
            litedram
            litepcie
            litevideo
            liteiclink
            litesdcard
            litex-boards
            pythondata-cpu-vexriscv
            pythondata-cpu-rocket
          ]);
        nativeBuildInputs = [
          python-with-packages
          verilator
          dtc
          git
          vivado
        ];
        patches = [ ./patches/litex-buildenv.patch ];
        buildPhase = ''
          export PLATFORM=${platform}
          export CPU=${cpu}
          export TARGET=${target}
          python make.py --platform=${platform} --cpu-type=${cpu} --cpu-variant=linux --target=${target}
        '';
        installPhase = ''
          cp -r build $out
        '';
      };
    configs = mapAttrs (name: attrs: with-litex-buildenv (attrs // { inherit name; }));
  in
    configs {
      vexriscv = {
        platform = "arty";
        cpu = "vexriscv";
        target = "base";
        bits = "64";
      };
      rocket = {
        platform = "arty";
        cpu = "rocket";
        target = "base";
        bits = "64";
      };
    };

  with-yosys-git = mkShell {
    buildInputs = [ yosys-git ];
  };
}

# Local Variables:
# eval: (add-to-list 'imenu-generic-expression '("Package" "^  \\([a-zA-Z0-9_-]+\\) =.*$" 1))
# End:
