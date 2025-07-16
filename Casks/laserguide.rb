cask "laserguide" do
  version "0.5.3"
  sha256 "26190ad843072d34e6ebcac3de81a0bb690fc4bf6c74242e400a21d522eec68d"

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