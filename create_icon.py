#!/usr/bin/env python3
"""
Generate a high-resolution macOS app icon for Dwell.
Creates an Apple-style icon similar to the News app with a rounded square,
gradient background, and symbolic house icon.
"""

import math
import os
from PIL import Image, ImageDraw, ImageFilter

def create_rounded_rectangle(width, height, radius, fill):
    """Create a rounded rectangle image with the given fill color."""
    img = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Draw rounded rectangle using arcs
    draw.rectangle([radius, 0, width - radius, height], fill=fill)
    draw.rectangle([0, radius, width, height - radius], fill=fill)

    # Draw quarter circles at corners
    draw.pieslice([0, 0, radius * 2, radius * 2], 180, 270, fill=fill)
    draw.pieslice([width - radius * 2, 0, width, radius * 2], 270, 360, fill=fill)
    draw.pieslice([0, height - radius * 2, radius * 2, height], 90, 180, fill=fill)
    draw.pieslice([width - radius * 2, height - radius * 2, width, height], 0, 90, fill=fill)

    return img

def create_icon(size):
    """Create a single icon at the given size."""
    # Apple icon corner radius ratio (approximately 22% of size)
    radius = int(size * 0.22)

    # Create gradient background - warm amber/orange gradient like News app
    base_color = (255, 180, 50)  # Warm amber
    highlight_color = (255, 220, 120)  # Light gold
    shadow_color = (200, 120, 20)  # Deep amber

    # Create base with gradient effect
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Draw gradient background
    for y in range(size):
        ratio = y / size
        r = int(highlight_color[0] + (base_color[0] - highlight_color[0]) * ratio)
        g = int(highlight_color[1] + (base_color[1] - highlight_color[1]) * ratio)
        b = int(highlight_color[2] + (base_color[2] - highlight_color[2]) * ratio)
        draw.line([(0, y), (size, y)], fill=(r, g, b, 255))

    # Create rounded mask
    mask = create_rounded_rectangle(size, size, radius, (255, 255, 255, 255))

    # Apply rounded corners to background
    background = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    background.paste(img, (0, 0), mask)

    # Add subtle inner shadow for depth
    inner_shadow = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(inner_shadow)
    shadow_overlay = create_rounded_rectangle(size, size, radius, (0, 0, 0, 40))
    inner_shadow.paste(shadow_overlay, (0, 0), shadow_overlay)

    # Create blur for shadow effect
    inner_shadow = inner_shadow.filter(ImageFilter.GaussianBlur(radius=size//20))

    # Composite
    result = Image.alpha_composite(background, inner_shadow)

    # Draw house icon in center
    house_draw = ImageDraw.Draw(result)
    house_color = (60, 40, 20)  # Dark brown

    # House dimensions
    house_width = size * 0.45
    house_height = size * 0.4
    house_left = (size - house_width) / 2
    house_top = size * 0.28

    # Draw house body (rectangle)
    body_top = house_top + house_height * 0.35
    body_bottom = house_top + house_height
    body_left = house_left
    body_right = house_left + house_width

    house_draw.rectangle(
        [body_left, body_top, body_right, body_bottom],
        fill=house_color
    )

    # Draw roof (triangle)
    roof_points = [
        (house_left - house_width * 0.1, body_top),  # Left eaves
        (house_left + house_width / 2, house_top - house_height * 0.35),  # Peak
        (body_right + house_width * 0.1, body_top),  # Right eaves
    ]
    house_draw.polygon(roof_points, fill=house_color)

    # Draw door
    door_width = house_width * 0.25
    door_height = house_height * 0.4
    door_left = house_left + (house_width - door_width) / 2
    door_top = body_bottom - door_height

    house_draw.rectangle(
        [door_left, door_top, door_left + door_width, body_bottom],
        fill=(40, 25, 10)  # Darker door
    )

    # Add subtle highlight to roof
    highlight_points = [
        (house_left - house_width * 0.1, body_top),
        (house_left + house_width / 2, house_top - house_height * 0.35),
        (house_left + house_width * 0.15, body_top),
    ]
    house_draw.polygon(highlight_points, fill=(80, 55, 30))

    # Add soft shadow under house for depth
    shadow_overlay = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow_overlay)
    shadow_y = body_bottom - size * 0.02
    shadow_draw.ellipse(
        [house_left + size*0.1, shadow_y, body_right - size*0.1, shadow_y + size*0.08],
        fill=(0, 0, 0, 30)
    )
    shadow_overlay = shadow_overlay.filter(ImageFilter.GaussianBlur(radius=size//25))
    result = Image.alpha_composite(result, shadow_overlay)

    return result

def create_appiconset(output_dir):
    """Create AppIcon.appiconset with all required sizes."""
    appiconset_dir = os.path.join(output_dir, 'AppIcon.appiconset')
    os.makedirs(appiconset_dir, exist_ok=True)

    # macOS app icon sizes (in points, using @2x for Retina)
    sizes = [
        (16, 'icon_16x16.png'),
        (32, 'icon_16x16@2x.png'),
        (32, 'icon_32x32.png'),
        (64, 'icon_32x32@2x.png'),
        (128, 'icon_128x128.png'),
        (256, 'icon_128x128@2x.png'),
        (256, 'icon_256x256.png'),
        (512, 'icon_256x256@2x.png'),
        (512, 'icon_512x512.png'),
        (1024, 'icon_512x512@2x.png'),
    ]

    for size, filename in sizes:
        icon = create_icon(size)
        icon.save(os.path.join(appiconset_dir, filename), 'PNG')

    # Create Contents.json
    contents_json = '''{
  "images" : [
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "16x16"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "16x16"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "32x32"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "32x32"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "128x128"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "128x128"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "256x256"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "256x256"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "512x512"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}'''

    with open(os.path.join(appiconset_dir, 'Contents.json'), 'w') as f:
        f.write(contents_json)

    print(f"Created AppIcon.appiconset at {appiconset_dir}")
    return appiconset_dir

if __name__ == '__main__':
    # Create in current directory
    create_appiconset('.')
    print("App icon created successfully!")
