class Cursorfinder < Formula
  desc "Display laser lines from screen corners to your mouse cursor"
  homepage "https://github.com/kawaz/CursorFinder"
  url "https://github.com/kawaz/CursorFinder/releases/download/v0.1.0/CursorFinder.zip"
  sha256 "b178eaa1429acbae4e35cb22efe4d41779f22d62ab0961588aedf52b906653be"
  license "MIT"

  depends_on :macos => :sonoma

  def install
    # Install the app
    prefix.install "CursorFinder.app"
    
    # Create a command-line launcher
    (bin/"cursorfinder").write <<~EOS
      #!/bin/bash
      open "#{prefix}/CursorFinder.app"
    EOS
    chmod 0755, bin/"cursorfinder"
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