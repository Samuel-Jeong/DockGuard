#!/bin/bash

echo "=== 디스플레이 하단 영역 디버그 도구 ==="
echo ""
echo "🖥️  이 도구는 DockGuard가 어떻게 디스플레이 하단을 감지하는지 보여줍니다"
echo ""

# Check if DockGuard is built
if [ ! -f "DockGuard.app/Contents/MacOS/DockGuard" ]; then
    echo "❌ DockGuard가 빌드되지 않았습니다. 먼저 ./build.sh를 실행하세요."
    exit 1
fi

echo "📍 좌표계 설명:"
echo "   • NSScreen (AppKit): 원점이 왼쪽 아래 (0,0)"
echo "   • Quartz (CGEvent): 원점이 왼쪽 위 (0,0)"
echo "   • DockGuard는 Quartz 좌표계를 사용합니다"
echo ""

echo "🎯 하단 감지 방식:"
echo "   • 각 디스플레이의 하단에서 30픽셀 이내"
echo "   • 거리 계산: (디스플레이_Y + 높이) - 마우스_Y"
echo "   • 30픽셀 이하면 '하단 영역'으로 판단"
echo ""

echo "🔍 실시간 테스트 방법:"
echo "   1. DockGuard 앱을 실행하세요"
echo "   2. 콘솔 앱을 열어 로그를 확인하세요 (Console.app)"
echo "   3. 검색 필터에 'DockGuard'를 입력하세요"
echo "   4. 마우스를 각 디스플레이 하단으로 이동해보세요"
echo ""

echo "📊 현재 디스플레이 구성 (시스템 정보):"
echo ""

# Use system_profiler to get display information
system_profiler SPDisplaysDataType | grep -E "(Display Type|Resolution|Main Display)" | head -20

echo ""
echo "🧪 테스트 시나리오:"
echo "   1. 마우스를 메인 디스플레이 맨 아래로 이동"
echo "   2. 마우스를 보조 디스플레이 맨 아래로 이동"
echo "   3. 각 경우에 콘솔에서 로그 메시지 확인"
echo ""

echo "📝 로그에서 확인할 내용:"
echo "   • '[DockGuard] Mouse on display X: ALLOWED/NOT_ALLOWED'"
echo "   • 'bounds: X,Y WxH' - 디스플레이 경계"
echo "   • 'distance from bottom: N' - 하단까지 거리"
echo "   • '*** WILL BLOCK ***' - 하단 영역 감지됨"
echo ""

echo "💡 문제 해결 팁:"
echo "   • 로그가 보이지 않으면: 접근성 권한 확인"
echo "   • 거리가 음수로 나오면: 좌표 변환 문제"
echo "   • 디스플레이가 감지되지 않으면: 시스템 재시작 필요"
echo ""

echo "🚀 DockGuard 실행하기:"
echo "   open DockGuard.app"
echo ""
echo "또는 디버그 모드로 실행:"
echo "   DockGuard.app/Contents/MacOS/DockGuard"