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
