var data = {
	x_min: Number.MAX_VALUE,
	x_max: Number.MIN_VALUE,
	y_min: Number.MAX_VALUE,
	y_max: Number.MIN_VALUE,
	x_data: [],
	y_data: [],
	x_px: [],
	y_labels: [],
	width: 600,
	height: 400,
};

var ul = $('ul#facet');

ul.find('li label').each( function(){
	var v = parseFloat( $(this).text() );
	if ( isNaN(v) ) v = 0;
	if ( v > data.x_max ) data.x_max = v;
	if ( v < data.x_min ) data.x_min = v;
	data.x_data.push( v );
});

ul.find('li span.count').each( function(){
	var v = parseFloat( $(this).text() ); // FIXME not numeric!
	if ( isNaN(v) ) v = 0;
	if ( v > data.y_max ) data.y_max = v;
	if ( v < data.y_min ) data.y_min = v;
	data.y_data.push( v );
});

data.y_min = 0; // XXX force to 0, because it's count

data.x_range = data.x_max - data.x_min;
data.y_range = data.y_max - data.y_min;


var y_num_labels = Math.round( data.height / 20 ); // padding between vertical labels
var y_inc = Math.ceil( data.y_range / y_num_labels );

var y_pos = data.y_min;
var y_last_pos = Math.ceil( data.y_max - y_inc / 2 );
while( y_pos < y_last_pos ) {
	data.y_labels.push( y_pos );
	y_pos += y_inc;
}
data.y_labels.push( data.y_max );

data.numeric = $('span#numeric').length;
data.x_inc = data.numeric
	? Math.round( data.width / data.x_range )
	: data.width / data.x_data.length
	;

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
ctx.fillStyle = '#ffcc88';

ctx.moveTo( 0, 0 );
ctx.beginPath();

for( var i in data.x_data ) {
	var x = data.x_data[i];
	if ( data.numeric ) x = Math.ceil( ( x - data.x_min ) / data.x_range * data.width  );
	var y = Math.ceil( ( data.y_data[i] - data.y_min ) / data.y_range * data.height );
	if ( data.numeric ) {
		ctx.lineTo( x, -y );
		data.x_px.push( x );
	} else {
		var x_px = i * data.x_inc;
		console.debug( x_px, y );
		ctx.fillRect( x_px, 0, data.x_inc, -y );
		ctx.strokeRect( x_px, 0, data.x_inc, -y );
	}
}

ctx.stroke();
ctx.closePath();

if ( data.numeric ) {

var labels_x = $('<ul class="labels-x"></ul>')
	.css({ width: data.width, height: data.height, position: 'absolute' });

for( var x_pos = 0; x_pos < data.width; x_pos += data.x_inc ) {
	var x_val = ( x_pos / data.width * data.x_range ) + data.x_min;
	$('<li><span class="label">' + x_val + '</span></li>')
		.css({ left: x_pos })
		.appendTo(labels_x);
}

$('<li><span class="label">' + data.x_max + '</span></li>')
		.css({ right: 0 })
		.appendTo(labels_x);

labels_x.appendTo(canvasContain);

} // data.numeric

var labels_y = $('<ul class="labels-y"></ul>')
	.css({ width: data.width, height: data.height, position: 'absolute' });

for( var i in data.y_labels ) {
		$('<li><span class="line"></span><span class="label">' + data.y_labels[i] + '</span></li>')
			.css({ bottom: Math.ceil( ( data.y_labels[i] - data.y_min ) / data.y_range * data.height ) })
			.appendTo(labels_y);
}
labels_y.appendTo(canvasContain);
