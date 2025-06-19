#!/bin/bash

# 앱 아이콘 자동 생성 스크립트
echo "🎨 앱 아이콘 생성 시작..."

LOGO="assets/images/app_logo.png"

# iOS 앱 아이콘들
echo "🍎 iOS 앱 아이콘 생성 중..."
magick "$LOGO" -resize 29x29 ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png
magick "$LOGO" -resize 58x58 ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png
magick "$LOGO" -resize 87x87 ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png
magick "$LOGO" -resize 40x40 ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png
magick "$LOGO" -resize 80x80 ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png
magick "$LOGO" -resize 120x120 ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png
magick "$LOGO" -resize 120x120 ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png
magick "$LOGO" -resize 180x180 ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png
magick "$LOGO" -resize 76x76 ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png
magick "$LOGO" -resize 152x152 ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png
magick "$LOGO" -resize 167x167 ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png
magick "$LOGO" -resize 1024x1024 ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png

# Android 앱 아이콘들
echo "🤖 Android 앱 아이콘 생성 중..."
magick "$LOGO" -resize 48x48 android/app/src/main/res/mipmap-mdpi/ic_launcher.png
magick "$LOGO" -resize 72x72 android/app/src/main/res/mipmap-hdpi/ic_launcher.png
magick "$LOGO" -resize 96x96 android/app/src/main/res/mipmap-xhdpi/ic_launcher.png
magick "$LOGO" -resize 144x144 android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png
magick "$LOGO" -resize 192x192 android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png

# 웹 아이콘들 및 파비콘
echo "🌐 웹 아이콘 및 파비콘 생성 중..."
magick "$LOGO" -resize 192x192 web/icons/Icon-192.png
magick "$LOGO" -resize 512x512 web/icons/Icon-512.png
magick "$LOGO" -resize 192x192 web/icons/Icon-maskable-192.png
magick "$LOGO" -resize 512x512 web/icons/Icon-maskable-512.png
magick "$LOGO" -resize 32x32 web/favicon.png

echo "✅ 모든 앱 아이콘 생성 완료!"
echo "🚀 이제 flutter run으로 앱을 실행해보세요!" 