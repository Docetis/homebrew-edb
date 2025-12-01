class Edb < Formula
  desc "eXist-DB CLI toolkit – export/import, watch-sync, XAR build, backup & rollback"
  homepage "https://github.com/Docetis/edb"
  url "https://github.com/Docetis/edb/archive/refs/tags/v0.0.3.tar.gz"
  sha256 "5fefa19c74fd0c644245defb0c22f5ca7e367230fe8b869b517af04b2d1a4cb5"
  license "MIT"

  depends_on "curl"
  depends_on "zip"

  def install
    bin.install "edb.sh" => "edb"
  end

  test do
    # Just print usage to ensure the binary runs
    system "#{bin}/edb"
  end
end
