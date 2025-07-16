# frozen_string_literal: true

cask "laserguide" do
  version "0.6.1"
  sha256 "1ad4ccf0f62790633b460a57f9b5d84c6fdc9452925215f496c1e9b9ec3f40a2"

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
