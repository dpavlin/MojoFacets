var data = {
	x: {
		min: Number.MAX_VALUE,
		max: Number.MIN_VALUE,
		range: 0,
		inc: 0,
		inc_bar: 0,
		data: [],
		px: [],
		num_labels: 0,
		label_spacing: 30,
	},
	y: {
		min: Number.MAX_VALUE,
		max: Number.MIN_VALUE,
		range: 0,
		data: [],
		inc: 0,
		num_labels: 0,
		label_spacing: 25,
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



data.numeric = $('span#numeric').length;
data.x.inc_bar = data.numeric
	? Math.round( data.width / data.x.range )
	: data.width / data.x.data.length
	;

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
		var x_px = i * data.x.inc_bar;
		console.debug( x_px, y );
		ctx.fillRect( x_px, 0, data.x.inc_bar, -y );
		ctx.strokeRect( x_px, 0, data.x.inc_bar, -y );
	}
}

ctx.stroke();
ctx.closePath();

function draw_labels(class_name,axis,size,css_pos,last_css_pos) {

	var labels = $('<ul class="'+class_name+'"></ul>')
		.css({ width: data.width, height: data.height, position: 'absolute' });

	axis.num_labels = Math.round( size / axis.label_spacing );
	if ( axis.num_labels > axis.range ) axis.num_labels = axis.range;
	axis.inc = Math.ceil( axis.range / axis.num_labels );

	for( var val = axis.min; val < axis.max ; val += axis.inc ) {
		var pos = Math.ceil( ( val - axis.min ) / axis.range * size );
		$('<li style="'+css_pos+': '+pos+'px"><span class="line"></span><span class="label">' + val + '</span></li>')
			.appendTo(labels);
	}

	$('<li style="'+last_css_pos+'"><span class="line"></span><span class="label">' + axis.max + '</span></li>')
		.appendTo(labels);

	labels.appendTo(canvasContain);

}

if ( data.numeric )  draw_labels( 'labels-x', data.x, data.width, 'left', 'right:0px' );

draw_labels( 'labels-y', data.y, data.height, 'bottom', 'bottom:'+data.height+'px' );


console.debug( 'data', data );

