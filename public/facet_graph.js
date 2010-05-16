var data = {
	min_x: Number.MAX_VALUE,
	max_x: Number.MIN_VALUE,
	min_y: Number.MAX_VALUE,
	max_y: Number.MIN_VALUE,
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


var y_num_labels = Math.round( data.height / 20 ); // padding between vertical labels
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

ctx.moveTo( 0, 0 );
ctx.beginPath();

for( var i in data.x_data ) {
	var x = Math.ceil( ( data.x_data[i] - data.min_x ) / data.x_range * data.width  );
	var y = Math.ceil( ( data.y_data[i] - data.min_y ) / data.y_range * data.height );
//	console.debug( i, x, y );
	ctx.lineTo( x, -y );
	data.x_px.push( x );
}

ctx.stroke();
ctx.closePath();

var labels_x = $('<ul class="labels-x"></ul>')
	.css({ width: data.width, height: data.height, position: 'absolute' });

var x_pos = 0;

for( var i in data.x_data ) {
	if ( Math.abs( data.x_px[i] - x_pos ) > 20 ) {
		x_pos = data.x_px[i];
		$('<li><span class="line"></span><span class="label">' + data.x_data[i] + '</span></li>')
			.css({ left: x_pos })
			.appendTo(labels_x);
	}
}
labels_x.appendTo(canvasContain);

var labels_y = $('<ul class="labels-y"></ul>')
	.css({ width: data.width, height: data.height, position: 'absolute' });

for( var i in data.y_labels ) {
		$('<li><span class="line"></span><span class="label">' + data.y_labels[i] + '</span></li>')
			.css({ bottom: Math.ceil( data.y_labels[i] / data.y_range * data.height ) })
			.appendTo(labels_y);
}
labels_y.appendTo(canvasContain);
