#!/bin/bash

# Create a simple icon for DockGuard using macOS built-in tools
# This creates a basic colored square that can serve as an app icon

echo "Creating DockGuard icon..."

# Create a simple colored PNG using built-in tools
# We'll use a system framework approach
cat > create_icon.py << 'EOF'
#!/usr/bin/env python3
import sys
import os

# Create a simple SVG icon first
svg_content = '''<?xml version="1.0" encoding="UTF-8"?>
<svg width="512" height="512" viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="shieldGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#4A90E2;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#2E5BBA;stop-opacity:1" />
    </linearGradient>
  </defs>
  <!-- Shield shape -->
  <path d="M256 50 L100 120 L100 300 L256 450 L412 300 L412 120 Z" 
        fill="url(#shieldGrad)" stroke="#1E3A8A" stroke-width="8"/>
  <!-- Lock symbol -->
  <rect x="220" y="220" width="72" height="80" rx="8" 
        fill="#FFFFFF" stroke="#E5E7EB" stroke-width="2"/>
  <!-- Lock shackle -->
  <path d="M236 220 L236 200 Q236 180 256 180 Q276 180 276 200 L276 220" 
        fill="none" stroke="#FFFFFF" stroke-width="8" stroke-linecap="round"/>
  <!-- Lock keyhole -->
  <circle cx="256" cy="250" r="8" fill="#4A90E2"/>
  <rect x="252" y="250" width="8" height="16" fill="#4A90E2"/>
</svg>'''

# Write SVG file
with open('DockGuard_icon.svg', 'w') as f:
    f.write(svg_content)

print("Created SVG icon file")
EOF

python3 create_icon.py

# Convert SVG to PNG using built-in tools if available
if command -v rsvg-convert >/dev/null 2>&1; then
    echo "Converting SVG to PNG using rsvg-convert..."
    rsvg-convert -w 1024 -h 1024 DockGuard_icon.svg -o DockGuard_1024.png
elif command -v qlmanage >/dev/null 2>&1; then
    echo "Using qlmanage to convert..."
    qlmanage -t -s 1024 -o . DockGuard_icon.svg
    mv DockGuard_icon.svg.png DockGuard_1024.png 2>/dev/null || true
else
    echo "Creating a simple colored PNG as fallback..."
    # Create a simple colored rectangle as a basic icon
    # This is a fallback method using only system tools
    python3 -c "
import sys
# Create a very simple PNG data - just a basic colored square
# This is a minimal approach without external dependencies
print('Creating basic fallback icon...')

# Create basic iconset structure manually
import os
os.makedirs('DockGuard.iconset', exist_ok=True)

# We'll use a system app icon as template and modify it
# Or create a very simple icon using ASCII art approach
"
fi

# Create iconset directory structure
mkdir -p DockGuard.iconset

# If we have a PNG, create different sizes
if [ -f "DockGuard_1024.png" ]; then
    echo "Creating different icon sizes..."
    
    # Use sips to resize (built into macOS)
    sips -z 16 16 DockGuard_1024.png --out DockGuard.iconset/icon_16x16.png >/dev/null 2>&1
    sips -z 32 32 DockGuard_1024.png --out DockGuard.iconset/icon_16x16@2x.png >/dev/null 2>&1
    sips -z 32 32 DockGuard_1024.png --out DockGuard.iconset/icon_32x32.png >/dev/null 2>&1
    sips -z 64 64 DockGuard_1024.png --out DockGuard.iconset/icon_32x32@2x.png >/dev/null 2>&1
    sips -z 128 128 DockGuard_1024.png --out DockGuard.iconset/icon_128x128.png >/dev/null 2>&1
    sips -z 256 256 DockGuard_1024.png --out DockGuard.iconset/icon_128x128@2x.png >/dev/null 2>&1
    sips -z 256 256 DockGuard_1024.png --out DockGuard.iconset/icon_256x256.png >/dev/null 2>&1
    sips -z 512 512 DockGuard_1024.png --out DockGuard.iconset/icon_256x256@2x.png >/dev/null 2>&1
    sips -z 512 512 DockGuard_1024.png --out DockGuard.iconset/icon_512x512.png >/dev/null 2>&1
    sips -z 1024 1024 DockGuard_1024.png --out DockGuard.iconset/icon_512x512@2x.png >/dev/null 2>&1
else
    echo "Creating minimal iconset with system tools..."
    # Fallback: copy a system icon and modify it
    # Use SF Symbols or create a very basic icon
    
    # Create a simple blue square as basic icon using built-in capabilities
    for size in "16x16" "16x16@2x:32" "32x32" "32x32@2x:64" "128x128" "128x128@2x:256" "256x256" "256x256@2x:512" "512x512" "512x512@2x:1024"; do
        name=$(echo $size | cut -d: -f1)
        pixels=$(echo $size | cut -d: -f2)
        if [ -z "$pixels" ]; then
            pixels=$(echo $name | sed 's/x.*//' | sed 's/@2x//')
        fi
        
        # Create a very basic PNG using system Python
        python3 -c "
# Create a minimal PNG file with basic header
import struct
import zlib

def create_png(width, height, color):
    def write_chunk(f, chunk_type, data):
        f.write(struct.pack('>I', len(data)))
        f.write(chunk_type)
        f.write(data)
        crc = zlib.crc32(data, zlib.crc32(chunk_type)) & 0xffffffff
        f.write(struct.pack('>I', crc))

    width, height = int(width), int(height)
    with open('DockGuard.iconset/icon_$name.png', 'wb') as f:
        f.write(b'\x89PNG\r\n\x1a\n')  # PNG signature
        
        # IHDR chunk
        ihdr = struct.pack('>2I5B', width, height, 8, 2, 0, 0, 0)
        write_chunk(f, b'IHDR', ihdr)
        
        # IDAT chunk - simple blue square
        row = b'\\x00' + (b'\\x41\\x69\\xE1' * width)  # Blue color RGB
        raw_data = b''.join([row for y in range(height)])
        compressor = zlib.compressobj()
        png_data = compressor.compress(raw_data)
        png_data += compressor.flush()
        write_chunk(f, b'IDAT', png_data)
        
        # IEND chunk
        write_chunk(f, b'IEND', b'')

create_png($pixels, $pixels, (65, 105, 225))
" 2>/dev/null || echo "Skipping $name"
    done
fi

# Create the .icns file using iconutil
if [ -d "DockGuard.iconset" ]; then
    echo "Creating .icns file..."
    iconutil -c icns DockGuard.iconset -o DockGuard.icns
    
    if [ -f "DockGuard.icns" ]; then
        echo "Successfully created DockGuard.icns"
        
        # Copy to the app bundle
        cp DockGuard.icns "DockGuard.app/Contents/Resources/"
        echo "Copied icon to app bundle"
        
        # Clean up
        rm -rf DockGuard.iconset
        rm -f DockGuard_1024.png DockGuard_icon.svg create_icon.py
        
        echo "Icon creation completed successfully!"
    else
        echo "Failed to create .icns file"
    fi
else
    echo "Failed to create iconset directory"
fi