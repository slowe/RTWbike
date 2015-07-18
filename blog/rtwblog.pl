#!/usr/bin/perl
###################################
# Config

$dir = "./";

# Read in config
open(FILE,"README.md");
@lines = <FILE>;
close(FILE);

$inbody = 0;
$recent = 4;
for($i = 0; $i < @lines ; $i++){
	$lines[$i] =~ s/[\n\r]//g;
	if($lines[$i] =~ /^Title\:[\t\s]+(.*)$/){ $maintitle = $1; }
	if($lines[$i] =~ /^Link\:[\t\s]+(.*)$/){ $link = $1; }
	if($lines[$i] =~ /^Flickr\:[\t\s]+(.*)$/){ $flickr = $1; }
	if($lines[$i] =~ /^Recent\:[\t\s]+(.*)$/){ $recent = $1; }
	if($lines[$i] =~ /^Author\:[\t\s]+(.*)$/){ $author = $1; }
}

###################################

# Read in template file
open(FILE,"template.html");
@template = <FILE>;
close(FILE);

# Read in entry template file
open(FILE,"template_entry.html");
@template_entry = <FILE>;
close(FILE);


# Read the directory containing the Markdown files
opendir(my $dh, $dir);
@filenames = sort readdir( $dh );
@files = ();
@htmls = ();
foreach $file (@filenames){
	if($file =~ /[0-9]+\.md$/){
		push(@files,$file);
		$file =~ s/\.md/\.html/g;
		push(@htmls,$file);
	}
}
closedir $dh;

$oldmonth = "";

$list = "";
@posts = ();

for($i = 0; $i < @files; $i++){
	$file = $files[$i];
	print "$dir$file\n";
	preProcessPost($dir.$file);
	($title,$date,$post) = processPost($dir.$file);
	$d = getDate(getJulianFromISO($date),"%D %d%e %M %Y (%t %Z)");
	$month = getDate(getJulianFromISO($date),"%B %Y");

	$html = "";
	$content = "";
	$indent = "";
	$indent_entry = "";
	foreach $line (@template_entry){
		if($line =~ /^(.*)\%ENTRY\%/){ $indent_entry = $1; }
	}
	foreach $line (@template){
		if($line =~ /^(.*)\%CONTENT\%/){ $indent = $1; }
	}

	$post =~ s/([\n\r])/$1$indent$indent_entry/g;
	$nav = "<nav>";
	if($i > 0){ $nav .= "<a href=\"".$htmls[$i-1]."\" class=\"prev\">previous</a>"; }
	#$nav .= "<a href=\"archive.html\" class=\"archive\">archive</a>";
	if($i < @files - 1){ $nav .= "<a href=\"".$htmls[$i+1]."\" class=\"next\">next</a>"; }
	$nav .= "</nav>\n";
	
	foreach $line (@template_entry){
		$str = $line;
		$str =~ s/\%NAV\%/$nav/g;
		$str =~ s/\%TITLE\%/$title/g;
		$str =~ s/\%AUTHOR\%/$author/g;
		$str =~ s/\%POSTDATE\%/<time pubdate=\"$date\" datetime=\"$date\">$d<\/time>/g;
		$str =~ s/\%ENTRY\%/$post/g;
		$str =~ s/\%[^\%]+\%//g;
		$content .= $indent.$str;
	}
	$idx = "";
	foreach $line (@template_entry){
		$str = $line;
		$str =~ s/\%NAV\%//g;
		$str =~ s/\%TITLE\%/<a href="$htmls[$i]">$title<\/a>/g;
		$str =~ s/\%AUTHOR\%/$author/g;
		$str =~ s/\%POSTDATE\%/<time pubdate=\"$date\" datetime=\"$date\">$d<\/time>/g;
		$str =~ s/\%ENTRY\%/$post/g;
		$str =~ s/\%[^\%]+\%//g;
		$idx .= $indent.$str;
	}
	push(@posts,$idx);

	foreach $line (@template){
		$str = $line;
		$str =~ s/\%TITLE\%/$title/g;
		$str =~ s/\%CONTENT\%/$content/g;
		
		$html .= $str;
	}
	
	open(FILE,">","$dir$htmls[$i]");
	print FILE "$html\n";
	close(FILE);

	if(!$list){ $list = "$indent</ul>\n"; }
	if($oldmonth && $month ne $oldmonth){
		$list = "$indent</ul>\n$indent<h2>$oldmonth</h2>\n$indent<ul>\n".$list;
	}
	$list = "$indent\t<li><a href=\"$htmls[$i]\">$title</a></li>\n".$list;

	$oldmonth = $month;
	
	if(@posts > $recent){ shift(@posts); }
}

$list = "$indent<h2>$oldmonth</h2>\n$indent<ul>\n".$list;

# Construct the archive page
$html = "";
foreach $line (@template){
	$str = $line;
	$str =~ s/\%TITLE\%/$maintitle/g;
	$str =~ s/\%CONTENT\%/\n$list/g;	
	$html .= $str;
}
open(FILE,">","archive.html");
print FILE "$html";
close(FILE);

# Construct the index page
$content = "";
$html = "";
for($i = @posts-1 ; $i >= 0 ; $i--){ $content .= $posts[$i]; }

$content .= "<nav><a href=\"archive.html\" class=\"next\">archive</a></nav>\n";

foreach $line (@template){
	$str = $line;
	$str =~ s/\%TITLE\%/$maintitle/g;
	$str =~ s/\%CONTENT\%/$content/g;
	$html .= $str;
}

open(FILE,">","index.html");
print FILE "$html";
close(FILE);



#################################
# Sub-routines

sub preProcessPost {
	local($inbody,$i,$file,@lines,$line,$post,$url,$newurl,$update);
	local $file = $_[0];

	open(FILE,$file);
	@lines = <FILE>;
	close(FILE);

	$post = "";
	for($i = 0; $i < @lines ; $i++){
		$lines[$i] =~ s/[\n\r]//g;
		$post .= $lines[$i]."\n";
	}

	$update = 0;

	# Turn basic short Flickr links into link to small jpg version
	#$post =~ s/flic.kr\/p\/([^\.\s]+)/flic.kr\/p\/img\/$1\_m.jpg/g;
	while($post =~ /(https?:\/\/flic.kr\/p\/)([^\.\s]+)/){
		$url = $1.$2;
		$newurl = $1."img/".$2."_m.jpg";
		$newurl = effectiveURL($newurl);
		$newurl =~ s/\_m.jpg/.jpg/;	# medium, 500 on longest side: https://www.flickr.com/services/api/misc.urls.html
		$post =~ s/$url/$newurl/g;
		$update++;
	}

	if($update > 0){
		open(FILE,">",$file);
		print FILE $post;
		close(FILE);
		print "Updating Flickr links in $file\n";
	}
	
	return;
}

sub effectiveURL {
	return `curl -Ls -o /dev/null -w %{url_effective} $_[0]`;
}

sub processPost {
	local($inbody,$i,$file,@lines,$line,$title,$date,$post);
	local $file = $_[0];

	open(FILE,$file);
	@lines = <FILE>;
	close(FILE);

	$post = "";
	$inbody = 0;
	for($i = 0; $i < @lines ; $i++){


		$lines[$i] =~ s/[\n\r]//g;
		if($inbody == 2){ $post .= $lines[$i]."\n"; }
		if($lines[$i] =~ /^Date\:\t(.*)$/){ $date = $1; }
		if($lines[$i] =~ /^Title\:\t(.*)$/){ $title = $1; }
		if($lines[$i] =~ /^\-\-\-/){ $inbody++; }

	}
	$post = Markdown2HTML($post);
	return ($title,$date,$post);
}

# My own routine to convert Markdown to HTML
sub Markdown2HTML {
	my $md = $_[0];

	# Convert italic
	$md =~ s/(^|\W)\_\_/$1<em>/g;
	$md =~ s/\_\_(\W|$)/<\/em>$1/g;

	# Convert bold
	$md =~ s/(^|\W)\*\*/$1<strong>/g;
	$md =~ s/\*\*(\W|$)/<\/strong>$1/g;

	# Convert strike through
	$md =~ s/\~\~([^\~]{1,})\~\~/<strike>$1<\/strike>/g;

	# Make block quotes
	$md =~ s/[\n\r][\>] ([^\n\r]*)[\n\r]/\n<blockquote>"$1"<\/blockquote>\n/g;

	# Add paragraph splits
	$md =~ s/\n\n/<\/p>\n\n<p>/g;

	# Make Flickr links
	$md =~ s/\!\[landscape]\(https:\/\/www.flickr.com([^\s]+) \"([^\"]*)\"\)/<figure class=\"landscape\"><iframe src="https:\/\/www.flickr.com$1\/player\/" height="333" width="500" frameborder="0" allowfullscreen webkitallowfullscreen mozallowfullscreen oallowfullscreen msallowfullscreen><\/iframe><figcaption>$2<\/figcaption><\/figure>/g;
	$md =~ s/\!\[]\(https:\/\/www.flickr.com([^\s]+) \"([^\"]*)\"\)/<figure class=\"landscape\"><iframe src="https:\/\/www.flickr.com$1\/player\/" height="333" width="500" frameborder="0" allowfullscreen webkitallowfullscreen mozallowfullscreen oallowfullscreen msallowfullscreen><\/iframe><figcaption>$2<\/figcaption><\/figure>/g;
	$md =~ s/\!\[portrait]\(https:\/\/www.flickr.com([^\s]+) \"([^\"]*)\"\)/<figure class=\"portrait\"><iframe src="https:\/\/www.flickr.com$1\/player\/" height="750" width="500" frameborder="0" allowfullscreen webkitallowfullscreen mozallowfullscreen oallowfullscreen msallowfullscreen><\/iframe><figcaption>$2<\/figcaption><\/figure>/g;
	$md =~ s/\!\[panorama]\(https:\/\/www.flickr.com([^\s]+) \"([^\"]*)\"\)/<figure class=\"full\"><iframe src="https:\/\/www.flickr.com$1\/player\/" height="500" width="500" frameborder="0" allowfullscreen webkitallowfullscreen mozallowfullscreen oallowfullscreen msallowfullscreen><\/iframe><figcaption>$2<\/figcaption><\/figure>/g;

	$md =~ s/\!\[panorama]\((https:\/\/farm[0-9]*.staticflickr.com\/[0-9]+\/)([^\_]+)([^\s]+) \"([^\"]*)\"\)/<figure class=\"full\"><a href=\"$flickr$2\"><img src=\"$1$2$3\" alt=\"panorama\" title=\"$4\" \/><\/a><figcaption>$4<\/figcaption><\/figure>/g;
	$md =~ s/\!\[[^\]]*]\((https:\/\/farm[0-9]*.staticflickr.com\/[0-9]+\/)([^\_]+)([^\s]+) \"([^\"]*)\"\)/<figure class=\"landscape\"><a href=\"$flickr$2\"><img src=\"$1$2$3\" alt=\"photo\" title=\"$4\" \/><\/a><figcaption>$4<\/figcaption><\/figure>/g;

	# Make images
	$md =~ s/\!\[([^\]]*)]\(([^\s]+) \"([^\"]*)\"\)/<figure class=\"$1\"><img src="$2" alt="$1" title="$3" \/><figcaption>$3<\/figcaption><\/figure>/g;

	# Make links
	$md =~ s/\[([^\]]*)\]\(([^\)]*)\)/<a href="$2">$1<\/a>/g;

	$md =~ s/^[\n\r]//g;
	$md =~ s/[\n\r]$//g;
	return "<p>".$md."</p>";
}



sub getDate {
	my $mytime = $_[0];
	my $format = $_[1];
	my $mytime2;
	my $tz;
	my $sec;
	my $min;
	my $hour;
	my $mday;
	my $mon;
	my $year;
	my $wday;
	my $ext;
	my $date;
	my $newtz;
	local ($shorttime,$longtime);
	
	my @days   = ('Sun','Mon','Tue','Wed','Thu','Fri','Sat');
	my @longdays   = ('Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday');
	my @months = ('Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec');
	my @monthslong = ('January','February','March','April','May','June','July','August','September','October','November','December');

	# Get all the date variables
	$mytime2 = $mytime;

	($sec,$min,$hour,$mday,$mon,$year,$wday,$tz) = (&getUnixDate($mytime))[0,1,2,3,4,5,6,7];

	if(!$tz){ $tz = "UT"; }

	# Format the time.
	$shorttime = sprintf("%02d:%02d",$hour,$min);
	$longtime = $shorttime.":".sprintf("%02d",$sec);

	# Add th,st,nd,rd
	if($mday%10 == 1 && $mday != 11){ $ext = "st"; }
	elsif($mday%10 == 2 && $mday != 12){ $ext = "nd"; }
	elsif($mday%10 == 3 && $mday != 13){ $ext = "rd"; }
	else{ $ext = "th"; }

	$mon = sprintf("%02d",$mon);
	$mday = sprintf("%02d",$mday);
	# Format the date.
	if($format){
		$date = $format;
		$date =~ s/\%D/$longdays[$wday]/g;
		$date =~ s/\%a/$days[$wday]/g;
		$date =~ s/\%d/$mday/g;
		$date =~ s/\%Y/$year/g;
		$date =~ s/\%M/$months[$mon-1]/g;
		$date =~ s/\%B/$monthslong[$mon-1]/g;
		$date =~ s/\%m/$mon/g;
		$date =~ s/\%T/$longtime/g;
		$date =~ s/\%t/$shorttime/g;
		$date =~ s/\%e/$ext/g;
		$date =~ s/\%Z/$tz/g;
		$newtz = getTimeZones("RFC-822",$tz);
		$date =~ s/\%z/$newtz/g;
	}else{	$date = "$days[$wday] $mday$ext $months[$mon-1] $year ($shorttime)"; }
	return $date;
}

sub getJulianFromISO {
	my ($dd,$tt,$iso,$y,$m,$d,$h,$mn,$sc,$tz,$tz_offset,$tzh,$tzm);
	$iso = $_[0];
	$dd = substr($iso,0,10);
	$tt = substr($iso,11);
	($y,$m,$d) = split(/\-/,$dd);
	($h,$mn,$sc) = split(/\:/,$tt);

	if($sc){ $tz = substr($sc,2,length($sc)); }
	else{ $tz = substr($mn,2,length($mn));	}
	$tz_offset = $tz;
	if($tz =~ /[A-Z]/){
		$tz =~ s/^\+//g;
		$tz_offset = getTimeZones("RFC-822",$tz);
		$tz = "+".$tz;
	}
	$tz_offset =~ /^([\+\-])([0-9]{2})([0-9]{2})/;
	$tz_offset = ($1 eq "+" ? 1 : -1)*(int($2) + int($3)/60);
	$sc = substr($sc,0,2);
	if($tz !~ /[A-Z]/){ $tz = ""; }
	return (getJulianDate($y,$m,$d,$h,$mn,$sc)-($tz_offset/24.0)).$tz;
}
sub getJulianDate {
	my $y = $_[0];
	my $m = $_[1];
	my $d = $_[2];
	my $h = $_[3];
	my $mn = $_[4];
	my $sc = $_[5];
	my $jy;
	my $jm;
	my $intgr;
	my $gregcal;
	my $ja;
	my $dayfrac;
	my $frac;
	my $jd;

	if(!$y || $y==0){ return ((time)/86400.0 + 2440587.5); }
	
	if(!$m || !$d){
		if($y){ $thistime = $y; }
		else{ $thistime = time; }
		# System time in seconds since 1/1/1970 00:00
		# To get Julian Date we just divide this by number of seconds
		# in a day and add Julian Date for start of system time
		return (($thistime)/86400.0 + 2440587.5);		

	}

	if($y == 1582 && $m == 10 && $d > 4 && $d < 15 ) {
		# The dates 5 through 14 October, 1582, do not exist in the Gregorian system!
		return ((time)/86400.0 + 2440587.5); 
	}

	if($y < 0){ $y = $y + 1; } # B.C.
	if($m > 2) {
		$jy = $y;
		$jm = $m + 1;
	}else{
		$jy = $y - 1;
		$jm = $m + 13;
	}
	$intgr = int(int(365.25*$jy) + int(30.6001*$jm) + $d + 1720995);

	#check for switch to Gregorian calendar
	$gregcal = 588829;
	if( ($d + 31*($m + 12*$y)) >= $gregcal ) {
		$ja = int(0.01*$jy);
		$intgr = $intgr + 2 - $ja + int(0.25*$ja);
	}

	#correct for half-day offset
	$dayfrac = ($h/24.0) - 0.5;
	if( $dayfrac < 0.0 ) {
		$dayfrac += 1.0;
		$intgr = $intgr - 1;
	}

	#now set the fraction of a day
	$frac = $dayfrac + ($mn + $sc/60.0)/60.0/24.0;

	#round to nearest second
	$jd = ($intgr + $frac)*86400;
	$jd = int($jd+0.5);


	return ($jd/86400.0);
	
}

sub getUnixDate {
	my $thistime = $_[0];
	my $thetime = "";
	my $timezone = "";
	my @output;
	
	# Check supplied timezone
	if($thistime =~ /[\-\+]/){ 
		($thetime,$timezone) = split(/[\-\+]/,$thistime);
	}else{ $thetime = $thistime; $timezone = "UTC"; }

	if($thetime <= 0){
		my ($sec,$min,$hour,$mday,$mon,$year,$wday) = (localtime(time))[0,1,2,3,4,5,6];
		if($year < 1900){ $year += 1900; }
		$mon = sprintf("%02d",($mon+1));
		return ($sec,$min,$hour,$mday,$mon,$year,$wday,"UT");
	}

	# The following routine is adapted from the DJM()
	# function of Toby Thurston's Cal::Date
	# http://www.wildfire.dircon.co.uk/
	# Add on the timezone offset as a fraction of a day
	# this assumes that the input time is in UT
	my $jd  = $thetime + getTimeZones($timezone)/24.0;

	# jd0 is the Julian number for noon on the day in question
	# for example   mjd  jd jd0   === mjd0
	#   3.0  ...3.5  ...4.0   === 3.5
	#   3.3  ...3.8  ...4.0   === 3.5
	#   3.7  ...4.2  ...4.0   === 3.5
	#   3.9  ...4.4  ...4.0   === 3.5
	#   4.0  ...4.5  ...5.0   === 4.5
	my $jd0 = int($jd+0.5);

	# next we convert to Julian dates to make the rest of the maths easier.
	# JD1867217 = 1 Mar 400, so $b is the number of complete Gregorian
	# centuries since then.  The constant 36524.25 is the number of days
	# in a Gregorian century.  The 0.25 on the other constant ensures that
	# $b correctly rounds down on the last day of the 400 year cycle.
	# For example $b == 15.9999... on 2000 Feb 29 not 16.00000.
	my $b = int(($jd0-1867216.25)/36524.25);

	# b-int(b/4) is the number of Julian leap days that are not counted in
	# the Gregorian calendar, and 1402 is the number of days from 1 Jan 4713BC
	# back to 1 Mar 4716BC.  $c represents the date in the Julian calendar
	# corrected back to the start of a leap year cycle.
	my $c = $jd0+($b-int($b/4))+1402;

	# d is the whole number of Julian years from 1 Mar 4716BC to the date
	# we are trying to find.
	my $d = int(($c+0.9)/365.25);

	# e is the number of days from 1 Mar 4716BC to 1 Mar this year
	# using the Julian calendar
	my $e = 365*$d+int($d/4);

	# c-e is now the remaining days in this year from 1 Mar to our date
	# and we need to work out the magic number f such that f-1 == month
	my $f = int(($c-$e+123)/30.6001);

	# int(f*30.6001) is the day of the start of the month
	# so the day of the month is the difference between that and c-e+123
	my $day = $c-$e+123-int(30.6001*$f);

	# month is now f-1, except that Jan and Feb are f-13
	# ie f 4 5 6 7 8 9 10 11 12 13 14 15
	#m 3 4 5 6 7 8  9 10 11 12  1  2
	my $month = ($f-2)%12+1;

	# year is d - 4716 (adjusted for Jan and Feb again)
	my $year = $d - 4716 + ($month<3);

	# finally work out the hour (if any)
	my $hour = 24 * ($jd+0.5-$jd0);
	my $min = 0;
	my $sec = 0;
	if ($hour == 0) {
		#@output = (0,0,0,$day,$month,$year,0);
		#return @output;
	} else {
		$hour = int($hour*60+0.5)/60;   # round to nearest minute
		$min = int(0.5+60 * ($hour - int($hour)));
		$hour = int($hour);
		#@output = (0,$min,$hour,$day,$month,$year,0);
		#return @output;
	}
	$month = sprintf("%02d",($month));
	
	# work out the day of the week
	# Note that this only works back until the change in the calendar
	# as a number of days not divisible by seven were removed
	my $diff = $jd - 2453240.5;
	if($diff >= 0){ $diff += 1.0; }
	my $wday = $diff % 7;
	
	return ($sec,$min,$hour,$day,$month,$year,$wday,$timezone);
}

sub getDateID {
	#@days   = ('Sun','Mon','Tue','Wed','Thu','Fri','Sat');
	#@months = ('Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec');

	# Get all the date variables
	($sec,$min,$hour,$mday,$mon,$year) = (localtime(time))[0,1,2,3,4,5];
	
	if($year <= 1900){ $year += 1900; }
	$mon = $mon + 1;
	return sprintf("%4d%02d%02d%02d%02d%02d",$year,$mon,$mday,$hour,$min,$sec);
}

sub formatDates {

	local($i,$x,$output,@monthnames,@dateparts,$datestring,$d,$m,$y,$monthold);
	$datestring = $_[0];
	$shorter = $_[1];

	@monthnames = ('January','February','March','April','May','June','July',
		   'August','September','October','November','December');

	if($datestring !~ /\,/ && $datestring =~ / /){ $datestring =~ s/ /\,/g; }
	@dateparts = split(/,/,$datestring);

	$output = "";
	$x = 0;
	for($i = 0 ; $i < (@dateparts) ; $i++){
		($d,$m,$y) = split(/\//, $dateparts[$i]);
		if($x == 0){ $monthold = $m; }
		if($m != $monthold){
			$output =~ s/\/$/ /;
			$output .= $monthnames[$monthold-1]." ";
			$monthold = $m;
		}
		if($shorter){
			if($i==0){ $output .= $d." "; }
			if($i == (@dateparts)-1){ $output .= " - ".$d." "; }
		}else{
			$output .= $d."/";
		}
		$x++;	
	}
	$output =~ s/\/$/ /;
	$output .= $monthnames[$monthold-1];
	return $output;	
}

sub differentDate {

	local($output,$datestring1,$datestring2,$d1,$m1,$y1,$d2,$m2,$y2,$type);
	$datestring1 = $_[0];
	$datestring2 = $_[1];
	$type = $_[2];

	if(!$datestring2){ return 0; }
	
	$datestring1 =~ s/^([^\s]*) .*$/$1/;
	$datestring2 =~ s/^([^\s]*) .*$/$1/;
	
	($d1,$m1,$y1) = split(/\//, $datestring1);
	($d2,$m2,$y2) = split(/\//, $datestring2);

	if($type eq "month"){
		if($m1 != $m2){ return $m1; }
		else{ return 0; }
	}elsif($type eq "year"){
		if($y1 != $y2){ return $y1; }
		else{ return 0; }
	}

	return 0;
}

sub hasItExpired {
	local($datestring, @dateparts,$m, $d, $y, @junk);
	$datestring = $_[0];

	($now_d,$now_m,$now_y) = (localtime(time))[3,4,5];
	if($now_y < 1900){ $now_y += 1900; }
	$now_m = $now_m + 1;
	
	@dateparts = split(/,/,$datestring);

	$stilltocome = 0;

	foreach $datestring (@dateparts){
		($d,$m,$y,@junk) = split(/\//, $datestring);
		if(($now_y == $y && $now_m == $m && $now_d >= $d) || ($now_y == $y && $now_m > $m) || $now_y > $y){ $stilltocome++; }
	}
	if($stilltocome > 0){ return 0; }
	else{ return 1; }
}

sub getTimeZones {

	my $type = $_[0];
	my $tz = $_[1];
	my $tz_m;
	my $output = "";
	my %tzs = ("A",1,"ACDT",10.5,"ACST",9.5,"ADT",-3,"AEDT",11,"AEST",10,"AKDT",-8,"AKST",-9,"AST",-4,"AWST",8,"B",2,"BST",1,"C",3,"CDT",-5,"CEDT",2,"CEST",2,"CET",1,"CST",-6,"CXT",7,"D",4,"E",5,"EDT",-4,"EEDT",3,"EEST",3,"EET",2,"EST",-5,"F",6,"G",7,"GMT",0,"H",8,"HAA",-3,"HAC",-5,"HADT",-9,"HAE",-4,"HAP",-7,"HAR",-6,"HAST",-10,"HAT",-2.5,"HAY",-8,"HNA",-4,"HNC",-6,"HNE",-5,"HNP",-8,"HNR",-7,"HNT",-3.5,"HNY",-9,"I",9,"IST",9,"IST",1,"JST",9,"K",10,"L",11,"M",12,"MDT",-6,"MESZ",2,"MEZ",1,"MST",-7,"N",-1,"NDT",-2.5,"NFT",11.5,"NST",-3.5,"O",-2,"P",-3,"PDT",-7,"PST",-8,"Q",-4,"R",-5,"S",-6,"T",-7,"U",-8,"UTC",0,"UT",0,"V",-9,"W",-10,"WEDT",1,"WEST",1,"WET",0,"WST",8,"X",-11,"Y",-12,"Z",0);

	if($type eq "options"){
		if(!$data{'timezone'}){ $data{'timezone'} = $user{$data{'blog'}}{'timezone'} }
		foreach $tz (sort(keys(%tzs))){
			if($data{'timezone'} eq $tz){ $output .= "<option value=\"$tz\" selected>$tz\n"; }
			else{ $output .= "<option value=\"$tz\">$tz\n"; }
		}
	}elsif($type eq "RFC-822"){
		$tz = $tzs{$tz};
		$output = roundInt($tz);
		$tz_m = ($tz-floorInt($tz))*60;
		$output = sprintf("%+03d%02d",$tz,$tz_m);
	}else{
		if($tzs{$type}){ $output = $tzs{$type}; }
		else{ $output = 0; }
	}
	return $output;
}

sub roundInt {
	if($_[0] < 0){ return int($_[0] - .5); }
	else{ return int($_[0] + .5); }
}

sub floorInt {
	return int($_[0]);
}

sub encodebase58 {
	my ($val,$symbols,$b);
	$val = $_[0];
	$symbols = "123456789abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ";
	$base = length($symbols);
	$b = '';
	while ($val) {
		$b = substr($symbols, $val % $base, 1) . $b;
		$val = int $val / $base;
	}
	return $b || '0';
}

sub decodeBase58 {

	my $num = shift;
	my @symbols = split(//,"123456789abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ");
	my $divisor = @symbols;

	# strip leading 0's
	$num =~ s/$0+//g;
	
	my ($y, $result) = (0, 0);
	
	foreach (split(//, reverse($num))) {
		my $found = 0;
	
		foreach my $item (@symbols) {
			if($item eq $_) {
				last;
			}
			$found++;
		}
	
		my $temp = $found * ($divisor ** $y);
		$result += $temp;
		$y++;
	}

	return $result;
}