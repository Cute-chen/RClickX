cask "rclickx" do
  version "1.0.0"
  sha256 :no_check

  url "https://github.com/Cute-chen/RClickX/releases/download/v#{version}/RClickX-v#{version}.dmg"
  name "RClickX"
  desc "Modern zero-config right-click contextual menu enhancer for macOS Finder"
  homepage "https://github.com/Cute-chen/RClickX"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true
  depends_on macos: ">= :sequoia"

  app "RClickX.app"

  uninstall quit: [
    "com.cutechen.rclickx",
    "com.cutechen.rclickx.FinderSyncExt",
  ]

  zap trash: [
    "~/Library/Application Support/RClick",
    "~/Library/Caches/com.cutechen.rclickx",
    "~/Library/Containers/com.cutechen.rclickx",
    "~/Library/Containers/com.cutechen.rclickx.FinderSyncExt",
    "~/Library/Group Containers/group.com.cutechen.rclickx",
    "~/Library/Preferences/com.cutechen.rclickx.plist",
  ]
end
