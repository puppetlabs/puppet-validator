function toggleChecks() {
  var enabled = $('input#lint').is(":checked");

  $('ul#checks input').attr('disabled', ! enabled);
}

function toggleMenu() {
  $('#checks-menu').slideToggle();
  return false;
}
