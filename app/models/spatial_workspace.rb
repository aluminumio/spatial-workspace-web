module SpatialWorkspace
  VERSION = "0.1.0"

  def self.version
    sha = ENV["SOURCE_VERSION"] || ENV["GIT_REV"] || git_sha
    sha ? "v#{VERSION}-#{sha[0..6]}" : "v#{VERSION}"
  end

  def self.git_sha
    `git rev-parse HEAD 2>/dev/null`.strip.presence
  end
end
