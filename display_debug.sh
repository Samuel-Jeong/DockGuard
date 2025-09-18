#!/bin/bash

echo "=== Display Bottom Area Debug Tool ==="
echo ""
echo "🖥️  This tool shows how DockGuard detects the bottom area of displays"
echo ""

# Check if DockGuard is built
if [ ! -f "DockGuard.app/Contents/MacOS/DockGuard" ]; then
    echo "❌ DockGuard is not built. Please run ./build.sh first."
    exit 1
fi

echo "📍 Coordinate System Explanation:"
echo "   • NSScreen (AppKit): Origin at bottom-left (0,0)"
echo "   • Quartz (CGEvent): Origin at top-left (0,0)"
echo "   • DockGuard uses the Quartz coordinate system"
echo ""

echo "🎯 Bottom Detection Method:"
echo "   • Within 30 pixels from the bottom of each display"
echo "   • Distance calculation: (Display_Y + Height) - Mouse_Y"
echo "   • Areas within 30 pixels are considered 'bottom zones'"
echo ""

echo "🔍 Real-time Testing Method:"
echo "   1. Run the DockGuard app"
echo "   2. Open Console app to check logs (Console.app)"
echo "   3. Enter 'DockGuard' in the search filter"
echo "   4. Move your mouse to the bottom of each display"
echo ""

echo "📊 Current Display Configuration (System Info):"
echo ""

# Use system_profiler to get display information
system_profiler SPDisplaysDataType | grep -E "(Display Type|Resolution|Main Display)" | head -20

echo ""
echo "🧪 Test Scenarios:"
echo "   1. Move mouse to the bottom of the main display"
echo "   2. Move mouse to the bottom of secondary displays"
echo "   3. Check log messages in Console for each case"
echo ""

echo "📝 What to Check in Logs:"
echo "   • '[DockGuard] Mouse on display X: ALLOWED/NOT_ALLOWED'"
echo "   • 'bounds: X,Y WxH' - Display boundaries"
echo "   • 'distance from bottom: N' - Distance to bottom"
echo "   • '*** WILL BLOCK ***' - Bottom area detected"
echo ""

echo "💡 Troubleshooting Tips:"
echo "   • If no logs appear: Check accessibility permissions"
echo "   • If distance shows negative values: Coordinate conversion issue"
echo "   • If displays are not detected: System restart required"
echo ""

echo "🚀 Running DockGuard:"
echo "   open DockGuard.app"
echo ""
echo "Or run in debug mode:"
echo "   DockGuard.app/Contents/MacOS/DockGuard"