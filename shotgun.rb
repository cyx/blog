ROOT_PATH = File.expand_path(File.dirname(__FILE__))

$:.unshift(*Dir[File.join(ROOT_PATH, "vendor/*/lib")])

require "fileutils"
require "json"
require "yaml"
require "cuba"
require "haml"

module Kernel
private

  def root(*args)
    File.join(ROOT_PATH, *args)
  end
end
