{
  disko.devices.disk.root = {
    type = "disk";
    # Verified from the installer on 2026-11-07. Never replace this with /dev/sdX:
    # the PC also holds the Windows NVMe and two game drives.
    device = "/dev/disk/by-id/ata-Samsung_SSD_850_EVO_250GB_S2R6NX0J548174K";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
            mountOptions = [ "noatime" ];
          };
        };
      };
    };
  };
}
