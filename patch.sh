#!/usr/bin/env bash
set -euo pipefail

# DockGuard 패치 스크립트 (Patch Script)
# 이 스크립트는 DockGuard 애플리케이션의 빌드, 업데이트, 배포를 자동화합니다.
#
# 사용법:
#   chmod +x patch.sh
#   ./patch.sh                    # 기본 패치 (빌드 + 아이콘 생성)
#   ./patch.sh --clean            # 클린 빌드
#   ./patch.sh --sign             # 코드 사이닝 포함
#   ./patch.sh --full             # 전체 패치 (클린 + 빌드 + 아이콘 + 사이닝)
#   ./patch.sh --backup           # 기존 앱 백업 후 패치
#   ./patch.sh --install          # 패치 후 Applications 폴더에 설치
#   ./patch.sh --debug            # 디버그 모드로 실행
#   ./patch.sh --help             # 도움말 표시

APP_NAME="DockGuard"
BUNDLE="$APP_NAME.app"
BACKUP_DIR="backups"
INSTALL_DIR="/Applications"
VERSION=$(date +"%Y%m%d_%H%M%S")

# 컬러 출력 함수
print_header() {
    echo ""
    echo "🔧 =================================="
    echo "🔧 DockGuard 패치 스크립트"
    echo "🔧 =================================="
    echo ""
}

print_step() {
    echo "📋 $1"
}

print_success() {
    echo "✅ $1"
}

print_error() {
    echo "❌ $1"
}

print_warning() {
    echo "⚠️  $1"
}

# 도움말 표시
show_help() {
    cat << EOF
DockGuard 패치 스크립트 사용법:

기본 명령어:
  ./patch.sh                 기본 패치 (빌드만)
  ./patch.sh --help          이 도움말 표시

옵션:
  --clean                    이전 빌드 파일 삭제 후 클린 빌드
  --sign                     애플리케이션에 임시 코드 사이닝 적용
  --full                     전체 패치 (클린 + 빌드 + 사이닝)
  --backup                   기존 앱을 백업 후 패치
  --install                  패치 완료 후 /Applications에 설치
  --restart                  기존 프로세스 종료 후 새 버전으로 재시작
  --debug                    디버그 모드로 앱 실행
  --test                     빌드 후 간단한 테스트 실행

조합 예시:
  ./patch.sh --clean --sign --install --restart
  ./patch.sh --backup --full --install --restart
  ./patch.sh --clean --debug
  ./patch.sh --restart                        # 기존 프로세스만 재시작

EOF
}

# 백업 생성
create_backup() {
    if [ -d "$BUNDLE" ]; then
        print_step "기존 앱 백업 중..."
        mkdir -p "$BACKUP_DIR"
        backup_name="${APP_NAME}_backup_${VERSION}.app"
        cp -r "$BUNDLE" "$BACKUP_DIR/$backup_name"
        print_success "백업 완료: $BACKUP_DIR/$backup_name"
    else
        print_warning "백업할 앱이 없습니다."
    fi
}

# 실행 중인 DockGuard 프로세스 종료
kill_existing_processes() {
    print_step "기존 DockGuard 프로세스 확인 중..."
    
    # pkill을 사용하여 DockGuard 프로세스 종료
    if pgrep -f "DockGuard" > /dev/null 2>&1; then
        print_warning "실행 중인 DockGuard 프로세스를 종료합니다."
        pkill -f "DockGuard" || true
        sleep 2
        
        # 강제 종료가 필요한 경우
        if pgrep -f "DockGuard" > /dev/null 2>&1; then
            print_warning "프로세스가 종료되지 않아 강제 종료합니다."
            pkill -9 -f "DockGuard" || true
            sleep 1
        fi
        
        print_success "기존 프로세스 종료 완료"
    else
        print_success "실행 중인 DockGuard 프로세스가 없습니다."
    fi
}

# 클린 빌드 준비
clean_build() {
    print_step "이전 빌드 파일 정리 중..."
    rm -rf "$BUNDLE"
    rm -f *.o
    print_success "정리 완료"
}


# 메인 빌드
build_app() {
    print_step "애플리케이션 빌드 중..."
    if [ -f "build.sh" ]; then
        chmod +x build.sh
        ./build.sh
        print_success "빌드 완료"
    else
        print_error "build.sh 스크립트를 찾을 수 없습니다."
        exit 1
    fi
}

# 코드 사이닝
sign_app() {
    if command -v codesign >/dev/null 2>&1; then
        print_step "애플리케이션 서명 중..."
        codesign --force --deep --sign - "$BUNDLE" || {
            print_warning "코드 사이닝 실패, 계속 진행합니다."
        }
        print_success "서명 완료"
    else
        print_warning "codesign 도구를 찾을 수 없습니다."
    fi
}

# 애플리케이션 설치
install_app() {
    if [ -d "$BUNDLE" ]; then
        print_step "애플리케이션을 $INSTALL_DIR에 설치 중..."
        if [ -d "$INSTALL_DIR/$BUNDLE" ]; then
            print_warning "기존 설치된 앱을 제거합니다."
            rm -rf "$INSTALL_DIR/$BUNDLE"
        fi
        cp -r "$BUNDLE" "$INSTALL_DIR/"
        print_success "설치 완료: $INSTALL_DIR/$BUNDLE"
    else
        print_error "설치할 애플리케이션을 찾을 수 없습니다."
        exit 1
    fi
}

# 애플리케이션 재시작
restart_app() {
    local app_path=""
    
    # 설치된 앱이 있는지 확인
    if [ -d "$INSTALL_DIR/$BUNDLE" ]; then
        app_path="$INSTALL_DIR/$BUNDLE"
    elif [ -d "$BUNDLE" ]; then
        app_path="$BUNDLE"
    else
        print_error "재시작할 애플리케이션을 찾을 수 없습니다."
        return 1
    fi
    
    print_step "DockGuard 애플리케이션 재시작 중..."
    
    # 백그라운드에서 앱 실행
    nohup open "$app_path" > /dev/null 2>&1 &
    
    # 잠시 대기 후 실행 확인
    sleep 3
    if pgrep -f "DockGuard" > /dev/null 2>&1; then
        print_success "DockGuard가 성공적으로 시작되었습니다."
    else
        print_warning "DockGuard 시작 확인이 불가능합니다. 수동으로 확인해주세요."
    fi
}

# 간단한 테스트
run_test() {
    if [ -d "$BUNDLE" ]; then
        print_step "애플리케이션 테스트 중..."
        
        # 번들 구조 확인
        if [ -f "$BUNDLE/Contents/MacOS/$APP_NAME" ]; then
            print_success "실행 파일 확인 완료"
        else
            print_error "실행 파일을 찾을 수 없습니다."
            return 1
        fi
        
        # Info.plist 확인
        if [ -f "$BUNDLE/Contents/Info.plist" ]; then
            print_success "Info.plist 확인 완료"
        else
            print_error "Info.plist를 찾을 수 없습니다."
            return 1
        fi
        
        # 아이콘 확인
        if [ -f "$BUNDLE/Contents/Resources/DockGuard.icns" ]; then
            print_success "아이콘 파일 확인 완료"
        else
            print_warning "아이콘 파일이 없습니다."
        fi
        
        print_success "모든 테스트 통과"
    else
        print_error "테스트할 애플리케이션을 찾을 수 없습니다."
        exit 1
    fi
}

# 디버그 모드로 실행
debug_run() {
    if [ -d "$BUNDLE" ]; then
        print_step "디버그 모드로 애플리케이션 실행 중..."
        print_warning "애플리케이션을 종료하려면 Ctrl+C를 누르세요."
        "$BUNDLE/Contents/MacOS/$APP_NAME"
    else
        print_error "실행할 애플리케이션을 찾을 수 없습니다."
        exit 1
    fi
}

# 패치 완료 메시지
show_completion() {
    print_success "패치 완료!"
    echo ""
    echo "📱 실행 방법:"
    echo "   open '$BUNDLE'"
    echo ""
    if [ -f "display_debug.sh" ]; then
        echo "🔍 디버그 도구:"
        echo "   ./display_debug.sh"
        echo ""
    fi
    echo "📂 생성된 파일:"
    echo "   $BUNDLE"
    if [ -d "$BACKUP_DIR" ]; then
        echo "   $BACKUP_DIR/ (백업)"
    fi
    echo ""
}

# 메인 실행 로직
main() {
    print_header
    
    # 명령행 인자 파싱
    CLEAN=false
    SIGN=false
    BACKUP=false
    INSTALL=false
    RESTART=false
    DEBUG=false
    FULL=false
    TEST=false
    
    # 인자가 없으면 기본적으로 빌드 + 재시작 적용
    DEFAULT_RUN=false
    if [[ $# -eq 0 ]]; then
        RESTART=true
        DEFAULT_RUN=true
    fi
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --clean)
                CLEAN=true
                shift
                ;;
            --sign)
                SIGN=true
                shift
                ;;
            --backup)
                BACKUP=true
                shift
                ;;
            --install)
                INSTALL=true
                shift
                ;;
            --restart)
                RESTART=true
                shift
                ;;
            --debug)
                DEBUG=true
                shift
                ;;
            --full)
                FULL=true
                CLEAN=true
                SIGN=true
                shift
                ;;
            --test)
                TEST=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                print_error "알 수 없는 옵션: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    
    # 재시작만 하는 경우 (명시적으로 --restart만 사용한 경우, 기본 실행은 제외)
    if [ "$RESTART" = true ] && [ "$DEFAULT_RUN" = false ] && [ "$CLEAN" = false ] && [ "$SIGN" = false ] && [ "$INSTALL" = false ] && [ "$TEST" = false ] && [ "$BACKUP" = false ]; then
        kill_existing_processes
        restart_app
        exit 0
    fi
    
    # 디버그 모드인 경우
    if [ "$DEBUG" = true ]; then
        debug_run
        exit 0
    fi
    
    # 기존 프로세스 종료 (재시작이 요청된 경우)
    if [ "$RESTART" = true ]; then
        kill_existing_processes
    fi
    
    # 백업 생성
    if [ "$BACKUP" = true ]; then
        create_backup
    fi
    
    # 클린 빌드
    if [ "$CLEAN" = true ]; then
        clean_build
    fi
    
    
    # 애플리케이션 빌드
    build_app
    
    # 코드 사이닝
    if [ "$SIGN" = true ]; then
        sign_app
    fi
    
    # 테스트 실행
    if [ "$TEST" = true ]; then
        run_test
    fi
    
    # 애플리케이션 설치
    if [ "$INSTALL" = true ]; then
        install_app
    fi
    
    # 애플리케이션 재시작
    if [ "$RESTART" = true ]; then
        restart_app
    fi
    
    # 완료 메시지
    show_completion
}

# 스크립트 실행
main "$@"