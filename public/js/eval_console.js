$(document).ready( function(){

	var $form = $('form#eval');

	$form.find('textarea').each( function() {
		console.debug('grow',this);

		var rows = this.rows;
		console.debug( 'textarea_grow', rows, this );
		var grow = function(ta) {
    		var lines = ta.value.split('\n').length;
			if ( lines != rows ) {
				ta.rows = lines;
				rows    = lines;
				console.debug('keyup', lines, rows, ta );
			}
		};
		grow(this);
		this.onkeyup = function() { grow(this) };
	});

	if ( $form.is(':visible') ) {
		$('body').css({ 'margin-bottom': $form.height() });
	}

	$('input#close').click( function(){
		console.debug( 'close console' );
		$.post( document.location, { code: '' } );
		$(this).parent().hide();
	});

	var $out = $('pre#out');
	if ( $out.height() > ( $(window).height() / 3 * 2 ) ) {
		$out.height( $(window).height() / 3 * 2 ).css({ overflow: 'auto' });
	}

	$('a#console').click( function() {
		console.debug('open console');
		var $f = $('form#eval');
		if ( $f.is(':visible') ) {
			$f.hide();
			$('body').css({ 'margin-bottom': 0 });
		} else {
			$f.show();
			$('body').css({ 'margin-bottom': $form.height() });
		}
		return false;
	}).show();

});

