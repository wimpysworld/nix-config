---
name: love-graphics
description: The primary responsibility for the love.graphics module is the drawing of lines, shapes, text, Images and other Drawable objects onto the screen. Its secondary responsibilities include loading external files (including Images and Fonts) into memory, creating specialized objects (such as ParticleSystems or Canvases) and managing screen geometry. LÖVE's coordinate system is rooted in the upper-left corner of the screen, which is at location (0, 0). The x axis is horizontal: larger values are further to the right. The y axis is vertical: larger values are further towards the bottom. In many cases, you draw images or shapes in terms of their upper-left corner. Many of the functions are used to manipulate the graphics coordinate system, which is essentially the way coordinates are mapped to the display. You can change the position, scale, and even rotation in this way. Use this skill when working with drawing operations, sprites, animations, shaders, or any visual rendering in LÖVE games.
license: MIT
metadata:
  author: Ron Dekker <rondekker.nl>
---

## When to use this skill
The primary responsibility for the love.graphics module is the drawing of lines, shapes, text, Images and other Drawable objects onto the screen. Its secondary responsibilities include loading external files (including Images and Fonts) into memory, creating specialized objects (such as ParticleSystems or Canvases) and managing screen geometry. LÖVE's coordinate system is rooted in the upper-left corner of the screen, which is at location (0, 0). The x axis is horizontal: larger values are further to the right. The y axis is vertical: larger values are further towards the bottom. In many cases, you draw images or shapes in terms of their upper-left corner. Many of the functions are used to manipulate the graphics coordinate system, which is essentially the way coordinates are mapped to the display. You can change the position, scale, and even rotation in this way. Use this skill when working with drawing operations, sprites, animations, shaders, or any visual rendering in LÖVE games.

## Common use cases
- Drawing shapes, images, and text
- Creating animations and particle effects
- Implementing custom shaders and post-processing effects
- Managing sprites and sprite batches
- Handling screen transitions and visual effects

## Functions

- `love.graphics.applyTransform(transform: Transform)`: Applies the given Transform object to the current coordinate transformation. This effectively multiplies the existing coordinate transformation's matrix with the Transform object's internal matrix to produce the new coordinate transformation.
- `love.graphics.arc` - Draws a filled or unfilled arc at position (x, y). The arc is drawn from angle1 to angle2 in radians. The segments parameter determines how many segments are used to draw the arc. The more segments, the smoother the edge.
  - `love.graphics.arc(drawmode: DrawMode, x: number, y: number, radius: number, angle1: number, angle2: number, segments: number)`: Draws an arc using the 'pie' ArcType.
  - `love.graphics.arc(drawmode: DrawMode, arctype: ArcType, x: number, y: number, radius: number, angle1: number, angle2: number, segments: number)`: 
- `love.graphics.captureScreenshot` - Creates a screenshot once the current frame is done (after love.draw has finished). Since this function enqueues a screenshot capture rather than executing it immediately, it can be called from an input callback or love.update and it will still capture all of what's drawn to the screen in that frame.
  - `love.graphics.captureScreenshot(filename: string)`: Capture a screenshot and save it to a file at the end of the current frame.
  - `love.graphics.captureScreenshot(callback: function)`: Capture a screenshot and call a callback with the generated ImageData at the end of the current frame.
  - `love.graphics.captureScreenshot(channel: Channel)`: Capture a screenshot and push the generated ImageData to a Channel at the end of the current frame.
- `love.graphics.circle` - Draws a circle.
  - `love.graphics.circle(mode: DrawMode, x: number, y: number, radius: number)`: No description
  - `love.graphics.circle(mode: DrawMode, x: number, y: number, radius: number, segments: number)`: No description
- `love.graphics.clear` - Clears the screen or active Canvas to the specified color. This function is called automatically before love.draw in the default love.run function. See the example in love.run for a typical use of this function. Note that the scissor area bounds the cleared region. In versions prior to 11.0, color component values were within the range of 0 to 255 instead of 0 to 1. In versions prior to background color instead.
  - `love.graphics.clear()`: Clears the screen to the background color in 0.9.2 and earlier, or to transparent black (0, 0, 0, 0) in LÖVE 0.10.0 and newer.
  - `love.graphics.clear(r: number, g: number, b: number, a: number, clearstencil: boolean, cleardepth: boolean)`: Clears the screen or active Canvas to the specified color.
  - `love.graphics.clear(color: table, ...: table, clearstencil: boolean, cleardepth: boolean)`: Clears multiple active Canvases to different colors, if multiple Canvases are active at once via love.graphics.setCanvas. A color must be specified for each active Canvas, when this function variant is used.
  - `love.graphics.clear(clearcolor: boolean, clearstencil: boolean, cleardepth: boolean)`: Clears the stencil or depth buffers without having to clear the color canvas as well.
- `love.graphics.discard` - Discards (trashes) the contents of the screen or active Canvas. This is a performance optimization function with niche use cases. If the active Canvas has just been changed and the 'replace' BlendMode is about to be used to draw something which covers the entire screen, calling love.graphics.discard rather than calling love.graphics.clear or doing nothing may improve performance on mobile devices. On some desktop systems this function may do nothing.
  - `love.graphics.discard(discardcolor: boolean, discardstencil: boolean)`: No description
  - `love.graphics.discard(discardcolors: table, discardstencil: boolean)`: No description
- `love.graphics.draw` - Draws a Drawable object (an Image, Canvas, SpriteBatch, ParticleSystem, Mesh, Text object, or Video) on the screen with optional rotation, scaling and shearing. Objects are drawn relative to their local coordinate system. The origin is by default located at the top left corner of Image and Canvas. All scaling, shearing, and rotation arguments transform the object relative to that point. Also, the position of the origin can be specified on the screen coordinate system. It's possible to rotate an object about its center by offsetting the origin to the center. Angles must be given in radians for rotation. One can also use a negative scaling factor to flip about its centerline.  Note that the offsets are applied before rotation, scaling, or shearing; scaling and shearing are applied before rotation. The right and bottom edges of the object are shifted at an angle defined by the shearing factors. When using the default shader anything drawn with this function will be tinted according to the currently selected color.  Set it to pure white to preserve the object's original colors.
  - `love.graphics.draw(drawable: Drawable, x: number, y: number, r: number, sx: number, sy: number, ox: number, oy: number, kx: number, ky: number)`: No description
  - `love.graphics.draw(texture: Texture, quad: Quad, x: number, y: number, r: number, sx: number, sy: number, ox: number, oy: number, kx: number, ky: number)`: No description
  - `love.graphics.draw(drawable: Drawable, transform: Transform)`: No description
  - `love.graphics.draw(texture: Texture, quad: Quad, transform: Transform)`: No description
- `love.graphics.drawInstanced` - Draws many instances of a Mesh with a single draw call, using hardware geometry instancing. Each instance can have unique properties (positions, colors, etc.) but will not by default unless a custom per-instance vertex attributes or the love_InstanceID GLSL 3 vertex shader variable is used, otherwise they will all render at the same position on top of each other. Instancing is not supported by some older GPUs that are only capable of using OpenGL ES 2 or OpenGL 2. Use love.graphics.getSupported to check.
  - `love.graphics.drawInstanced(mesh: Mesh, instancecount: number, x: number, y: number, r: number, sx: number, sy: number, ox: number, oy: number, kx: number, ky: number)`: No description
  - `love.graphics.drawInstanced(mesh: Mesh, instancecount: number, transform: Transform)`: No description
- `love.graphics.drawLayer` - Draws a layer of an Array Texture.
  - `love.graphics.drawLayer(texture: Texture, layerindex: number, x: number, y: number, r: number, sx: number, sy: number, ox: number, oy: number, kx: number, ky: number)`: Draws a layer of an Array Texture.
  - `love.graphics.drawLayer(texture: Texture, layerindex: number, quad: Quad, x: number, y: number, r: number, sx: number, sy: number, ox: number, oy: number, kx: number, ky: number)`: Draws a layer of an Array Texture using the specified Quad. The specified layer index overrides any layer index set on the Quad via Quad:setLayer.
  - `love.graphics.drawLayer(texture: Texture, layerindex: number, transform: Transform)`: Draws a layer of an Array Texture using the specified Transform.
  - `love.graphics.drawLayer(texture: Texture, layerindex: number, quad: Quad, transform: Transform)`: Draws a layer of an Array Texture using the specified Quad and Transform. In order to use an Array Texture or other non-2D texture types as the main texture in a custom void effect() variant must be used in the pixel shader, and MainTex must be declared as an ArrayImage or sampler2DArray like so: uniform ArrayImage MainTex;.
- `love.graphics.ellipse` - Draws an ellipse.
  - `love.graphics.ellipse(mode: DrawMode, x: number, y: number, radiusx: number, radiusy: number)`: No description
  - `love.graphics.ellipse(mode: DrawMode, x: number, y: number, radiusx: number, radiusy: number, segments: number)`: No description
- `love.graphics.flushBatch()`: Immediately renders any pending automatically batched draws. LÖVE will call this function internally as needed when most state is changed, so it is not necessary to manually call it. The current batch will be automatically flushed by love.graphics state changes (except for the transform stack and the current color), as well as Shader:send and methods on Textures which change their state. Using a different Image in consecutive love.graphics.draw calls will also flush the current batch. SpriteBatches, ParticleSystems, Meshes, and Text objects do their own batching and do not affect automatic batching of other draws, aside from flushing the current batch when they're drawn.
- `love.graphics.getBackgroundColor() -> r: number, g: number, b: number, a: number`: Gets the current background color. In versions prior to 11.0, color component values were within the range of 0 to 255 instead of 0 to 1.
- `love.graphics.getBlendMode() -> mode: BlendMode, alphamode: BlendAlphaMode`: Gets the blending mode.
- `love.graphics.getCanvas() -> canvas: Canvas`: Gets the current target Canvas.
- `love.graphics.getCanvasFormats` - Gets the available Canvas formats, and whether each is supported.
  - `love.graphics.getCanvasFormats() -> formats: table`: No description
  - `love.graphics.getCanvasFormats(readable: boolean) -> formats: table`: No description
- `love.graphics.getColor() -> r: number, g: number, b: number, a: number`: Gets the current color. In versions prior to 11.0, color component values were within the range of 0 to 255 instead of 0 to 1.
- `love.graphics.getColorMask() -> r: boolean, g: boolean, b: boolean, a: boolean`: Gets the active color components used when drawing. Normally all 4 components are active unless love.graphics.setColorMask has been used. The color mask determines whether individual components of the colors of drawn objects will affect the color of the screen. They affect love.graphics.clear and Canvas:clear as well.
- `love.graphics.getDPIScale() -> scale: number`: Gets the DPI scale factor of the window. The DPI scale factor represents relative pixel density. The pixel density inside the window might be greater (or smaller) than the 'size' of the window. For example on a retina screen in Mac OS X with the highdpi window flag enabled, the window may take up the same physical size as an 800x600 window, but the area inside the window uses 1600x1200 pixels. love.graphics.getDPIScale() would return 2 in that case. The love.window.fromPixels and love.window.toPixels functions can also be used to convert between units. The highdpi window flag must be enabled to use the full pixel density of a Retina screen on Mac OS X and iOS. The flag currently does nothing on Windows and Linux, and on Android it is effectively always enabled.
- `love.graphics.getDefaultFilter() -> min: FilterMode, mag: FilterMode, anisotropy: number`: Returns the default scaling filters used with Images, Canvases, and Fonts.
- `love.graphics.getDepthMode() -> comparemode: CompareMode, write: boolean`: Gets the current depth test mode and whether writing to the depth buffer is enabled. This is low-level functionality designed for use with custom vertex shaders and Meshes with custom vertex attributes. No higher level APIs are provided to set the depth of 2D graphics such as shapes, lines, and Images.
- `love.graphics.getDimensions() -> width: number, height: number`: Gets the width and height in pixels of the window.
- `love.graphics.getFont() -> font: Font`: Gets the current Font object.
- `love.graphics.getFrontFaceWinding() -> winding: VertexWinding`: Gets whether triangles with clockwise- or counterclockwise-ordered vertices are considered front-facing. This is designed for use in combination with Mesh face culling. Other love.graphics shapes, lines, and sprites are not guaranteed to have a specific winding order to their internal vertices.
- `love.graphics.getHeight() -> height: number`: Gets the height in pixels of the window.
- `love.graphics.getImageFormats() -> formats: table`: Gets the raw and compressed pixel formats usable for Images, and whether each is supported.
- `love.graphics.getLineJoin() -> join: LineJoin`: Gets the line join style.
- `love.graphics.getLineStyle() -> style: LineStyle`: Gets the line style.
- `love.graphics.getLineWidth() -> width: number`: Gets the current line width.
- `love.graphics.getMeshCullMode() -> mode: CullMode`: Gets whether back-facing triangles in a Mesh are culled. Mesh face culling is designed for use with low level custom hardware-accelerated 3D rendering via custom vertex attributes on Meshes, custom vertex shaders, and depth testing with a depth buffer.
- `love.graphics.getPixelDimensions() -> pixelwidth: number, pixelheight: number`: Gets the width and height in pixels of the window. love.graphics.getDimensions gets the dimensions of the window in units scaled by the screen's DPI scale factor, rather than pixels. Use getDimensions for calculations related to drawing to the screen and using the graphics coordinate system (calculating the center of the screen, for example), and getPixelDimensions only when dealing specifically with underlying pixels (pixel-related calculations in a pixel Shader, for example).
- `love.graphics.getPixelHeight() -> pixelheight: number`: Gets the height in pixels of the window. The graphics coordinate system and DPI scale factor, rather than raw pixels. Use getHeight for calculations related to drawing to the screen and using the coordinate system (calculating the center of the screen, for example), and getPixelHeight only when dealing specifically with underlying pixels (pixel-related calculations in a pixel Shader, for example).
- `love.graphics.getPixelWidth() -> pixelwidth: number`: Gets the width in pixels of the window. The graphics coordinate system and DPI scale factor, rather than raw pixels. Use getWidth for calculations related to drawing to the screen and using the coordinate system (calculating the center of the screen, for example), and getPixelWidth only when dealing specifically with underlying pixels (pixel-related calculations in a pixel Shader, for example).
- `love.graphics.getPointSize() -> size: number`: Gets the point size.
- `love.graphics.getRendererInfo() -> name: string, version: string, vendor: string, device: string`: Gets information about the system's video card and drivers.
- `love.graphics.getScissor() -> x: number, y: number, width: number, height: number`: Gets the current scissor box.
- `love.graphics.getShader() -> shader: Shader`: Gets the current Shader. Returns nil if none is set.
- `love.graphics.getStackDepth() -> depth: number`: Gets the current depth of the transform / state stack (the number of pushes without corresponding pops).
- `love.graphics.getStats` - Gets performance-related rendering statistics. 
  - `love.graphics.getStats() -> stats: table`: No description
  - `love.graphics.getStats(stats: table) -> stats: table`: This variant accepts an existing table to fill in, instead of creating a new one.
- `love.graphics.getStencilTest() -> comparemode: CompareMode, comparevalue: number`: Gets the current stencil test configuration. When stencil testing is enabled, the geometry of everything that is drawn afterward will be clipped / stencilled out based on a comparison between the arguments of this function and the stencil value of each pixel that the geometry touches. The stencil values of pixels are affected via love.graphics.stencil. Each Canvas has its own per-pixel stencil values.
- `love.graphics.getSupported() -> features: table`: Gets the optional graphics features and whether they're supported on the system. Some older or low-end systems don't always support all graphics features.
- `love.graphics.getSystemLimits() -> limits: table`: Gets the system-dependent maximum values for love.graphics features.
- `love.graphics.getTextureTypes() -> texturetypes: table`: Gets the available texture types, and whether each is supported.
- `love.graphics.getWidth() -> width: number`: Gets the width in pixels of the window.
- `love.graphics.intersectScissor(x: number, y: number, width: number, height: number)`: Sets the scissor to the rectangle created by the intersection of the specified rectangle with the existing scissor.  If no scissor is active yet, it behaves like love.graphics.setScissor. The scissor limits the drawing area to a specified rectangle. This affects all graphics calls, including love.graphics.clear. The dimensions of the scissor is unaffected by graphical transformations (translate, scale, ...).
- `love.graphics.inverseTransformPoint(screenX: number, screenY: number) -> globalX: number, globalY: number`: Converts the given 2D position from screen-space into global coordinates. This effectively applies the reverse of the current graphics transformations to the given position. A similar Transform:inverseTransformPoint method exists for Transform objects.
- `love.graphics.isActive() -> active: boolean`: Gets whether the graphics module is able to be used. If it is not active, love.graphics function and method calls will not work correctly and may cause the program to crash. The graphics module is inactive if a window is not open, or if the app is in the background on iOS. Typically the app's execution will be automatically paused by the system, in the latter case.
- `love.graphics.isGammaCorrect() -> gammacorrect: boolean`: Gets whether gamma-correct rendering is supported and enabled. It can be enabled by setting t.gammacorrect = true in love.conf. Not all devices support gamma-correct rendering, in which case it will be automatically disabled and this function will return false. It is supported on desktop systems which have graphics cards that are capable of using OpenGL 3 / DirectX 10, and iOS devices that can use OpenGL ES 3.
- `love.graphics.isWireframe() -> wireframe: boolean`: Gets whether wireframe mode is used when drawing.
- `love.graphics.line` - Draws lines between points.
  - `love.graphics.line(x1: number, y1: number, x2: number, y2: number, ...: number)`: No description
  - `love.graphics.line(points: table)`: No description
- `love.graphics.newArrayImage(slices: table, settings: table) -> image: Image`: Creates a new array Image. An array image / array texture is a single object which contains multiple 'layers' or 'slices' of 2D sub-images. It can be thought of similarly to a texture atlas or sprite sheet, but it doesn't suffer from the same tile / quad bleeding artifacts that texture atlases do – although every sub-image must have the same dimensions. A specific layer of an array image can be drawn with love.graphics.drawLayer / SpriteBatch:addLayer, or with the Quad variant of love.graphics.draw and Quad:setLayer, or via a custom Shader. To use an array image in a Shader, it must be declared as a ArrayImage or sampler2DArray type (instead of Image or sampler2D). The Texel(ArrayImage image, vec3 texturecoord) shader function must be used to get pixel colors from a slice of the array image. The vec3 argument contains the texture coordinate in the first two components, and the 0-based slice index in the third component.
- `love.graphics.newCanvas` - Creates a new Canvas object for offscreen rendering.
  - `love.graphics.newCanvas() -> canvas: Canvas`: No description
  - `love.graphics.newCanvas(width: number, height: number) -> canvas: Canvas`: No description
  - `love.graphics.newCanvas(width: number, height: number, settings: table) -> canvas: Canvas`: Creates a 2D or cubemap Canvas using the given settings. Some Canvas formats have higher system requirements than the default format. Use love.graphics.getCanvasFormats to check for support.
  - `love.graphics.newCanvas(width: number, height: number, layers: number, settings: table) -> canvas: Canvas`: Creates a volume or array texture-type Canvas.
- `love.graphics.newCubeImage` - Creates a new cubemap Image. Cubemap images have 6 faces (sides) which represent a cube. They can't be rendered directly, they can only be used in Shader code (and sent to the shader via Shader:send). To use a cubemap image in a Shader, it must be declared as a CubeImage or samplerCube type (instead of Image or sampler2D). The Texel(CubeImage image, vec3 direction) shader function must be used to get pixel colors from the cubemap. The vec3 argument is a normalized direction from the center of the cube, rather than explicit texture coordinates. Each face in a cubemap image must have square dimensions. For variants of this function which accept a single image containing multiple cubemap faces, they must be laid out in one of the following forms in the image:    +y +z +x -z    -y    -x or:    +y -x +z +x -z    -y or: +x -x +y -y +z -z or: +x -x +y -y +z -z
  - `love.graphics.newCubeImage(filename: string, settings: table) -> image: Image`: Creates a cubemap Image given a single image file containing multiple cube faces.
  - `love.graphics.newCubeImage(faces: table, settings: table) -> image: Image`: Creates a cubemap Image given a different image file for each cube face.
- `love.graphics.newFont` - Creates a new Font from a TrueType Font or BMFont file. Created fonts are not cached, in that calling this function with the same arguments will always create a new Font object. All variants which accept a filename can also accept a Data object instead.
  - `love.graphics.newFont(filename: string) -> font: Font`: Create a new BMFont or TrueType font. If the file is a TrueType font, it will be size 12. Use the variant below to create a TrueType font with a custom size.
  - `love.graphics.newFont(filename: string, size: number, hinting: HintingMode, dpiscale: number) -> font: Font`: Create a new TrueType font.
  - `love.graphics.newFont(filename: string, imagefilename: string) -> font: Font`: Create a new BMFont.
  - `love.graphics.newFont(size: number, hinting: HintingMode, dpiscale: number) -> font: Font`: Create a new instance of the default font (Vera Sans) with a custom size.
- `love.graphics.newImage` - Creates a new Image from a filepath, FileData, an ImageData, or a CompressedImageData, and optionally generates or specifies mipmaps for the image.
  - `love.graphics.newImage(filename: string, settings: table) -> image: Image`: No description
  - `love.graphics.newImage(fileData: FileData, settings: table) -> image: Image`: No description
  - `love.graphics.newImage(imageData: ImageData, settings: table) -> image: Image`: No description
  - `love.graphics.newImage(compressedImageData: CompressedImageData, settings: table) -> image: Image`: No description
- `love.graphics.newImageFont` - Creates a new specifically formatted image. In versions prior to 0.9.0, LÖVE expects ISO 8859-1 encoding for the glyphs string.
  - `love.graphics.newImageFont(filename: string, glyphs: string) -> font: Font`: No description
  - `love.graphics.newImageFont(imageData: ImageData, glyphs: string) -> font: Font`: No description
  - `love.graphics.newImageFont(filename: string, glyphs: string, extraspacing: number) -> font: Font`: Instead of using this function, consider using a BMFont generator such as bmfont, littera, or bmGlyph with love.graphics.newFont. Because slime said it was better.
- `love.graphics.newMesh` - Creates a new Mesh. Use Mesh:setTexture if the Mesh should be textured with an Image or Canvas when it's drawn. In versions prior to 11.0, color and byte component values were within the range of 0 to 255 instead of 0 to 1.
  - `love.graphics.newMesh(vertices: table, mode: MeshDrawMode, usage: SpriteBatchUsage) -> mesh: Mesh`: Creates a standard Mesh with the specified vertices.
  - `love.graphics.newMesh(vertexcount: number, mode: MeshDrawMode, usage: SpriteBatchUsage) -> mesh: Mesh`: Creates a standard Mesh with the specified number of vertices. Mesh:setVertices or Mesh:setVertex and Mesh:setDrawRange can be used to specify vertex information once the Mesh is created.
  - `love.graphics.newMesh(vertexformat: table, vertices: table, mode: MeshDrawMode, usage: SpriteBatchUsage) -> mesh: Mesh`: Creates a Mesh with custom vertex attributes and the specified vertex data. The values in each vertex table are in the same order as the vertex attributes in the specified vertex format. If no value is supplied for a specific vertex attribute component, it will be set to a default value of 0 if its data type is 'float', or 1 if its data type is 'byte'. If the data type of an attribute is 'float', components can be in the range 1 to 4, if the data type is 'byte' it must be 4. If a custom vertex attribute uses the name 'VertexPosition', 'VertexTexCoord', or 'VertexColor', then the vertex data for that vertex attribute will be used for the standard vertex positions, texture coordinates, or vertex colors respectively, when drawing the Mesh. Otherwise a Vertex Shader is required in order to make use of the vertex attribute when the Mesh is drawn. A Mesh '''must''' have a 'VertexPosition' attribute in order to be drawn, but it can be attached from a different Mesh via Mesh:attachAttribute. To use a custom named vertex attribute in a Vertex Shader, it must be declared as an attribute variable of the same name. Variables can be sent from Vertex Shader code to Pixel Shader code by making a varying variable. For example: ''Vertex Shader code'' attribute vec2 CoolVertexAttribute; varying vec2 CoolVariable; vec4 position(mat4 transform_projection, vec4 vertex_position) {     CoolVariable = CoolVertexAttribute;     return transform_projection * vertex_position; } ''Pixel Shader code'' varying vec2 CoolVariable; vec4 effect(vec4 color, Image tex, vec2 texcoord, vec2 pixcoord) {     vec4 texcolor = Texel(tex, texcoord + CoolVariable);     return texcolor * color; }
  - `love.graphics.newMesh(vertexformat: table, vertexcount: number, mode: MeshDrawMode, usage: SpriteBatchUsage) -> mesh: Mesh`: Creates a Mesh with custom vertex attributes and the specified number of vertices. Each vertex attribute component is initialized to 0 if its data type is 'float', or 1 if its data type is 'byte'. Vertex Shader is required in order to make use of the vertex attribute when the Mesh is drawn. A Mesh '''must''' have a 'VertexPosition' attribute in order to be drawn, but it can be attached from a different Mesh via Mesh:attachAttribute.
  - `love.graphics.newMesh(vertexcount: number, texture: Texture, mode: MeshDrawMode) -> mesh: Mesh`: Mesh:setVertices or Mesh:setVertex and Mesh:setDrawRange can be used to specify vertex information once the Mesh is created.
- `love.graphics.newParticleSystem` - Creates a new ParticleSystem.
  - `love.graphics.newParticleSystem(image: Image, buffer: number) -> system: ParticleSystem`: No description
  - `love.graphics.newParticleSystem(texture: Texture, buffer: number) -> system: ParticleSystem`: No description
- `love.graphics.newQuad` - Creates a new Quad. The purpose of a Quad is to use a fraction of an image to draw objects, as opposed to drawing entire image. It is most useful for sprite sheets and atlases: in a sprite atlas, multiple sprites reside in same image, quad is used to draw a specific sprite from that image; in animated sprites with all frames residing in the same image, quad is used to draw specific frame from the animation.
  - `love.graphics.newQuad(x: number, y: number, width: number, height: number, sw: number, sh: number) -> quad: Quad`: No description
  - `love.graphics.newQuad(x: number, y: number, width: number, height: number, texture: Texture) -> quad: Quad`: No description
- `love.graphics.newShader` - Creates a new Shader object for hardware-accelerated vertex and pixel effects. A Shader contains either vertex shader code, pixel shader code, or both. Shaders are small programs which are run on the graphics card when drawing. Vertex shaders are run once for each vertex (for example, an image has 4 vertices - one at each corner. A Mesh might have many more.) Pixel shaders are run once for each pixel on the screen which the drawn object touches. Pixel shader code is executed after all the object's vertices have been processed by the vertex shader.
  - `love.graphics.newShader(code: string) -> shader: Shader`: No description
  - `love.graphics.newShader(pixelcode: string, vertexcode: string) -> shader: Shader`: No description
- `love.graphics.newSpriteBatch` - Creates a new SpriteBatch object.
  - `love.graphics.newSpriteBatch(image: Image, maxsprites: number) -> spriteBatch: SpriteBatch`: No description
  - `love.graphics.newSpriteBatch(image: Image, maxsprites: number, usage: SpriteBatchUsage) -> spriteBatch: SpriteBatch`: No description
  - `love.graphics.newSpriteBatch(texture: Texture, maxsprites: number, usage: SpriteBatchUsage) -> spriteBatch: SpriteBatch`: No description
- `love.graphics.newText` - Creates a new drawable Text object.
  - `love.graphics.newText(font: Font, textstring: string) -> text: Text`: No description
  - `love.graphics.newText(font: Font, coloredtext: table) -> text: Text`: No description
- `love.graphics.newVideo` - Creates a new drawable Video. Currently only Ogg Theora video files are supported.
  - `love.graphics.newVideo(filename: string) -> video: Video`: No description
  - `love.graphics.newVideo(videostream: VideoStream) -> video: Video`: No description
  - `love.graphics.newVideo(filename: string, settings: table) -> video: Video`: No description
  - `love.graphics.newVideo(filename: string, loadaudio: boolean) -> video: Video`: No description
  - `love.graphics.newVideo(videostream: VideoStream, loadaudio: boolean) -> video: Video`: No description
- `love.graphics.newVolumeImage(layers: table, settings: table) -> image: Image`: Creates a new volume (3D) Image. Volume images are 3D textures with width, height, and depth. They can't be rendered directly, they can only be used in Shader code (and sent to the shader via Shader:send). To use a volume image in a Shader, it must be declared as a VolumeImage or sampler3D type (instead of Image or sampler2D). The Texel(VolumeImage image, vec3 texcoords) shader function must be used to get pixel colors from the volume image. The vec3 argument is a normalized texture coordinate with the z component representing the depth to sample at (ranging from 1). Volume images are typically used as lookup tables in shaders for color grading, for example, because sampling using a texture coordinate that is partway in between two pixels can interpolate across all 3 dimensions in the volume image, resulting in a smooth gradient even when a small-sized volume image is used as the lookup table. Array images are a much better choice than volume images for storing multiple different sprites in a single array image for directly drawing them.
- `love.graphics.origin()`: Resets the current coordinate transformation. This function is always used to reverse any previous calls to love.graphics.rotate, love.graphics.scale, love.graphics.shear or love.graphics.translate. It returns the current transformation state to its defaults.
- `love.graphics.points` - Draws one or more points.
  - `love.graphics.points(x: number, y: number, ...: number)`: No description
  - `love.graphics.points(points: table)`: No description
  - `love.graphics.points(points: table)`: Draws one or more individually colored points. In versions prior to 11.0, color component values were within the range of 0 to 255 instead of 0 to 1. The pixel grid is actually offset to the center of each pixel. So to get clean pixels drawn use 0.5 + integer increments. Points are not affected by size is always in pixels.
- `love.graphics.polygon` - Draw a polygon. Following the mode argument, this function can accept multiple numeric arguments or a single table of numeric arguments. In either case the arguments are interpreted as alternating x and y coordinates of the polygon's vertices.
  - `love.graphics.polygon(mode: DrawMode, ...: number)`: No description
  - `love.graphics.polygon(mode: DrawMode, vertices: table)`: No description
- `love.graphics.pop()`: Pops the current coordinate transformation from the transformation stack. This function is always used to reverse a previous push operation. It returns the current transformation state to what it was before the last preceding push.
- `love.graphics.present()`: Displays the results of drawing operations on the screen. This function is used when writing your own love.run function. It presents all the results of your drawing operations on the screen. See the example in love.run for a typical use of this function.
- `love.graphics.print` - Draws text on screen. If no Font is set, one will be created and set (once) if needed. As of LOVE 0.7.1, when using translation and scaling functions while drawing text, this function assumes the scale occurs first.  If you don't script with this in mind, the text won't be in the right position, or possibly even on screen. love.graphics.print and love.graphics.printf both support UTF-8 encoding. You'll also need a proper Font for special characters. In versions prior to 11.0, color and byte component values were within the range of 0 to 255 instead of 0 to 1.
  - `love.graphics.print(text: string, x: number, y: number, r: number, sx: number, sy: number, ox: number, oy: number, kx: number, ky: number)`: No description
  - `love.graphics.print(coloredtext: table, x: number, y: number, angle: number, sx: number, sy: number, ox: number, oy: number, kx: number, ky: number)`: The color set by love.graphics.setColor will be combined (multiplied) with the colors of the text.
  - `love.graphics.print(text: string, transform: Transform)`: No description
  - `love.graphics.print(coloredtext: table, transform: Transform)`: The color set by love.graphics.setColor will be combined (multiplied) with the colors of the text.
  - `love.graphics.print(text: string, font: Font, transform: Transform)`: No description
  - `love.graphics.print(coloredtext: table, font: Font, transform: Transform)`: 
- `love.graphics.printf` - Draws formatted text, with word wrap and alignment. See additional notes in love.graphics.print. The word wrap limit is applied before any scaling, rotation, and other coordinate transformations. Therefore the amount of text per line stays constant given the same wrap limit, even if the scale arguments change. In version 0.9.2 and earlier, wrapping was implemented by breaking up words by spaces and putting them back together to make sure things fit nicely within the limit provided. However, due to the way this is done, extra spaces between words would end up missing when printed on the screen, and some lines could overflow past the provided wrap limit. In version 0.10.0 and newer this is no longer the case. In versions prior to 11.0, color and byte component values were within the range of 0 to 255 instead of 0 to 1.
  - `love.graphics.printf(text: string, x: number, y: number, limit: number, align: AlignMode, r: number, sx: number, sy: number, ox: number, oy: number, kx: number, ky: number)`: No description
  - `love.graphics.printf(text: string, font: Font, x: number, y: number, limit: number, align: AlignMode, r: number, sx: number, sy: number, ox: number, oy: number, kx: number, ky: number)`: No description
  - `love.graphics.printf(text: string, transform: Transform, limit: number, align: AlignMode)`: No description
  - `love.graphics.printf(text: string, font: Font, transform: Transform, limit: number, align: AlignMode)`: No description
  - `love.graphics.printf(coloredtext: table, x: number, y: number, limit: number, align: AlignMode, angle: number, sx: number, sy: number, ox: number, oy: number, kx: number, ky: number)`: The color set by love.graphics.setColor will be combined (multiplied) with the colors of the text.
  - `love.graphics.printf(coloredtext: table, font: Font, x: number, y: number, limit: number, align: AlignMode, angle: number, sx: number, sy: number, ox: number, oy: number, kx: number, ky: number)`: The color set by love.graphics.setColor will be combined (multiplied) with the colors of the text.
  - `love.graphics.printf(coloredtext: table, transform: Transform, limit: number, align: AlignMode)`: The color set by love.graphics.setColor will be combined (multiplied) with the colors of the text.
  - `love.graphics.printf(coloredtext: table, font: Font, transform: Transform, limit: number, align: AlignMode)`: 
- `love.graphics.push` - Copies and pushes the current coordinate transformation to the transformation stack. This function is always used to prepare for a corresponding pop operation later. It stores the current coordinate transformation state into the transformation stack and keeps it active. Later changes to the transformation can be undone by using the pop operation, which returns the coordinate transform to the state it was in before calling push.
  - `love.graphics.push()`: Pushes the current transformation to the transformation stack.
  - `love.graphics.push(stack: StackType)`: Pushes a specific type of state to the stack.
- `love.graphics.rectangle` - Draws a rectangle.
  - `love.graphics.rectangle(mode: DrawMode, x: number, y: number, width: number, height: number)`: No description
  - `love.graphics.rectangle(mode: DrawMode, x: number, y: number, width: number, height: number, rx: number, ry: number, segments: number)`: Draws a rectangle with rounded corners.
- `love.graphics.replaceTransform(transform: Transform)`: Replaces the current coordinate transformation with the given Transform object.
- `love.graphics.reset()`: Resets the current graphics settings. Calling reset makes the current drawing color white, the current background color black, disables any active color component masks, disables wireframe mode and resets the current graphics transformation to the origin. It also sets both the point and line drawing modes to smooth and their sizes to 1.0.
- `love.graphics.rotate(angle: number)`: Rotates the coordinate system in two dimensions. Calling this function affects all future drawing operations by rotating the coordinate system around the origin by the given amount of radians. This change lasts until love.draw() exits.
- `love.graphics.scale(sx: number, sy: number)`: Scales the coordinate system in two dimensions. By default the coordinate system in LÖVE corresponds to the display pixels in horizontal and vertical directions one-to-one, and the x-axis increases towards the right while the y-axis increases downwards. Scaling the coordinate system changes this relation. After scaling by sx and sy, all coordinates are treated as if they were multiplied by sx and sy. Every result of a drawing operation is also correspondingly scaled, so scaling by (2, 2) for example would mean making everything twice as large in both x- and y-directions. Scaling by a negative value flips the coordinate system in the corresponding direction, which also means everything will be drawn flipped or upside down, or both. Scaling by zero is not a useful operation. Scale and translate are not commutative operations, therefore, calling them in different orders will change the outcome. Scaling lasts until love.draw() exits.
- `love.graphics.setBackgroundColor` - Sets the background color.
  - `love.graphics.setBackgroundColor(red: number, green: number, blue: number, alpha: number)`: No description
  - `love.graphics.setBackgroundColor(rgba: table)`: No description
- `love.graphics.setBlendMode` - Sets the blending mode.
  - `love.graphics.setBlendMode(mode: BlendMode)`: No description
  - `love.graphics.setBlendMode(mode: BlendMode, alphamode: BlendAlphaMode)`: The default 'alphamultiply' alpha mode should normally be preferred except when drawing content with pre-multiplied alpha. If content is drawn to a Canvas using the 'alphamultiply' mode, the Canvas texture will have pre-multiplied alpha afterwards, so the 'premultiplied' alpha mode should generally be used when drawing a Canvas to the screen.
- `love.graphics.setCanvas` - Captures drawing operations to a Canvas.
  - `love.graphics.setCanvas(canvas: Canvas, mipmap: number)`: Sets the render target to a specified stencil or depth testing with an active Canvas, the stencil buffer or depth buffer must be explicitly enabled in setCanvas via the variants below. Note that no canvas should be active when ''love.graphics.present'' is called. ''love.graphics.present'' is called at the end of love.draw in the default love.run, hence if you activate a canvas using this function, you normally need to deactivate it at some point before ''love.draw'' finishes.
  - `love.graphics.setCanvas()`: Resets the render target to the screen, i.e. re-enables drawing to the screen.
  - `love.graphics.setCanvas(canvas1: Canvas, canvas2: Canvas, ...: Canvas)`: Sets the render target to multiple simultaneous 2D Canvases. All drawing operations until the next ''love.graphics.setCanvas'' call will be redirected to the specified canvases and not shown on the screen. Normally all drawing operations will draw only to the first canvas passed to the function, but that can be changed if a pixel shader is used with the void effect function instead of the regular vec4 effect. All canvas arguments must have the same widths and heights and the same texture type. Not all computers which support Canvases will support multiple render targets. If love.graphics.isSupported('multicanvas') returns true, at least 4 simultaneously active canvases are supported.
  - `love.graphics.setCanvas(canvas: Canvas, slice: number, mipmap: number)`: Sets the render target to the specified layer/slice and mipmap level of the given non-2D Canvas. All drawing operations until the next ''love.graphics.setCanvas'' call will be redirected to the Canvas and not shown on the screen.
  - `love.graphics.setCanvas(setup: table)`: Sets the active render target(s) and active stencil and depth buffers based on the specified setup information. All drawing operations until the next ''love.graphics.setCanvas'' call will be redirected to the specified Canvases and not shown on the screen. The RenderTargetSetup parameters can either be a Canvas|[1]|The Canvas to use for this active render target.}} {{param|number|mipmap (1)|The mipmap level to render to, for Canvases with [[Texture:getMipmapCount|mipmaps.}} {{param|number|layer (1)|Only used for Volume and Array-type Canvases. For Array textures this is the array layer to render to. For volume textures this is the depth slice.}} {{param|number|face (1)|Only used for Cubemap-type Canvases. The cube face index to render to (between 1 and 6)}}
- `love.graphics.setColor` - Sets the color used for drawing. In versions prior to 11.0, color component values were within the range of 0 to 255 instead of 0 to 1.
  - `love.graphics.setColor(red: number, green: number, blue: number, alpha: number)`: No description
  - `love.graphics.setColor(rgba: table)`: No description
- `love.graphics.setColorMask` - Sets the color mask. Enables or disables specific color components when rendering and clearing the screen. For example, if '''red''' is set to '''false''', no further changes will be made to the red component of any pixels.
  - `love.graphics.setColorMask(red: boolean, green: boolean, blue: boolean, alpha: boolean)`: Enables color masking for the specified color components.
  - `love.graphics.setColorMask()`: Disables color masking.
- `love.graphics.setDefaultFilter(min: FilterMode, mag: FilterMode, anisotropy: number)`: Sets the default scaling filters used with Images, Canvases, and Fonts.
- `love.graphics.setDepthMode` - Configures depth testing and writing to the depth buffer. This is low-level functionality designed for use with custom vertex shaders and Meshes with custom vertex attributes. No higher level APIs are provided to set the depth of 2D graphics such as shapes, lines, and Images.
  - `love.graphics.setDepthMode(comparemode: CompareMode, write: boolean)`: No description
  - `love.graphics.setDepthMode()`: Disables depth testing and depth writes.
- `love.graphics.setFont(font: Font)`: Set an already-loaded Font as the current font or create and load a new one from the file and size. It's recommended that Font objects are created with love.graphics.newFont in the loading stage and then passed to this function in the drawing stage.
- `love.graphics.setFrontFaceWinding(winding: VertexWinding)`: Sets whether triangles with clockwise- or counterclockwise-ordered vertices are considered front-facing. This is designed for use in combination with Mesh face culling. Other love.graphics shapes, lines, and sprites are not guaranteed to have a specific winding order to their internal vertices.
- `love.graphics.setLineJoin(join: LineJoin)`: Sets the line join style. See LineJoin for the possible options.
- `love.graphics.setLineStyle(style: LineStyle)`: Sets the line style.
- `love.graphics.setLineWidth(width: number)`: Sets the line width.
- `love.graphics.setMeshCullMode(mode: CullMode)`: Sets whether back-facing triangles in a Mesh are culled. This is designed for use with low level custom hardware-accelerated 3D rendering via custom vertex attributes on Meshes, custom vertex shaders, and depth testing with a depth buffer. By default, both front- and back-facing triangles in Meshes are rendered.
- `love.graphics.setNewFont` - Creates and sets a new Font.
  - `love.graphics.setNewFont(size: number) -> font: Font`: No description
  - `love.graphics.setNewFont(filename: string, size: number) -> font: Font`: No description
  - `love.graphics.setNewFont(file: File, size: number) -> font: Font`: No description
  - `love.graphics.setNewFont(data: Data, size: number) -> font: Font`: No description
  - `love.graphics.setNewFont(rasterizer: Rasterizer) -> font: Font`: No description
- `love.graphics.setPointSize(size: number)`: Sets the point size.
- `love.graphics.setScissor` - Sets or disables scissor. The scissor limits the drawing area to a specified rectangle. This affects all graphics calls, including love.graphics.clear.  The dimensions of the scissor is unaffected by graphical transformations (translate, scale, ...).
  - `love.graphics.setScissor(x: number, y: number, width: number, height: number)`: Limits the drawing area to a specified rectangle. 
  - `love.graphics.setScissor()`: Disables scissor.
- `love.graphics.setShader` - Sets or resets a Shader as the current pixel effect or vertex shaders. All drawing operations until the next ''love.graphics.setShader'' will be drawn using the Shader object specified.
  - `love.graphics.setShader(shader: Shader)`: Sets the current shader to a specified Shader. All drawing operations until the next ''love.graphics.setShader'' will be drawn using the Shader object specified.
  - `love.graphics.setShader()`: Disables shaders, allowing unfiltered drawing operations.
- `love.graphics.setStencilTest` - Configures or disables stencil testing. When stencil testing is enabled, the geometry of everything that is drawn afterward will be clipped / stencilled out based on a comparison between the arguments of this function and the stencil value of each pixel that the geometry touches. The stencil values of pixels are affected via love.graphics.stencil.
  - `love.graphics.setStencilTest(comparemode: CompareMode, comparevalue: number)`: No description
  - `love.graphics.setStencilTest()`: Disables stencil testing.
- `love.graphics.setWireframe(enable: boolean)`: Sets whether wireframe lines will be used when drawing.
- `love.graphics.shear(kx: number, ky: number)`: Shears the coordinate system.
- `love.graphics.stencil(stencilfunction: function, action: StencilAction, value: number, keepvalues: boolean)`: Draws geometry as a stencil. The geometry drawn by the supplied function sets invisible stencil values of pixels, instead of setting pixel colors. The stencil buffer (which contains those stencil values) can act like a mask / stencil - love.graphics.setStencilTest can be used afterward to determine how further rendering is affected by the stencil values in each pixel. Stencil values are integers within the range of 255.
- `love.graphics.transformPoint(globalX: number, globalY: number) -> screenX: number, screenY: number`: Converts the given 2D position from global coordinates into screen-space. This effectively applies the current graphics transformations to the given position. A similar Transform:transformPoint method exists for Transform objects.
- `love.graphics.translate(dx: number, dy: number)`: Translates the coordinate system in two dimensions. When this function is called with two numbers, dx, and dy, all the following drawing operations take effect as if their x and y coordinates were x+dx and y+dy.  Scale and translate are not commutative operations, therefore, calling them in different orders will change the outcome. This change lasts until love.draw() exits or else a love.graphics.pop reverts to a previous love.graphics.push. Translating using whole numbers will prevent tearing/blurring of images and fonts draw after translating.
- `love.graphics.validateShader` - Validates shader code. Check if specified shader code does not contain any errors.
  - `love.graphics.validateShader(gles: boolean, code: string) -> status: boolean, message: string`: No description
  - `love.graphics.validateShader(gles: boolean, pixelcode: string, vertexcode: string) -> status: boolean, message: string`: No description

## Types

- `Canvas`: A Canvas is used for off-screen rendering. Think of it as an invisible screen that you can draw to, but that will not be visible until you draw it to the actual visible screen. It is also known as "render to texture". By drawing things that do not change position often (such as background items) to the Canvas, and then drawing the entire Canvas instead of each item,  you can reduce the number of draw operations performed each frame. In versions prior to love.graphics.isSupported("canvas") could be used to check for support at runtime.
  - `love.Canvas.generateMipmaps()`: Generates mipmaps for the Canvas, based on the contents of the highest-resolution mipmap level. The Canvas must be created with mipmaps set to a MipmapMode other than 'none' for this function to work. It should only be called while the Canvas is not the active render target. If the mipmap mode is set to 'auto', this function is automatically called inside love.graphics.setCanvas when switching from this Canvas to another Canvas or to the main screen.
  - `love.Canvas.getMSAA() -> samples: number`: Gets the number of multisample antialiasing (MSAA) samples used when drawing to the Canvas. This may be different than the number used as an argument to love.graphics.newCanvas if the system running LÖVE doesn't support that number.
  - `love.Canvas.getMipmapMode() -> mode: MipmapMode`: Gets the MipmapMode this Canvas was created with.
  - `love.Canvas.newImageData() -> data: ImageData`: Generates ImageData from the contents of the Canvas.
  - `love.Canvas.renderTo(func: function, ...: any)`: Render to the Canvas using a function. This is a shortcut to love.graphics.setCanvas: canvas:renderTo( func ) is the same as love.graphics.setCanvas( canvas ) func() love.graphics.setCanvas()

- `Drawable`: Superclass for all things that can be drawn on screen. This is an abstract type that can't be created directly.

- `Font`: Defines the shape of characters that can be drawn onto the screen.
  - `love.Font.getAscent() -> ascent: number`: Gets the ascent of the Font. The ascent spans the distance between the baseline and the top of the glyph that reaches farthest from the baseline.
  - `love.Font.getBaseline() -> baseline: number`: Gets the baseline of the Font. Most scripts share the notion of a baseline: an imaginary horizontal line on which characters rest. In some scripts, parts of glyphs lie below the baseline.
  - `love.Font.getDPIScale() -> dpiscale: number`: Gets the DPI scale factor of the Font. The DPI scale factor represents relative pixel density. A DPI scale factor of 2 means the font's glyphs have twice the pixel density in each dimension (4 times as many pixels in the same area) compared to a font with a DPI scale factor of 1. The font size of TrueType fonts is scaled internally by the font's specified DPI scale factor. By default, LÖVE uses the screen's DPI scale factor when creating TrueType fonts.
  - `love.Font.getDescent() -> descent: number`: Gets the descent of the Font. The descent spans the distance between the baseline and the lowest descending glyph in a typeface.
  - `love.Font.getFilter() -> min: FilterMode, mag: FilterMode, anisotropy: number`: Gets the filter mode for a font.
  - `love.Font.getHeight() -> height: number`: Gets the height of the Font. The height of the font is the size including any spacing; the height which it will need.
  - `love.Font.getKerning(leftchar: string, rightchar: string) -> kerning: number`: Gets the kerning between two characters in the Font. Kerning is normally handled automatically in love.graphics.print, Text objects, Font:getWidth, Font:getWrap, etc. This function is useful when stitching text together manually.
  - `love.Font.getLineHeight() -> height: number`: Gets the line height. This will be the value previously set by Font:setLineHeight, or 1.0 by default.
  - `love.Font.getWidth(text: string) -> width: number`: Determines the maximum width (accounting for newlines) taken by the given string.
  - `love.Font.getWrap(text: string, wraplimit: number) -> width: number, wrappedtext: table`: Gets formatting information for text, given a wrap limit. This function accounts for newlines correctly (i.e. '\n').
  - `love.Font.hasGlyphs(text: string) -> hasglyph: boolean`: Gets whether the Font can render a character or string.
  - `love.Font.setFallbacks(fallbackfont1: Font, ...: Font)`: Sets the fallback fonts. When the Font doesn't contain a glyph, it will substitute the glyph from the next subsequent fallback Fonts. This is akin to setting a 'font stack' in Cascading Style Sheets (CSS).
  - `love.Font.setFilter(min: FilterMode, mag: FilterMode, anisotropy: number)`: Sets the filter mode for a font.
  - `love.Font.setLineHeight(height: number)`: Sets the line height. When rendering the font in lines the actual height will be determined by the line height multiplied by the height of the font. The default is 1.0.

- `Image`: Drawable image type.
  - `love.Image.isCompressed() -> compressed: boolean`: Gets whether the Image was created from CompressedData. Compressed images take up less space in VRAM, and drawing a compressed image will generally be more efficient than drawing one created from raw pixel data.
  - `love.Image.isFormatLinear() -> linear: boolean`: Gets whether the Image was created with the linear (non-gamma corrected) flag set to true. This method always returns false when gamma-correct rendering is not enabled.
  - `love.Image.replacePixels(data: ImageData, slice: number, mipmap: number, x: number, y: number, reloadmipmaps: boolean)`: Replace the contents of an Image.

- `Mesh`: A 2D polygon mesh used for drawing arbitrary textured shapes.
  - `love.Mesh.attachAttribute(name: string, mesh: Mesh)`: Attaches a vertex attribute from a different Mesh onto this Mesh, for use when drawing. This can be used to share vertex attribute data between several different Meshes.
  - `love.Mesh.detachAttribute(name: string) -> success: boolean`: Removes a previously attached vertex attribute from this Mesh.
  - `love.Mesh.flush()`: Immediately sends all modified vertex data in the Mesh to the graphics card. Normally it isn't necessary to call this method as love.graphics.draw(mesh, ...) will do it automatically if needed, but explicitly using **Mesh:flush** gives more control over when the work happens. If this method is used, it generally shouldn't be called more than once (at most) between love.graphics.draw(mesh, ...) calls.
  - `love.Mesh.getDrawMode() -> mode: MeshDrawMode`: Gets the mode used when drawing the Mesh.
  - `love.Mesh.getDrawRange() -> min: number, max: number`: Gets the range of vertices used when drawing the Mesh.
  - `love.Mesh.getTexture() -> texture: Texture`: Gets the texture (Image or Canvas) used when drawing the Mesh.
  - `love.Mesh.getVertex(index: number) -> attributecomponent: number, ...: number`: Gets the properties of a vertex in the Mesh. In versions prior to 11.0, color and byte component values were within the range of 0 to 255 instead of 0 to 1.
  - `love.Mesh.getVertexAttribute(vertexindex: number, attributeindex: number) -> value1: number, value2: number, ...: number`: Gets the properties of a specific attribute within a vertex in the Mesh. Meshes without a custom vertex format specified in love.graphics.newMesh have position as their first attribute, texture coordinates as their second attribute, and color as their third attribute.
  - `love.Mesh.getVertexCount() -> count: number`: Gets the total number of vertices in the Mesh.
  - `love.Mesh.getVertexFormat() -> format: table`: Gets the vertex format that the Mesh was created with.
  - `love.Mesh.getVertexMap() -> map: table`: Gets the vertex map for the Mesh. The vertex map describes the order in which the vertices are used when the Mesh is drawn. The vertices, vertex map, and mesh draw mode work together to determine what exactly is displayed on the screen. If no vertex map has been set previously via Mesh:setVertexMap, then this function will return nil in LÖVE 0.10.0+, or an empty table in 0.9.2 and older.
  - `love.Mesh.isAttributeEnabled(name: string) -> enabled: boolean`: Gets whether a specific vertex attribute in the Mesh is enabled. Vertex data from disabled attributes is not used when drawing the Mesh.
  - `love.Mesh.setAttributeEnabled(name: string, enable: boolean)`: Enables or disables a specific vertex attribute in the Mesh. Vertex data from disabled attributes is not used when drawing the Mesh.
  - `love.Mesh.setDrawMode(mode: MeshDrawMode)`: Sets the mode used when drawing the Mesh.
  - `love.Mesh.setDrawRange(start: number, count: number)`: Restricts the drawn vertices of the Mesh to a subset of the total.
  - `love.Mesh.setTexture(texture: Texture)`: Sets the texture (Image or Canvas) used when drawing the Mesh.
  - `love.Mesh.setVertex(index: number, attributecomponent: number, ...: number)`: Sets the properties of a vertex in the Mesh. In versions prior to 11.0, color and byte component values were within the range of 0 to 255 instead of 0 to 1.
  - `love.Mesh.setVertexAttribute(vertexindex: number, attributeindex: number, value1: number, value2: number, ...: number)`: Sets the properties of a specific attribute within a vertex in the Mesh. Meshes without a custom vertex format specified in love.graphics.newMesh have position as their first attribute, texture coordinates as their second attribute, and color as their third attribute.
  - `love.Mesh.setVertexMap(map: table)`: Sets the vertex map for the Mesh. The vertex map describes the order in which the vertices are used when the Mesh is drawn. The vertices, vertex map, and mesh draw mode work together to determine what exactly is displayed on the screen. The vertex map allows you to re-order or reuse vertices when drawing without changing the actual vertex parameters or duplicating vertices. It is especially useful when combined with different Mesh Draw Modes.
  - `love.Mesh.setVertices(vertices: table, startvertex: number, count: number)`: Replaces a range of vertices in the Mesh with new ones. The total number of vertices in a Mesh cannot be changed after it has been created. This is often more efficient than calling Mesh:setVertex in a loop.

- `ParticleSystem`: A ParticleSystem can be used to create particle effects like fire or smoke. The particle system has to be created using update it in the update callback to see any changes in the particles emitted. The particle system won't create any particles unless you call setParticleLifetime and setEmissionRate.
  - `love.ParticleSystem.clone() -> particlesystem: ParticleSystem`: Creates an identical copy of the ParticleSystem in the stopped state.
  - `love.ParticleSystem.emit(numparticles: number)`: Emits a burst of particles from the particle emitter.
  - `love.ParticleSystem.getBufferSize() -> size: number`: Gets the maximum number of particles the ParticleSystem can have at once.
  - `love.ParticleSystem.getColors() -> r1: number, g1: number, b1: number, a1: number, r2: number, g2: number, b2: number, a2: number, r8: number, g8: number, b8: number, a8: number`: Gets the series of colors applied to the particle sprite. In versions prior to 11.0, color component values were within the range of 0 to 255 instead of 0 to 1.
  - `love.ParticleSystem.getCount() -> count: number`: Gets the number of particles that are currently in the system.
  - `love.ParticleSystem.getDirection() -> direction: number`: Gets the direction of the particle emitter (in radians).
  - `love.ParticleSystem.getEmissionArea() -> distribution: AreaSpreadDistribution, dx: number, dy: number, angle: number, directionRelativeToCenter: boolean`: Gets the area-based spawn parameters for the particles.
  - `love.ParticleSystem.getEmissionRate() -> rate: number`: Gets the amount of particles emitted per second.
  - `love.ParticleSystem.getEmitterLifetime() -> life: number`: Gets how long the particle system will emit particles (if -1 then it emits particles forever).
  - `love.ParticleSystem.getInsertMode() -> mode: ParticleInsertMode`: Gets the mode used when the ParticleSystem adds new particles.
  - `love.ParticleSystem.getLinearAcceleration() -> xmin: number, ymin: number, xmax: number, ymax: number`: Gets the linear acceleration (acceleration along the x and y axes) for particles. Every particle created will accelerate along the x and y axes between xmin,ymin and xmax,ymax.
  - `love.ParticleSystem.getLinearDamping() -> min: number, max: number`: Gets the amount of linear damping (constant deceleration) for particles.
  - `love.ParticleSystem.getOffset() -> ox: number, oy: number`: Gets the particle image's draw offset.
  - `love.ParticleSystem.getParticleLifetime() -> min: number, max: number`: Gets the lifetime of the particles.
  - `love.ParticleSystem.getPosition() -> x: number, y: number`: Gets the position of the emitter.
  - `love.ParticleSystem.getQuads() -> quads: table`: Gets the series of Quads used for the particle sprites.
  - `love.ParticleSystem.getRadialAcceleration() -> min: number, max: number`: Gets the radial acceleration (away from the emitter).
  - `love.ParticleSystem.getRotation() -> min: number, max: number`: Gets the rotation of the image upon particle creation (in radians).
  - `love.ParticleSystem.getSizeVariation() -> variation: number`: Gets the amount of size variation (0 meaning no variation and 1 meaning full variation between start and end).
  - `love.ParticleSystem.getSizes() -> size1: number, size2: number, size8: number`: Gets the series of sizes by which the sprite is scaled. 1.0 is normal size. The particle system will interpolate between each size evenly over the particle's lifetime.
  - `love.ParticleSystem.getSpeed() -> min: number, max: number`: Gets the speed of the particles.
  - `love.ParticleSystem.getSpin() -> min: number, max: number, variation: number`: Gets the spin of the sprite.
  - `love.ParticleSystem.getSpinVariation() -> variation: number`: Gets the amount of spin variation (0 meaning no variation and 1 meaning full variation between start and end).
  - `love.ParticleSystem.getSpread() -> spread: number`: Gets the amount of directional spread of the particle emitter (in radians).
  - `love.ParticleSystem.getTangentialAcceleration() -> min: number, max: number`: Gets the tangential acceleration (acceleration perpendicular to the particle's direction).
  - `love.ParticleSystem.getTexture() -> texture: Texture`: Gets the texture (Image or Canvas) used for the particles.
  - `love.ParticleSystem.hasRelativeRotation() -> enable: boolean`: Gets whether particle angles and rotations are relative to their velocities. If enabled, particles are aligned to the angle of their velocities and rotate relative to that angle.
  - `love.ParticleSystem.isActive() -> active: boolean`: Checks whether the particle system is actively emitting particles.
  - `love.ParticleSystem.isPaused() -> paused: boolean`: Checks whether the particle system is paused.
  - `love.ParticleSystem.isStopped() -> stopped: boolean`: Checks whether the particle system is stopped.
  - `love.ParticleSystem.moveTo(x: number, y: number)`: Moves the position of the emitter. This results in smoother particle spawning behaviour than if ParticleSystem:setPosition is used every frame.
  - `love.ParticleSystem.pause()`: Pauses the particle emitter.
  - `love.ParticleSystem.reset()`: Resets the particle emitter, removing any existing particles and resetting the lifetime counter.
  - `love.ParticleSystem.setBufferSize(size: number)`: Sets the size of the buffer (the max allowed amount of particles in the system).
  - `love.ParticleSystem.setColors(r1: number, g1: number, b1: number, a1: number, ...: number)`: Sets a series of colors to apply to the particle sprite. The particle system will interpolate between each color evenly over the particle's lifetime. Arguments can be passed in groups of four, representing the components of the desired RGBA value, or as tables of RGBA component values, with a default alpha value of 1 if only three values are given. At least one color must be specified. A maximum of eight may be used. In versions prior to 11.0, color component values were within the range of 0 to 255 instead of 0 to 1.
  - `love.ParticleSystem.setDirection(direction: number)`: Sets the direction the particles will be emitted in.
  - `love.ParticleSystem.setEmissionArea(distribution: AreaSpreadDistribution, dx: number, dy: number, angle: number, directionRelativeToCenter: boolean)`: Sets area-based spawn parameters for the particles. Newly created particles will spawn in an area around the emitter based on the parameters to this function.
  - `love.ParticleSystem.setEmissionRate(rate: number)`: Sets the amount of particles emitted per second.
  - `love.ParticleSystem.setEmitterLifetime(life: number)`: Sets how long the particle system should emit particles (if -1 then it emits particles forever).
  - `love.ParticleSystem.setInsertMode(mode: ParticleInsertMode)`: Sets the mode to use when the ParticleSystem adds new particles.
  - `love.ParticleSystem.setLinearAcceleration(xmin: number, ymin: number, xmax: number, ymax: number)`: Sets the linear acceleration (acceleration along the x and y axes) for particles. Every particle created will accelerate along the x and y axes between xmin,ymin and xmax,ymax.
  - `love.ParticleSystem.setLinearDamping(min: number, max: number)`: Sets the amount of linear damping (constant deceleration) for particles.
  - `love.ParticleSystem.setOffset(x: number, y: number)`: Set the offset position which the particle sprite is rotated around. If this function is not used, the particles rotate around their center.
  - `love.ParticleSystem.setParticleLifetime(min: number, max: number)`: Sets the lifetime of the particles.
  - `love.ParticleSystem.setPosition(x: number, y: number)`: Sets the position of the emitter.
  - `love.ParticleSystem.setQuads(quad1: Quad, ...: Quad)`: Sets a series of Quads to use for the particle sprites. Particles will choose a Quad from the list based on the particle's current lifetime, allowing for the use of animated sprite sheets with ParticleSystems.
  - `love.ParticleSystem.setRadialAcceleration(min: number, max: number)`: Set the radial acceleration (away from the emitter).
  - `love.ParticleSystem.setRelativeRotation(enable: boolean)`: Sets whether particle angles and rotations are relative to their velocities. If enabled, particles are aligned to the angle of their velocities and rotate relative to that angle.
  - `love.ParticleSystem.setRotation(min: number, max: number)`: Sets the rotation of the image upon particle creation (in radians).
  - `love.ParticleSystem.setSizeVariation(variation: number)`: Sets the amount of size variation (0 meaning no variation and 1 meaning full variation between start and end).
  - `love.ParticleSystem.setSizes(size1: number, size2: number, size8: number)`: Sets a series of sizes by which to scale a particle sprite. 1.0 is normal size. The particle system will interpolate between each size evenly over the particle's lifetime. At least one size must be specified. A maximum of eight may be used.
  - `love.ParticleSystem.setSpeed(min: number, max: number)`: Sets the speed of the particles.
  - `love.ParticleSystem.setSpin(min: number, max: number)`: Sets the spin of the sprite.
  - `love.ParticleSystem.setSpinVariation(variation: number)`: Sets the amount of spin variation (0 meaning no variation and 1 meaning full variation between start and end).
  - `love.ParticleSystem.setSpread(spread: number)`: Sets the amount of spread for the system.
  - `love.ParticleSystem.setTangentialAcceleration(min: number, max: number)`: Sets the tangential acceleration (acceleration perpendicular to the particle's direction).
  - `love.ParticleSystem.setTexture(texture: Texture)`: Sets the texture (Image or Canvas) to be used for the particles.
  - `love.ParticleSystem.start()`: Starts the particle emitter.
  - `love.ParticleSystem.stop()`: Stops the particle emitter, resetting the lifetime counter.
  - `love.ParticleSystem.update(dt: number)`: Updates the particle system; moving, creating and killing particles.

- `Quad`: A quadrilateral (a polygon with four sides and four corners) with texture coordinate information. Quads can be used to select part of a texture to draw. In this way, one large texture atlas can be loaded, and then split up into sub-images.
  - `love.Quad.getTextureDimensions() -> sw: number, sh: number`: Gets reference texture dimensions initially specified in love.graphics.newQuad.
  - `love.Quad.getViewport() -> x: number, y: number, w: number, h: number`: Gets the current viewport of this Quad.
  - `love.Quad.setViewport(x: number, y: number, w: number, h: number, sw: number, sh: number)`: Sets the texture coordinates according to a viewport.

- `Shader`: A Shader is used for advanced hardware-accelerated pixel or vertex manipulation. These effects are written in a language based on GLSL (OpenGL Shading Language) with a few things simplified for easier coding. Potential uses for shaders include HDR/bloom, motion blur, grayscale/invert/sepia/any kind of color effect, reflection/refraction, distortions, bump mapping, and much more! Here is a collection of basic shaders and good starting point to learn: https://github.com/vrld/moonshine
  - `love.Shader.getWarnings() -> warnings: string`: Returns any warning and error messages from compiling the shader code. This can be used for debugging your shaders if there's anything the graphics hardware doesn't like.
  - `love.Shader.hasUniform(name: string) -> hasuniform: boolean`: Gets whether a uniform / extern variable exists in the Shader. If a graphics driver's shader compiler determines that a uniform / extern variable doesn't affect the final output of the shader, it may optimize the variable out. This function will return false in that case.
  - `love.Shader.send(name: string, number: number, ...: number)`: Sends one or more values to a special (''uniform'') variable inside the shader. Uniform variables have to be marked using the ''uniform'' or ''extern'' keyword, e.g. uniform float time;  // 'float' is the typical number type used in GLSL shaders. uniform float varsvec2 light_pos; uniform vec4 colors[4; The corresponding send calls would be shader:send('time', t) shader:send('vars',a,b) shader:send('light_pos', {light_x, light_y}) shader:send('colors', {r1, g1, b1, a1},  {r2, g2, b2, a2},  {r3, g3, b3, a3},  {r4, g4, b4, a4}) Uniform / extern variables are read-only in the shader code and remain constant until modified by a Shader:send call. Uniform variables can be accessed in both the Vertex and Pixel components of a shader, as long as the variable is declared in each.
  - `love.Shader.sendColor(name: string, color: table, ...: table)`: Sends one or more colors to a special (''extern'' / ''uniform'') vec3 or vec4 variable inside the shader. The color components must be in the range of 1. The colors are gamma-corrected if global gamma-correction is enabled. Extern variables must be marked using the ''extern'' keyword, e.g. extern vec4 Color; The corresponding sendColor call would be shader:sendColor('Color', {r, g, b, a}) Extern variables can be accessed in both the Vertex and Pixel stages of a shader, as long as the variable is declared in each. In versions prior to 11.0, color component values were within the range of 0 to 255 instead of 0 to 1.

- `SpriteBatch`: Using a single image, draw any number of identical copies of the image using a single call to love.graphics.draw(). This can be used, for example, to draw repeating copies of a single background image with high performance. A SpriteBatch can be even more useful when the underlying image is a texture atlas (a single image file containing many independent images); by adding Quads to the batch, different sub-images from within the atlas can be drawn.
  - `love.SpriteBatch.add(x: number, y: number, r: number, sx: number, sy: number, ox: number, oy: number, kx: number, ky: number) -> id: number`: Adds a sprite to the batch. Sprites are drawn in the order they are added.
  - `love.SpriteBatch.addLayer(layerindex: number, x: number, y: number, r: number, sx: number, sy: number, ox: number, oy: number, kx: number, ky: number) -> spriteindex: number`: Adds a sprite to a batch created with an Array Texture.
  - `love.SpriteBatch.attachAttribute(name: string, mesh: Mesh)`: Attaches a per-vertex attribute from a Mesh onto this SpriteBatch, for use when drawing. This can be combined with a Shader to augment a SpriteBatch with per-vertex or additional per-sprite information instead of just having per-sprite colors. Each sprite in a SpriteBatch has 4 vertices in the following order: top-left, bottom-left, top-right, bottom-right. The index returned by SpriteBatch:add (and used by SpriteBatch:set) can used to determine the first vertex of a specific sprite with the formula 1 + 4 * ( id - 1 ).
  - `love.SpriteBatch.clear()`: Removes all sprites from the buffer.
  - `love.SpriteBatch.flush()`: Immediately sends all new and modified sprite data in the batch to the graphics card. Normally it isn't necessary to call this method as love.graphics.draw(spritebatch, ...) will do it automatically if needed, but explicitly using SpriteBatch:flush gives more control over when the work happens. If this method is used, it generally shouldn't be called more than once (at most) between love.graphics.draw(spritebatch, ...) calls.
  - `love.SpriteBatch.getBufferSize() -> size: number`: Gets the maximum number of sprites the SpriteBatch can hold.
  - `love.SpriteBatch.getColor() -> r: number, g: number, b: number, a: number`: Gets the color that will be used for the next add and set operations. If no color has been set with SpriteBatch:setColor or the current SpriteBatch color has been cleared, this method will return nil. In versions prior to 11.0, color component values were within the range of 0 to 255 instead of 0 to 1.
  - `love.SpriteBatch.getCount() -> count: number`: Gets the number of sprites currently in the SpriteBatch.
  - `love.SpriteBatch.getTexture() -> texture: Texture`: Gets the texture (Image or Canvas) used by the SpriteBatch.
  - `love.SpriteBatch.set(spriteindex: number, x: number, y: number, r: number, sx: number, sy: number, ox: number, oy: number, kx: number, ky: number)`: Changes a sprite in the batch. This requires the sprite index returned by SpriteBatch:add or SpriteBatch:addLayer.
  - `love.SpriteBatch.setColor(r: number, g: number, b: number, a: number)`: Sets the color that will be used for the next add and set operations. Calling the function without arguments will disable all per-sprite colors for the SpriteBatch. In versions prior to 11.0, color component values were within the range of 0 to 255 instead of 0 to 1. In version 0.9.2 and older, the global color set with love.graphics.setColor will not work on the SpriteBatch if any of the sprites has its own color.
  - `love.SpriteBatch.setDrawRange(start: number, count: number)`: Restricts the drawn sprites in the SpriteBatch to a subset of the total.
  - `love.SpriteBatch.setLayer(spriteindex: number, layerindex: number, x: number, y: number, r: number, sx: number, sy: number, ox: number, oy: number, kx: number, ky: number)`: Changes a sprite previously added with add or addLayer, in a batch created with an Array Texture.
  - `love.SpriteBatch.setTexture(texture: Texture)`: Sets the texture (Image or Canvas) used for the sprites in the batch, when drawing.

- `Text`: Drawable text.
  - `love.Text.add(textstring: string, x: number, y: number, angle: number, sx: number, sy: number, ox: number, oy: number, kx: number, ky: number) -> index: number`: Adds additional colored text to the Text object at the specified position.
  - `love.Text.addf(textstring: string, wraplimit: number, align: AlignMode, x: number, y: number, angle: number, sx: number, sy: number, ox: number, oy: number, kx: number, ky: number) -> index: number`: Adds additional formatted / colored text to the Text object at the specified position. The word wrap limit is applied before any scaling, rotation, and other coordinate transformations. Therefore the amount of text per line stays constant given the same wrap limit, even if the scale arguments change.
  - `love.Text.clear()`: Clears the contents of the Text object.
  - `love.Text.getDimensions() -> width: number, height: number`: Gets the width and height of the text in pixels.
  - `love.Text.getFont() -> font: Font`: Gets the Font used with the Text object.
  - `love.Text.getHeight() ->  height : number`: Gets the height of the text in pixels.
  - `love.Text.getWidth() -> width: number`: Gets the width of the text in pixels.
  - `love.Text.set(textstring: string)`: Replaces the contents of the Text object with a new unformatted string.
  - `love.Text.setFont(font: Font)`: Replaces the Font used with the text.
  - `love.Text.setf(textstring: string, wraplimit: number, align: AlignMode)`: Replaces the contents of the Text object with a new formatted string.

- `Texture`: Superclass for drawable objects which represent a texture. All Textures can be drawn with Quads. This is an abstract type that can't be created directly.
  - `love.Texture.getDPIScale() -> dpiscale: number`: Gets the DPI scale factor of the Texture. The DPI scale factor represents relative pixel density. A DPI scale factor of 2 means the texture has twice the pixel density in each dimension (4 times as many pixels in the same area) compared to a texture with a DPI scale factor of 1. For example, a texture with pixel dimensions of 100x100 with a DPI scale factor of 2 will be drawn as if it was 50x50. This is useful with high-dpi /  retina displays to easily allow swapping out higher or lower pixel density Images and Canvases without needing any extra manual scaling logic.
  - `love.Texture.getDepth() -> depth: number`: Gets the depth of a Volume Texture. Returns 1 for 2D, Cubemap, and Array textures.
  - `love.Texture.getDepthSampleMode() -> compare: CompareMode`: Gets the comparison mode used when sampling from a depth texture in a shader. Depth texture comparison modes are advanced low-level functionality typically used with shadow mapping in 3D.
  - `love.Texture.getDimensions() -> width: number, height: number`: Gets the width and height of the Texture.
  - `love.Texture.getFilter() -> min: FilterMode, mag: FilterMode, anisotropy: number`: Gets the filter mode of the Texture.
  - `love.Texture.getFormat() -> format: PixelFormat`: Gets the pixel format of the Texture.
  - `love.Texture.getHeight() -> height: number`: Gets the height of the Texture.
  - `love.Texture.getLayerCount() -> layers: number`: Gets the number of layers / slices in an Array Texture. Returns 1 for 2D, Cubemap, and Volume textures.
  - `love.Texture.getMipmapCount() -> mipmaps: number`: Gets the number of mipmaps contained in the Texture. If the texture was not created with mipmaps, it will return 1.
  - `love.Texture.getMipmapFilter() -> mode: FilterMode, sharpness: number`: Gets the mipmap filter mode for a Texture. Prior to 11.0 this method only worked on Images.
  - `love.Texture.getPixelDimensions() -> pixelwidth: number, pixelheight: number`: Gets the width and height in pixels of the Texture. Texture:getDimensions gets the dimensions of the texture in units scaled by the texture's DPI scale factor, rather than pixels. Use getDimensions for calculations related to drawing the texture (calculating an origin offset, for example), and getPixelDimensions only when dealing specifically with pixels, for example when using Canvas:newImageData.
  - `love.Texture.getPixelHeight() -> pixelheight: number`: Gets the height in pixels of the Texture. DPI scale factor, rather than pixels. Use getHeight for calculations related to drawing the texture (calculating an origin offset, for example), and getPixelHeight only when dealing specifically with pixels, for example when using Canvas:newImageData.
  - `love.Texture.getPixelWidth() -> pixelwidth: number`: Gets the width in pixels of the Texture. DPI scale factor, rather than pixels. Use getWidth for calculations related to drawing the texture (calculating an origin offset, for example), and getPixelWidth only when dealing specifically with pixels, for example when using Canvas:newImageData.
  - `love.Texture.getTextureType() -> texturetype: TextureType`: Gets the type of the Texture.
  - `love.Texture.getWidth() -> width: number`: Gets the width of the Texture.
  - `love.Texture.getWrap() -> horiz: WrapMode, vert: WrapMode, depth: WrapMode`: Gets the wrapping properties of a Texture. This function returns the currently set horizontal and vertical wrapping modes for the texture.
  - `love.Texture.isReadable() -> readable: boolean`: Gets whether the Texture can be drawn and sent to a Shader. Canvases created with stencil and/or depth PixelFormats are not readable by default, unless readable=true is specified in the settings table passed into love.graphics.newCanvas. Non-readable Canvases can still be rendered to.
  - `love.Texture.setDepthSampleMode(compare: CompareMode)`: Sets the comparison mode used when sampling from a depth texture in a shader. Depth texture comparison modes are advanced low-level functionality typically used with shadow mapping in 3D. When using a depth texture with a comparison mode set in a shader, it must be declared as a sampler2DShadow and used in a GLSL 3 Shader. The result of accessing the texture in the shader will return a float between 0 and 1, proportional to the number of samples (up to 4 samples will be used if bilinear filtering is enabled) that passed the test set by the comparison operation. Depth texture comparison can only be used with readable depth-formatted Canvases.
  - `love.Texture.setFilter(min: FilterMode, mag: FilterMode, anisotropy: number)`: Sets the filter mode of the Texture.
  - `love.Texture.setMipmapFilter(filtermode: FilterMode, sharpness: number)`: Sets the mipmap filter mode for a Texture. Prior to 11.0 this method only worked on Images. Mipmapping is useful when drawing a texture at a reduced scale. It can improve performance and reduce aliasing issues. In created with the mipmaps flag enabled for the mipmap filter to have any effect. In versions prior to 0.10.0 it's best to call this method directly after creating the image with love.graphics.newImage, to avoid bugs in certain graphics drivers. Due to hardware restrictions and driver bugs, in versions prior to 0.10.0 images that weren't loaded from a CompressedData must have power-of-two dimensions (64x64, 512x256, etc.) to use mipmaps.
  - `love.Texture.setWrap(horiz: WrapMode, vert: WrapMode, depth: WrapMode)`: Sets the wrapping properties of a Texture. This function sets the way a Texture is repeated when it is drawn with a Quad that is larger than the texture's extent, or when a custom Shader is used which uses texture coordinates outside of [0, 1]. A texture may be clamped or set to repeat in both horizontal and vertical directions. Clamped textures appear only once (with the edges of the texture stretching to fill the extent of the Quad), whereas repeated ones repeat as many times as there is room in the Quad.

- `Video`: A drawable video.
  - `love.Video.getDimensions() -> width: number, height: number`: Gets the width and height of the Video in pixels.
  - `love.Video.getFilter() -> min: FilterMode, mag: FilterMode, anisotropy: number`: Gets the scaling filters used when drawing the Video.
  - `love.Video.getHeight() -> height: number`: Gets the height of the Video in pixels.
  - `love.Video.getSource() -> source: Source`: Gets the audio Source used for playing back the video's audio. May return nil if the video has no audio, or if Video:setSource is called with a nil argument.
  - `love.Video.getStream() -> stream: VideoStream`: Gets the VideoStream object used for decoding and controlling the video.
  - `love.Video.getWidth() -> width: number`: Gets the width of the Video in pixels.
  - `love.Video.isPlaying() -> playing: boolean`: Gets whether the Video is currently playing.
  - `love.Video.pause()`: Pauses the Video.
  - `love.Video.play()`: Starts playing the Video. In order for the video to appear onscreen it must be drawn with love.graphics.draw.
  - `love.Video.rewind()`: Rewinds the Video to the beginning.
  - `love.Video.seek(offset: number)`: Sets the current playback position of the Video.
  - `love.Video.setFilter(min: FilterMode, mag: FilterMode, anisotropy: number)`: Sets the scaling filters used when drawing the Video.
  - `love.Video.setSource(source: Source)`: Sets the audio Source used for playing back the video's audio. The audio Source also controls playback speed and synchronization.
  - `love.Video.tell() -> seconds: number`: Gets the current playback position of the Video.

## Enums

- `AlignMode`: Text alignment.
  - `center`: Align text center.
  - `left`: Align text left.
  - `right`: Align text right.
  - `justify`: Align text both left and right.

- `ArcType`: Different types of arcs that can be drawn.
  - `pie`: The arc is drawn like a slice of pie, with the arc circle connected to the center at its end-points.
  - `open`: The arc circle's two end-points are unconnected when the arc is drawn as a line. Behaves like the "closed" arc type when the arc is drawn in filled mode.
  - `closed`: The arc circle's two end-points are connected to each other.

- `AreaSpreadDistribution`: Types of particle area spread distribution.
  - `uniform`: Uniform distribution.
  - `normal`: Normal (gaussian) distribution.
  - `ellipse`: Uniform distribution in an ellipse.
  - `borderellipse`: Distribution in an ellipse with particles spawning at the edges of the ellipse.
  - `borderrectangle`: Distribution in a rectangle with particles spawning at the edges of the rectangle.
  - `none`: No distribution - area spread is disabled.

- `BlendAlphaMode`: Different ways alpha affects color blending. See BlendMode and the BlendMode Formulas for additional notes.
  - `alphamultiply`: The RGB values of what's drawn are multiplied by the alpha values of those colors during blending. This is the default alpha mode.
  - `premultiplied`: The RGB values of what's drawn are '''not''' multiplied by the alpha values of those colors during blending. For most blend modes to work correctly with this alpha mode, the colors of a drawn object need to have had their RGB values multiplied by their alpha values at some point previously ("premultiplied alpha").

- `BlendMode`: Different ways to do color blending. See BlendAlphaMode and the BlendMode Formulas for additional notes.
  - `alpha`: Alpha blending (normal). The alpha of what's drawn determines its opacity.
  - `replace`: The colors of what's drawn completely replace what was on the screen, with no additional blending. The BlendAlphaMode specified in love.graphics.setBlendMode still affects what happens.
  - `screen`: 'Screen' blending.
  - `add`: The pixel colors of what's drawn are added to the pixel colors already on the screen. The alpha of the screen is not modified.
  - `subtract`: The pixel colors of what's drawn are subtracted from the pixel colors already on the screen. The alpha of the screen is not modified.
  - `multiply`: The pixel colors of what's drawn are multiplied with the pixel colors already on the screen (darkening them). The alpha of drawn objects is multiplied with the alpha of the screen rather than determining how much the colors on the screen are affected, even when the "alphamultiply" BlendAlphaMode is used.
  - `lighten`: The pixel colors of what's drawn are compared to the existing pixel colors, and the larger of the two values for each color component is used. Only works when the "premultiplied" BlendAlphaMode is used in love.graphics.setBlendMode.
  - `darken`: The pixel colors of what's drawn are compared to the existing pixel colors, and the smaller of the two values for each color component is used. Only works when the "premultiplied" BlendAlphaMode is used in love.graphics.setBlendMode.
  - `additive`: Additive blend mode.
  - `subtractive`: Subtractive blend mode.
  - `multiplicative`: Multiply blend mode.
  - `premultiplied`: Premultiplied alpha blend mode.

- `CompareMode`: Different types of per-pixel stencil test and depth test comparisons. The pixels of an object will be drawn if the comparison succeeds, for each pixel that the object touches.
  - `equal`: * stencil tests: the stencil value of the pixel must be equal to the supplied value. * depth tests: the depth value of the drawn object at that pixel must be equal to the existing depth value of that pixel.
  - `notequal`: * stencil tests: the stencil value of the pixel must not be equal to the supplied value. * depth tests: the depth value of the drawn object at that pixel must not be equal to the existing depth value of that pixel.
  - `less`: * stencil tests: the stencil value of the pixel must be less than the supplied value. * depth tests: the depth value of the drawn object at that pixel must be less than the existing depth value of that pixel.
  - `lequal`: * stencil tests: the stencil value of the pixel must be less than or equal to the supplied value. * depth tests: the depth value of the drawn object at that pixel must be less than or equal to the existing depth value of that pixel.
  - `gequal`: * stencil tests: the stencil value of the pixel must be greater than or equal to the supplied value. * depth tests: the depth value of the drawn object at that pixel must be greater than or equal to the existing depth value of that pixel.
  - `greater`: * stencil tests: the stencil value of the pixel must be greater than the supplied value. * depth tests: the depth value of the drawn object at that pixel must be greater than the existing depth value of that pixel.
  - `never`: Objects will never be drawn.
  - `always`: Objects will always be drawn. Effectively disables the depth or stencil test.

- `CullMode`: How Mesh geometry is culled when rendering.
  - `back`: Back-facing triangles in Meshes are culled (not rendered). The vertex order of a triangle determines whether it is back- or front-facing.
  - `front`: Front-facing triangles in Meshes are culled.
  - `none`: Both back- and front-facing triangles in Meshes are rendered.

- `DrawMode`: Controls whether shapes are drawn as an outline, or filled.
  - `fill`: Draw filled shape.
  - `line`: Draw outlined shape.

- `FilterMode`: How the image is filtered when scaling.
  - `linear`: Scale image with linear interpolation.
  - `nearest`: Scale image with nearest neighbor interpolation.

- `GraphicsFeature`: Graphics features that can be checked for with love.graphics.getSupported.
  - `clampzero`: Whether the "clampzero" WrapMode is supported.
  - `lighten`: Whether the "lighten" and "darken" BlendModes are supported.
  - `multicanvasformats`: Whether multiple formats can be used in the same love.graphics.setCanvas call.
  - `glsl3`: Whether GLSL 3 Shaders can be used.
  - `instancing`: Whether mesh instancing is supported.
  - `fullnpot`: Whether textures with non-power-of-two dimensions can use mipmapping and the 'repeat' WrapMode.
  - `pixelshaderhighp`: Whether pixel shaders can use "highp" 32 bit floating point numbers (as opposed to just 16 bit or lower precision).
  - `shaderderivatives`: Whether shaders can use the dFdx, dFdy, and fwidth functions for computing derivatives.

- `GraphicsLimit`: Types of system-dependent graphics limits checked for using love.graphics.getSystemLimits.
  - `pointsize`: The maximum size of points.
  - `texturesize`: The maximum width or height of Images and Canvases.
  - `multicanvas`: The maximum number of simultaneously active canvases (via love.graphics.setCanvas.)
  - `canvasmsaa`: The maximum number of antialiasing samples for a Canvas.
  - `texturelayers`: The maximum number of layers in an Array texture.
  - `volumetexturesize`: The maximum width, height, or depth of a Volume texture.
  - `cubetexturesize`: The maximum width or height of a Cubemap texture.
  - `anisotropy`: The maximum amount of anisotropic filtering. Texture:setMipmapFilter internally clamps the given anisotropy value to the system's limit.

- `IndexDataType`: Vertex map datatype for Data variant of Mesh:setVertexMap.
  - `uint16`: The vertex map is array of unsigned word (16-bit).
  - `uint32`: The vertex map is array of unsigned dword (32-bit).

- `LineJoin`: Line join style.
  - `miter`: The ends of the line segments beveled in an angle so that they join seamlessly.
  - `none`: No cap applied to the ends of the line segments.
  - `bevel`: Flattens the point where line segments join together.

- `LineStyle`: The styles in which lines are drawn.
  - `rough`: Draw rough lines.
  - `smooth`: Draw smooth lines.

- `MeshDrawMode`: How a Mesh's vertices are used when drawing.
  - `fan`: The vertices create a "fan" shape with the first vertex acting as the hub point. Can be easily used to draw simple convex polygons.
  - `strip`: The vertices create a series of connected triangles using vertices 1, 2, 3, then 3, 2, 4 (note the order), then 3, 4, 5, and so on.
  - `triangles`: The vertices create unconnected triangles.
  - `points`: The vertices are drawn as unconnected points (see love.graphics.setPointSize.)

- `MipmapMode`: Controls whether a Canvas has mipmaps, and its behaviour when it does.
  - `none`: The Canvas has no mipmaps.
  - `auto`: The Canvas has mipmaps. love.graphics.setCanvas can be used to render to a specific mipmap level, or Canvas:generateMipmaps can (re-)compute all mipmap levels based on the base level.
  - `manual`: The Canvas has mipmaps, and all mipmap levels will automatically be recomputed when switching away from the Canvas with love.graphics.setCanvas.

- `ParticleInsertMode`: How newly created particles are added to the ParticleSystem.
  - `top`: Particles are inserted at the top of the ParticleSystem's list of particles.
  - `bottom`: Particles are inserted at the bottom of the ParticleSystem's list of particles.
  - `random`: Particles are inserted at random positions in the ParticleSystem's list of particles.

- `SpriteBatchUsage`: Usage hints for SpriteBatches and Meshes to optimize data storage and access.
  - `dynamic`: The object's data will change occasionally during its lifetime. 
  - `static`: The object will not be modified after initial sprites or vertices are added.
  - `stream`: The object data will always change between draws.

- `StackType`: Graphics state stack types used with love.graphics.push.
  - `transform`: The transformation stack (love.graphics.translate, love.graphics.rotate, etc.)
  - `all`: All love.graphics state, including transform state.

- `StencilAction`: How a stencil function modifies the stencil values of pixels it touches.
  - `replace`: The stencil value of a pixel will be replaced by the value specified in love.graphics.stencil, if any object touches the pixel.
  - `increment`: The stencil value of a pixel will be incremented by 1 for each object that touches the pixel. If the stencil value reaches 255 it will stay at 255.
  - `decrement`: The stencil value of a pixel will be decremented by 1 for each object that touches the pixel. If the stencil value reaches 0 it will stay at 0.
  - `incrementwrap`: The stencil value of a pixel will be incremented by 1 for each object that touches the pixel. If a stencil value of 255 is incremented it will be set to 0.
  - `decrementwrap`: The stencil value of a pixel will be decremented by 1 for each object that touches the pixel. If the stencil value of 0 is decremented it will be set to 255.
  - `invert`: The stencil value of a pixel will be bitwise-inverted for each object that touches the pixel. If a stencil value of 0 is inverted it will become 255.

- `TextureType`: Types of textures (2D, cubemap, etc.)
  - `2d`: Regular 2D texture with width and height.
  - `array`: Several same-size 2D textures organized into a single object. Similar to a texture atlas / sprite sheet, but avoids sprite bleeding and other issues.
  - `cube`: Cubemap texture with 6 faces. Requires a custom shader (and Shader:send) to use. Sampling from a cube texture in a shader takes a 3D direction vector instead of a texture coordinate.
  - `volume`: 3D texture with width, height, and depth. Requires a custom shader to use. Volume textures can have texture filtering applied along the 3rd axis.

- `VertexAttributeStep`: The frequency at which a vertex shader fetches the vertex attribute's data from the Mesh when it's drawn. Per-instance attributes can be used to render a Mesh many times with different positions, colors, or other attributes via a single love.graphics.drawInstanced call, without using the love_InstanceID vertex shader variable.
  - `pervertex`: The vertex attribute will have a unique value for each vertex in the Mesh.
  - `perinstance`: The vertex attribute will have a unique value for each instance of the Mesh.

- `VertexWinding`: How Mesh geometry vertices are ordered.
  - `cw`: Clockwise.
  - `ccw`: Counter-clockwise.

- `WrapMode`: How the image wraps inside a Quad with a larger quad size than image size. This also affects how Meshes with texture coordinates which are outside the range of 1 are drawn, and the color returned by the Texel Shader function when using it to sample from texture coordinates outside of the range of 1.
  - `clamp`: Clamp the texture. Appears only once. The area outside the texture's normal range is colored based on the edge pixels of the texture.
  - `repeat`: Repeat the texture. Fills the whole available extent.
  - `mirroredrepeat`: Repeat the texture, flipping it each time it repeats. May produce better visual results than the repeat mode when the texture doesn't seamlessly tile.
  - `clampzero`: Clamp the texture. Fills the area outside the texture's normal range with transparent black (or opaque black for textures with no alpha channel.)

## Examples

### Drawing a colored rectangle
```lua
-- Draw a red rectangle
function love.draw()
  love.graphics.setColor(1, 0, 0, 1)  -- RGBA: red, fully opaque
  love.graphics.rectangle("fill", 100, 100, 200, 150)
end
```

### Loading and drawing an image
```lua
local image

function love.load()
  image = love.graphics.newImage("sprite.png")
end

function love.draw()
  love.graphics.draw(image, 200, 200, 0, 2, 2)  -- Draw at 200,200 with 2x scale
end
```

## Best practices
- Load graphics resources in love.load() to avoid delays during gameplay
- Use sprite batches for efficient drawing of many identical sprites
- Consider using canvas objects for complex compositions
- Be mindful of coordinate system (0,0 is top-left by default)
- Use appropriate image formats: PNG for transparency, JPEG for photos

## Performance considerations
- Too many draw calls can cause performance issues
- Large images consume more memory
- Complex shaders impact GPU performance
- Frequent state changes (color, blend mode) can be expensive
- Particle systems can be CPU-intensive with many particles

## Platform compatibility
- **Desktop (Windows, macOS, Linux)**: Full graphics support including shaders
- **Mobile (iOS, Android)**: Full support but some shader features may be limited
- **Web**: Good support but some advanced features may not be available
