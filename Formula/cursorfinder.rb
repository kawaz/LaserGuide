class Cursorfinder < Formula
  desc "Display laser lines from screen corners to your mouse cursor"
  homepage "https://github.com/kawaz/CursorFinder"
  url "https://github.com/kawaz/CursorFinder/releases/download/v0.1.5/CursorFinder.zip"
  sha256 "5afa38a0c4d7a0b0567f3b50499d7c33ecf8474b6a5b66801aebd627ef92589b"
  license "MIT"

  depends_on :macos => :sonoma

  def install
    # Check if CursorFinder.app exists in the buildpath
    if (buildpath/"CursorFinder.app").exist?
      # Standard installation when the app bundle exists
      libexec.install "CursorFinder.app"
    else
      # Fallback: reconstruct the app bundle if only Contents exists
      (libexec/"CursorFinder.app").mkpath
      (libexec/"CursorFinder.app").install Dir["*"]
    end
    
    # Create a command-line launcher
    (bin/"cursorfinder").write <<~EOS
      #!/bin/bash
      open "#{libexec}/CursorFinder.app"
    EOS
    chmod 0755, bin/"cursorfinder"
  end

  def post_install
    system "xattr", "-dr", "com.apple.quarantine", "#{libexec}/CursorFinder.app"
  end

  def caveats
    <<~EOS
      CursorFinder has been installed to #{libexec}/CursorFinder.app
      
      To launch CursorFinder:
        cursorfinder
      
      Or you can copy it to your Applications folder:
        cp -r #{libexec}/CursorFinder.app /Applications/
      
      CursorFinder requires accessibility permissions to track mouse movements.
      You will be prompted to grant these permissions on first launch.
    EOS
  end

  test do
    assert_predicate libexec/"CursorFinder.app", :exist?
  end
end