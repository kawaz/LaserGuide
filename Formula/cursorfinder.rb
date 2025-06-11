class Cursorfinder < Formula
  desc "Display laser lines from screen corners to your mouse cursor"
  homepage "https://github.com/kawaz/CursorFinder"
  url "https://github.com/kawaz/CursorFinder/releases/download/v1.0.0/CursorFinder.zip"
  sha256 "2998cbeb4c91500be102584050e3e1207b1f2e21de01212b16936f1a23343724"
  license "MIT"

  depends_on :macos => :sonoma

  def install
    app = "CursorFinder.app"
    prefix.install app
    
    # Create a command-line launcher
    (bin/"cursorfinder").write <<~EOS
      #!/bin/bash
      open "#{prefix}/#{app}"
    EOS
  end

  def post_install
    system "xattr", "-dr", "com.apple.quarantine", "#{prefix}/CursorFinder.app"
  end

  def caveats
    <<~EOS
      CursorFinder has been installed to #{prefix}/CursorFinder.app
      
      To launch CursorFinder:
        cursorfinder
      
      Or you can copy it to your Applications folder:
        cp -r #{prefix}/CursorFinder.app /Applications/
      
      CursorFinder requires accessibility permissions to track mouse movements.
      You will be prompted to grant these permissions on first launch.
    EOS
  end

  test do
    assert_predicate prefix/"CursorFinder.app", :exist?
  end
end