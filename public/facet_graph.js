var data = {
	min_x: 0,
	max_x: 0,
	min_y: 0,
	max_y: 0,
	x_data: [],
	y_data: [],
	y_labels: [],
	width: 600,
	height: 400,
};

var ul = $('ul#facet');

ul.find('li label').each( function(){
	var v = parseFloat( $(this).text() );
	if ( isNaN(v) ) v = 0;
	if ( v > data.max_x ) data.max_x = v;
	if ( v < data.min_x ) data.min_x = v;
	data.x_data.push( v );
});

ul.find('li span.count').each( function(){
	var v = parseFloat( $(this).text() ); // FIXME not numeric!
	if ( isNaN(v) ) v = 0;
	if ( v > data.max_y ) data.max_y = v;
	if ( v < data.min_y ) data.min_y = v;
	data.y_data.push( v );
});


data.x_range = data.max_x - data.min_x;
data.y_range = data.max_y - data.min_y;


var y_num_labels = Math.round( data.height / 30 ); // padding between vertical labels
var y_inc = Math.ceil( data.y_range / y_num_labels );

var y_pos = data.min_y;
while( y_pos < data.max_y - y_inc ) {
	data.y_labels.push( y_pos );
	y_pos += y_inc;
}
data.y_labels.push( data.max_y );

console.debug( 'data', data );

var canvas = $('<canvas/>');

canvas.attr({
	width: data.width,
	height: data.height,
});

var canvasContain = $('<div class="chart"></div>')
	.css({ width: data.width, height: data.height })
	.append( canvas )
	.insertBefore( ul );

var ctx = canvas[0].getContext('2d');
ctx.translate( 0, data.height ); // start at bottom left
ctx.lineWidth = 2;
ctx.strokeStyle = '#ff8800';

ctx.moveTo( 0, -data.y_data[0] );
ctx.beginPath();

for( var i in data.x_data ) {
	var x = Math.ceil( ( data.x_data[i] - data.min_x ) / data.x_range * data.width  );
	var y = Math.ceil( ( data.y_data[i] - data.min_y ) / data.y_range * data.height );
	console.debug( i, x, y );
	ctx.lineTo( x, -y );
}

ctx.stroke();
ctx.closePath();

