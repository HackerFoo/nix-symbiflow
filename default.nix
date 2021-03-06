{
  sources ? import ./nix/sources.nix,
  use-vivado ? true,              # set to true to install and use Vivado, only works on Linux
  pkgs ? import sources.nixpkgs (
    if use-vivado
    then { config.allowUnfree = true; }
    else { }
  )
}:

with builtins;
with pkgs;
with lib;
with callPackage ./library.nix {};

rec {

  inherit pkgs;

  # to force fetching all source
  project_list = attrNames (fromJSON (readFile ./nix/sources.json));
  all_source = linkFarm "all_source" (map (name: { inherit name; path = getAttr name sources; }) project_list);

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
    buildInputs = let
      python-with-packages = python.withPackages (p: with p; [
        prettytable
        python-constraint
        lxml
      ]);
    in [
      cairo
      clang-tools
      coreutils
      fontconfig
      gperftools
      gtk3
      harfbuzz
      libxml2
      mount
      pcre
      perl
      python-with-packages
      tbb
      time
      getopt
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

  vtr-verilog-to-routing = vtr;
  vtr-verilog-to-routing-optimized = vtr-optimized;

  vtr-optimized = vtr.overrideAttrs (attrs: {
    src = sources.vtr-run;
    buildInputs = attrs.buildInputs ++ [
      symbiflow-arch-defs-install
    ];
    dontConfigure = true;
    buildPhase = ''
      set -e
      BUILD_ROOT=$PWD
      PGO_TARGETS="vpr genfasm" # Executables needed for PGO
      export SYMBIFLOW=${symbiflow-arch-defs-install}
      mkdir build
      pushd build

      # ODIN and ABC are disabled to minimize build time.
      COMMON_CMAKE_FLAGS="\
          -DCMAKE_BUILD_TYPE=Release \
          -DWITH_ODIN=OFF \
          -DWITH_ABC=OFF"

      cmake ''${COMMON_CMAKE_FLAGS} \
          -DVPR_PGO_CONFIG=prof_gen \
          -DVPR_PGO_DATA_DIR=''${BUILD_ROOT}/pgo \
          ..

      make -k -j$NIX_BUILD_CORES $PGO_TARGETS || make VERBOSE=1
      popd

      mkdir -p symbiflow
      source ${./run-sf.sh}

      pushd build
      make clean
      cmake ''${COMMON_CMAKE_FLAGS} \
          -DCMAKE_INSTALL_PREFIX=$out \
          -DVPR_PGO_CONFIG=prof_use \
          -DVPR_PGO_DATA_DIR=''${BUILD_ROOT}/pgo \
          ..
      grep -i flags CMakeCache.txt
      make -k -j$NIX_BUILD_CORES || make VERBOSE=1
    '';
  });

  vtr-run = vtr.overrideAttrs (attrs: {
    src = sources.vtr-run;
  });

  replace_constants = subst:
    concatMapStrings (name:
      let
        m = getAttr name subst;
      in
        "bash ${./scripts/replace-consts.sh} ${name} ${concatMapStrings (key: " ${key}=${toString (getAttr key m)}") (attrNames m)}\n")
      (attrNames subst);

  vtr-custom = subst: vtr.overrideAttrs (attrs: rec {
    src = sources.vtr-run;
    # patches = [ ./patches/vpr_kscale.patch ];
    # cmakeFlags = "-DVTR_ASSERT_LEVEL=3";
    postPatch = ''
      touch constants.patch
      ${replace_constants subst}
      mkdir -p $out
      cp constants.patch $out
    '';
  });

  abc-verifier = src: attrs:
    (pkgs.abc-verifier.override attrs).overrideAttrs (oldAttrs: {
      inherit src;
    }) // {
      inherit (src) rev; # this doesn't update otherwise
    };

  yosys-symbiflow = let
    abc = abc-verifier sources.abc-yosys {};
  in yosys-with-symbiflow-plugins {
    bin = "yosys-filterlib,yosys-smtbmc,yosys-abc";
    yosys = (pkgs.yosys.override {
      abc-verifier = abc;
    }).overrideAttrs (oldAttrs: rec {
      src = sources.yosys;
      doCheck = false;
      patchPhase = ''
        substituteInPlace ./Makefile \
          --replace 'CXX = clang' "" \
          --replace 'LD = clang++' 'LD = $(CXX)' \
          --replace 'CXX = gcc' "" \
          --replace 'LD = gcc' 'LD = $(CXX)' \
          --replace 'ABCMKARGS = CC="$(CXX)" CXX="$(CXX)"' 'ABCMKARGS =' \
          --replace 'echo UNKNOWN' 'echo ${builtins.substring 0 10 src.rev}'
        substituteInPlace ./misc/yosys-config.in \
          --replace '/bin/bash' '${bash}/bin/bash'
        patchShebangs tests
      '';
      preBuild = let
        shortAbcRev = builtins.substring 0 7 abc.rev;
      in ''
        chmod -R u+w .
        make config-${if stdenv.cc.isClang or false then "clang" else "gcc"}
        echo 'ABCREV = default' >> Makefile.conf
        echo 'ENABLE_NDEBUG := 1' >> Makefile.conf
        export CXXFLAGS="-fvisibility-inlines-hidden -fmessage-length=0 -march=nocona -mtune=haswell -ftree-vectorize -fPIC -fstack-protector-strong -fno-plt -O2 -ffunction-sections -fPIC -Os -fno-merge-constants"
        # we have to do this ourselves for some reason...
        (cd misc && ${protobuf}/bin/protoc --cpp_out ../backends/protobuf/ ./yosys.proto)
        cp -r ${sources.abc-yosys} abc
        chmod -R a+w abc
      '';
      postInstall = ''
        cp yosys-abc $out/bin/
      '';
    });
  };

  yosys-git = (pkgs.yosys.override {
    abc-verifier = abc-verifier sources.abc-yosys {};
  }).overrideAttrs (oldAttrs: rec {
    src = sources.yosys;
    doCheck = false;
  });

  yosys-with-symbiflow-plugins = {
    yosys,
    stdenv ? pkgs.stdenv,
    src ? sources.yosys-symbiflow-plugins,
    plugins ? "fasm xdc params selection sdc get_count ql-iob design_introspection",
    bin ? "yosys-filterlib,yosys-smtbmc"
  }: stdenv.mkDerivation {
    inherit (yosys) name; # HACK keep path the same size to allow bbe replacement
    inherit src plugins;
    phases = "unpackPhase buildPhase installPhase";
    buildPhase = ''
      for i in $plugins; do
        make -C ''${i}-plugin ''${i}.so
      done
    '';
    installPhase = ''
      mkdir -p $out/bin $out/share/yosys/plugins
      cp -rs ${yosys}/share $out/
      cp -s ${yosys}/bin/{${bin}} $out/bin/
      sed "s|${yosys}|''${out}|g" ${yosys}/bin/yosys-config > $out/bin/yosys-config
      ${bbe}/bin/bbe -e "s|${yosys}|''${out}|g" ${yosys}/bin/yosys > $out/bin/yosys
      chmod +x $out/bin/{yosys,yosys-config}
      for i in $plugins; do
        make -C ''${i}-plugin install PLUGINS_DIR=$out/share/yosys/plugins
      done
    '';
    buildInputs = [ yosys bison flex tk libffi readline ];
  };

  sv2v = with haskellPackages.override {
    overrides = self: super: {
      githash = pkgs.haskell.lib.overrideCabal super.githash {
        version = "0.1.4.0";
        sha256 = "0rsz230srhszwybg5a40vhzzp9z0r4yvdz4xg2hwwwphmbi8pfy3";
      };
    };
  }; mkDerivation {
    pname = "sv2v";
    version = "0.0.5";
    src = sources.sv2v;
    isLibrary = false;
    isExecutable = true;
    executableHaskellDepends = [
      array base cmdargs containers directory filepath githash hashable
      mtl vector
    ];
    executableToolDepends = [ alex happy pkgs.git ];
    homepage = "https://github.com/zachjs/sv2v";
    description = "SystemVerilog to Verilog conversion";
    license = stdenv.lib.licenses.bsd3;
  };
  zachjs-sv2v = writeScriptBin "zachjs-sv2v" ''
    #!${pkgs.stdenv.shell}
    ${sv2v}/bin/sv2v $@
  '';

  # custom Python
  python = pkgs.python37.override {
    packageOverrides = import ./python-overlay.nix {
      inherit pkgs sources prjxray migen;
      pythonPackages = python37Packages;
    };
  };

  symbiflow-arch-defs-install = runCommand
    "symbiflow-arch-defs-install"
    (import ./symbiflow-install-packages.nix { inherit fetchurl; })
    ''
      mkdir -p $out
      cd $out
      tar xJf $toolchain
      tar xJf $benchmarks
      tar xJf $arch_50t
      tar xJf $arch_100t
      tar xJf $arch_200t
      patchShebangs bin
    '';

  # SymbiFlow architecture definitions
  symbiflow-arch-defs = make-symbiflow-arch-defs "";
  make-symbiflow-arch-defs = target: clangStdenv.mkDerivation rec {
    name = "symbiflow";
    yosys = yosys-symbiflow;
    buildInputs = let
      python-with-packages = ignore-collisions (python.withPackages (p:
        with p;
        with p.litexPackages;
        [
          GitPython
          arpeggio
          cairosvg
          colorclass
          cytoolz
          fasm
          flake8
          hilbertcurve
          intervaltree
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
          xc-fasm
          yapf
          Mako
          edalize-lowRISC
          fusesoc-lowRISC
        ]));
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
        prjxray
        python-with-packages
        readline
        sqlite-interactive
        zachjs-sv2v
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
        riscv64Pkgs.stdenv.cc
      ];
    src = sources.symbiflow-arch-defs;
    patches = [
      ./patches/symbiflow-arch-defs-disable-tests.patch
    ];
    postPatch = ''
      patchShebangs utils
      patchShebangs third_party/prjxray/utils
    '';
    configurePhase = ''
      export XRAY_VIVADO_SETTINGS=${vivado_settings}
      export XDG_CACHE_HOME=$PWD/.cache
      mkdir -p $XDG_CACHE_HOME
      mkdir -p build
      pushd build
      cmake \
        -DCMAKE_INSTALL_PREFIX=$out \
        -DYOSYS_DATADIR="${yosys}/share/yosys" \
        -DVPR_CAPNP_SCHEMA_DIR="${vtr}/capnp" \
        -DPRJXRAY_DB_DIR=${prjxray-db} \
        ..
      popd
    '';
    buildPhase = ''
      export VPR_NUM_WORKERS=$NIX_BUILD_CORES
      if [ -n "${target}" ]; then
        make -C build -j $NIX_BUILD_CORES ${target}
      fi
    '';
    enableParallelBuilding = true;
    installPhase = ''
      export VPR_NUM_WORKERS=$NIX_BUILD_CORES
      make -C build -j $NIX_BUILD_CORES install
    '';

    # so genericBuild works from source directory in nix-shell
    shellHook = ''
      export XRAY_VIVADO_SETTINGS=${vivado_settings}
      export phases="configurePhase buildPhase"
    '';
  };

  symbiflow-arch-defs-200t = make-symbiflow-arch-defs-200t "";
  make-symbiflow-arch-defs-200t = target: (make-symbiflow-arch-defs target).overrideAttrs (attrs: {
    name = "symbiflow-200t";
    configurePhase = ''
      export XRAY_VIVADO_SETTINGS=${vivado_settings}
      export XDG_CACHE_HOME=$PWD/.cache
      mkdir -p $XDG_CACHE_HOME
      mkdir -p build
      pushd build
      cmake \
        -DCMAKE_INSTALL_PREFIX=$out \
        -DYOSYS_DATADIR="${yosys}/share/yosys" \
        -DVPR_CAPNP_SCHEMA_DIR="${vtr}/capnp" \
        -DINSTALL_DEVICE=xc7a200t \
        -DPRJXRAY_DB_DIR=${prjxray-db} \
        ..
      popd
    '';
  });

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
    src = sources.prjxray;
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
    src = sources.nextpnr-xilinx;
    nativeBuildInputs = [ cmake ];
    buildInputs = [
      yosys-git
      prjxray
      python37
      (boost.override { python = python37; enablePython = true; })
      eigen
    ] ++ optionals stdenv.cc.isClang [
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

  mac-lscpu = writeScriptBin "lscpu" ''
        #!${pkgs.stdenv.shell}
        sysctl -a | grep machdep.cpu
  '';

  no-lscpu = writeScriptBin "lscpu" ''
        #!${pkgs.stdenv.shell}
        echo "lscpu not available"
  '';

  prjxray-config = writeScriptBin "prjxray-config" ''
    #!${pkgs.stdenv.shell}
    echo "${prjxray-db}"
  '';

  capnp-schemas-dir = writeScriptBin "capnp-schemas-dir" ''
    #!${pkgs.stdenv.shell}
    echo "${vtr}/capnp"
  '';

  fpga-tool-perf = make-fpga-tool-perf {};
  fpga-tool-perf-test = make-fpga-tool-perf {
    constants = {
      "vpr/src/route/bucket.cpp" = {
        kMaxMaxBuckets = 42;
      };
    };
  };
  make-fpga-tool-perf = options@{extra_vpr_flags ? {}, constants ? {}, ...}: let
    src = sources.fpga-tool-perf;
    default_vpr_flags = {
      max_router_iterations = 500;
      routing_failure_predictor = "off";
      router_high_fanout_threshold = -1;
      constant_net_method = "route";
      route_chan_width = 500;
      router_heap = "bucket";
      clock_modeling = "route";
      place_delta_delay_matrix_calculation_method = "dijkstra";
      place_delay_model = "delta";
      router_lookahead = "extended_map";
      check_route = "quick";
      strict_checks = "off";
      allow_dangling_combinational_nodes = "on";
      disable_errors = "check_unbuffered_edges:check_route";
      congested_routing_iteration_threshold = 0.8;
      incremental_reroute_delay_ripup = "off";
      base_cost_type = "delay_normalized_length_bounded";
      bb_factor = 10;
      acc_fac = 0.7;
      astar_fac = 1.8;
      initial_pres_fac = 2.828;
      pres_fac_mult = 1.2;
      check_rr_graph = "off";
      suppress_warnings = "noisy_warnings.log,sum_pin_class:check_unbuffered_edges:load_rr_indexed_data_T_values:check_rr_node:trans_per_R:check_route:set_rr_graph_tool_comment:calculate_average_switch";
    };
    vpr_flags = default_vpr_flags // extra_vpr_flags;
    mkTest = { projectName, toolchain, board }: stdenv.mkDerivation rec {
      name = "fpga-tool-perf-${projectName}-${toolchain}-${board}";
      inherit src;
      usesVPR = hasPrefix "vpr" toolchain;
      yosys = yosys-symbiflow;
      vtr = if constants == {} then vtr-optimized else vtr-custom constants;
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
        scalene
        simplejson
        symbiflow-xc-fasm2bels
        terminaltables
        textx
        tqdm
        xc-fasm
        yapf
      ]);
      buildInputs = [
        capnp-schemas-dir
        coreutils
        getopt
        icestorm
        nextpnr
        nextpnr-xilinx
        prjxray
        prjxray-config
        python-with-packages
        symbiflow-arch-defs-install
        vtr
        yosys
        zachjs-sv2v
        which
      ] ++ optionals stdenv.isLinux [
        no-lscpu
      ] ++ optionals stdenv.isDarwin [
        mac-lscpu
      ];
      toolchain-arg = if toolchain == "vivado-yosys" then "yosys-vivado" else toolchain;
      buildPhase = ''
        cat << EOF > env.sh
        export PYTHONPATH=${prjxray}
        export VIVADO_SETTINGS=${vivado_settings}
        export XRAY_DATABASE_DIR=${prjxray-db}
        export XRAY_FASM2FRAMES="-m prjxray.fasm2frames"
        export XRAY_TOOLS_DIR="${prjxray}/bin"
        export SYMBIFLOW="${symbiflow-arch-defs-install}"
        export FPGA_TOOL_PERF_BASE_DIR=$(pwd)
        EOF
        source env.sh

        touch utils/__init__.py # fix: ModuleNotFoundError: No module named 'utils.utils'
        mkdir -p env/conda/pkgs
        rm -f env/conda/pkgs/nextpnr-xilinx
        ln -s ${nextpnr-xilinx} env/conda/pkgs/nextpnr-xilinx
        source $VIVADO_SETTINGS
        python3 fpgaperf.py \
          --project ${projectName} \
          --toolchain ${toolchain-arg} \
          --board ${board} \
          --out-dir $out \
          --verbose \
          ${optionalString (extra_vpr_flags != {}) '' --params_string='${flags_to_string vpr_flags}' ''}
      '';
      installPhase = ''
        mkdir -p $out/nix-support
        if [ -f ${vtr}/constants.patch ]; then
          cp ${vtr}/constants.patch $out
        fi
        cat <<EOF > $out/options.json
        ${toJSON options}
        EOF
        echo "file json $out/meta.json" > $out/nix-support/hydra-build-products
        find $out \
            -type f \
          ! -name meta.json \
          ! -name hydra-build-products \
            -printf "file data %p\n" >> $out/nix-support/hydra-build-products
      '';
      shellHook = ''
        export PYTHONPATH=${prjxray}
        export VIVADO_SETTINGS=${vivado_settings}
        export XRAY_DATABASE_DIR=${prjxray-db}
        export XRAY_FASM2FRAMES="-m prjxray.fasm2frames"
        export XRAY_TOOLS_DIR="${prjxray}/bin"
        export SYMBIFLOW="${symbiflow-arch-defs-install}"
        export FPGA_TOOL_PERF_BASE_DIR=$(pwd)
        export LD_LIBRARY_PATH=${lib.makeLibraryPath [stdenv.cc.cc]}
      '';
      requiredSystemFeatures = [ "benchmark" ]; # only run these on benchmark machines
    };
    projectNames = map (n: head (match "([^.]*).json$" n)) (attrNames (readDir (src + "/project/")));
    boards = fromJSON (readFile (src + "/other/boards.json"));
  in
    listToAttrs (map (projectName:
      let
        projectInfo = fromJSON (readFile (src + "/project/${projectName}.json"));
        boards = concatMap (vendor: projectInfo.vendors.${vendor}) (attrNames projectInfo.vendors);
        mkBoard = toolchain: board: {
          name = board;
          value = mkTest { inherit projectName toolchain board; };
        };
        mkToolchain = toolchain: {
          name = toolchain;
          value = listToAttrs (map (mkBoard toolchain) boards);
        };
      in
        {
          name = projectName;
          value = listToAttrs (map mkToolchain projectInfo.required_toolchains);
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

  riscvPkgs = bits: import sources.nixpkgs {
    crossSystem = {
      config = "riscv${toString bits}-none-elf";
      libc = "newlib";
      platform = systems.platforms.riscv-multiplatform "${toString bits}";
    };
  };
  riscv64Pkgs = riscvPkgs 64;

  litex-buildenv = let
    with-litex-buildenv = attrs@{ name, platform, cpu, target, bits }:
      (riscvPkgs bits).stdenv.mkDerivation rec {
        name = "litex-buildenv-${attrs.name}";
        src = fetchgit {
          url = "https://github.com/timvideos/litex-buildenv.git";
          rev = "690901d9c86c0d74e154a5a47de1e850e6f4ea40";
          sha256 = "0gibrk7nacypmcm6yfr88rl4b33xv1lr3prhvqragiaxxkpl35wi";
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
        bits = 64;
      };
      rocket = {
        platform = "arty";
        cpu = "rocket";
        target = "base";
        bits = 64;
      };
    };

  with-yosys-git = mkShell {
    buildInputs = [ yosys-git ];
  };

  # use this as a temporary fix for Python collisions
  ignore-collisions = p: p.override (args: { ignoreCollisions = true; });
}

# Local Variables:
# eval: (add-to-list 'imenu-generic-expression '("Package" "^  \\([a-zA-Z0-9_-]+\\) =.*$" 1))
# End:
