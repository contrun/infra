{
  android_sdk.accept_license = true;
  allowUnfree = true;
  allowBroken = true;
  # The official binary cache build packages with pulseaudio enabled.
  # We want to use these pre-built binaries to avoid long building process.
  pulseaudio = true;
  experimental-features = "nix-command flakes";
}
