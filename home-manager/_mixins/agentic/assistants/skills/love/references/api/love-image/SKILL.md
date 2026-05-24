---
name: love-image
description: Provides an interface to decode encoded image data. Use this skill when working with image operations, texture management, image data manipulation, or any image-related operations in LÖVE games.
license: MIT
metadata:
  author: Ron Dekker <rondekker.nl>
---

## When to use this skill
Provides an interface to decode encoded image data. Use this skill when working with image operations, texture management, image data manipulation, or any image-related operations in LÖVE games.

## Common use cases
- Loading and processing image files
- Managing image data and textures
- Performing image transformations and manipulations
- Working with compressed image formats
- Handling image metadata and properties

## Functions

- `love.image.isCompressed` - Determines whether a file can be loaded as CompressedImageData.
  - `love.image.isCompressed(filename: string) -> compressed: boolean`: No description
  - `love.image.isCompressed(fileData: FileData) -> compressed: boolean`: No description
- `love.image.newCompressedData` - Create a new CompressedImageData object from a compressed image file. LÖVE supports several compressed texture formats, enumerated in the CompressedImageFormat page.
  - `love.image.newCompressedData(filename: string) -> compressedImageData: CompressedImageData`: No description
  - `love.image.newCompressedData(fileData: FileData) -> compressedImageData: CompressedImageData`: No description
- `love.image.newImageData` - Creates a new ImageData object.
  - `love.image.newImageData(width: number, height: number) -> imageData: ImageData`: No description
  - `love.image.newImageData(width: number, height: number, format: PixelFormat, data: string) -> imageData: ImageData`: No description
  - `love.image.newImageData(width: number, height: number, data: string) -> imageData: ImageData`: No description
  - `love.image.newImageData(filename: string) -> imageData: ImageData`: No description
  - `love.image.newImageData(filedata: FileData) -> imageData: ImageData`: No description

## Types

- `CompressedImageData`: Represents compressed image data designed to stay compressed in RAM. CompressedImageData encompasses standard compressed texture formats such as  DXT1, DXT5, and BC5 / 3Dc. You can't draw CompressedImageData directly to the screen. See Image for that.
  - `love.CompressedImageData.getDimensions() -> width: number, height: number`: Gets the width and height of the CompressedImageData.
  - `love.CompressedImageData.getFormat() -> format: CompressedImageFormat`: Gets the format of the CompressedImageData.
  - `love.CompressedImageData.getHeight() -> height: number`: Gets the height of the CompressedImageData.
  - `love.CompressedImageData.getMipmapCount() -> mipmaps: number`: Gets the number of mipmap levels in the CompressedImageData. The base mipmap level (original image) is included in the count.
  - `love.CompressedImageData.getWidth() -> width: number`: Gets the width of the CompressedImageData.

- `ImageData`: Raw (decoded) image data. You can't draw ImageData directly to screen. See Image for that.
  - `love.ImageData.encode(format: ImageFormat, filename: string) -> filedata: FileData`: Encodes the ImageData and optionally writes it to the save directory.
  - `love.ImageData.getDimensions() -> width: number, height: number`: Gets the width and height of the ImageData in pixels.
  - `love.ImageData.getHeight() -> height: number`: Gets the height of the ImageData in pixels.
  - `love.ImageData.getPixel(x: number, y: number) -> r: number, g: number, b: number, a: number`: Gets the color of a pixel at a specific position in the image. Valid x and y values start at 0 and go up to image width and height minus 1. Non-integer values are floored. In versions prior to 11.0, color component values were within the range of 0 to 255 instead of 0 to 1.
  - `love.ImageData.getWidth() -> width: number`: Gets the width of the ImageData in pixels.
  - `love.ImageData.mapPixel(pixelFunction: function, x: number, y: number, width: number, height: number)`: Transform an image by applying a function to every pixel. This function is a higher-order function. It takes another function as a parameter, and calls it once for each pixel in the ImageData. The passed function is called with six parameters for each pixel in turn. The parameters are numbers that represent the x and y coordinates of the pixel and its red, green, blue and alpha values. The function should return the new red, green, blue, and alpha values for that pixel. function pixelFunction(x, y, r, g, b, a)     -- template for defining your own pixel mapping function     -- perform computations giving the new values for r, g, b and a     -- ...     return r, g, b, a end In versions prior to 11.0, color component values were within the range of 0 to 255 instead of 0 to 1.
  - `love.ImageData.paste(source: ImageData, dx: number, dy: number, sx: number, sy: number, sw: number, sh: number)`: Paste into ImageData from another source ImageData.
  - `love.ImageData.setPixel(x: number, y: number, r: number, g: number, b: number, a: number)`: Sets the color of a pixel at a specific position in the image. Valid x and y values start at 0 and go up to image width and height minus 1. In versions prior to 11.0, color component values were within the range of 0 to 255 instead of 0 to 1.
  - `love.ImageData.getFormat() -> format: PixelFormat`: Gets the pixel format of the ImageData.

## Enums

- `CompressedImageFormat`: Compressed image data formats. Here and here are a couple overviews of many of the formats. Unlike traditional PNG or jpeg, these formats stay compressed in RAM and in the graphics card's VRAM. This is good for saving memory space as well as improving performance, since the graphics card will be able to keep more of the image's pixels in its fast-access cache when drawing it.
  - `DXT1`: The DXT1 format. RGB data at 4 bits per pixel (compared to 32 bits for ImageData and regular Images.) Suitable for fully opaque images on desktop systems.
  - `DXT3`: The DXT3 format. RGBA data at 8 bits per pixel. Smooth variations in opacity do not mix well with this format.
  - `DXT5`: The DXT5 format. RGBA data at 8 bits per pixel. Recommended for images with varying opacity on desktop systems.
  - `BC4`: The BC4 format (also known as 3Dc+ or ATI1.) Stores just the red channel, at 4 bits per pixel.
  - `BC4s`: The signed variant of the BC4 format. Same as above but pixel values in the texture are in the range of 1 instead of 1 in shaders.
  - `BC5`: The BC5 format (also known as 3Dc or ATI2.) Stores red and green channels at 8 bits per pixel.
  - `BC5s`: The signed variant of the BC5 format.
  - `BC6h`: The BC6H format. Stores half-precision floating-point RGB data in the range of 65504 at 8 bits per pixel. Suitable for HDR images on desktop systems.
  - `BC6hs`: The signed variant of the BC6H format. Stores RGB data in the range of +65504.
  - `BC7`: The BC7 format (also known as BPTC.) Stores RGB or RGBA data at 8 bits per pixel.
  - `ETC1`: The ETC1 format. RGB data at 4 bits per pixel. Suitable for fully opaque images on older Android devices.
  - `ETC2rgb`: The RGB variant of the ETC2 format. RGB data at 4 bits per pixel. Suitable for fully opaque images on newer mobile devices.
  - `ETC2rgba`: The RGBA variant of the ETC2 format. RGBA data at 8 bits per pixel. Recommended for images with varying opacity on newer mobile devices.
  - `ETC2rgba1`: The RGBA variant of the ETC2 format where pixels are either fully transparent or fully opaque. RGBA data at 4 bits per pixel.
  - `EACr`: The single-channel variant of the EAC format. Stores just the red channel, at 4 bits per pixel.
  - `EACrs`: The signed single-channel variant of the EAC format. Same as above but pixel values in the texture are in the range of 1 instead of 1 in shaders.
  - `EACrg`: The two-channel variant of the EAC format. Stores red and green channels at 8 bits per pixel.
  - `EACrgs`: The signed two-channel variant of the EAC format.
  - `PVR1rgb2`: The 2 bit per pixel RGB variant of the PVRTC1 format. Stores RGB data at 2 bits per pixel. Textures compressed with PVRTC1 formats must be square and power-of-two sized.
  - `PVR1rgb4`: The 4 bit per pixel RGB variant of the PVRTC1 format. Stores RGB data at 4 bits per pixel.
  - `PVR1rgba2`: The 2 bit per pixel RGBA variant of the PVRTC1 format.
  - `PVR1rgba4`: The 4 bit per pixel RGBA variant of the PVRTC1 format.
  - `ASTC4x4`: The 4x4 pixels per block variant of the ASTC format. RGBA data at 8 bits per pixel.
  - `ASTC5x4`: The 5x4 pixels per block variant of the ASTC format. RGBA data at 6.4 bits per pixel.
  - `ASTC5x5`: The 5x5 pixels per block variant of the ASTC format. RGBA data at 5.12 bits per pixel.
  - `ASTC6x5`: The 6x5 pixels per block variant of the ASTC format. RGBA data at 4.27 bits per pixel.
  - `ASTC6x6`: The 6x6 pixels per block variant of the ASTC format. RGBA data at 3.56 bits per pixel.
  - `ASTC8x5`: The 8x5 pixels per block variant of the ASTC format. RGBA data at 3.2 bits per pixel.
  - `ASTC8x6`: The 8x6 pixels per block variant of the ASTC format. RGBA data at 2.67 bits per pixel.
  - `ASTC8x8`: The 8x8 pixels per block variant of the ASTC format. RGBA data at 2 bits per pixel.
  - `ASTC10x5`: The 10x5 pixels per block variant of the ASTC format. RGBA data at 2.56 bits per pixel.
  - `ASTC10x6`: The 10x6 pixels per block variant of the ASTC format. RGBA data at 2.13 bits per pixel.
  - `ASTC10x8`: The 10x8 pixels per block variant of the ASTC format. RGBA data at 1.6 bits per pixel.
  - `ASTC10x10`: The 10x10 pixels per block variant of the ASTC format. RGBA data at 1.28 bits per pixel.
  - `ASTC12x10`: The 12x10 pixels per block variant of the ASTC format. RGBA data at 1.07 bits per pixel.
  - `ASTC12x12`: The 12x12 pixels per block variant of the ASTC format. RGBA data at 0.89 bits per pixel.

- `ImageFormat`: Encoded image formats.
  - `tga`: Targa image format.
  - `png`: PNG image format.
  - `jpg`: JPG image format.
  - `bmp`: BMP image format.

- `PixelFormat`: Pixel formats for Textures, ImageData, and CompressedImageData.
  - `unknown`: Indicates unknown pixel format, used internally.
  - `normal`: Alias for rgba8, or srgba8 if gamma-correct rendering is enabled.
  - `hdr`: A format suitable for high dynamic range content - an alias for the rgba16f format, normally.
  - `r8`: Single-channel (red component) format (8 bpp).
  - `rg8`: Two channels (red and green components) with 8 bits per channel (16 bpp).
  - `rgba8`: 8 bits per channel (32 bpp) RGBA. Color channel values range from 0-255 (0-1 in shaders).
  - `srgba8`: gamma-correct version of rgba8.
  - `r16`: Single-channel (red component) format (16 bpp).
  - `rg16`: Two channels (red and green components) with 16 bits per channel (32 bpp).
  - `rgba16`: 16 bits per channel (64 bpp) RGBA. Color channel values range from 0-65535 (0-1 in shaders).
  - `r16f`: Floating point single-channel format (16 bpp). Color values can range from [-65504, +65504].
  - `rg16f`: Floating point two-channel format with 16 bits per channel (32 bpp). Color values can range from [-65504, +65504].
  - `rgba16f`: Floating point RGBA with 16 bits per channel (64 bpp). Color values can range from [-65504, +65504].
  - `r32f`: Floating point single-channel format (32 bpp).
  - `rg32f`: Floating point two-channel format with 32 bits per channel (64 bpp).
  - `rgba32f`: Floating point RGBA with 32 bits per channel (128 bpp).
  - `la8`: Same as rg8, but accessed as (L, L, L, A)
  - `rgba4`: 4 bits per channel (16 bpp) RGBA.
  - `rgb5a1`: RGB with 5 bits each, and a 1-bit alpha channel (16 bpp).
  - `rgb565`: RGB with 5, 6, and 5 bits each, respectively (16 bpp). There is no alpha channel in this format.
  - `rgb10a2`: RGB with 10 bits per channel, and a 2-bit alpha channel (32 bpp).
  - `rg11b10f`: Floating point RGB with 11 bits in the red and green channels, and 10 bits in the blue channel (32 bpp). There is no alpha channel. Color values can range from [0, +65024].
  - `stencil8`: No depth buffer and 8-bit stencil buffer.
  - `depth16`: 16-bit depth buffer and no stencil buffer.
  - `depth24`: 24-bit depth buffer and no stencil buffer.
  - `depth32f`: 32-bit float depth buffer and no stencil buffer.
  - `depth24stencil8`: 24-bit depth buffer and 8-bit stencil buffer.
  - `depth32fstencil8`: 32-bit float depth buffer and 8-bit stencil buffer.
  - `DXT1`: The DXT1 format. RGB data at 4 bits per pixel (compared to 32 bits for ImageData and regular Images.) Suitable for fully opaque images on desktop systems.
  - `DXT3`: The DXT3 format. RGBA data at 8 bits per pixel. Smooth variations in opacity do not mix well with this format.
  - `DXT5`: The DXT5 format. RGBA data at 8 bits per pixel. Recommended for images with varying opacity on desktop systems.
  - `BC4`: The BC4 format (also known as 3Dc+ or ATI1.) Stores just the red channel, at 4 bits per pixel.
  - `BC4s`: The signed variant of the BC4 format. Same as above but pixel values in the texture are in the range of 1 instead of 1 in shaders.
  - `BC5`: The BC5 format (also known as 3Dc or ATI2.) Stores red and green channels at 8 bits per pixel.
  - `BC5s`: The signed variant of the BC5 format.
  - `BC6h`: The BC6H format. Stores half-precision floating-point RGB data in the range of 65504 at 8 bits per pixel. Suitable for HDR images on desktop systems.
  - `BC6hs`: The signed variant of the BC6H format. Stores RGB data in the range of +65504.
  - `BC7`: The BC7 format (also known as BPTC.) Stores RGB or RGBA data at 8 bits per pixel.
  - `ETC1`: The ETC1 format. RGB data at 4 bits per pixel. Suitable for fully opaque images on older Android devices.
  - `ETC2rgb`: The RGB variant of the ETC2 format. RGB data at 4 bits per pixel. Suitable for fully opaque images on newer mobile devices.
  - `ETC2rgba`: The RGBA variant of the ETC2 format. RGBA data at 8 bits per pixel. Recommended for images with varying opacity on newer mobile devices.
  - `ETC2rgba1`: The RGBA variant of the ETC2 format where pixels are either fully transparent or fully opaque. RGBA data at 4 bits per pixel.
  - `EACr`: The single-channel variant of the EAC format. Stores just the red channel, at 4 bits per pixel.
  - `EACrs`: The signed single-channel variant of the EAC format. Same as above but pixel values in the texture are in the range of 1 instead of 1 in shaders.
  - `EACrg`: The two-channel variant of the EAC format. Stores red and green channels at 8 bits per pixel.
  - `EACrgs`: The signed two-channel variant of the EAC format.
  - `PVR1rgb2`: The 2 bit per pixel RGB variant of the PVRTC1 format. Stores RGB data at 2 bits per pixel. Textures compressed with PVRTC1 formats must be square and power-of-two sized.
  - `PVR1rgb4`: The 4 bit per pixel RGB variant of the PVRTC1 format. Stores RGB data at 4 bits per pixel.
  - `PVR1rgba2`: The 2 bit per pixel RGBA variant of the PVRTC1 format.
  - `PVR1rgba4`: The 4 bit per pixel RGBA variant of the PVRTC1 format.
  - `ASTC4x4`: The 4x4 pixels per block variant of the ASTC format. RGBA data at 8 bits per pixel.
  - `ASTC5x4`: The 5x4 pixels per block variant of the ASTC format. RGBA data at 6.4 bits per pixel.
  - `ASTC5x5`: The 5x5 pixels per block variant of the ASTC format. RGBA data at 5.12 bits per pixel.
  - `ASTC6x5`: The 6x5 pixels per block variant of the ASTC format. RGBA data at 4.27 bits per pixel.
  - `ASTC6x6`: The 6x6 pixels per block variant of the ASTC format. RGBA data at 3.56 bits per pixel.
  - `ASTC8x5`: The 8x5 pixels per block variant of the ASTC format. RGBA data at 3.2 bits per pixel.
  - `ASTC8x6`: The 8x6 pixels per block variant of the ASTC format. RGBA data at 2.67 bits per pixel.
  - `ASTC8x8`: The 8x8 pixels per block variant of the ASTC format. RGBA data at 2 bits per pixel.
  - `ASTC10x5`: The 10x5 pixels per block variant of the ASTC format. RGBA data at 2.56 bits per pixel.
  - `ASTC10x6`: The 10x6 pixels per block variant of the ASTC format. RGBA data at 2.13 bits per pixel.
  - `ASTC10x8`: The 10x8 pixels per block variant of the ASTC format. RGBA data at 1.6 bits per pixel.
  - `ASTC10x10`: The 10x10 pixels per block variant of the ASTC format. RGBA data at 1.28 bits per pixel.
  - `ASTC12x10`: The 12x10 pixels per block variant of the ASTC format. RGBA data at 1.07 bits per pixel.
  - `ASTC12x12`: The 12x12 pixels per block variant of the ASTC format. RGBA data at 0.89 bits per pixel.

## Examples

### Loading an image
```lua
-- Load an image file
local imageData = love.image.newImageData("texture.png")
local image = love.graphics.newImage(imageData)
```

### Creating image data
```lua
-- Create new image data
local width, height = 256, 256
local imageData = love.image.newImageData(width, height)

-- Modify pixel data
for y = 0, height-1 do
  for x = 0, width-1 do
    local r = x / width
    local g = y / height
    local b = 0.5
    imageData:setPixel(x, y, r, g, b, 1)
  end
end

-- Create image from data
local image = love.graphics.newImage(imageData)
```

## Best practices
- Load images during initialization to avoid runtime delays
- Use appropriate image formats for different use cases
- Consider memory usage when working with large images
- Handle image loading errors gracefully
- Test image formats on target platforms

## Platform compatibility
- **Desktop (Windows, macOS, Linux)**: Full image support
- **Mobile (iOS, Android)**: Full support with some format limitations
- **Web**: Good support but some formats may not be available
