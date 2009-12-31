#!/bin/bash

rm -f frames/*.*
rm -f frames/raw/*

# for ((i=0; i<20; i++)); do
#     rm -f frames/*.tga
#     rm -f frames/*.raw
#     rm -f frames/raw/*
#     bin/4k-debug < demos/robots/grab.4k
#     cp frames/raw/*.raw frames
#     c=$((0))
#     for f in frames/*.raw; do
# 	convert -flip -size 720x576 -depth 8 rgba:$f t.tga
# 	mv t.tga frames/$c.tga
# 	c=$((c+1))
#     done
#     ffmpeg -r 50 -b 30000000 -i frames/%d.tga frames/$i.mpg
# done

bin/4k-debug < demos/robots/grab.4k
c=$((0))
for f in frames/raw/*.raw; do
    convert -flip -size 720x576 -depth 8 rgba:$f t.tga
    mv t.tga frames/$(printf "%05d.tga" $c)
    c=$((c+1))
    rm $f
done
cd frames
mencoder "mf://*.tga" -mf fps=50 -o test.avi -ovc lavc -lavcopts vcodec=msmpeg4v2:vbitrate=3000000
# ffmpeg -r 50 -b 30000000 -i %d.tga -vcodec mpeg4 out.mpg

