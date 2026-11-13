#!/bin/sh
# Renders the media that shows plot_twist: the README's hero GIF, pub.dev
# screenshots, the gallery's link-preview card, the repository's social
# preview, and clips for posts.
#
#   cd example && tool/make_media.sh
#   cd example && SKIP_CAPTURE=1 tool/make_media.sh   # only re-encode
#
# Needs ffmpeg. The frames come from tool/capture_media_test.dart; everything
# else is written under build/media, except the files copied at the end.
set -eu
cd "$(dirname "$0")/.."
media=build/media

# SKIP_CAPTURE=1 reuses the frames already in build/media.
if [ "${SKIP_CAPTURE:-}" != 1 ]; then
  rm -rf "$media"
  flutter test tool/capture_media_test.dart
fi

mkdir -p "$media/clips"
for dir in "$media"/frames/*/; do
  name=$(basename "$dir")
  crop=""
  if [ -f "$dir/crop.txt" ]; then crop="crop=$(cat "$dir/crop.txt"),"; fi
  ffmpeg -y -loglevel error -framerate 25 -i "$dir/%04d.png" \
    -vf "${crop}scale=1280:-2:flags=lanczos,format=yuv420p" \
    -c:v libx264 -crf 20 -preset slow -movflags +faststart "$media/clips/$name.mp4"
  ffmpeg -y -loglevel error -framerate 25 -i "$dir/%04d.png" \
    -vf "${crop}fps=15,scale=800:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=128:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle" \
    "$media/clips/$name.gif"
done

# Link previews at their real sizes.
ffmpeg -y -loglevel error -i "$media/cards/og@2x.png" -vf scale=1200:630:flags=lanczos web/og.png
mkdir -p ../.github/media
ffmpeg -y -loglevel error -i "$media/cards/social-preview@2x.png" \
  -vf scale=1280:640:flags=lanczos ../.github/media/social-preview.png

# The README's hero.
cp "$media/clips/a26-candles.gif" ../.github/media/hero.gif

# pub.dev screenshots: light stills of the demos that show the most.
mkdir -p ../doc/screenshots
# A10's readout measures real frames, which a test does not have; leave it out.
for n in 26 4 11 10 3 16 6 7; do
  trim=""
  if [ "$n" = 10 ]; then trim="crop=iw:ih-120:0:120,"; fi
  ffmpeg -y -loglevel error -i "$media/stills/a$n-light.png" \
    -vf "${trim}scale=1200:-1:flags=lanczos" "../doc/screenshots/a$(printf %02d "$n").png"
done

ls -l ../.github/media ../doc/screenshots web/og.png "$media/clips"
