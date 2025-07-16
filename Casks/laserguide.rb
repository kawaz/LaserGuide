# frozen_string_literal: true

cask "laserguide" do
  version "0.5.4"
  sha256 "6516ed794ac0017fc7e0a763efd9d4ebafb80aa4482f2ffbcc05aa4eac2db2c2"

  url "https://github.com/kawaz/LaserGuide/releases/download/v#{version}/LaserGuide-#{version}.zip"
  name "LaserGuide"
  desc "Display laser lines from screen corners to your mouse cursor"
  homepage "https://github.com/kawaz/LaserGuide"

  depends_on macos: ">= :sequoia"

  app "LaserGuide.app"

  uninstall quit: "com.kawaz.LaserGuide"

  zap trash: [
    "~/Library/Preferences/com.kawaz.LaserGuide.plist",
    "~/Library/Saved Application State/com.kawaz.LaserGuide.savedState",
  ]
end
