(function ( $ ) {
    $.fn.RspecValidator = function(options) {
      var settings = $.extend({
         label: "Validate",
          spec: null,
          cols: 65,
          rows: 25,
        server: "",
      }, options );

      return this.each(function() {
        var element = $(this);
        var server  = settings.server + "/api/v0/validate/rspec"
        if(element.attr('data-spec')) {
          settings.spec = element.attr('data-spec')

        }

        if (settings.spec == null) {
          console.log("[FATAL] RspecValidator: spec is a required parameter.")
          return;
        }

        var form    = $("<form>", {
                         "action": server,
                         "method": "post",
                        });
        var editor  = $("<textarea>", {
                           "name": "code",
                           "cols": settings.cols,
                           "rows": settings.rows,
                          "class": "validator editor",
                        });
        var spec    = $("<input>", {
                           "name": "spec",
                           "type": "hidden",
                          "value": settings.spec,
                        });
        var submit  = $("<input>", {
                           "name": "submit",
                           "type": "submit",
                          "value": settings.label,
                        });

        submit.on('click', function(event){
          event.preventDefault();

          var editor = $(this).siblings('textarea')
          var code   = editor.val();

          $.post(server, {code: code, spec: settings.spec}, function(data) {
            console.log(data);
            var results = jQuery.parseJSON(data);
            if(results.success) {
              editor.addClass('validated');
              editor.removeClass('failed');
              alert('yay!');
            }
            else {
              editor.addClass('failed');
              editor.removeClass('validated');
              alert("Failures:\n" + results.errors.join("\n"));
            }
          }).fail(function(jqXHR) {
            alert("Unknown API error:\n" + jqXHR.responseText);
          });
        });

        form.append(editor);
        form.append(spec);
        form.append(submit);
        element.replaceWith(form)

        return this;
      });
    };

}(jQuery));
