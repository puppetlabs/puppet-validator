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
                          "class": "validator",
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

        form.append(editor);
        form.append(spec);
        form.append(submit);
        element.replaceWith(form);

        // if we've got CodeMirror loaded, then make a pretty editor
        if(typeof CodeMirror != 'undefined') {
          var cmEditor = CodeMirror.fromTextArea(editor[0], {
               lineNumbers: true,
               smartIndent: true,
            indentWithTabs: true,
                      mode: 'puppet',
          });
        }

        submit.on('click', function(event){
          event.preventDefault();

          // propogates text to the textarea
          if(typeof cmEditor != 'undefined') {
            cmEditor.save();
          }

          var wrapper = $(this).parent('form');
          var editor  = $(this).siblings('textarea')
          var code    = editor.val();

          $.post(server, {code: code, spec: settings.spec}, function(data) {
            console.log(data);
            var results = jQuery.parseJSON(data);
            if(results.success) {
              wrapper.addClass('validated');
              wrapper.removeClass('failed');
              alert('yay!');
            }
            else {
              wrapper.addClass('failed');
              wrapper.removeClass('validated');
              alert("Failures:\n" + results.errors.join("\n"));
            }
          }).fail(function(jqXHR) {
            alert("Unknown API error:\n" + jqXHR.responseText);
          });
        });

        return this;
      });
    };

}(jQuery));
