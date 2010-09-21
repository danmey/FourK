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
#!/bin/sh 

words=`grep fourk2.S -e '.*DEF_\(IMM\)\|\(CODE\).*$' | 
sed -n 's/DEF_.*"\(.*\)".*$/\1/gp'`;
for i in $words;
do echo -n "$i "; 
done;

vars=`grep fourk2.S -e 'DEF_VAR' | sed -n 's/DEF_VAR(\(.*\),.*$/\1/gp'`;
for i in $vars;
do echo -n "$i ";
done;
echo;

varcount=`echo "$vars" | wc -l `;
count=`echo "$words" | wc -l`;
result=$(($count+$varcount));

echo "$result words";
echo "$((256-$result)) remaining free words";
