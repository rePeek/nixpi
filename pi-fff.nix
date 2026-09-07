# @ff-labs/pi-fff plugin: fuzzy file finder for pi.
# PI_FFF_MODE = "override" makes fff override pi's built-in file tools.
_: {
  programs.pi-coding-agent.settings.packages = [
    "npm:@ff-labs/pi-fff@0.10.1"
  ];

  home.sessionVariables = {
    PI_FFF_MODE = "override";
  };
}
