(function($) {
  $.errors = {
    email: {
      not_present: "Email is required.",
      not_email:   "Email is invalid.",
      not_unique:  "Email is already taken."
    }
  }

  $.fn.inlineError = function(tuple) {
    var $inp = $(this),
        $markup = $("<span class='error'><em></em></span>"),
        $existing = $inp.next(".error"),
        msg = $.errors[tuple[0]][tuple[1]];
    
    if ($existing.length > 0) $existing.remove();
    
    $inp.after($markup.find("em").text(msg).end());
  };
  
  $("form#invite input.stubbed").live("focus", function() {
    $(this).removeClass("stubbed").val("");
  });

  $("form#invite").submit(function() {
    var $form = $(this),
        $email  = $form.find("input[type='text']"),
        success = "<p class='success'>You have successfully requested an invite.</p>";

    $.ajax({
      url: $form.attr("action"),
      type: "post",
      data: $form.serialize(),
      dataType: "json",
      success: function(resp) {
        if (resp.errors) {
          for (var i = 0; i < resp.errors.length; i++) {
            $email.inlineError(resp.errors[i]);
          }
        } else {
          $form.after(success);
          $form.remove();
        }
      }
    });

    return false;
  });
})(jQuery);
