set -e
VIVADO_VERSION=2019.2

source $stdenv/setup

echo "unpacking $src..."
mkdir extracted
tar xzf $src -C extracted --strip-components=1

echo "running installer..."

cat <<EOF > install_config.txt
Edition=Vivado HL WebPACK
Destination=$out/opt
Modules=DocNav:0,Kintex UltraScale:0,Zynq-7000:1,System Generator for DSP:0,Artix-7:1,Kintex-7:0
InstallOptions=
CreateProgramGroupShortcuts=0
ProgramGroupFolder=Xilinx Design Tools
CreateShortcutsForAllUsers=0
CreateDesktopShortcuts=0
CreateFileAssociation=0
EOF

patchShebangs extracted

patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
         extracted/tps/lnx64/jre9.0.4/bin/java

mkdir -p $out/opt

sed -i -- 's|/bin/rm|rm|g' extracted/xsetup

# The installer will be killed as soon as it says that post install tasks have failed.
# This is required because it tries to run the unpatched scripts to check if the installation
# has succeeded. However, these scripts will fail because they have not been patched yet,
# and the installer will proceed to delete the installation if not killed.

export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$libPath
(extracted/xsetup --agree 3rdPartyEULA,WebTalkTerms,XilinxEULA --batch Install --config install_config.txt || true) | while read line
do
    [[ "${line}" == *"Execution of Pre/Post Installation Tasks Failed"* ]] && echo "killing installer!" && ((pkill -9 -f "extracted/tps/lnx64/jre9.0.4/bin/java") || true)
    echo ${line}
done

#rm -rf extracted

# Patch installed files
for dir in Vivado; do
    patchShebangs $out/opt/${dir}/${VIVADO_VERSION}/bin
    patchShebangs $out/opt/${dir}/${VIVADO_VERSION}/scripts
    sed -i -- 's|/bin/touch|touch|g' $out/opt/${dir}/${VIVADO_VERSION}/scripts/ISEWrap.sh
    sed -i -- 's|/bin/touch|touch|g' $out/opt/${dir}/${VIVADO_VERSION}/scripts/ISEWrapReports.sh
done
echo "Shebangs patched"

# Hack around lack of libtinfo in NixOS
ln -s $ncurses/lib/libncursesw.so.6 $out/opt/Vivado/${VIVADO_VERSION}/lib/lnx64.o/libtinfo.so.5
#ln -s $ncurses/lib/libncursesw.so.6 $out/opt/SDK/${VIVADO_VERSION}/lib/lnx64.o/libtinfo.so.5

# Patch ELFs
for f in $out/opt/Vivado/${VIVADO_VERSION}/bin/unwrapped/lnx64.o/*
do
    patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $f || true
done

# for f in $out/opt/SDK/${VIVADO_VERSION}/bin/unwrapped/lnx64.o/*
# do
#     patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $f || true
# done

# patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $out/opt/SDK/${VIVADO_VERSION}/eclipse/lnx64.o/eclipse

# patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $out/opt/SDK/${VIVADO_VERSION}/tps/lnx64/jre9.0.4/bin/java

echo "ELFs patched"

wrapProgram $out/opt/Vivado/${VIVADO_VERSION}/bin/vivado --prefix LD_LIBRARY_PATH : "$libPath"
# wrapProgram $out/opt/SDK/${VIVADO_VERSION}/bin/xsdk --prefix LD_LIBRARY_PATH : "$libPath"
# wrapProgram $out/opt/SDK/${VIVADO_VERSION}/eclipse/lnx64.o/eclipse --prefix LD_LIBRARY_PATH : "$libPath"
# wrapProgram $out/opt/SDK/${VIVADO_VERSION}/tps/lnx64/jre9.0.4/bin/java --prefix LD_LIBRARY_PATH : "$libPath"
# wrapProgram on its own will not work because of the way the Vivado script runs ./launch
# Therefore, we need Even More Patches...
sed -i -- 's|`basename "\$0"`|vivado|g' $out/opt/Vivado/${VIVADO_VERSION}/bin/.vivado-wrapped
# sed -i -- 's|`basename "\$0"`|xsdk|g' $out/opt/SDK/${VIVADO_VERSION}/bin/.xsdk-wrapped

# Add vivado and xsdk to bin folder
mkdir $out/bin
ln -s $out/opt/Vivado/${VIVADO_VERSION}/bin/vivado $out/bin/vivado
#ln -s $out/opt/SDK/${VIVADO_VERSION}/bin/xsdk $out/bin/xsdk
