# DockGuard Code Signing Solution

## 문제 상황
다음과 같은 코드 서명 문제가 발생했습니다:
```
Info.plist=not bound
TeamIdentifier=not set
Sealed Resources=none
Internal requirements=none
```

이는 앱이 ad-hoc 서명만 되어 있고 적절한 Developer ID로 서명되지 않았기 때문입니다.

## 해결 방법

### 1. 전제 조건
- Apple Developer 계정 및 Developer ID 인증서 필요
- Xcode Command Line Tools 설치: `xcode-select --install`

### 2. 사용 가능한 인증서 확인
```bash
security find-identity -v -p codesigning
```

### 3. 적절한 서명으로 빌드
두 가지 방법이 있습니다:

#### 방법 A: 새로운 서명 스크립트 사용 (권장)
```bash
./sign_and_build.sh "Developer ID Application: Your Name (TEAM_ID)"
```

#### 방법 B: 환경 변수 설정 후 빌드
```bash
export DEVELOPER_ID="Developer ID Application: Your Name (TEAM_ID)"
CLEAN=1 SIGN=1 ./build.sh
```

### 4. 서명 확인
빌드 후 다음 명령으로 서명 상태를 확인할 수 있습니다:
```bash
codesign -dv --verbose=4 DockGuard.app
```

올바르게 서명되었다면 다음과 같이 표시됩니다:
```
Info.plist=bound
TeamIdentifier=YOUR_TEAM_ID
Sealed Resources=version 2, ...
Internal requirements count=1 size=...
```

## 추가된 파일들

### 1. DockGuard.entitlements
앱이 필요로 하는 권한들을 정의합니다:
- 전역 마우스 이벤트 모니터링
- 접근성 기능
- 디스플레이 관리

### 2. sign_and_build.sh
완전한 빌드 및 서명 프로세스를 자동화하는 스크립트입니다.

## 문제 해결

### 인증서를 찾을 수 없는 경우
1. Apple Developer 계정에서 인증서 생성
2. 키체인 접근에서 인증서 설치 확인
3. `security find-identity -v -p codesigning`으로 설치된 인증서 확인

### 권한 문제가 발생하는 경우
- 시스템 환경설정 > 보안 및 개인 정보 보호 > 개인 정보 보호 > 접근성에서 앱 허용

## App Store 배포를 위한 추가 단계

앱을 App Store나 외부 배포를 위해서는 공증(notarization)도 필요합니다:

```bash
# 앱을 zip으로 압축
ditto -c -k --keepParent DockGuard.app DockGuard.app.zip

# 공증 요청
xcrun notarytool submit DockGuard.app.zip \
  --keychain-profile "notarytool-profile" \
  --wait

# 공증 첨부
xcrun stapler staple DockGuard.app
```

## 요약

이제 다음 단계를 통해 모든 서명 문제가 해결됩니다:

1. ✅ **DockGuard.entitlements** - 필요한 권한 정의
2. ✅ **build.sh 개선** - Developer ID 서명 지원
3. ✅ **sign_and_build.sh** - 완전한 서명 자동화
4. ✅ **문서화** - 사용법 및 문제 해결 가이드

이제 `./sign_and_build.sh "Your Developer ID"`로 적절히 서명된 앱을 빌드할 수 있습니다.