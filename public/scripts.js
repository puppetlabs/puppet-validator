function toggleChecks() {
  var enabled = $('input#lint').is(":checked");

  $('ul#checks input').attr('disabled', ! enabled);
}

function toggleMenu() {
  $('#checks-menu').slideToggle();
}

function loadPaste() {
  var location = $('#location').val();
  window.location = "/load/"+location;
}

function gist() {
  var code = $('#code').val();
  if (typeof(code) == 'string' && $.trim(code).length != 0) {
    var data = {
      "description": "Validated by " + window.location.origin + '/load/referer',
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
        popup(null, { text: 'Gist posted to:', url: response['html_url'] } );
      })
      .error(function(error) {
        console.warn("Cannot save gist: ", error);
        popup('Gist save failed.', { text: error });
      });
  }
}

function popup(title, options) {
  var dialog = $('<div id="popup" />');
  var params = {
      modal: true,
      title: title,
      buttons: {
          Ok: function () {
              $(this).dialog("close");
              $("#popup").remove();
          }
      }
  };

  if (typeof options === 'object') {
    if('html' in options) {
       dialog.append( $(options.html) );
    }
    if('text' in options) {
       dialog.append( $("<p/>").text(options.text) );
    }
    if('url' in options) {
      dialog.append( '<ul><li id="url"></li></ul>' )
      dialog.find('li#url').append( $("<a />", { href: options.url, text: options.url }) );
    }

    if('height' in options) {
      params.height = options.height;
    }
    if('width' in options) {
      params.width = options.width;
    }
  }

  $(dialog).dialog(params);
}

function showRelationships() {
  if(typeof editor != 'undefined' ) { editor.save(); }

  $('#relationships').prop("disabled",true);
  $('html,body').css('cursor','wait');

  $.post('/api/v0/validate/relationships', {code: $('#code').val()}, function(data) {
    popup('Resource Relationships', {
        html: '<center>'+data+'</center>',
       width: $(window).width() * .8,
      height: $(window).height() * .8
    });

  }).fail(function(jqXHR) {
    alert("Unknown API error:\n" + jqXHR.responseText);

  }).always(function() {
    $('html,body').css('cursor','default');
    $('#relationships').prop("disabled",false);
  });
}

function puppet_validator(cm, updateLinting, options) {
  if(typeof editor == 'undefined' ) { return null; }

  // propogates text to the textarea
  editor.save();

  var output  = $('#results');
  var spinner = $('#spinner');
  var message = $('#message');
  var version = $('#version');
  var wrapper = $('form');
  var params  = {
       code: $('#code').val(),
    version: $('#versions').val(),
  };

  if( $('input#lint').is(':checked') ) {
    params['lint']   = true;
    params['checks'] = $('#checks input:checked').map(function() { return this.value; }).get();
  }

  message.empty();
  spinner.show();
  output.removeClass('hidden');
  output.removeClass('validated');
  $('#validate').prop("disabled",true);

  var errors = [];
  $.post('/api/v0/validate', params, function(data) {
    console.log(data);
    var results = jQuery.parseJSON(data);

    spinner.hide();
    message.text(results['message']);
    version.text(results['version']);
    wrapper.addClass('validated');
    output.addClass('validated');

    if(results.success) {
      wrapper.removeClass('failed');
      output.removeClass('failed');
      $('#share').show();
    }
    else {
      wrapper.addClass('failed');
      output.addClass('failed');
      $('#share').hide();

      if('line' in results) {
        var min = Math.max(results['line'] - 3, 0);
        var max = Math.min(results['line'] + 3, editor.lineCount());
        editor.scrollIntoView(min, max);
      }
    }

    if ('messages' in results) {
      var messages = results['messages'];
      for ( var i = 0; i < messages.length; i++) {
        var item = messages[i];
        errors.push({
              from: CodeMirror.Pos(item.from[0], item.from[1]),
                to: CodeMirror.Pos(item.to[0],   item.to[1]  ),
           message: item.message,
          severity: item.severity
        });
      }
      updateLinting(errors);
    }
  }).fail(function(jqXHR) {
    alert("Unknown API error:\n" + jqXHR.responseText);
  }).always(function() {
    spinner.hide();
    $('#validate').prop("disabled",false);
  });
}


$( document ).ready(function() {
  toggleChecks();
  $('#checks-menu').hide();

  $("input#load").on('click', function(event){
    event.preventDefault();
    loadPaste();
  });

  $("input#relationships").on('click', function(event){
    event.preventDefault();
    showRelationships();
  });

  // don't fail if the theme doesn't load codemirror
  if(typeof CodeMirror != 'undefined') {
    var textbox = $("textarea#code")[0]
    editor = CodeMirror.fromTextArea(textbox, {
         lineNumbers: true,
         smartIndent: true,
      indentWithTabs: true,
     styleActiveLine: true,
                mode: 'puppet',
             gutters: ["CodeMirror-lint-markers"],
                lint: {
                        getAnnotations: puppet_validator,
                          lintOnChange: false,
                                 async: true
                      },
    });

    // this is slow as crap. There must be a faster way.
    editor.on("renderLine", function(cm, lineHandle, element) {
      if(element.querySelector('.CodeMirror-lint-mark-error')) {
        //cm.getDoc().addLineClass(lineHandle, 'wrap', 'CodeMirror-lint-mark-error');
        element.classList.add('CodeMirror-lint-mark-error');
      }

      if(element.querySelector('.CodeMirror-lint-mark-warning')) {
        //cm.getDoc().addLineClass(lineHandle, 'wrap', 'CodeMirror-lint-mark-warning');
        element.classList.add('CodeMirror-lint-mark-warning');
      }
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
      editor.performLint();
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
