-- Locality — local editor integration (editors/nvim in the Locality repo).
-- Lazy-loads on first use of any :Locality* command.
return {
  {
    dir = "/home/sebishogun/Work/Development/Locality/editors/nvim",
    name = "locality",
    cmd = {
      "LocalityPhaseB",
      "LocalityPhaseA",
      "LocalityStats",
      "LocalityBrowse",
      "LocalityGraph",
      "LocalityTreemap",
      "LocalityFlame",
      "LocalityDetect",
      "LocalityViewer",
    },
    config = function()
      require("locality").setup({ bin = "locality" })
    end,
  },
}
