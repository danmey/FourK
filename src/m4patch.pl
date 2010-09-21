#!/usr/bin/perl

# FourK - Concatenative, stack based, Forth like language optimised for 
#        non-interactive 4KB size demoscene presentations.

# Copyright (C) 2009, 2010 Wojciech Meyer, Josef P. Bernhart

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


# replacements 
%rep = ('ccomma' => 'c,',
	'comma' => ',',
	  'lb' => '[',
	  'rb' => ']');

open(FH, '<', "bin/t.s") or die $';

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
