flutter pub run build_runner build --delete-conflicting-outputs

# iOS 빌드 전 pod 정리 및 재설치
clean_pods() {
  cd ios
  pod deintegrate
  pod cache clean --all
  rm -rf Pods
  rm -rf Podfile.lock
  pod install
  cd ..
}

# 필요시 pod 정리
clean_pods

# flutter run -d ios  # -> 연결한 iphone device_id 확인 
# 13pro
fvm flutter run -d "00008110-001C156936D3801E"

# 12mini
fvm flutter run -d "00008101-000375E91189003A"

# 갤럭시 S20
# fvm flutter precache --android
fvm flutter run -d "R3CNC030KPB"

# # 1. FVM 설치 (한 번만)
# dart pub global activate fvm

# # 2. 프로젝트 Flutter 버전 설치
# fvm install 3.32.1

# # 3. 프로젝트에서 해당 버전 사용
# fvm use 3.32.1

# # 4. 의존성 설치
# fvm flutter pub get

# # 5. 앱 실행 (이후 flutter 대신 fvm flutter 사용)
# fvm flutter run


# 프로젝트 루트에서 실행
# fvm flutter clean
# fvm flutter pub get
# # Flutter SDK 캐시 정리
# fvm flutter pub cache repair
# # Dart pub 캐시 정리 
# dart pub cache repair