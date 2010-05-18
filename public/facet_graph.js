var data = {
	x: {
		min: Number.MAX_VALUE,
		max: Number.MIN_VALUE,
		range: 0,
		inc: 0,
		data: [],
		px: [],
	},
	y: {
		min: Number.MAX_VALUE,
		max: Number.MIN_VALUE,
		range: 0,
		data: [],
		inc: 0,
		num_labels: 0,
		labels: [],
	},
	width: 600,
	height: 400,
};

var ul = $('ul#facet');

ul.find('li label').each( function(){
	var v = parseFloat( $(this).text() );
	if ( isNaN(v) ) v = 0;
	if ( v > data.x.max ) data.x.max = v;
	if ( v < data.x.min ) data.x.min = v;
	data.x.data.push( v );
});

ul.find('li span.count').each( function(){
	var v = parseFloat( $(this).text() ); // FIXME not numeric!
	if ( isNaN(v) ) v = 0;
	if ( v > data.y.max ) data.y.max = v;
	if ( v < data.y.min ) data.y.min = v;
	data.y.data.push( v );
});

data.y.min = 0; // XXX force to 0, because it's count

data.x.range = data.x.max - data.x.min;
data.y.range = data.y.max - data.y.min;


var y_num_labels = Math.round( data.height / 20 ); // padding between vertical labels
data.y.inc = Math.ceil( data.y.range / y_num_labels );

var y_last_pos = Math.ceil( data.y.max - data.y.inc / 2 );
for( var y_pos = data.y.min; y_pos < y_last_pos; y_pos += data.y.inc ) {
	data.y.labels.push( y_pos );
}
data.y.labels.push( data.y.max );

data.numeric = $('span#numeric').length;
data.x.inc = data.numeric
	? Math.round( data.width / data.x.range )
	: data.width / data.x.data.length
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

for( var i in data.x.data ) {
	var x = data.x.data[i];
	if ( data.numeric ) x = Math.ceil( ( x - data.x.min ) / data.x.range * data.width  );
	var y = Math.ceil( ( data.y.data[i] - data.y.min ) / data.y.range * data.height );
	if ( data.numeric ) {
		ctx.lineTo( x, -y );
		data.x.px.push( x );
	} else {
		var x_px = i * data.x.inc;
		console.debug( x_px, y );
		ctx.fillRect( x_px, 0, data.x.inc, -y );
		ctx.strokeRect( x_px, 0, data.x.inc, -y );
	}
}

ctx.stroke();
ctx.closePath();

if ( data.numeric ) {

var labels_x = $('<ul class="labels-x"></ul>')
	.css({ width: data.width, height: data.height, position: 'absolute' });

for( var x_pos = 0; x_pos < data.width; x_pos += data.x.inc ) {
	var x_val = ( x_pos / data.width * data.x.range ) + data.x.min;
	$('<li><span class="label">' + x_val + '</span></li>')
		.css({ left: x_pos })
		.appendTo(labels_x);
}

$('<li><span class="label">' + data.x.max + '</span></li>')
		.css({ right: 0 })
		.appendTo(labels_x);

labels_x.appendTo(canvasContain);

} // data.numeric

var labels_y = $('<ul class="labels-y"></ul>')
	.css({ width: data.width, height: data.height, position: 'absolute' });

for( var i in data.y.labels ) {
		$('<li><span class="line"></span><span class="label">' + data.y.labels[i] + '</span></li>')
			.css({ bottom: Math.ceil( ( data.y.labels[i] - data.y.min ) / data.y.range * data.height ) })
			.appendTo(labels_y);
}
labels_y.appendTo(canvasContain);
