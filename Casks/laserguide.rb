# frozen_string_literal: true

cask "laserguide" do
  version "0.6.2"
  sha256 "e185d9cca542790d9a1c2677b5a9ca1a23c34f776514d32564d52609c21ff5b8"

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
