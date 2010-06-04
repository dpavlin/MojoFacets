$(document).ready( function() {

var cell_blur = function() {
	console.debug( 'cell_blur'
//		, this
//		, $(this).val()
	);

/*
	// FIXME primary key is fixed to 1st column
	var pk = $('table tr th:nth(0) > a').text();
	var id = $(this).parent().siblings(':nth(0)').text()
*/
	var _row_id = $(this).parent().parent().attr('title');

	var x = $(this).parent().attr('cellIndex');
	var y = $(this).parent().parent().attr('rowIndex');

	var new_content = $(this).val();
//	$(this).replaceWith( new_content );

	var name = $('table tr th:nth('+x+') > a').text();
	console.info( x, y, _row_id, name, new_content );

	var update = $(this);

	$.post( '/data/edit', {
		path: document.title, _row_id: _row_id,
		name: name, new_content: new_content
	} , function(data, textStatus) {
		console.debug( 'data:', data, 'status:', textStatus );
		if ( ! data ) {
			data = new_content; // fallback to submited data for 304
		} else {
			if ( $('a.save_changes').length == 0 )
			$('a.changes').before('<a class=save_changes href="/data/save">save</a>')
		}
		var vals = data.split('¶');
		data = vals.join('<span class=d>¶</span>');
		update.replaceWith( data );
	});
}

var cell_click = function(event) {
	console.debug( 'cell_click'
		, this
		, event
		, $(this).text()
	);
	var new_content = $(this).text() // we don't want para markup
		.replace(/^[ \n\r]+/,'')
		.replace(/[ \n\r]+$/,'')
	;
console.debug( 'new_content', new_content );
	var rows = new_content.split('¶').length * 2 + 1;
	var textarea = $('<textarea rows='+rows+'/>');
	textarea.val( new_content );
	$(this).html( textarea );
	textarea.focus();
	textarea.blur( cell_blur )
};


console.info('double-click on cell to edit it');
$('table td').live( 'dblclick', cell_click );

}); // document.ready


