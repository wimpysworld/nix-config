/*
Mochi is the one-eyed block cursor, blinking innocently and flaring a tiny
cloak as they scurry along a line. Leap between lines and they fart rainbows,
kick-up sparkles and stars, and stick big landings hard enough to shake the
whole terminal.
*/

// ============================================================================
// CONFIGURATION
// ============================================================================

// ──────────────────────────────────────────────────────────────────────────
// MASTER TOGGLES
// ──────────────────────────────────────────────────────────────────────────

// Enable/disable entire trail effect
const float TRAIL_ENABLED = 1.0;  // 1.0 = visible, 0.0 = hidden

// Enable/disable path bending (curved trajectories)
const float BEND_ENABLED = 1.0;   // 1.0 = curved, 0.0 = straight lines

// ──────────────────────────────────────────────────────────────────────────
// ANIMATION TIMING
// ──────────────────────────────────────────────────────────────────────────

// Time for trail tail to fully catch up to cursor (seconds)
// Lower = snappier, higher = more visible easing
// Recommended: 0.3-0.6 for visible easing effects
const float TAIL_CATCHUP_TIME = 0.5;

// Duration of soft fade zone at trail tail (where alpha transitions to 0)
const float TAIL_FADE_DURATION = 0.15;

// Extra time trail remains faintly visible after catchup completes
const float LEG_PERSISTENCE = 0.25;

// Timings are in seconds. Landing scale changes are fractions of cursor size.
const float CURSOR_TRAVEL_TIME = 0.140;
#ifndef MOCHI_KEY_REPEAT_RATE
#define MOCHI_KEY_REPEAT_RATE 30.0
#endif
const float CURSOR_SMALL_MOVE_TIME = 1.0 / MOCHI_KEY_REPEAT_RATE;
const float CURSOR_BOB_PERIOD = 1.400;
const float CURSOR_BOB_COMPRESSION = 0.14;
const float CURSOR_BOB_HOLD_TIME = 0.140;
const float CURSOR_BOB_RETURN_TIME = 0.400;
const float CURSOR_LANDING_TIME = 0.090;
const vec2 CURSOR_LANDING_SCALE = vec2(0.25, -0.40);
const float CURSOR_TOP_RADIUS = 0.23;
const vec2 CURSOR_CAPE = vec2(0.35, 0.55);
const float CURSOR_CAPE_HOLD_TIME = 0.140;
const float CURSOR_CAPE_RETURN_TIME = 0.400;
const int LANDING_PARTICLE_COUNT = 18;
const float LANDING_PARTICLE_TIME = 1.000;
const float LANDING_FULL_DISTANCE = 40.0;
const float LANDING_SHAKE_DISTANCE = LANDING_FULL_DISTANCE * 1.25;
const float LANDING_SHAKE_TIME = 0.260;
const vec2 LANDING_SHAKE_PIXELS = vec2(1.25, -5.50);
const float LANDING_SHAKE_DEGREES = 0.15;

// ──────────────────────────────────────────────────────────────────────────
// TAIL CATCHUP EASING
// ──────────────────────────────────────────────────────────────────────────

// Controls the speed profile of tail catchup animation.
// Must be float (not const) for runtime branching to work.
//
// Available presets:
//   0 = Linear           (constant speed)
//   1 = EaseInQuad       (slow start, fast end)
//   2 = EaseOutQuad      (fast start, slow end)
//   3 = EaseInOutQuad    (slow-fast-slow) ← DEFAULT, smooth & natural
//   4 = EaseInCubic      (stronger acceleration)
//   5 = EaseOutCubic     (smoother deceleration)
//   6 = EaseInOutCubic   (very smooth S-curve)
//   7 = EaseInQuart      (even slower start)
//   8 = EaseOutQuart     (very gentle finish)
//   9 = EaseInOutQuart   (extremely smooth)
//  10 = Elastic          (bouncy overshoot - very noticeable)
//  11 = Bounce           (ballistic bounce - very noticeable)
//  12 = Back             (overshoot then settle)
//  13 = SmoothStep       (gentle S-curve, softer than Quad)
//  14 = Exponential      (fast catchup after delay)
float TAIL_EASING_PRESET = 8.0;

// ──────────────────────────────────────────────────────────────────────────
// TRAIL SIZE CONTROL
// ──────────────────────────────────────────────────────────────────────────

// Size multipliers relative to actual cursor size (1.0 = same as cursor)
// Interpolates smoothly between these keyframes along the path

// Size at trail tail (t = 0.0, where animation starts)
const float TRAIL_SIZE_START = 0.0;

// Size at path middle (t = 0.5)
const float TRAIL_SIZE_MID = 1.2;

// Size at trail head (t = 1.0, at cursor position)
const float TRAIL_SIZE_END = 1.0;

// Enable smooth interpolation between size keyframes
// 1.0 = smooth S-curve interpolation, 0.0 = linear interpolation
const float TRAIL_SIZE_SMOOTH = 1.0;

// ──────────────────────────────────────────────────────────────────────────
// PATH BENDING: PRIMARY CURVE
// ──────────────────────────────────────────────────────────────────────────

// Maximum lateral offset for the curved path (normalized units)
// Higher = more pronounced curve
const float BEND_STRENGTH = 0.12;

// Movement distance below which no bending occurs (avoids jitter on tiny moves)
const float BEND_DISTANCE_MIN = 0.05;

// Movement distance at which bending reaches full strength
const float BEND_DISTANCE_MAX = 0.30;

// ──────────────────────────────────────────────────────────────────────────
// PATH BENDING: DIRECTION CONTROL
// ──────────────────────────────────────────────────────────────────────────

// Use consistent screen-space arc direction instead of random per movement
// 0.0 = random direction per movement (uses BEND_MIRROR_RANDOM)
// 1.0 = always same screen-space direction (creates consistent "hill" or "valley" shape)
const float BEND_CONSISTENT_ARC = 1.0;

// Which direction the arc bends when BEND_CONSISTENT_ARC = 1.0:
// For horizontal movement: 1.0 = up (hill), -1.0 = down (valley)
// For vertical movement:   1.0 = right, -1.0 = left
const float BEND_ARC_DIRECTION = 1.0;

// Randomly flip bend direction per movement (only used when BEND_CONSISTENT_ARC = 0.0)
// 0.0 = never flip, 1.0 = 50/50 random flip
const float BEND_MIRROR_RANDOM = 1.0;

// ──────────────────────────────────────────────────────────────────────────
// PATH BENDING: VARIATION
// ──────────────────────────────────────────────────────────────────────────

// Vary bend strength randomly per movement (adds organic feel)
// 0.0 = consistent strength, 1.0 = high variation (0.5x to 1.5x base strength)
const float BEND_STRENGTH_RANDOM = 0.0;

// ──────────────────────────────────────────────────────────────────────────
// PATH BENDING: SECONDARY CURVE
// ──────────────────────────────────────────────────────────────────────────

// Add a second bend curve layered on top of primary (creates S-curves, waves)
const float BEND2_ENABLED = 0.0;  // 1.0 = enable, 0.0 = disable

// Strength of secondary curve (typically 0.3-0.7 of primary BEND_STRENGTH)
const float BEND2_STRENGTH = 0.06;

// Frequency multiplier for secondary curve
// 2.0 = double wave (S-curve), 3.0 = triple wave, etc.
const float BEND2_FREQUENCY = 2.0;

// Randomize secondary curve phase per movement (adds variety)
// 0.0 = fixed phase, 1.0 = random per movement
const float BEND2_PHASE_RANDOM = 1.0;

// ──────────────────────────────────────────────────────────────────────────
// PATH BENDING: NOISE
// ──────────────────────────────────────────────────────────────────────────

// Add subtle per-point noise along the path (breaks up perfect curves)
// 0.0 = smooth curve, higher = more jitter
const float BEND_RANDOMNESS = 0.0;

// ──────────────────────────────────────────────────────────────────────────
// COLOUR SETTINGS
// ──────────────────────────────────────────────────────────────────────────

// Catppuccin Mocha RGB values from lib/catppuccin-palette.json.
// From cursor to tail: Red, Peach, Yellow, Green, Sapphire, Blue, Mauve.
const vec3 TRAIL_COLOURS[7] = vec3[7](
    vec3(243.0, 139.0, 168.0) / 255.0,
    vec3(250.0, 179.0, 135.0) / 255.0,
    vec3(249.0, 226.0, 175.0) / 255.0,
    vec3(166.0, 227.0, 161.0) / 255.0,
    vec3(116.0, 199.0, 236.0) / 255.0,
    vec3(137.0, 180.0, 250.0) / 255.0,
    vec3(203.0, 166.0, 247.0) / 255.0
);

// ──────────────────────────────────────────────────────────────────────────
// OPACITY SETTINGS
// ──────────────────────────────────────────────────────────────────────────

// Base opacity multiplier for the trail.
const float TRAIL_BASE_ALPHA = 0.80;

// Each half of the cursor fade lasts this many seconds.
const float CURSOR_FADE_HALF_PERIOD = 0.75;
const float CURSOR_FADE_HOLD_TIME = 0.500;

// ──────────────────────────────────────────────────────────────────────────
// RENDERING SETTINGS
// ──────────────────────────────────────────────────────────────────────────

// Maximum cursor movement distance (in cursor-width units) to consider valid
// Movements larger than this won't trigger trail rendering
const float MAX_VALID_MOVE_DISTANCE = 100.0;

// Minimum movement distance to trigger trail rendering (filters out jitter)
const float MIN_MOVE_DISTANCE = 0.01;

// Allow small coordinate differences when detecting one-cell horizontal or vertical moves.
const float SMALL_MOVE_TOLERANCE = 0.05;

// Number of points joined by rounded segments over the remaining path.
// Higher values follow the curve more closely but add GPU work.
const int PATH_SAMPLES = 128;

// ============================================================================
// EASING FUNCTIONS
// ============================================================================

const float PI = 3.14159265359;

float easeLinear(float t) { return clamp(t, 0.0, 1.0); }
float easeInQuad(float t) { t = clamp(t, 0.0, 1.0); return t * t; }
float easeOutQuad(float t) { t = clamp(t, 0.0, 1.0); return t * (2.0 - t); }
float easeInOutQuad(float t) { t = clamp(t, 0.0, 1.0); return t < 0.5 ? 2.0 * t * t : -1.0 + (4.0 - 2.0 * t) * t; }
float easeInCubic(float t) { t = clamp(t, 0.0, 1.0); return t * t * t; }
float easeOutCubic(float t) { t = clamp(t, 0.0, 1.0); float mt = 1.0 - t; return 1.0 - mt * mt * mt; }
float easeInOutCubic(float t) { t = clamp(t, 0.0, 1.0); return t < 0.5 ? 4.0 * t * t * t : 1.0 - pow(-2.0 * t + 2.0, 3.0) * 0.5; }
float easeInQuart(float t) { t = clamp(t, 0.0, 1.0); return t * t * t * t; }
float easeOutQuart(float t) { t = clamp(t, 0.0, 1.0); float mt = 1.0 - t; return 1.0 - mt * mt * mt * mt; }
float easeInOutQuart(float t) { t = clamp(t, 0.0, 1.0); return t < 0.5 ? 8.0 * t * t * t * t : 1.0 - pow(-2.0 * t + 2.0, 4.0) * 0.5; }
float easeElastic(float t) { t = clamp(t, 0.0, 1.0); if (t < 0.001 || t > 0.999) return t; float p = 0.3; return pow(2.0, -10.0 * t) * sin((t - p * 0.25) * (2.0 * PI) / p) + 1.0; }
float easeBounce(float t) { t = clamp(t, 0.0, 1.0); float n1 = 7.5625, d1 = 2.75; if (t < 1.0 / d1) return n1 * t * t; else if (t < 2.0 / d1) { t -= 1.5 / d1; return n1 * t * t + 0.75; } else if (t < 2.5 / d1) { t -= 2.25 / d1; return n1 * t * t + 0.9375; } else { t -= 2.625 / d1; return n1 * t * t + 0.984375; } }
float easeBack(float t) { t = clamp(t, 0.0, 1.0); float c1 = 1.70158, c3 = c1 + 1.0; return c3 * t * t * t - c1 * t * t; }
float easeSmoothStep(float t) { t = clamp(t, 0.0, 1.0); return t * t * (3.0 - 2.0 * t); }
float easeExponential(float t) { t = clamp(t, 0.0, 1.0); if (t < 0.001) return 0.0; return pow(2.0, 10.0 * (t - 1.0)); }

float getCursorAlpha(float elapsed) {
    float phase = mod(elapsed, 2.0 * CURSOR_FADE_HALF_PERIOD);
    float t = mod(phase, CURSOR_FADE_HALF_PERIOD) / CURSOR_FADE_HALF_PERIOD;
    return phase < CURSOR_FADE_HALF_PERIOD
        ? 1.0 - easeSmoothStep(t)
        : easeSmoothStep(t);
}

float getSquashPulse(float progress) {
    return easeSmoothStep(1.0 - abs(2.0 * clamp(progress, 0.0, 1.0) - 1.0));
}

float getLandingShakePulse(float progress) {
    if (progress < 0.15) return easeSmoothStep(progress / 0.15);
    if (progress < 0.60) return mix(1.0, -0.20, easeSmoothStep((progress - 0.15) / 0.45));
    return mix(-0.20, 0.0, easeSmoothStep((progress - 0.60) / 0.40));
}

float applyTailEasing(float t) {
    if (TAIL_EASING_PRESET < 0.5) return easeLinear(t);
    if (TAIL_EASING_PRESET < 1.5) return easeInQuad(t);
    if (TAIL_EASING_PRESET < 2.5) return easeOutQuad(t);
    if (TAIL_EASING_PRESET < 3.5) return easeInOutQuad(t);
    if (TAIL_EASING_PRESET < 4.5) return easeInCubic(t);
    if (TAIL_EASING_PRESET < 5.5) return easeOutCubic(t);
    if (TAIL_EASING_PRESET < 6.5) return easeInOutCubic(t);
    if (TAIL_EASING_PRESET < 7.5) return easeInQuart(t);
    if (TAIL_EASING_PRESET < 8.5) return easeOutQuart(t);
    if (TAIL_EASING_PRESET < 9.5) return easeInOutQuart(t);
    if (TAIL_EASING_PRESET < 10.5) return easeElastic(t);
    if (TAIL_EASING_PRESET < 11.5) return easeBounce(t);
    if (TAIL_EASING_PRESET < 12.5) return easeBack(t);
    if (TAIL_EASING_PRESET < 13.5) return easeSmoothStep(t);
    return easeExponential(t);
}

// ============================================================================
// UTILITIES
// ============================================================================

float hash(vec3 p) {
    p = fract(p * 0.1031);
    p += dot(p, p.yzx + 33.33);
    return fract((p.x + p.y) * p.z);
}

float getBlinkClosure(float age, float duration) {
    float phase = age / duration;
    return smoothstep(0.0, 0.30, phase) * (1.0 - smoothstep(0.57, 1.0, phase));
}

vec3 getIdleExpressionEvent(float time, float idleReady) {
    // Starts are 20 to 40 seconds apart. Only complete events after idle readiness qualify.
    float slot = floor(time / 30.0);
    float start = slot * 30.0 + 1.0 + 10.0 * hash(vec3(slot, 740.0, 0.0));
    float doze = hash(vec3(slot, 740.0, 1.0)) < 0.25 ? 1.0 : 0.0;
    return start >= idleReady ? vec3(start, mix(2.7, 4.8, doze), doze) : vec3(-100.0, 0.0, 0.0);
}

float getEyeAperture(float time, vec3 expressionEvent, vec2 landingWindow) {
    // Blink starts are 2 to 10 seconds apart, independent of cursor movement and fading.
    float slot = floor(time / 6.0);
    float start = 0.5 + 4.0 * hash(vec3(slot, 720.0, 0.0));
    float duration = mix(0.280, 0.360, hash(vec3(slot, 720.0, 1.0)));
    bool doubleBlink = hash(vec3(slot, 720.0, 2.0)) < 0.20;
    float secondStart = duration + 0.090;
    float eventEnd = slot * 6.0 + start + (doubleBlink ? secondStart + duration : duration);
    // Skip the whole blink when an expression owns the eye, including its transition edges.
    if (slot * 6.0 + start < expressionEvent.x + expressionEvent.y && eventEnd > expressionEvent.x) return 1.0;
    if (slot * 6.0 + start < landingWindow.y && eventEnd > landingWindow.x) return 1.0;
    float age = mod(time, 6.0) - start;
    float closure = getBlinkClosure(age, duration);
    if (doubleBlink) closure = max(closure, getBlinkClosure(age - secondStart, duration));
    return 1.0 - closure;
}

vec3 getIdleGaze(float time, float idleReady) {
    // Jitter within fixed slots keeps event starts 5 to 12 seconds apart.
    float slot = floor(time / 8.5);
    float start = slot * 8.5 + 0.5 + 3.5 * hash(vec3(slot, 730.0, 0.0));
    float duration = mix(1.4, 2.2, hash(vec3(slot, 730.0, 1.0)));
    // Skip events that began before idle readiness instead of entering them partway through.
    if (start < idleReady || time < start || time >= start + duration) return vec3(0.0);

    float phase = (time - start) / duration;
    float angle = 2.0 * PI * hash(vec3(slot, 730.0, 2.0));
    if (hash(vec3(slot, 730.0, 3.0)) < 0.5) {
        float arc = mix(0.25, 0.45, hash(vec3(slot, 730.0, 4.0))) * PI;
        float direction = hash(vec3(slot, 730.0, 5.0)) < 0.5 ? -1.0 : 1.0;
        angle += direction * arc * smoothstep(0.30, 0.60, phase);
    }
    float pulse = smoothstep(0.0, 0.20, phase) * (1.0 - smoothstep(0.60, 1.0, phase));
    pulse *= mix(0.55, 0.85, hash(vec3(slot, 730.0, 6.0)));
    return vec3(cos(angle), sin(angle), pulse);
}

vec2 normalizeCoord(vec2 v, float isPosition) {
    return (v * 2.0 - (iResolution.xy * isPosition)) / iResolution.y;
}

float antialiasNoBlur(float d) {
    float w = fwidth(d) * 1.5;
    if (w < 0.001) w = 0.002;
    return 1.0 - smoothstep(-w, w, d);
}

float sdfRect(vec2 p, vec2 c, vec2 h) {
    vec2 d = abs(p - c) - h;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

float sdfCursor(vec2 point, vec2 halfSize) {
    float radius = point.y > 0.0 ? 2.0 * CURSOR_TOP_RADIUS * min(halfSize.x, halfSize.y) : 0.0;
    vec2 distance = abs(point) - halfSize + radius;
    return length(max(distance, 0.0)) + min(max(distance.x, distance.y), 0.0) - radius;
}

float sdfCursorCape(vec2 point, vec2 halfSize, float cape) {
    vec2 size = 2.0 * halfSize;
    point.x *= -sign(cape);
    // Overlap the lower rear edge, then narrow to one point outside the body.
    vec2 top = size * vec2(0.40, -0.20);
    vec2 bottom = size * vec2(0.40, -0.50);
    vec2 tip = vec2(halfSize.x + abs(cape),
        -halfSize.y - 0.05 * abs(cape) * size.y / max(size.x, 1e-6));
    vec2 upperEdge = tip - top;
    vec2 lowerEdge = bottom - tip;
    vec2 upperOffset = point - top;
    vec2 lowerOffset = point - tip;
    float upperDistance = (upperEdge.x * upperOffset.y - upperEdge.y * upperOffset.x)
        / max(length(upperEdge), 1e-6);
    float lowerDistance = (lowerEdge.x * lowerOffset.y - lowerEdge.y * lowerOffset.x)
        / max(length(lowerEdge), 1e-6);
    return max(top.x - point.x, max(upperDistance, lowerDistance));
}

// Return the tapered capsule distance and the closest position along it.
// Cursor-scaled coordinates give all segments the same elliptical aspect.
vec2 sdfTrailSegment(vec2 p, vec2 a, vec2 b, float ra, float rb) {
    vec2 segment = b - a;
    vec2 offset = p - a;
    float segmentLength = length(segment);
    float radiusChange = rb - ra;
    float u;

    // This also handles coincident endpoints without dividing by zero.
    if (segmentLength <= abs(radiusChange)) {
        u = rb > ra ? 1.0 : 0.0;
    } else {
        vec2 direction = segment / segmentLength;
        float along = dot(offset, direction);
        float across = length(offset - direction * along);
        float sideLength = sqrt((segmentLength - abs(radiusChange))
            * (segmentLength + abs(radiusChange)));
        u = clamp((along + radiusChange * across / sideLength) / segmentLength, 0.0, 1.0);
    }

    return vec2(length(offset - segment * u) - mix(ra, rb, u), u);
}

float getBendStrength(float L) {
    if (BEND_ENABLED < 0.5 || L <= BEND_DISTANCE_MIN) return 0.0;
    if (L >= BEND_DISTANCE_MAX) return BEND_STRENGTH;
    return BEND_STRENGTH * smoothstep(BEND_DISTANCE_MIN, BEND_DISTANCE_MAX, L);
}

// Unique per-movement ID (stable during entire trail animation)
float getMovementId(vec2 prev, vec2 curr, float len) {
    float t = fract(iTimeCursorChange * 10.0);
    float p = hash(vec3(prev, curr.x));
    float m = len * 10.0;
    return hash(vec3(t, p, m));
}

// Bend direction and strength variation per movement
vec2 getBendRandomization(float id) {
    float flip = 1.0, mult = 1.0;

    if (BEND_CONSISTENT_ARC > 0.5) {
        flip = BEND_ARC_DIRECTION;
    } else if (BEND_MIRROR_RANDOM > 0.5) {
        flip = hash(vec3(id, 100.0, 0.0)) > 0.5 ? 1.0 : -1.0;
    }

    if (BEND_STRENGTH_RANDOM > 0.001) {
        mult = 1.0 + (hash(vec3(id, 100.0, 1.0)) - 0.5) * 2.0 * BEND_STRENGTH_RANDOM;
        mult = clamp(mult, 0.5, 1.5);
    }
    return vec2(flip, mult);
}

float getBend2Phase(float id) {
    if (BEND2_PHASE_RANDOM > 0.5) return hash(vec3(id, 200.0, 0.0)) * 2.0 * PI;
    return 0.0;
}

// Calculate bent path position
vec2 getBentPathPosition(vec2 A, vec2 B, float t, float strength, float id) {
    vec2 pos = mix(A, B, t);
    if (strength < 0.001) return pos;

    vec2 dir = normalize(B - A + 0.0001);
    vec2 perp = vec2(-dir.y, dir.x);

    vec2 rand = getBendRandomization(id);
    float flip = rand.x, mult = rand.y;

    float offset;
    vec2 bendDir;

    if (BEND_CONSISTENT_ARC > 0.5) {
        // Screen-space direction (consistent regardless of movement direction)
        bool horizontal = abs(dir.x) > abs(dir.y);
        bendDir = horizontal ? vec2(0.0, 1.0) : vec2(1.0, 0.0);
        offset = sin(t * PI) * strength * mult * flip;
    } else {
        // Movement-relative perpendicular
        bendDir = perp;
        offset = sin(t * PI) * strength * mult;
    }

    // Secondary curve
    if (BEND2_ENABLED > 0.5 && BEND2_STRENGTH > 0.001) {
        float phase = getBend2Phase(id);
        float offset2 = sin(t * PI * BEND2_FREQUENCY + phase) * BEND2_STRENGTH * mult;
        offset2 *= sin(t * PI);  // Zero at endpoints
        offset += offset2;
    }

    // Per-point noise
    if (BEND_RANDOMNESS > 0.001) {
        offset += (hash(vec3(id, t * 7.0, 300.0)) - 0.5) * 2.0 * BEND_RANDOMNESS * strength * 0.2;
    }

    return pos + bendDir * offset;
}

// Trail size interpolation
float getTrailSize(float t) {
    float size, localT;
    if (t < 0.5) {
        localT = t * 2.0;
        if (TRAIL_SIZE_SMOOTH > 0.5) localT = localT * localT * (3.0 - 2.0 * localT);
        size = mix(TRAIL_SIZE_START, TRAIL_SIZE_MID, localT);
    } else {
        localT = (t - 0.5) * 2.0;
        if (TRAIL_SIZE_SMOOTH > 0.5) localT = localT * localT * (3.0 - 2.0 * localT);
        size = mix(TRAIL_SIZE_MID, TRAIL_SIZE_END, localT);
    }
    return size;
}

float getTrailRadius(vec2 halfSize, vec2 aspect, float t) {
    vec2 scaledSize = halfSize / aspect;
    return max(min(scaledSize.x, scaledSize.y) * getTrailSize(t), 0.0);
}

// ============================================================================
// MAIN
// ============================================================================

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 off = vec2(-0.5, 0.5);

    vec4 cur = vec4(normalizeCoord(iCurrentCursor.xy, 1.0), normalizeCoord(iCurrentCursor.zw, 0.0));
    vec4 prev = vec4(normalizeCoord(iPreviousCursor.xy, 1.0), normalizeCoord(iPreviousCursor.zw, 0.0));

    vec2 cC = cur.xy - (cur.zw * off);
    vec2 hC = cur.zw * 0.5;
    vec2 cP = prev.xy - (prev.zw * off);
    vec2 hP = prev.zw * 0.5;

    vec2 mv = cC - cP;
    float mL = length(mv);
    float minD = cur.w * MIN_MOVE_DISTANCE;
    float maxD = cur.w * MAX_VALID_MOVE_DISTANCE;
    // Compare origins so cursor size changes do not imply a different row or column.
    bool smallHorizontalMove = abs(cur.y - prev.y) <= min(cur.w, prev.w) * SMALL_MOVE_TOLERANCE
        && abs(cur.x - prev.x) <= min(cur.z, prev.z) * (1.0 + SMALL_MOVE_TOLERANCE);
    bool smallVerticalMove = abs(cur.x - prev.x) <= min(cur.z, prev.z) * SMALL_MOVE_TOLERANCE
        && abs(cur.y - prev.y) <= min(cur.w, prev.w) * (1.0 + SMALL_MOVE_TOLERANCE);

    float timeSince = iTime - iTimeCursorChange;

    bool cursorGeometryValid = cur.z > 0.0 && cur.w > 0.0;
    bool cursorVisible = iFocus > 0 && iCursorVisible > 0 && cursorGeometryValid;
    bool valid = cursorGeometryValid && prev.z > 0.0 && prev.w > 0.0
        && !smallHorizontalMove && !smallVerticalMove && (mL > minD) && (mL < maxD) && timeSince >= 0.0;
    bool jump = cursorVisible && valid && iCurrentCursorStyle == CURSORSTYLE_BLOCK_HOLLOW
        && iTimeCursorChange > iTimeFocus;
    bool smallSlide = cursorVisible && prev.z > 0.0 && prev.w > 0.0
        && (smallHorizontalMove || smallVerticalMove) && length(cur.xy - prev.xy) > minD
        && mL > minD && mL < maxD && timeSince >= 0.0
        && iCurrentCursorStyle == CURSORSTYLE_BLOCK_HOLLOW && iTimeCursorChange > iTimeFocus;
    float landingStart = CURSOR_TRAVEL_TIME;
    float jumpEnd = landingStart + CURSOR_LANDING_TIME;
    // Measure origin displacement in cells, independent of font size and aspect.
    float cellDistance = valid ? length((cur.xy - prev.xy) / max(cur.zw, vec2(1e-6))) : 0.0;
    vec2 renderCoord = fragCoord;
    vec2 sampleCoord = fragCoord;
    if (jump && cellDistance > LANDING_SHAKE_DISTANCE
        && timeSince > landingStart && timeSince < landingStart + LANDING_SHAKE_TIME) {
        float progress = (timeSince - landingStart) / LANDING_SHAKE_TIME;
        float intensity = smoothstep(LANDING_SHAKE_DISTANCE, LANDING_SHAKE_DISTANCE * 1.5, cellDistance);
        float pulse = intensity * getLandingShakePulse(progress);
        // Inverse sampling moves the screen down first, then through one small rebound.
        renderCoord -= LANDING_SHAKE_PIXELS * pulse;
        float horizontalDirection = (cur.x - prev.x) / max(cur.z, 1e-6) / cellDistance;
        float angle = radians(LANDING_SHAKE_DEGREES) * horizontalDirection * pulse;
        float rotationCos = cos(angle);
        float rotationSin = sin(angle);
        vec2 pivot = iResolution.xy * 0.5;
        // Anticlockwise source sampling makes rightward jumps rotate the screen clockwise.
        renderCoord = pivot + mat2(rotationCos, rotationSin, -rotationSin, rotationCos) * (renderCoord - pivot);
        // Clamp the source sample to texel centres without clipping procedural effects.
        sampleCoord = clamp(renderCoord, vec2(0.5), iResolution.xy - vec2(0.5));
    }

    #if !defined(WEB)
    fragColor = texture(iChannel0, sampleCoord.xy / iResolution.xy);
    #endif

    vec2 vu = normalizeCoord(renderCoord, 1.0);
    vec4 outC = fragColor;
    float strength = (valid || smallSlide) ? getBendStrength(mL) : 0.0;
    float id = (valid || smallSlide) ? getMovementId(cP, cC, mL) : 0.0;
    float headProgress = 1.0;
    vec2 renderedCenter = cC;
    vec2 renderedHalfSize = hC;
    vec2 renderedScale = vec2(1.0);

    if (smallSlide && timeSince < CURSOR_SMALL_MOVE_TIME) {
        headProgress = easeLinear(timeSince / CURSOR_SMALL_MOVE_TIME);
        renderedCenter = getBentPathPosition(cP, cC, headProgress, strength, id);
        renderedHalfSize = mix(hP, hC, headProgress);
    } else if (jump && timeSince < jumpEnd) {
        headProgress = easeSmoothStep(timeSince / CURSOR_TRAVEL_TIME);
        renderedCenter = getBentPathPosition(cP, cC, headProgress, strength, id);
        vec2 baseHalfSize = mix(hP, hC, headProgress);
        vec2 squash = CURSOR_LANDING_SCALE * getSquashPulse((timeSince - landingStart) / CURSOR_LANDING_TIME);
        renderedScale += squash;
        renderedHalfSize = baseHalfSize * renderedScale;
        // Keep the lower edge fixed while the cursor becomes shorter.
        renderedCenter.y += renderedHalfSize.y - baseHalfSize.y;
    }

    vec2 baseHalfSize = renderedHalfSize / renderedScale;
    vec2 cursorLocal = (vu - renderedCenter) / renderedScale;
    vec2 capeLocal = cursorLocal;
    float capeDistanceScale = min(renderedScale.x, renderedScale.y);
    if (smallSlide) {
        // The shared clock keeps the bob phase continuous across repeated cells.
        float cycle = 0.5 - 0.5 * cos(2.0 * PI * iTime / CURSOR_BOB_PERIOD);
        float release = 1.0 - easeSmoothStep((timeSince - CURSOR_BOB_HOLD_TIME) / CURSOR_BOB_RETURN_TIME);
        float bobScale = 1.0 - CURSOR_BOB_COMPRESSION * cycle * release;
        // Scale only the head and eye about the lower edge, leaving the cape unchanged.
        cursorLocal.y = (cursorLocal.y + baseHalfSize.y) / bobScale - baseHalfSize.y;
        renderedScale.y *= bobScale;
    }
    float sdfCur = sdfRect(vu, renderedCenter, renderedHalfSize);
    if (cursorGeometryValid && iCurrentCursorStyle == CURSORSTYLE_BLOCK_HOLLOW) {
        float cape = 0.0;
        if (smallSlide || jump) {
            vec2 movement = cur.xy - prev.xy;
            float horizontalDirection = movement.x / max(length(movement), 1e-6);
            if (smallSlide) {
                float extension = 1.0 - easeSmoothStep((timeSince - CURSOR_CAPE_HOLD_TIME) / CURSOR_CAPE_RETURN_TIME);
                cape = horizontalDirection * extension * 2.0 * baseHalfSize.x * CURSOR_CAPE.x;
            } else {
                float phase = clamp(timeSince / CURSOR_TRAVEL_TIME, 0.0, 1.0);
                float motion = horizontalDirection * getSquashPulse(phase) * 2.0 * baseHalfSize.x;
                cape = motion * CURSOR_CAPE.y * (1.0 + 0.10 * sin(2.0 * PI * phase));
            }
        }
        sdfCur = sdfCursor(cursorLocal, baseHalfSize) * min(renderedScale.x, renderedScale.y);
        if (cape != 0.0) sdfCur = min(sdfCur, sdfCursorCape(capeLocal, baseHalfSize, cape) * capeDistanceScale);
    }
    // Let the trail grow behind the moving cursor before its tail catches up.
    float trailTime = timeSince - (jump ? landingStart : 0.0);
    bool visible = trailTime < (TAIL_CATCHUP_TIME + LEG_PERSISTENCE);

    if (TRAIL_ENABLED > 0.5 && cursorVisible && valid && visible
        && iTimeCursorChange > iTimeFocus) {
        float progress = clamp(trailTime / TAIL_CATCHUP_TIME, 0.0, 1.0);
        progress = applyTailEasing(progress);

        float tStart = clamp(progress, 0.0, headProgress), tEnd = headProgress;

        if (tStart < tEnd) {
            float minDist = 1e6, bestT = tStart;
            // A shared aspect keeps the elliptical caps identical at joins.
            // Changed cursor proportions use the radius inside both dimensions.
            vec2 aspect = max(hC, vec2(1e-6));
            vec2 point = vu / aspect;
            float previousT = tStart;
            vec2 previousPos = getBentPathPosition(cP, cC, previousT, strength, id) / aspect;
            float previousRadius = getTrailRadius(mix(hP, hC, previousT), aspect, previousT);

            for (int i = 1; i < PATH_SAMPLES; i++) {
                float t = mix(tStart, tEnd, float(i) / float(PATH_SAMPLES - 1));
                vec2 pathPos = getBentPathPosition(cP, cC, t, strength, id) / aspect;
                float radius = getTrailRadius(mix(hP, hC, t), aspect, t);
                vec2 segment = sdfTrailSegment(point, previousPos, pathPos, previousRadius, radius);

                if (segment.x < minDist) {
                    minDist = segment.x;
                    bestT = mix(previousT, t, segment.y);
                }
                previousT = t;
                previousPos = pathPos;
                previousRadius = radius;
            }
            minDist *= min(aspect.x, aspect.y);

            // Trail alpha components
            float trailAlpha = bestT;  // Gradient: 0 at tail, 1 at cursor

            // Soft fade at trail tail
            if (bestT < tStart + TAIL_FADE_DURATION) {
                trailAlpha *= smoothstep(tStart, tStart + TAIL_FADE_DURATION, bestT);
            }

            // Antialiasing edge smoothing
            trailAlpha *= antialiasNoBlur(minDist);

            // Base opacity multiplier
            trailAlpha *= TRAIL_BASE_ALPHA;
            trailAlpha *= step(0.0, sdfCur);

            // Fit all seven bands to the remaining path as the tail catches up.
            float colourPosition = clamp((tEnd - bestT) / (tEnd - tStart), 0.0, 1.0);
            int colourBand = min(int(floor(colourPosition * 7.0)), 6);
            vec4 trailColor = vec4(TRAIL_COLOURS[colourBand], mix(1.0, 0.8, bestT) * trailAlpha);

            if (trailColor.a > 0.001) {
                outC = mix(outC, vec4(trailColor.rgb, outC.a), trailColor.a);
            }
        }
    }

    float particleAge = timeSince - landingStart;
    if (jump && particleAge >= 0.0 && particleAge < LANDING_PARTICLE_TIME) {
        float intensity = smoothstep(LANDING_FULL_DISTANCE / 12.0, LANDING_FULL_DISTANCE, cellDistance);
        int particleCount = int(floor(mix(4.0, float(LANDING_PARTICLE_COUNT), intensity) + 0.5));
        int starCount = int(floor(4.0 * intensity + 0.5));
        float horizontalSpread = mix(0.25, 1.0, intensity);
        float pixel = 2.0 / iResolution.y;
        vec2 origin = cC - vec2(0.0, hC.y);
        vec2 offset = vu - origin;
        // Include the widest star tips and their antialiasing edges.
        vec2 padding = vec2(10.0 * pixel);
        if (all(greaterThan(offset, -cur.zw * vec2(3.1, 2.8) - padding))
            && all(lessThan(offset, cur.zw * vec2(3.1, 1.0) + padding))) {
            for (int i = 0; i < LANDING_PARTICLE_COUNT; i++) {
                if (i >= particleCount) break;
                float a = hash(vec3(id, float(i), 410.0));
                float b = hash(vec3(id, float(i), 411.0));
                float c = hash(vec3(id, float(i), 412.0));
                float lifetime = mix(0.700, LANDING_PARTICLE_TIME, a);
                if (particleAge >= lifetime) continue;

                float strand = 2.0 * float(i) / float(particleCount - 1) - 1.0;
                float progress = particleAge / lifetime;
                float apex = mix(0.34, 0.38, c);
                float riseAge = progress / apex;
                // Positive Y rises from the fixed lower edge, then gravity pulls down.
                vec2 position = origin + cur.zw * vec2(
                    strand * (0.4 + 2.7 * easeOutQuad(progress)) * horizontalSpread,
                    mix(0.5, 1.0, b) * (2.0 * riseAge - riseAge * riseAge)
                );
                float radius = clamp(min(cur.z, cur.w) * mix(0.075, 0.16, c),
                    0.80 * pixel, 2.30 * pixel);
                vec2 delta = abs(vu - position);
                float distance = length(delta) - radius;
                if (i % 5 == 0 && i / 5 < starCount) {
                    // Two narrow diamonds form four points with concave sides.
                    distance = (min(delta.x + 3.0 * delta.y, 3.0 * delta.x + delta.y)
                        - 2.6 * radius) / sqrt(10.0);
                }
                float alpha = 1.0 - smoothstep(-pixel, pixel, distance);
                alpha *= smoothstep(0.0, 0.018, particleAge)
                    * (1.0 - smoothstep(0.58, 1.0, progress));
                float sparkle = pow(0.5 + 0.5 * sin(particleAge * 24.0 + c * 2.0 * PI), 8.0);
                alpha *= mix(0.86, 0.98, b) * (0.86 + 0.14 * sparkle);
                alpha *= smoothstep(0.0, pixel, sdfCur);
                // Deepen the gold derived from Catppuccin Yellow and Peach.
                vec3 colour = mix(TRAIL_COLOURS[2], TRAIL_COLOURS[1], a * 0.35)
                    * vec3(1.0, 0.95, 0.55);
                float core = 1.0 - smoothstep(0.15 * radius, 0.85 * radius, length(delta));
                colour = mix(colour, vec3(1.0, 0.96, 0.72), core * (0.65 + 0.35 * sparkle));
                outC = mix(outC, vec4(colour, outC.a), alpha);
            }
        }
    }

    if (cursorVisible) {
        float cursorAlpha = 1.0;
        if (iCurrentCursorStyle == CURSORSTYLE_BLOCK_HOLLOW) {
            float movementEnd = jump ? jumpEnd : (smallSlide ? CURSOR_SMALL_MOVE_TIME : 0.0);
            float fadeDelay = movementEnd + ((smallSlide || jump) ? CURSOR_FADE_HOLD_TIME : 0.0);
            float resetTime = max(iTimeCursorChange + fadeDelay, iTimeFocus);
            cursorAlpha = getCursorAlpha(max(iTime - resetTime, 0.0));
        }

        vec3 cursorColour = iCurrentCursorColor.rgb;
        if (iCurrentCursorStyle == CURSORSTYLE_BLOCK_HOLLOW) {
            float eyeRadius = 0.72 * min(baseHalfSize.x, baseHalfSize.y);
            float pixel = 2.0 / iResolution.y;
            // Keep subpixel cursors plain when the pupil cannot remain clear.
            if (eyeRadius >= 2.0 * pixel) {
                vec2 eyeAnchor = vec2(0.0, min(0.12 * baseHalfSize.y + pixel, baseHalfSize.y - eyeRadius));
                float time = max(iTime, 0.0);
                float idleSince = max(iTimeCursorChange, iTimeFocus);
                vec3 expressionEvent = getIdleExpressionEvent(time, idleSince + 10.0);
                float expressionAge = time - expressionEvent.x;
                float expressionWeight = smoothstep(0.0, 0.25, expressionAge)
                    * (1.0 - smoothstep(expressionEvent.y - 0.35, expressionEvent.y, expressionAge));
                float mouthOpen = 0.0;
                float expressionClosure = 0.0;
                float lidDrop = 0.0;
                float expressionGaze = 0.0;
                float startle = 0.0;
                if (expressionWeight > 0.0) {
                    if (expressionEvent.z < 0.5) {
                        mouthOpen = smoothstep(0.35, 1.0, expressionAge)
                            * (1.0 - smoothstep(1.75, 2.25, expressionAge));
                        expressionClosure = smoothstep(0.40, 1.0, expressionAge)
                            * (1.0 - smoothstep(1.90, 2.70, expressionAge));
                        expressionGaze = 0.35 * smoothstep(0.0, 0.35, expressionAge)
                            * (1.0 - smoothstep(0.45, 0.95, expressionAge));
                    } else {
                        lidDrop = 0.92 * smoothstep(0.25, 1.90, expressionAge)
                            * (1.0 - smoothstep(2.50, 2.60, expressionAge));
                        expressionGaze = -0.70 * smoothstep(0.25, 1.90, expressionAge)
                            * (1.0 - smoothstep(2.50, 2.60, expressionAge));
                        startle = smoothstep(2.50, 2.60, expressionAge)
                            * (1.0 - smoothstep(3.80, 4.40, expressionAge));
                        expressionClosure = max(getBlinkClosure(expressionAge - 3.05, 0.220),
                            getBlinkClosure(expressionAge - 3.36, 0.220));
                    }
                }
                float restingEyeRadius = eyeRadius;
                eyeRadius = mix(eyeRadius, min(1.15 * eyeRadius,
                    min(baseHalfSize.x, baseHalfSize.y - eyeAnchor.y)), startle);
                vec2 eyeCoord = cursorLocal - eyeAnchor;
                vec3 idleGaze = getIdleGaze(time, idleSince + 2.0);
                vec2 gazeDirection = idleGaze.xy;
                float gazePulse = idleGaze.z;
                vec2 movement = cur.xy - prev.xy;
                float movementLength = length(movement);
                if (prev.z > 0.0 && prev.w > 0.0 && timeSince >= 0.0 && timeSince < 2.0
                    && iTimeCursorChange > iTimeFocus && movementLength > minD && movementLength < maxD) {
                    gazePulse = (smallHorizontalMove || smallVerticalMove ? 1.0 : easeSmoothStep(timeSince / 0.080))
                        * (1.0 - easeSmoothStep((timeSince - CURSOR_TRAVEL_TIME) / 1.200));
                    gazeDirection = movement / movementLength;
                }
                vec2 blendedGaze = mix(gazeDirection * gazePulse, vec2(0.0, expressionGaze), expressionWeight);
                gazePulse = length(blendedGaze);
                gazeDirection = gazePulse > 0.0 ? blendedGaze / gazePulse : vec2(0.0);
                vec2 gaze = gazeDirection * (0.20 * eyeRadius * gazePulse);
                vec2 eyeMargin = baseHalfSize - vec2(eyeRadius);
                vec2 eyeShift = clamp(gazeDirection * (0.08 * eyeRadius),
                    -eyeMargin - eyeAnchor, eyeMargin - eyeAnchor);
                eyeCoord -= eyeShift * gazePulse;

                vec2 landingWindow = jump ? iTimeCursorChange + vec2(landingStart - 0.060, jumpEnd + 0.160) : vec2(-100.0);
                float aperture = getEyeAperture(time, expressionEvent, landingWindow) * (1.0 - expressionClosure);
                if (jump) {
                    float landingAperture = 1.0 - smoothstep(landingStart - 0.060, landingStart, timeSince)
                        * (1.0 - smoothstep(jumpEnd + 0.040, jumpEnd + 0.160, timeSince));
                    aperture = min(aperture, landingAperture);
                }
                float distanceScale = min(renderedScale.x, renderedScale.y);
                float eyeDistance = max(length(eyeCoord) - eyeRadius,
                    abs(eyeCoord.y) - eyeRadius * aperture) * distanceScale;
                // Positive Y points up. Lower only the upper eyelid during the doze.
                eyeDistance = max(eyeDistance, (eyeCoord.y - eyeRadius * (1.0 - 2.0 * lidDrop)) * distanceScale);
                float eyeAA = max(0.75 * fwidth(eyeDistance), 0.5 * pixel);
                float openVisibility = smoothstep(0.0, pixel, eyeRadius * aperture * renderedScale.y);
                // Inset the outline and its antialiasing within the original eye footprint.
                float outlineMask = (1.0 - smoothstep(-eyeAA, 0.0, eyeDistance)) * openVisibility;
                float eyeMask = (1.0 - smoothstep(-eyeAA, 0.0, eyeDistance + 0.90 * pixel)) * openVisibility;
                float pupilDistance = (length(eyeCoord - gaze) - 0.40 * eyeRadius) * distanceScale;
                float pupilAA = max(0.75 * fwidth(pupilDistance), 0.5 * pixel);
                float pupilMask = min(eyeMask, 1.0 - smoothstep(-pupilAA, pupilAA, pupilDistance));
                vec2 glintCentre = gaze + vec2(-0.13, 0.15) * eyeRadius;
                float glintDistance = (length(eyeCoord - glintCentre) - 0.11 * eyeRadius) * distanceScale;
                float glintAA = max(0.75 * fwidth(glintDistance), 0.5 * pixel);
                float glintMask = min(pupilMask, 1.0 - smoothstep(-glintAA, glintAA, glintDistance));
                float lidX = eyeCoord.x / eyeRadius;
                float lidCurve = -0.13 * eyeRadius * (1.0 - lidX * lidX);
                float lidDistance = max(abs(eyeCoord.y - lidCurve)
                    / sqrt(1.0 + 0.0676 * lidX * lidX) * distanceScale - 0.50 * pixel,
                    (abs(eyeCoord.x) - 0.82 * eyeRadius) * distanceScale);
                float lidAA = max(0.75 * fwidth(lidDistance), 0.5 * pixel);
                float lidMask = (1.0 - smoothstep(-lidAA, lidAA, lidDistance))
                    * (1.0 - smoothstep(0.0, 0.35, aperture));
                lidMask *= 1.0 - smoothstep(-eyeAA, 0.0,
                    (length(eyeCoord) - eyeRadius) * distanceScale);
                cursorColour = mix(cursorColour, vec3(0.0), max(outlineMask, lidMask));
                cursorColour = mix(cursorColour, vec3(1.0), eyeMask);
                cursorColour = mix(cursorColour, vec3(0.0), pupilMask);
                cursorColour = mix(cursorColour, vec3(1.0), glintMask);
                if (mouthOpen > 0.0) {
                    // Raise the mouth into the space below the closing eye.
                    float mouthTop = eyeAnchor.y - 1.08 * restingEyeRadius - pixel
                        + min(1.5 * pixel, 0.25 * restingEyeRadius) * expressionClosure;
                    float mouthSpace = mouthTop + baseHalfSize.y;
                    if (mouthSpace >= 1.5 * pixel) {
                        vec2 mouthRadius = vec2(0.32 * restingEyeRadius,
                            min(0.34 * restingEyeRadius, 0.45 * mouthSpace));
                        vec2 mouthCentre = vec2(0.0, mouthTop - 0.5 * mouthSpace);
                        mouthRadius.y *= mouthOpen;
                        float mouthDistance = (length((cursorLocal - mouthCentre)
                            / max(mouthRadius, vec2(1e-6))) - 1.0) * min(mouthRadius.x, mouthRadius.y) * distanceScale;
                        float mouthAA = max(0.75 * fwidth(mouthDistance), 0.5 * pixel);
                        float mouthMask = (1.0 - smoothstep(-mouthAA, 0.0, mouthDistance)) * mouthOpen;
                        cursorColour = mix(cursorColour, vec3(0.0), mouthMask);
                    }
                }
            }
        }

        float cursorMask = antialiasNoBlur(sdfCur) * cursorAlpha;
        outC = mix(outC, vec4(cursorColour, outC.a), cursorMask);
    }

    fragColor = outC;
}
