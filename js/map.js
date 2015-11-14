function r(f){/in/.test(document.readyState)?setTimeout('r('+f+')',9):f()}

function loadJSON(file,fn,attrs){

	if(!attrs) attrs = {};
	attrs['_file'] = file;

    var httpRequest = new XMLHttpRequest();
    httpRequest.onreadystatechange = function() {
        if (httpRequest.readyState === 4) {
            if (httpRequest.status === 200) {
                var data = JSON.parse(httpRequest.responseText);
                if(typeof fn==="function") fn.call((attrs['this'] ? attrs['this'] : this),data,attrs);
            }else{
				console.log('error loading '+file)
				if(typeof attrs.error==="function") attrs.error.call((attrs['this'] ? attrs['this'] : this),httpRequest.responseText,attrs);
            }
        }
    };
    httpRequest.open('GET', file);
    httpRequest.send(); 
}

r(function(){

	var maps = document.getElementsByClassName('map');

	// Load the data files
	for(var i = 0; i < maps.length; i++) loadJSON(maps[i].getAttribute('data-file'),parseIt,{'el':maps[i]});


	function parseIt(data,attrs){

		var west = 180;
		var east = -180;
		var north = -90;
		var south = 90;

		for(var i = 0 ; i < data.features[0].geometry.coordinates.length; i++){
			// Check longitude
			lonlat = data.features[0].geometry.coordinates[i];
			if(lonlat[0] > east) east = lonlat[0];
			if(lonlat[0] < west) west = lonlat[0];
			if(lonlat[1] > north) north = lonlat[1];
			if(lonlat[1] < south) south = lonlat[1];
		}

		var mid = Math.floor(data.features[0].geometry.coordinates.length/2);
		var coor = [data.features[0].geometry.coordinates[mid][1],data.features[0].geometry.coordinates[mid][0]]
		var mapid = attrs.el.getAttribute('id');
		//var map = L.map(mapid).setView(coor, 9);
		var map = L.map(mapid).fitBounds([
			[south, west],
			[north, east]
		]);
		L.control.scale().addTo(map);

		// add an OpenStreetMap tile layer
		L.tileLayer('http://{s}.tile.osm.org/{z}/{x}/{y}.png', {
			attribution: 'Map tiles/data by <a href="http://openstreetmap.org">OpenStreetMap</a> (ODbL)',
				maxZoom: 17
		}).addTo(map);
		
		L.geoJson(data.features[0]).addTo(map);

		return true;
	}

});