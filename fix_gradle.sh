#!/bin/bash

set -e  # Stop on error

# Define variables
GRADLE_VERSION="8.2"
GRADLE_PLUGIN_VERSION="8.1.1"
GRADLE_WRAPPER_FILE="android/gradle/wrapper/gradle-wrapper.properties"
BUILD_GRADLE_FILE="android/build.gradle"

# Ensure the script is run from the Flutter project root
echo "Checking if this is a Flutter project..."
if [ ! -d "android" ]; then
    echo "No 'android' directory found. Attempting to create one..."
    flutter create .
fi

# Verify the android directory now exists
if [ ! -d "android" ]; then
    echo "Error: Could not create 'android' directory. Please check your Flutter installation."
    exit 1
fi

echo "Upgrading Gradle wrapper..."
cd android
if ! grep -q "distributionUrl=.*gradle-$GRADLE_VERSION-all.zip" "$GRADLE_WRAPPER_FILE"; then
    ./gradlew wrapper --gradle-version $GRADLE_VERSION --distribution-type all || true
    echo "Updating gradle-wrapper.properties..."
    sed -i "s|distributionUrl=.*|distributionUrl=https\://services.gradle.org/distributions/gradle-$GRADLE_VERSION-all.zip|" "$GRADLE_WRAPPER_FILE"
else
    echo "Gradle wrapper is already up to date."
fi
cd ..

echo "Updating build.gradle file..."
if ! grep -q "com.android.tools.build:gradle:$GRADLE_PLUGIN_VERSION" "$BUILD_GRADLE_FILE"; then
    sed -i "s|com.android.tools.build:gradle:[0-9.]*|com.android.tools.build:gradle:$GRADLE_PLUGIN_VERSION|" "$BUILD_GRADLE_FILE"
    echo "build.gradle updated."
else
    echo "build.gradle is already up to date."
fi

echo "Cleaning and rebuilding Flutter project..."
flutter clean
flutter pub get
flutter build apk

echo "Gradle update and build process completed successfully!"
