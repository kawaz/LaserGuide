class Cursorfinder < Formula
  desc "Display laser lines from screen corners to your mouse cursor"
  homepage "https://github.com/kawaz/CursorFinder"
  url "https://github.com/kawaz/CursorFinder/releases/download/v0.1.1/CursorFinder.zip"
  sha256 "717ad588ce77ac9076918eb212ae105af3d663f920541c09de73c770b363f2c4"
  license "MIT"

  depends_on :macos => :sonoma

  def install
    # Install the app bundle from buildpath
    app = buildpath/"CursorFinder.app"
    if app.exist?
      libexec.install app
    else
      # Fallback if the app is in the current directory
      libexec.install "CursorFinder.app"
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