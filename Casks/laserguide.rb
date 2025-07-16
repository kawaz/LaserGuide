# frozen_string_literal: true

cask "laserguide" do
  version "0.6.3"
  sha256 "d13571db7f973828848d8ad085d543b5dfa9f910a948ea51394c4c14b20f4486"

  url "https://github.com/kawaz/LaserGuide/releases/download/v#{version}/LaserGuide-#{version}.zip"
  name "LaserGuide"
  desc "Display laser lines from screen corners to your mouse cursor"
  homepage "https://github.com/kawaz/LaserGuide"

  depends_on macos: ">= :sequoia"

  # アップグレード時にも既存プロセスを終了
  preflight do
    system_command "/usr/bin/pkill", args: ["-f", "LaserGuide"], sudo: false
  end

  app "LaserGuide.app"

  uninstall quit: "jp.kawaz.LaserGuide"

  zap trash: [
    "~/Library/Preferences/jp.kawaz.LaserGuide.plist",
    "~/Library/Saved Application State/jp.kawaz.LaserGuide.savedState",
  ]
end
