#!/bin/bash

# Create AppIcon.appiconset directory if it doesn't exist
ICON_DIR="Recruiting Tracker/Assets.xcassets/AppIcon.appiconset"
mkdir -p "$ICON_DIR"

# Function to generate icon
generate_icon() {
    size="$1"
    scale="$2"
    output="$3"
    final_size=$(echo "$size * $scale" | bc)
    final_size=${final_size%.*} # Remove decimal part
    
    sips -z $final_size $final_size "icon_source.png" --out "$ICON_DIR/$output"
}

# iPhone icons
generate_icon 20 2 "AppIcon-20@2x.png"
generate_icon 20 3 "AppIcon-20@3x.png"
generate_icon 29 2 "AppIcon-29@2x.png"
generate_icon 29 3 "AppIcon-29@3x.png"
generate_icon 40 2 "AppIcon-40@2x.png"
generate_icon 40 3 "AppIcon-40@3x.png"
generate_icon 60 2 "AppIcon-60@2x.png"
generate_icon 60 3 "AppIcon-60@3x.png"

# iPad icons
generate_icon 20 1 "AppIcon-20.png"
generate_icon 29 1 "AppIcon-29.png"
generate_icon 40 1 "AppIcon-40.png"
generate_icon 76 1 "AppIcon-76.png"
generate_icon 76 2 "AppIcon-76@2x.png"
generate_icon 83.5 2 "AppIcon-83.5@2x.png"

# App Store icon
generate_icon 1024 1 "AppIcon-1024.png"

echo "App icons generated successfully!"
