inputs:
{
  options.nixos.services.huginn.enable = inputs.lib.mkOption { type = inputs.lib.types.bool; default = false; };
  config = inputs.lib.mkIf inputs.config.nixos.services.huginn.enable
  {
    nixos.services =
    {
      docker.huginn =
      {
        image = inputs.pkgs.dockerTools.pullImage
        {
          imageName = "huginn/huginn";
          imageDigest = "sha256:dbe871597d43232add81d1adfc5ad9f5cf9dcb5e1f1ba3d669598c20b96ab6c1";
          sha256 = "0ls97k8ic7w5j54jlpwh8rrvj1y4pl4106j9pyap105r6p7dziiz";
          finalImageName = "huginn/huginn";
          finalImageTag = "2d5fcafc507da3e8c115c3479e9116a0758c5375";
        };
        ports = [ 3000 ];
        environmentFile = true;
      };
    };
  };
}
