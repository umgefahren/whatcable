{
  description = "WhatCable — macOS menu-bar utility for inspecting USB-C / charging state";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachSystem [ "aarch64-darwin" "x86_64-darwin" ] (system:
      let
        pkgs = import nixpkgs { inherit system; };

        whatcable = pkgs.swiftPackages.stdenv.mkDerivation {
          pname = "whatcable";
          version = "0.4.7";

          src = ./.;

          nativeBuildInputs = with pkgs; [
            swift
            swiftpm
          ];

          # SwiftPM needs a writable HOME and doesn't need network access at
          # build time (no external package dependencies in Package.swift).
          configurePhase = ''
            runHook preConfigure
            export HOME=$TMPDIR
            runHook postConfigure
          '';

          buildPhase = ''
            runHook preBuild
            swift build -c release --disable-sandbox
            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall

            binPath=$(swift build -c release --disable-sandbox --show-bin-path)

            mkdir -p $out/bin
            cp "$binPath/WhatCable" $out/bin/WhatCable

            # Bundle as a minimal .app so it can be launched as a GUI.
            appDir=$out/Applications/WhatCable.app
            mkdir -p $appDir/Contents/MacOS $appDir/Contents/Resources
            cp "$binPath/WhatCable" "$appDir/Contents/MacOS/WhatCable"

            if [ -f scripts/AppIcon.icns ]; then
              cp scripts/AppIcon.icns "$appDir/Contents/Resources/AppIcon.icns"
            fi

            cat > "$appDir/Contents/Info.plist" <<EOF
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
              <key>CFBundleDevelopmentRegion</key><string>en</string>
              <key>CFBundleExecutable</key><string>WhatCable</string>
              <key>CFBundleIconFile</key><string>AppIcon</string>
              <key>CFBundleIdentifier</key><string>com.bitmoor.whatcable</string>
              <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
              <key>CFBundleName</key><string>WhatCable</string>
              <key>CFBundleDisplayName</key><string>WhatCable</string>
              <key>CFBundlePackageType</key><string>APPL</string>
              <key>CFBundleShortVersionString</key><string>0.4.7</string>
              <key>CFBundleVersion</key><string>13</string>
              <key>LSMinimumSystemVersion</key><string>14.0</string>
              <key>LSUIElement</key><true/>
              <key>NSHighResolutionCapable</key><true/>
            </dict>
            </plist>
            EOF

            printf 'APPL????' > "$appDir/Contents/PkgInfo"

            # Ad-hoc sign the bundle so the app can launch on the local
            # machine. /usr/bin/codesign is provided by the system; this is a
            # no-op if it isn't available (e.g. inside CI without Xcode).
            /usr/bin/codesign --force --deep --sign - "$appDir" || true

            runHook postInstall
          '';

          meta = with pkgs.lib; {
            description = "macOS menu-bar utility for inspecting USB-C / charging state";
            homepage = "https://github.com/umgefahren/whatcable";
            license = licenses.mit;
            platforms = [ "aarch64-darwin" "x86_64-darwin" ];
            mainProgram = "WhatCable";
          };
        };
      in
      {
        packages = {
          default = whatcable;
          whatcable = whatcable;
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [ swift swiftpm ];
        };
      });
}
