{
  disko.devices.disk.root = {
    type = "disk";
    # Always a /dev/disk/by-id path: kernel names like /dev/sda can change between
    # boots, and the installer refuses anything else.
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
