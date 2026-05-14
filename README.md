# Sharebeam

Sharebeam is a professional-grade, cross-platform local file sharing application built with Flutter. It enables seamless file and clipboard transfers between devices on the same local network using mDNS for discovery and a robust internal server for data transmission.

## Features

- Local Network Discovery: Automatically find and connect to devices using mDNS.
- Fast Transfers: Direct point-to-point file and clipboard sharing.
- Cross-Platform Support: Available for Android, iOS, Linux, and Windows.
- Privacy-Focused: No cloud middleman; all transfers stay within your local network.

## Windows Build Status

The Windows build of Sharebeam is currently in an experimental state and remains untested. It is highly likely that you will encounter bugs or unexpected behavior on this platform.

If you are comfortable working with experimental software (or as we say, "okay with vibes"), you are encouraged to download the source code, test the build, and submit fixes or improvements.

## Prerequisites

Before setting up the project, ensure you have the following installed:

- Flutter SDK (latest stable version)
- Dart SDK
- Development environment for your target platform (Android Studio, Xcode, or Visual Studio)

## Installation Guide

Follow these steps to set up Sharebeam for development:

1. Clone the repository to your local machine:
   ```bash
   git clone https://github.com/Talhakhalidawan/Share-Beam.git
   ```

2. Navigate to the project directory:
   ```bash
   cd Share-Beam
   ```

3. Install the required dependencies:
   ```bash
   flutter pub get
   ```

4. Run the application on your connected device or emulator:
   ```bash
   flutter run
   ```

## Usage Instructions

### Hosting a Session

1. Open Sharebeam on the device that will host the transfer.
2. Navigate to the hosting section and start the service.
3. The device will now be visible to other Sharebeam clients on the local network.

### Connecting to a Host

1. Ensure your device is on the same local network as the host.
2. Open Sharebeam and scan for available devices.
3. Select the host from the list to establish a connection.
4. Once connected, you can share files or clipboard content directly.

## Future Development

Many enhancements are currently in development, including refined UI components, improved transfer speeds, and deeper platform integrations. Stay tuned for updates.

## Contribution Guidelines

Contributions are welcome and appreciated. To contribute to Sharebeam, please follow these professional standards:

1. Fork the repository.
2. Create a new branch for your feature or bug fix.
3. Ensure your code follows the project's linting and formatting rules.
4. Provide a clear and concise description of your changes in your pull request.
5. If you are fixing a bug in the Windows build, please provide details on the issue and your resolution.

## License

Sharebeam is licensed under a custom agreement. It is free for personal, non-commercial, and educational use. Commercial redistribution or resale of this software/source code is strictly prohibited. Attribution to the original author, Talha Khalid, is required.

For full details, please refer to the LICENSE file in the repository root.
