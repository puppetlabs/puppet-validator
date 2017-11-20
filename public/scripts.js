function toggleChecks() {
  var enabled = $('input#lint').is(":checked");

  $('ul#checks input').attr('disabled', ! enabled);
}

function toggleMenu() {
  $('#checks-menu').slideToggle();
}

function gist() {
  var code = $('#code').text();
  if (typeof(code) == 'string' && $.trim(code).length != 0) {
    var data = {
      "description": "Validated by puppetlinter.com",
      "public": true,
      "files": {
        "init.pp": {
          "content": code
        }
      }
    }
    $.ajax({
        url: 'https://api.github.com/gists',
        type: 'POST',
        dataType: 'json',
        data: JSON.stringify(data)
      })
      .success(function(response) {
        console.log(response);
        popup(null, 'Gist posted to:', response['html_url']);
      })
      .error(function(error) {
        console.warn("Cannot save gist: ", error);
        popup('Gist save failed.', error);
      });
  }
}

function popup(title, text, url) {
  var dialog = $('<div id="popup" />');
  $(dialog).append( $("<p/>").text(text) );

  if(url) {
    $(dialog).append( '<ul><li id="url"></li></ul>' )
    $(dialog).find('li#url').append( $("<a />", { href: url, text: url }) );
  }

  $(dialog).dialog({
      modal: true,
      title: title,
      width: 425,
      buttons: {
          Ok: function () {
              $(this).dialog("close");
              $("#popup").remove();
          }
      }
  });
}


/*
CodeMirror.registerHelper("lint", "puppet", function(text, options) {
  var found    = [];
  var messages = validate(code);

  for ( var i = 0; i < messages.length; i++) {
    message = messages[i];
    var startLine = message.line -1, endLine = message.line -1, startCol = message.col -1, endCol = message.col;
    found.push({
          from: CodeMirror.Pos(startLine, startCol),
            to: CodeMirror.Pos(endLine, endCol),
       message: message.message,
      severity: message.type
    });
  }
  return found;
});
*/


function puppet_validator(cm, updateLinting, options) {
  if(typeof editor != 'undefined') {
    console.log("Called, yo!");
    console.log(options);
    var errors = [];
    var messages = [
      { line: 3,
         col: 5,
         message: "ooga booga",
         type: "error"
      },
      { line: 5,
         col: 3,
         message: "ooga booga boo",
         type: "warning"
      }
    ];

    editor.save();
    var wrapper = $('form');
    var code    = $('#code').val();

    if( $('input#lint').is(':checked') ) {
      var lint   = 'on';
      var checks = $('#checks input:checked').map(function() { return this.value; }).get();
    }
    else  {
      var lint   = 'off';
      var checks = [];
    }


    $.post('/api/v0/validate', {code: code, lint: lint, checks: checks}, function(data) {
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
        console.log(results);
      }
    }).fail(function(jqXHR) {
      alert("Unknown API error:\n" + jqXHR.responseText);
    });



    for ( var i = 0; i < messages.length; i++) {
      message = messages[i];
      var startLine = message.line -1, endLine = message.line -1, startCol = message.col -1, endCol = message.col;
      errors.push({
            from: CodeMirror.Pos(startLine, startCol),
              to: CodeMirror.Pos(endLine, endCol),
         message: message.message,
        severity: message.type
      });
    }
    console.log(errors);

    updateLinting(errors);
  }
}


$( document ).ready(function() {
  toggleChecks();

  // don't fail if the theme doesn't load codemirror
  if(typeof CodeMirror != 'undefined') {
    var textbox = $("textarea#code")[0]
    editor = CodeMirror.fromTextArea(textbox, {
         lineNumbers: true,
         smartIndent: true,
      indentWithTabs: true,
                mode: 'puppet',
             gutters: ["CodeMirror-lint-markers"],
                lint: {
                        getAnnotations: puppet_validator,
                                 async: true,
                          lintOnChange: false
                      },
    });

    // indent with spaces to match style guide
    editor.setOption("extraKeys", {
      Tab: function(cm) {
        var spaces = Array(cm.getOption("indentUnit") + 1).join(" ");
        cm.replaceSelection(spaces);
      }
    });

    $("input#validate").on('click', function(event){
      event.preventDefault();

      // propogates text to the textarea
      editor.save();

      $(this).closest('form').submit();
    });
  }
  else {
    $("textarea#code").keydown(function(e) {
        if(e.keyCode === 9) { // tab was pressed
            // get caret position/selection
            var start = this.selectionStart;
            var end = this.selectionEnd;

            var $this = $(this);
            var value = $this.val();

            // set textarea value to: text before caret + tab + text after caret
            $this.val(value.substring(0, start)
                        + "\t"
                        + value.substring(end));

            // put caret at right position again (add one for the tab)
            this.selectionStart = this.selectionEnd = start + 1;

            // prevent the loss of focus
            e.preventDefault();
        }
    });
  }

  if ($('select#versions option').length == 1) {
    $('select#versions').attr('disabled', true);
  }

  $('.share_icon').tooltip();
});
