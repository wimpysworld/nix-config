---
name: love-math
description: Provides system-independent mathematical functions. Use this skill when working with mathematical operations, random number generation, geometric calculations, or any math-related operations in LÖVE games.
license: MIT
metadata:
  author: Ron Dekker <rondekker.nl>
---

## When to use this skill
Provides system-independent mathematical functions. Use this skill when working with mathematical operations, random number generation, geometric calculations, or any math-related operations in LÖVE games.

## Common use cases
- Performing mathematical calculations and transformations
- Generating random numbers for game mechanics
- Working with vectors and matrices
- Implementing geometric algorithms
- Handling noise generation and procedural content

## Functions

- `love.math.colorFromBytes(rb: number, gb: number, bb: number, ab: number) -> r: number, g: number, b: number, a: number`: Converts a color from 0..255 to 0..1 range.
- `love.math.colorToBytes(r: number, g: number, b: number, a: number) -> rb: number, gb: number, bb: number, ab: number`: Converts a color from 0..1 to 0..255 range.
- `love.math.gammaToLinear` - Converts a color from gamma-space (sRGB) to linear-space (RGB). This is useful when doing gamma-correct rendering and you need to do math in linear RGB in the few cases where LÖVE doesn't handle conversions automatically. Read more about gamma-correct rendering here, here, and here. In versions prior to 11.0, color component values were within the range of 0 to 255 instead of 0 to 1.
  - `love.math.gammaToLinear(r: number, g: number, b: number) -> lr: number, lg: number, lb: number`: An alpha value can be passed into the function as a fourth argument, but it will be returned unchanged because alpha is always linear.
  - `love.math.gammaToLinear(color: table) -> lr: number, lg: number, lb: number`: No description
  - `love.math.gammaToLinear(c: number) -> lc: number`: No description
- `love.math.getRandomSeed() -> low: number, high: number`: Gets the seed of the random number generator. The seed is split into two numbers due to Lua's use of doubles for all number values - doubles can't accurately represent integer  values above 2^53, but the seed can be an integer value up to 2^64.
- `love.math.getRandomState() -> state: string`: Gets the current state of the random number generator. This returns an opaque implementation-dependent string which is only useful for later use with love.math.setRandomState or RandomGenerator:setState. This is different from love.math.getRandomSeed in that getRandomState gets the random number generator's current state, whereas getRandomSeed gets the previously set seed number.
- `love.math.isConvex` - Checks whether a polygon is convex. PolygonShapes in love.physics, some forms of Meshes, and polygons drawn with love.graphics.polygon must be simple convex polygons.
  - `love.math.isConvex(vertices: table) -> convex: boolean`: No description
  - `love.math.isConvex(x1: number, y1: number, x2: number, y2: number, ...: number) -> convex: boolean`: No description
- `love.math.linearToGamma` - Converts a color from linear-space (RGB) to gamma-space (sRGB). This is useful when storing linear RGB color values in an image, because the linear RGB color space has less precision than sRGB for dark colors, which can result in noticeable color banding when drawing. In general, colors chosen based on what they look like on-screen are already in gamma-space and should not be double-converted. Colors calculated using math are often in the linear RGB space. Read more about gamma-correct rendering here, here, and here. In versions prior to 11.0, color component values were within the range of 0 to 255 instead of 0 to 1.
  - `love.math.linearToGamma(lr: number, lg: number, lb: number) -> cr: number, cg: number, cb: number`: An alpha value can be passed into the function as a fourth argument, but it will be returned unchanged because alpha is always linear.
  - `love.math.linearToGamma(color: table) -> cr: number, cg: number, cb: number`: No description
  - `love.math.linearToGamma(lc: number) -> c: number`: No description
- `love.math.newBezierCurve` - Creates a new BezierCurve object. The number of vertices in the control polygon determines the degree of the curve, e.g. three vertices define a quadratic (degree 2) Bézier curve, four vertices define a cubic (degree 3) Bézier curve, etc.
  - `love.math.newBezierCurve(vertices: table) -> curve: BezierCurve`: No description
  - `love.math.newBezierCurve(x1: number, y1: number, x2: number, y2: number, ...: number) -> curve: BezierCurve`: No description
- `love.math.newRandomGenerator` - Creates a new RandomGenerator object which is completely independent of other RandomGenerator objects and random functions.
  - `love.math.newRandomGenerator() -> rng: RandomGenerator`: No description
  - `love.math.newRandomGenerator(seed: number) -> rng: RandomGenerator`: See RandomGenerator:setSeed.
  - `love.math.newRandomGenerator(low: number, high: number) -> rng: RandomGenerator`: See RandomGenerator:setSeed.
- `love.math.newTransform` - Creates a new Transform object.
  - `love.math.newTransform() -> transform: Transform`: Creates a Transform with no transformations applied. Call methods on the returned object to apply transformations.
  - `love.math.newTransform(x: number, y: number, angle: number, sx: number, sy: number, ox: number, oy: number, kx: number, ky: number) -> transform: Transform`: Creates a Transform with the specified transformation applied on creation.
- `love.math.noise` - Generates a Simplex or Perlin noise value in 1-4 dimensions. The return value will always be the same, given the same arguments. Simplex noise is closely related to Perlin noise. It is widely used for procedural content generation. There are many webpages which discuss Perlin and Simplex noise in detail.
  - `love.math.noise(x: number) -> value: number`: Generates Simplex noise from 1 dimension.
  - `love.math.noise(x: number, y: number) -> value: number`: Generates Simplex noise from 2 dimensions.
  - `love.math.noise(x: number, y: number, z: number) -> value: number`: Generates Perlin noise (Simplex noise in version 0.9.2 and older) from 3 dimensions.
  - `love.math.noise(x: number, y: number, z: number, w: number) -> value: number`: Generates Perlin noise (Simplex noise in version 0.9.2 and older) from 4 dimensions.
- `love.math.random` - Generates a pseudo-random number in a platform independent manner. The default love.run seeds this function at startup, so you generally don't need to seed it yourself.
  - `love.math.random() -> number: number`: Get uniformly distributed pseudo-random real number within 1.
  - `love.math.random(max: number) -> number: number`: Get a uniformly distributed pseudo-random integer within max.
  - `love.math.random(min: number, max: number) -> number: number`: Get uniformly distributed pseudo-random integer within max.
- `love.math.randomNormal(stddev: number, mean: number) -> number: number`: Get a normally distributed pseudo random number.
- `love.math.setRandomSeed` - Sets the seed of the random number generator using the specified integer number. This is called internally at startup, so you generally don't need to call it yourself.
  - `love.math.setRandomSeed(seed: number)`: Due to Lua's use of double-precision floating point numbers, integer values above 2^53 cannot be accurately represented. Use the other variant of the function if you want to use a larger number.
  - `love.math.setRandomSeed(low: number, high: number)`: Combines two 32-bit integer numbers into a 64-bit integer value and sets the seed of the random number generator using the value.
- `love.math.setRandomState(state: string)`: Sets the current state of the random number generator. The value used as an argument for this function is an opaque implementation-dependent string and should only originate from a previous call to love.math.getRandomState. This is different from love.math.setRandomSeed in that setRandomState directly sets the random number generator's current implementation-dependent state, whereas setRandomSeed gives it a new seed value.
- `love.math.triangulate` - Decomposes a simple convex or concave polygon into triangles.
  - `love.math.triangulate(polygon: table) -> triangles: table`: No description
  - `love.math.triangulate(x1: number, y1: number, x2: number, y2: number, x3: number, y3: number) -> triangles: table`: No description

## Types

- `BezierCurve`: A Bézier curve object that can evaluate and render Bézier curves of arbitrary degree. For more information on Bézier curves check this great article on Wikipedia.
  - `love.BezierCurve.evaluate(t: number) -> x: number, y: number`: Evaluate Bézier curve at parameter t. The parameter must be between 0 and 1 (inclusive). This function can be used to move objects along paths or tween parameters. However it should not be used to render the curve, see BezierCurve:render for that purpose.
  - `love.BezierCurve.getControlPoint(i: number) -> x: number, y: number`: Get coordinates of the i-th control point. Indices start with 1.
  - `love.BezierCurve.getControlPointCount() -> count: number`: Get the number of control points in the Bézier curve.
  - `love.BezierCurve.getDegree() -> degree: number`: Get degree of the Bézier curve. The degree is equal to number-of-control-points - 1.
  - `love.BezierCurve.getDerivative() -> derivative: BezierCurve`: Get the derivative of the Bézier curve. This function can be used to rotate sprites moving along a curve in the direction of the movement and compute the direction perpendicular to the curve at some parameter t.
  - `love.BezierCurve.getSegment(startpoint: number, endpoint: number) -> curve: BezierCurve`: Gets a BezierCurve that corresponds to the specified segment of this BezierCurve.
  - `love.BezierCurve.insertControlPoint(x: number, y: number, i: number)`: Insert control point as the new i-th control point. Existing control points from i onwards are pushed back by 1. Indices start with 1. Negative indices wrap around: -1 is the last control point, -2 the one before the last, etc.
  - `love.BezierCurve.removeControlPoint(index: number)`: Removes the specified control point.
  - `love.BezierCurve.render(depth: number) -> coordinates: table`: Get a list of coordinates to be used with love.graphics.line. This function samples the Bézier curve using recursive subdivision. You can control the recursion depth using the depth parameter. If you are just interested to know the position on the curve given a parameter, use BezierCurve:evaluate.
  - `love.BezierCurve.renderSegment(startpoint: number, endpoint: number, depth: number) -> coordinates: table`: Get a list of coordinates on a specific part of the curve, to be used with love.graphics.line. This function samples the Bézier curve using recursive subdivision. You can control the recursion depth using the depth parameter. If you are just need to know the position on the curve given a parameter, use BezierCurve:evaluate.
  - `love.BezierCurve.rotate(angle: number, ox: number, oy: number)`: Rotate the Bézier curve by an angle.
  - `love.BezierCurve.scale(s: number, ox: number, oy: number)`: Scale the Bézier curve by a factor.
  - `love.BezierCurve.setControlPoint(i: number, x: number, y: number)`: Set coordinates of the i-th control point. Indices start with 1.
  - `love.BezierCurve.translate(dx: number, dy: number)`: Move the Bézier curve by an offset.

- `RandomGenerator`: A random number generation object which has its own random state.
  - `love.RandomGenerator.getSeed() -> low: number, high: number`: Gets the seed of the random number generator object. The seed is split into two numbers due to Lua's use of doubles for all number values - doubles can't accurately represent integer  values above 2^53, but the seed value is an integer number in the range of 2^64 - 1.
  - `love.RandomGenerator.getState() -> state: string`: Gets the current state of the random number generator. This returns an opaque string which is only useful for later use with RandomGenerator:setState in the same major version of LÖVE. This is different from RandomGenerator:getSeed in that getState gets the RandomGenerator's current state, whereas getSeed gets the previously set seed number.
  - `love.RandomGenerator.random() -> number: number`: Generates a pseudo-random number in a platform independent manner.
  - `love.RandomGenerator.randomNormal(stddev: number, mean: number) -> number: number`: Get a normally distributed pseudo random number.
  - `love.RandomGenerator.setSeed(seed: number)`: Sets the seed of the random number generator using the specified integer number.
  - `love.RandomGenerator.setState(state: string)`: Sets the current state of the random number generator. The value used as an argument for this function is an opaque string and should only originate from a previous call to RandomGenerator:getState in the same major version of LÖVE. This is different from RandomGenerator:setSeed in that setState directly sets the RandomGenerator's current implementation-dependent state, whereas setSeed gives it a new seed value.

- `Transform`: Object containing a coordinate system transformation. The love.graphics module has several functions and function variants which accept Transform objects.
  - `love.Transform.apply(other: Transform) -> transform: Transform`: Applies the given other Transform object to this one. This effectively multiplies this Transform's internal transformation matrix with the other Transform's (i.e. self * other), and stores the result in this object.
  - `love.Transform.clone() -> clone: Transform`: Creates a new copy of this Transform.
  - `love.Transform.getMatrix() -> e1_1: number, e1_2: number, e1_3: number, e1_4: number, e2_1: number, e2_2: number, e2_3: number, e2_4: number, e3_1: number, e3_2: number, e3_3: number, e3_4: number, e4_1: number, e4_2: number, e4_3: number, e4_4: number`: Gets the internal 4x4 transformation matrix stored by this Transform. The matrix is returned in row-major order.
  - `love.Transform.inverse() -> inverse: Transform`: Creates a new Transform containing the inverse of this Transform.
  - `love.Transform.inverseTransformPoint(localX: number, localY: number) -> globalX: number, globalY: number`: Applies the reverse of the Transform object's transformation to the given 2D position. This effectively converts the given position from the local coordinate space of the Transform into global coordinates. One use of this method can be to convert a screen-space mouse position into global world coordinates, if the given Transform has transformations applied that are used for a camera system in-game.
  - `love.Transform.isAffine2DTransform() -> affine: boolean`: Checks whether the Transform is an affine transformation.
  - `love.Transform.reset() -> transform: Transform`: Resets the Transform to an identity state. All previously applied transformations are erased.
  - `love.Transform.rotate(angle: number) -> transform: Transform`: Applies a rotation to the Transform's coordinate system. This method does not reset any previously applied transformations.
  - `love.Transform.scale(sx: number, sy: number) -> transform: Transform`: Scales the Transform's coordinate system. This method does not reset any previously applied transformations.
  - `love.Transform.setMatrix(e1_1: number, e1_2: number, e1_3: number, e1_4: number, e2_1: number, e2_2: number, e2_3: number, e2_4: number, e3_1: number, e3_2: number, e3_3: number, e3_4: number, e4_1: number, e4_2: number, e4_3: number, e4_4: number) -> transform: Transform`: Directly sets the Transform's internal 4x4 transformation matrix.
  - `love.Transform.setTransformation(x: number, y: number, angle: number, sx: number, sy: number, ox: number, oy: number, kx: number, ky: number) -> transform: Transform`: Resets the Transform to the specified transformation parameters.
  - `love.Transform.shear(kx: number, ky: number) -> transform: Transform`: Applies a shear factor (skew) to the Transform's coordinate system. This method does not reset any previously applied transformations.
  - `love.Transform.transformPoint(globalX: number, globalY: number) -> localX: number, localY: number`: Applies the Transform object's transformation to the given 2D position. This effectively converts the given position from global coordinates into the local coordinate space of the Transform.
  - `love.Transform.translate(dx: number, dy: number) -> transform: Transform`: Applies a translation to the Transform's coordinate system. This method does not reset any previously applied transformations.

## Enums

- `MatrixLayout`: The layout of matrix elements (row-major or column-major).
  - `row`: The matrix is row-major:
  - `column`: The matrix is column-major:

## Examples

### Random number generation
```lua
-- Generate random numbers
local randomValue = love.math.random()  -- 0.0 to 1.0
local randomInt = love.math.random(1, 100)  -- 1 to 100
```

### Vector operations
```lua
-- Create and manipulate vectors
local vec1 = {x = 10, y = 20}
local vec2 = {x = 5, y = 15}

-- Vector addition
local result = {
  x = vec1.x + vec2.x,
  y = vec1.y + vec2.y
}
```

## Best practices
- Use love.math.random() with proper seeding for reproducibility
- Consider performance implications of complex mathematical operations
- Use appropriate data types for mathematical calculations
- Test mathematical algorithms thoroughly
- Be mindful of floating-point precision issues

## Platform compatibility
- **Desktop (Windows, macOS, Linux)**: Full math support
- **Mobile (iOS, Android)**: Full support
- **Web**: Full support
