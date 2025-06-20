class Laserguide < Formula
  desc "Display laser lines from screen corners to your mouse cursor"
  homepage "https://github.com/kawaz/LaserGuide"
  url "https://github.com/kawaz/LaserGuide/releases/download/v0.5.1/LaserGuide-0.5.1.zip"
  sha256 "ccaa65de7e9351db32b70cf524350304161c0264731193f8b17977aad7b1c715"
  license "MIT"

  depends_on :macos => :sonoma

  def install
    # Check if LaserGuide.app exists in the buildpath
    if (buildpath/"LaserGuide.app").exist?
      # Standard installation when the app bundle exists
      libexec.install "LaserGuide.app"
    else
      # Fallback: reconstruct the app bundle if only Contents exists
      (libexec/"LaserGuide.app").mkpath
      (libexec/"LaserGuide.app").install Dir["*"]
    end
    
    # Create a command-line launcher
    (bin/"laserguide").write <<~EOS
      #!/bin/bash
      open "#{libexec}/LaserGuide.app"
    EOS
    chmod 0755, bin/"laserguide"
  end

  def post_install
    system "xattr", "-dr", "com.apple.quarantine", "#{libexec}/LaserGuide.app"
  end

  def caveats
    <<~EOS
      LaserGuide has been installed to #{libexec}/LaserGuide.app
      
      To launch LaserGuide:
        laserguide
      
      Or you can copy it to your Applications folder:
        cp -r #{libexec}/LaserGuide.app /Applications/
      
      LaserGuide requires accessibility permissions to track mouse movements.
      You will be prompted to grant these permissions on first launch.
    EOS
  end

  test do
    assert_predicate libexec/"LaserGuide.app", :exist?
  end
end