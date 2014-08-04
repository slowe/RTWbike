#!/usr/bin/perl
#============================================
# Parse .gpx files into a single geojson file
#============================================

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

$dir =~ s/\/$//g;

# Read the directory for .gpx files
opendir($dh,$dir);
@files = ();
while(readdir $dh) {
	print "$dir/$_\n";
	if($_ =~ /^.*.gpx$/){
		push(@files,$_);
	}
}
closedir($dh);


$output = "{\n\t\"type\": \"FeatureCollection\",\n\t\"features\": [\n";

$f = 0;

# Process each track
foreach $file (@files){

	open(GPX,"$dir/$file");
	@lines = <GPX>;
	close(GPX);

	$name = "";
	@lats = ();
	@lons = ();

	if(@lines == 1){
		@lines = split(/<\/trkpt>/,$lines[0]);
	}

	foreach $line (@lines){
		if($line =~ /<trkpt lat="([^\"]*)" lon="([^\"]*)">/){
			push(@lats,$1);
			push(@lons,$2);
		}
	}
	
	# Make the name for this section of track based on the date
	$name = $file;
	$name =~ s/\.gpx//g;

	if($name){
		if($f > 0){
			$output .= ",\n";
		}
		
		$output .= "\t\t{\n\t\t\t\"type\": \"Feature\",\n\t\t\t\"properties\": {\n\t\t\t\t\"name\": \"$name\",\n\t\t\t\t\"desc\": \"$name\",\n\t\t\t\t\"time\": \"2014-04-22T08:05:00+0800\"\n\t\t\t},\n\t\t\t\"geometry\": {\n\t\t\t\t\"type\": \"LineString\",\n\t\t\t\t\"coordinates\": [\n";
		for($i = 0 ; $i < @lats; $i++){
			if($i > 0){
				$output .= ",\n";
			}
			$output .= "\t\t\t\t\t[".sprintf("%.8f",$lons[$i]).",".sprintf("%.8f",$lats[$i])."]";
		}
		$output .= "\n\t\t\t\t]\n\t\t\t}\n\t\t}";
	
		$f++;
		print "$name ($file)\n";
	}
}

$output .= "\n\t]\n}";

open(FILE,">","lowe2014real.geojson");
print FILE $output;
close(FILE);

print "\n";