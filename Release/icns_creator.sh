#!/bin/bash
# Creates an icns file from a source image

# Copyright (c) 2015, JAMF Software, LLC. All rights reserved.

# Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

#     * Redistributions of source code must retain the above copyright notice, this
#       list of conditions, and the disclaimer below.
#     * Redistributions in binary form must reproduce the above copyright notice, this
#       list of conditions and the disclaimer below in the documentation and/or
#       other materials provided with the distribution.
#     * Neither the name of the JAMF Software, LLC nor the names of its contributors
#       may be used to endorse or promote products derived from this software without
#       specific prior written permission.
      
# THIS SOFTWARE IS PROVIDED BY JAMF SOFTWARE, LLC "AS IS" AND ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
# AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL JAMF SOFTWARE,
# LLC BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
# AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
# EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

src_image="$1"
if [ -z "$1" ]; then
    echo "No source image was passed to this script"
    exit 1
fi

icns_name="$2"
if [ -z "$2" ]; then
    icns_name="iconbuilder"
fi

if [ "${src_image:(-3)}" != "png" ]; then
    echo "Source image is not a PNG, making a converted copy..."
    /usr/bin/sips -s format png "$src_image" --out "${src_image}.png"
    if [ $? -ne 0 ]; then
        echo "The source image could not be converted to PNG format."
        exit 1
    fi
    src_image="${src_image}.png"
fi

iconset_path="./${icns_name}.iconset"
if [ -e "$iconset_path" ]; then
    /bin/rm -r "$iconset_path"
    if [ $? -ne 0 ]; then
        echo "There is a pre-existing file/dir $iconset_path the could not be deleted"
        exit 1
    fi
fi

/bin/mkdir "$iconset_path"

icon_file_list=(
    "icon_16x16.png"
    "icon_16x16@2x.png"
    "icon_32x32.png"
    "icon_32x32@2x.png"
    "icon_128x128.png"
    "icon_128x128@2x.png"
    "icon_256x256.png"
    "icon_256x256@2x.png"
    "icon_512x512.png"
    "icon_512x512@2x.png"
    )

icon_size=(
    '16'
    '32'
    '32'
    '64'
    '128'
    '256'
    '256'
    '512'
    '512'
    '1024'
    )

counter=0    
for a in ${icon_file_list[@]}; do
    icon="${iconset_path}/${a}"
    /bin/cp "$src_image" "$icon"
    icon_size=${icon_size[$counter]}
    /usr/bin/sips -z $icon_size $icon_size "$icon"
    counter=$(($counter + 1))
done

echo "Creating .icns file from $iconset_path"
/usr/bin/iconutil -c icns "$iconset_path"
if [ $? -ne 0 ]; then
    echo "There was an error creating the .icns file"
    exit 1
fi

echo "Done"
exit 0