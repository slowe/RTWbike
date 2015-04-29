#!/usr/bin/perl
#============================================================
# Parse a directory of .gpx files into a single geojson file
#============================================================

$dir = $ARGV[0];

# Error case 1
if(!$dir){
	print "You need to provide a directory.\n";
	exit;
}

# Error case 2
if(!-d $dir){
	print "$dir is not a directory.\n";
	exit;
}

#$dir =~ s/\/$//g;
$mn = 1e9;
$mx = 0;

# Read the directory for .gpx files
opendir($dh,$dir);
@files = ();
@filenames = sort readdir( $dh );
print @filenames;
foreach $file (@filenames){
	if($file =~ /\.gpx$/ && -s $dir.$file > 0){
		if($file =~ /([0-9]+)/){
			if($1 < $mn){ $mn = $1; }
			if($1 > $mx){ $mx = $1; }
		}
		push(@files,$file);
	}
}
closedir($dh);

print $mn." ".$mx."\n";

$output = "{\n\t\"type\": \"FeatureCollection\",\n\t\"features\": [\n";

$f = 0;

# Process each track
for($n = $mn ; $n <= $mx; $n++){

	$file = "route".$n.".gpx";

	open(GPX,"$dir/$file");
	@lines = <GPX>;
	close(GPX);

	$name = "";
	$desc = "";
	@lats = ();
	@lons = ();

	if(@lines == 1){
		@lines = split(/<\/trkpt>/,$lines[0]);
	}

	foreach $line (@lines){
		if(!$desc && $line =~ /<name>([^\<]*)<\/name>/){
			$desc = $1;
		}
		if($line =~ /<[^\s]+ lat="([^\"]*)" lon="([^\"]*)">/){
			push(@lats,$1);
			push(@lons,$2);
		}
	}
	
	if(!$name){
		# Make the name for this section of track based on the date
		$name = $file;
		$name =~ s/\.gpx//g;
	}

	if($name){

		if($f > 0){
			$output .= ",\n";
		}
	
		$output .= "\t\t{\n\t\t\t\"type\": \"Feature\",\n\t\t\t\"properties\": {\n\t\t\t\t\"name\": \"$name\",\n\t\t\t\t\"desc\": \"$desc\",\n\t\t\t\t\"time\": \"2015-05-02T16:00:00+0100\",\n\t\t\t\t\"stroke\": \"#009d00\"\n\t\t\t},\n\t\t\t\"geometry\": {\n\t\t\t\t\"type\": \"LineString\",\n\t\t\t\t\"coordinates\": [\n";
		
		for($i = 0 ; $i < @lats; $i++){
			if($i > 0){
				$output .= ",\n";
			}
			$output .= "\t\t\t\t\t[".sprintf("%.8f",$lons[$i]).",".sprintf("%.8f",$lats[$i])."]";
		}
	
		$f++;
		print "$name ($file)\n";
		$output .= "\n\t\t\t\t]\n\t\t\t}\n\t\t}";
	}
}

$output .= "\n\t]\n}";

open(FILE,">","lowe2015.geojson");
print FILE $output;
close(FILE);

print "\n";