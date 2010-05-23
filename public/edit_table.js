$(document).ready( function() {

var cell_blur = function() {
	console.debug( 'cell_blur'
		, this
		, $(this).val()
	);

	var x = $(this).parent().attr('cellIndex');
	var y = $(this).parent().parent().attr('rowIndex');

	var content = $(this).val();
	if ( 0 ) { // leave delimiters in edited cells visible
		var vals = content.split('¶');
		content = vals.join('<span class=d>¶</span>');
	}

//	var cell = $('<td>'+content+'</td>');
	$(this).replaceWith( content );

	var name = $('table tr th:nth('+x+') > a').text();
	console.info( x, y, name, content );
}

var cell_click = function(event) {
	console.debug( 'cell_click'
		, this
		, event
		, $(this).text()
	);
	var content = $(this).text(); // we don't want para markup
	var rows = content.split('¶').length * 2 + 1;
	var textarea = $('<textarea rows='+rows+'/>');
	textarea.val( content );
	$(this).html( textarea );
	textarea.focus();
	textarea.blur( cell_blur )
};


console.info('double-click on cell to edit it');
$('table td').live( 'dblclick', cell_click );

}); // document.ready


