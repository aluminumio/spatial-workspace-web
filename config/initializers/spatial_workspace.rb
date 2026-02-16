require "yaml"
require "erb"

SPATIAL_CONFIG = begin
  yaml = ERB.new(File.read(Rails.root.join("config", "spatial_workspace.yml"))).result
  YAML.safe_load(yaml, permitted_classes: [Symbol]).fetch(Rails.env, {}).with_indifferent_access
end
