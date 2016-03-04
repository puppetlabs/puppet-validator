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

$( document ).ready(function() {
  toggleChecks();

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

  if ($('select#versions option').length == 1) {
    $('select#versions').attr('disabled', true);
  }
  else {
    $('select#versions').change(function() {
      var action = ('/' + $( this ).val() + '/validate').replace(/^\/+/, '/');
      $('form').attr('action', action );
    });
  }

  $('.share_icon').tooltip();
});
