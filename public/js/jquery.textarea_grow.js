jQuery.fn.textarea_grow = function(){
	return this.each(function(){
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
};

