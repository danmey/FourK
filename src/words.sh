#!/bin/sh 

words=`grep fourk2.S -e 'DEF_CODE' | sed -n 's/DEF_CODE(.*,.*"\(.*\)".*)/\1/gp'`;
for i in $words;
do echo -n "$i "; 
done;

echo;

count=`echo "$words" | wc -l`;
echo "$count words";
