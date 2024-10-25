PACKAGE_NAME="$1"


xcodebuild -scheme "$PACKAGE_NAME" -sdk iphoneos -configuration Release BUILD_LIBRARY_FOR_DISTRIBUTION=YES ARCHS=arm64 BUILD_DIR=./Build -destination "generic/platform=iOS"
pushd Build/Release-iphoneos
  ar -crs "lib$PACKAGE_NAME.a" "$PACKAGE_NAME.o"
popd

xcodebuild -scheme "$PACKAGE_NAME" -sdk iphonesimulator -configuration Release BUILD_LIBRARY_FOR_DISTRIBUTION=YES ARCHS="arm64 x86_64" BUILD_DIR=./Build -destination "generic/platform=iOS Simulator"
pushd Build/Release-iphonesimulator
  ar -crs "lib$PACKAGE_NAME.a" "$PACKAGE_NAME.o"
  popd


xcodebuild -scheme "$PACKAGE_NAME" -sdk  macosx -configuration Release BUILD_LIBRARY_FOR_DISTRIBUTION=YES ARCHS="arm64 x86_64" BUILD_DIR=./Build -destination "generic/platform=macOS"
pushd Build/Release
  ar -crs "lib$PACKAGE_NAME.a" "$PACKAGE_NAME.o"
  popd

pushd Build
  xcodebuild -create-xcframework \
    -library "Release-iphonesimulator/lib$PACKAGE_NAME.a" \
    -library "Release-iphoneos/lib$PACKAGE_NAME.a" \
    -library "Release/lib$PACKAGE_NAME.a" \
    -output $PACKAGE_NAME.xcframework
popd
