# Generated with: ./list-symbiflow-tarballs.sh symbiflow-install-packages.nix
{ fetchurl }:
{
  arch_50t = fetchurl {
    name = "arch_50t";
    url = "https://www.googleapis.com/download/storage/v1/b/symbiflow-arch-defs/o/artifacts%2Fprod%2Ffoss-fpga-tools%2Fsymbiflow-arch-defs%2Fcontinuous%2Finstall%2F118%2F20201218-080731%2Fsymbiflow-arch-defs-xc7a50t_test-6a2d523c.tar.xz?generation=1608322880875697&alt=media";
    sha256 = "0k8km3l8jd7cz0fyq658fss99w6gz6d1hyi6lq4by6cxrvwkrsya";
  };
  arch_200t = fetchurl {
    name = "arch_200t";
    url = "https://www.googleapis.com/download/storage/v1/b/symbiflow-arch-defs/o/artifacts%2Fprod%2Ffoss-fpga-tools%2Fsymbiflow-arch-defs%2Fcontinuous%2Finstall%2F118%2F20201218-080731%2Fsymbiflow-arch-defs-xc7a200t_test-6a2d523c.tar.xz?generation=1608322885009734&alt=media";
    sha256 = "00bqw39ns0dh4wn9i0h7rcabdy1vacx03gbvl2j06npwzmgq2gd2";
  };
  benchmarks = fetchurl {
    name = "benchmarks";
    url = "https://www.googleapis.com/download/storage/v1/b/symbiflow-arch-defs/o/artifacts%2Fprod%2Ffoss-fpga-tools%2Fsymbiflow-arch-defs%2Fcontinuous%2Finstall%2F118%2F20201218-080731%2Fsymbiflow-arch-defs-benchmarks-6a2d523c.tar.xz?generation=1608322879183579&alt=media";
    sha256 = "1bm5kp9lk34bp0vl551l1vq8phyv8qk66rkv3ingzh6pkikzarbg";
  };
  toolchain = fetchurl {
    name = "toolchain";
    url = "https://www.googleapis.com/download/storage/v1/b/symbiflow-arch-defs/o/artifacts%2Fprod%2Ffoss-fpga-tools%2Fsymbiflow-arch-defs%2Fcontinuous%2Finstall%2F118%2F20201218-080731%2Fsymbiflow-arch-defs-install-6a2d523c.tar.xz?generation=1608322879183828&alt=media";
    sha256 = "0mhd9i39zy3ny77fl690m43j2mpzwna552617f0jfqa0fsljkm3n";
  };
  arch_100t = fetchurl {
    name = "arch_100t";
    url = "https://www.googleapis.com/download/storage/v1/b/symbiflow-arch-defs/o/artifacts%2Fprod%2Ffoss-fpga-tools%2Fsymbiflow-arch-defs%2Fcontinuous%2Finstall%2F118%2F20201218-080731%2Fsymbiflow-arch-defs-xc7a100t_test-6a2d523c.tar.xz?generation=1608322884025495&alt=media";
    sha256 = "06vxbl4cfy5lvhdk0hbkbp2br955f97czavnkyzlg18rj596x8p0";
  };
}
