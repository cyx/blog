require File.expand_path("shotgun", File.dirname(__FILE__))

Dir[root("lib/**/*.rb")].each { |rb| require rb }

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

Cuba.use Rack::Static,
  urls: ["/images", "/js", "/fonts", "/css/reset.css"],
  root: File.join(ROOT_PATH, "public")

Cuba.define do
  extend Cuba::Prelude
  
  def latest_post
    posts.first
  end

  def posts
    Dir[root("posts", "*.{html,markdown}")].sort.reverse.map { |file| Post[file] }
  end

  on get, path("") do
    @post = latest_post

    res.write haml("post")
  end

  on get, path("css"), path("application.css") do
    res.write stylesheet("css/application.sass")
  end

  on default do
    not_found
  end
end
