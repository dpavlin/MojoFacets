$(document).ready( function() {

var cell_blur = function() {
	console.debug( 'cell_blur'
		, this
		, $(this).val()
	);
	var content = $(this).val();
	var cell = $('<td>'+content+'</td>');
	$(this).replaceWith( cell );
	console.info( cell );
}

var cell_click = function(event) {
	console.debug( 'cell_click'
		, this
		, event
		, $(this).text()
	);
	var content = $(this).text(); // we don't want para markup
	var textarea = $('<textarea />');
	textarea.val( content );
	$(this).html( textarea );
	textarea.focus();
	textarea.blur( cell_blur )
};


console.info('double-click on cell to edit it');
$('table td').live( 'dblclick', cell_click );

}); // document.ready


