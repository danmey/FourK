#!/usr/bin/perl



%repls = ('ccomma' => 'c,',
	  'lb' => '\[',
	  'rb' => '\]');

open(FH, '<', "t.S") or die $';

while(<FH>)
{
	foreach $key (%repls){
	s/\(\.ASCII.*"\)$key\(".*\)/\1$repls{$key}\2/;
	}
	print;
}
