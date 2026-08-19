/*
 * WINKLE - GHOSTTY CURSOR TRAIL SHADER
 *
 * Derived from Wisp at:
 * https://github.com/hced/ghostty-cursor-trails/blob/78f597cf66427bc382077e5e33f26981a86bb207/wisp-cursor.glsl
 *
 * Winkle removes Wisp's synthetic cursor and masks the trail inside Ghostty's
 * native cursor rectangle, so Ghostty controls the cursor blink.
 *
 * MIT License
 *
 * Copyright (c) 2026 H. Cederblad
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
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
// COLOR SETTINGS
// ──────────────────────────────────────────────────────────────────────────

// NOTE:
// Format for all color values: vec4(R, G, B, A)
// - R, G, B: Red/Green/Blue channels (0.0 = none, 1.0 = full)
// - A: Alpha/opacity channel (0.0 = transparent, 1.0 = opaque)
// Example: vec4(0.2, 0.6, 1.0, 0.5) = semi-transparent blue

// Base Color (used for the whole trail when USE_CUSTOM_COLORS is disabled)
// Format: vec4(R, G, B, A)
// Default: iCurrentCursorColor (matches actual cursor)
vec4 TRAIL_COLOR = iCurrentCursorColor;

// Use custom colors for start/end (interpolation between tail and head)
// When enabled: trail interpolates from TRAIL_START_COLOR (tail) to TRAIL_END_COLOR (head)
// When disabled: entire trail uses TRAIL_COLOR
const float USE_CUSTOM_COLORS = 1.0;  // 1.0 = enable, 0.0 = disable

// Color at trail tail (t = 0.0, where animation starts)
// Format: vec4(R, G, B, A) - alpha is respected and interpolated
const vec4 TRAIL_START_COLOR = vec4(1.0, 1.0, 1.0, 1.0);  // White

// Color at trail head (t = 1.0, at cursor position)
// Format: vec4(R, G, B, A) - alpha is respected and interpolated
// Default: iCurrentCursorColor (matches actual cursor, including its alpha)
vec4 TRAIL_END_COLOR = vec4(0.2, 0.6, 1.0, 0.8);  // Blue

// ──────────────────────────────────────────────────────────────────────────
// OPACITY SETTINGS
// ──────────────────────────────────────────────────────────────────────────

// Base opacity multiplier for trail (applied after color alpha interpolation)
// This multiplies the final alpha: color_alpha * TRAIL_BASE_ALPHA * fade * antialias
const float TRAIL_BASE_ALPHA = 0.80;

// Opacity of actual cursor (rendered on top of trail)
const float CURSOR_ALPHA = 0.5;

// ──────────────────────────────────────────────────────────────────────────
// RENDERING SETTINGS
// ──────────────────────────────────────────────────────────────────────────

// Maximum cursor movement distance (in cursor-width units) to consider valid
// Movements larger than this won't trigger trail rendering
const float MAX_VALID_MOVE_DISTANCE = 100.0;

// Minimum movement distance to trigger trail rendering (filters out jitter)
const float MIN_MOVE_DISTANCE = 0.01;

// Number of points sampled along the path per pixel
// Higher = smoother trail but more GPU load
// 128 is a good balance for most systems
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

// ============================================================================
// MAIN
// ============================================================================

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    #if !defined(WEB)
    fragColor = texture(iChannel0, fragCoord.xy / iResolution.xy);
    #endif

    vec2 vu = normalizeCoord(fragCoord, 1.0);
    vec2 off = vec2(-0.5, 0.5);

    vec4 cur = vec4(normalizeCoord(iCurrentCursor.xy, 1.0), normalizeCoord(iCurrentCursor.zw, 0.0));
    vec4 prev = vec4(normalizeCoord(iPreviousCursor.xy, 1.0), normalizeCoord(iPreviousCursor.zw, 0.0));

    vec2 cC = cur.xy - (cur.zw * off);
    vec2 hC = cur.zw * 0.5;
    vec2 cP = prev.xy - (prev.zw * off);
    vec2 hP = prev.zw * 0.5;

    float sdfCur = sdfRect(vu, cC, hC);
    vec2 mv = cC - cP;
    float mL = length(mv);
    float minD = cur.w * MIN_MOVE_DISTANCE;
    float maxD = cur.w * MAX_VALID_MOVE_DISTANCE;

    vec4 outC = fragColor;
    float timeSince = iTime - iTimeCursorChange;

    bool valid = (mL > minD) && (mL < maxD);
    bool visible = timeSince < (TAIL_CATCHUP_TIME + LEG_PERSISTENCE);

    if (TRAIL_ENABLED > 0.5 && valid && visible) {
        float strength = getBendStrength(mL);
        float id = getMovementId(cP, cC, mL);

        float progress = clamp(timeSince / TAIL_CATCHUP_TIME, 0.0, 1.0);
        progress = applyTailEasing(progress);

        float tStart = progress, tEnd = 1.0;

        if (tStart < tEnd) {
            float minDist = 1e6, bestT = 0.0;

            for (int i = 0; i < PATH_SAMPLES; i++) {
                float t = float(i) / float(PATH_SAMPLES - 1);
                if (t < tStart || t > tEnd) continue;

                vec2 pathPos = getBentPathPosition(cP, cC, t, strength, id);
                vec2 pathSize = mix(hP, hC, t) * getTrailSize(t);
                float d = sdfRect(vu, pathPos, pathSize);

                if (d < minDist) { minDist = d; bestT = t; }
            }

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

            // Color selection with alpha preservation
            vec4 trailColor;
            if (USE_CUSTOM_COLORS > 0.5) {
                // Interpolate both RGB and A from start to end color
                // bestT: 0.0 = trail tail, 1.0 = cursor position
                trailColor = mix(TRAIL_START_COLOR, TRAIL_END_COLOR, bestT);
                // Multiply interpolated color alpha by trail alpha calculations
                trailColor.a *= trailAlpha;
            } else {
                // Use single color: multiply its alpha by trail alpha calculations
                trailColor = TRAIL_COLOR;
                trailColor.a *= trailAlpha;
            }

            if (trailColor.a > 0.001) {
                outC = mix(outC, vec4(trailColor.rgb, outC.a), trailColor.a);
            }
        }
    }

    fragColor = outC;
}
