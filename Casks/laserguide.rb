# frozen_string_literal: true

cask "laserguide" do
  version "0.6.0"
  sha256 "039c72846eee8470c533bddac0199b0066046c9dd3098ccbfd9aa74cb3a3c825"

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
