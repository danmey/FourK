#!/usr/bin/perl


# replacements 
%rep = ('ccomma' => 'c,',
	  'lb' => '[',
	  'rb' => ']');

open(FH, '<', "t.S") or die $';


while(<FH>)
{
	$fool=0;
	while (($key,$val) = each %rep)
	{
		if (/(^.*\.ASCII.*")$key(".*$)/)
		{
			print "$1$val$2\n";
			$fool=1;
		}
	}

	if($fool==0){
	print;
	}
} 
