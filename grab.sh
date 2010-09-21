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

