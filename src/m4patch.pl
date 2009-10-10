#!/usr/bin/perl


# replacements 
%rep = ('ccomma' => 'c,',
	'comma' => ',',
	  'lb' => '[',
	  'rb' => ']');

open(FH, '<', "bin/t.S") or die $';

$last="";
$match=0;
while(<FH>)
{
	$fool=0;
	while (($key,$val) = each %rep)
	{
		if (/(^.*\.ASCII.*")$key(".*$)/)
		{
			print "$1$val$2\n";
			$fool=1;
			$last=$val;
			$match=1;
		}
	}

	if(/.*\.FILL.*/)
	{
		if($match==1){
		$calc=32-length($last);
		print ".FILL $calc\n";
		$fool=1;
		$match=0;
		}
	}

	if($fool==0){
	print;
	}
} 
