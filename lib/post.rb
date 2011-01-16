class Post
  attr :title
  attr :data

  def initialize(title, data)
    @title = title
    @data  = data
  end

  def self.[](file)
    new(title(file), html(file))
  end

protected
  def self.title(file)
    File.basename(file, File.extname(file)).
      gsub(/^\d{4}-\d{1,2}-\d{1,2}-/, "").
      tr("-", " ").capitalize
  end
  
  def self.html(file)
    case file
    when /\.markdown$/
      Maruku.new(read(file)).to_html
    when /\.html$/
      read(file)
    end
  end

  def self.read(file)
    File.read(file, encoding: "utf-8")
  end
end
