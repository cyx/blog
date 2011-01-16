module Cuba::Prelude
  def haml(template, locals = {})
    layout(partial(template, locals))
  end

  def partial(template, locals = {})
    render("views/#{template}.haml", locals, ugly: true, escape_html: true)
  end

  def layout(content)
    partial("layout", content: content)
  end

  def stylesheet(template)
    if req.query_string =~ /[0-9]{10}/
      res.headers["Cache-Control"] = "public, max-age=29030400"
    end

    res.headers["Content-Type"] = "text/css; charset=utf-8"

    render("views/#{template}")
  end

  # Wraps the common case of throwing a 404 page in a nice little helper.
  #
  # @example
  #
  #   on path("user"), segment do |_, id|
  #     break not_found unless user = User[id]
  #
  #     res.write user.username
  #   end
  def not_found
    res.status = 404
    res.write haml("404")
  end
end