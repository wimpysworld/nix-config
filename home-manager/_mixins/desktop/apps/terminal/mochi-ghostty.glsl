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

// Toggle the rainbow trail without changing the cursor or landing effects.
const float TRAIL_ENABLED = 1.0;  // 1.0 = visible, 0.0 = hidden

// Toggle curved paths for the cursor and trail.
const float BEND_ENABLED = 1.0;   // 1.0 = curved, 0.0 = straight lines

// ──────────────────────────────────────────────────────────────────────────
// ANIMATION TIMING
// ──────────────────────────────────────────────────────────────────────────

// Tail catch-up time in seconds, measured from landing for jumps.
// Shorter times make the trail disappear faster.
const float TAIL_CATCHUP_TIME = 0.5;

// Width of the tail fade in path coordinates, where the full path spans 0 to 1.
const float TAIL_FADE_DURATION = 0.15;

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
const float CURSOR_CAPE = 2.0;
const float CURSOR_CAPE_HOLD_TIME = 0.140;
const float CURSOR_CAPE_RETURN_TIME = 0.400;
const float CURSOR_IDLE_HEM_TIME = 0.200;
const int LANDING_PARTICLE_COUNT = 18;
const float LANDING_PARTICLE_TIME = 1.000;
const float LANDING_FULL_DISTANCE = 40.0;
const float LANDING_SHAKE_DISTANCE = LANDING_FULL_DISTANCE * 1.25;
const float LANDING_SHAKE_TIME = 0.260;
const vec2 LANDING_SHAKE_PIXELS = vec2(1.25, -5.50);
const float LANDING_SHAKE_DEGREES = 0.15;

// ──────────────────────────────────────────────────────────────────────────
// TRAIL SIZE CONTROL
// ──────────────────────────────────────────────────────────────────────────

// Scale relative to the interpolated cursor size, using fixed positions on the full path.

// Size at the previous cursor position (t = 0.0).
const float TRAIL_SIZE_START = 0.0;

// Size at path middle (t = 0.5)
const float TRAIL_SIZE_MID = 1.2;

// Size at trail head (t = 1.0, at cursor position)
const float TRAIL_SIZE_END = 1.0;

// ──────────────────────────────────────────────────────────────────────────
// PATH BENDING: PRIMARY CURVE
// ──────────────────────────────────────────────────────────────────────────

// Base lateral offset in normalised coordinates.
const float BEND_STRENGTH = 0.12;

// Movement distance below which no bending occurs (avoids jitter on tiny moves)
const float BEND_DISTANCE_MIN = 0.05;

// Movement distance at which bending reaches full strength
const float BEND_DISTANCE_MAX = 0.30;

// ──────────────────────────────────────────────────────────────────────────
// PATH BENDING: DIRECTION CONTROL
// ──────────────────────────────────────────────────────────────────────────

// Screen-space arc direction, independent of movement direction.
// For horizontal movement: 1.0 = up, -1.0 = down.
// For vertical movement: 1.0 = right, -1.0 = left.
const float BEND_ARC_DIRECTION = 1.0;

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

// Maximum valid movement in cursor-height units, excluding the threshold itself.
const float MAX_VALID_MOVE_DISTANCE = 100.0;

// Minimum movement in cursor-height units, to filter out jitter.
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
float easeOutQuad(float t) { t = clamp(t, 0.0, 1.0); return t * (2.0 - t); }
float easeOutQuart(float t) { t = clamp(t, 0.0, 1.0); float mt = 1.0 - t; return 1.0 - mt * mt * mt * mt; }
float easeSmoothStep(float t) { t = clamp(t, 0.0, 1.0); return t * t * (3.0 - 2.0 * t); }

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

// ============================================================================
// UTILITIES
// ============================================================================

float hash(vec3 p) {
    p = fract(p * 0.1031);
    p += dot(p, p.yzx + 33.33);
    return fract((p.x + p.y) * p.z);
}

float envelope(float x, float riseStart, float riseEnd, float fallStart, float fallEnd) {
    return smoothstep(riseStart, riseEnd, x) * (1.0 - smoothstep(fallStart, fallEnd, x));
}

float getBlinkClosure(float age, float duration) {
    float phase = age / duration;
    return envelope(phase, 0.0, 0.30, 0.57, 1.0);
}

vec3 getIdleExpressionEvent(float time, float idleReady) {
    // Starts are 20 to 40 seconds apart. Only complete events after idle readiness qualify.
    float slot = floor(time / 30.0);
    float start = slot * 30.0 + 1.0 + 10.0 * hash(vec3(slot, 740.0, 0.0));
    float doze = hash(vec3(slot, 740.0, 1.0)) < 0.25 ? 1.0 : 0.0;
    return start >= idleReady ? vec3(start, mix(2.7, 4.8, doze), doze) : vec3(-100.0, 0.0, 0.0);
}

float getEyeAperture(float time, vec3 expressionEvent, vec2 landingWindow) {
    // Blink events start 2 to 10 seconds apart. An event can contain two blinks.
    float slot = floor(time / 6.0);
    float start = 0.5 + 4.0 * hash(vec3(slot, 720.0, 0.0));
    float duration = mix(0.280, 0.360, hash(vec3(slot, 720.0, 1.0)));
    bool doubleBlink = hash(vec3(slot, 720.0, 2.0)) < 0.20;
    float secondStart = duration + 0.090;
    float eventEnd = slot * 6.0 + start + (doubleBlink ? secondStart + duration : duration);
    // Skip blink events that overlap an expression or landing, including transition edges.
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
    float pulse = envelope(phase, 0.0, 0.20, 0.60, 1.0);
    pulse *= mix(0.55, 0.85, hash(vec3(slot, 730.0, 6.0)));
    return vec3(cos(angle), sin(angle), pulse);
}

// Centre positions but not sizes. Both use screen-height units, with positive Y upwards.
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

float sdfCursorCape(vec2 point, vec2 halfSize, float cape, float settle) {
    point.x *= -sign(cape);
    float radius = 2.0 * CURSOR_TOP_RADIUS * min(halfSize.x, halfSize.y);
    float root = halfSize.x - 0.25 * radius;
    float tip = halfSize.x + abs(cape);
    float span = max(tip - root, 1e-6);
    float t = clamp((point.x - root) / span, 0.0, 1.0);
    float taper = 1.0 - t;
    float reach = abs(cape) / span;
    float drop = 0.10 * radius * reach * reach * (1.0 - settle);
    // Raise the tip and straighten the curve as the cape becomes an idle flare.
    float lower = -halfSize.y - drop * t * (2.0 - t);
    float upper = lower + radius * mix(taper * taper, taper, settle);
    float lowerSlope = -2.0 * drop * taper / span;
    float upperSlope = lowerSlope - radius * mix(2.0 * taper, 1.0, settle) / span;
    float upperDistance = (point.y - upper - upperSlope * max(point.x - tip, 0.0))
        / sqrt(1.0 + upperSlope * upperSlope);
    float lowerDistance = (lower - point.y) / sqrt(1.0 + lowerSlope * lowerSlope);
    float edgeDistance = max(root - point.x, max(upperDistance, lowerDistance));
    return mix(max(point.x - tip, edgeDistance), edgeDistance, settle);
}

float sdfCursorIdleHem(vec2 point, vec2 halfSize, float extension) {
    float radius = 2.0 * CURSOR_TOP_RADIUS * min(halfSize.x, halfSize.y);
    point.x = abs(point.x);
    vec2 top = vec2(halfSize.x - 0.25 * radius, -halfSize.y + radius);
    vec2 edge = vec2(0.25 * radius + extension, -radius);
    vec2 offset = point - top;
    float upperDistance = (edge.x * offset.y - edge.y * offset.x) / max(length(edge), 1e-6);
    // Mirror both tips and keep their lower edges on the body baseline.
    return max(top.x - point.x, max(upperDistance, -halfSize.y - point.y));
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

// Derive a repeatable random seed that stays fixed throughout each movement.
float getMovementId(vec2 prev, vec2 curr, float len) {
    float t = fract(iTimeCursorChange * 10.0);
    float p = hash(vec3(prev, curr.x));
    float m = len * 10.0;
    return hash(vec3(t, p, m));
}

// Apply a screen-space curve to the straight path.
vec2 getBentPathPosition(vec2 A, vec2 B, float t, float strength) {
    vec2 pos = mix(A, B, t);
    if (strength < 0.001) return pos;

    vec2 dir = normalize(B - A + 0.0001);
    bool horizontal = abs(dir.x) > abs(dir.y);
    vec2 bendDir = horizontal ? vec2(0.0, 1.0) : vec2(1.0, 0.0);
    float offset = sin(t * PI) * strength * BEND_ARC_DIRECTION;

    return pos + bendDir * offset;
}

// Interpolate size over the full path, not just its visible remainder.
float getTrailSize(float t) {
    bool firstHalf = t < 0.5;
    float localT = easeSmoothStep(firstHalf ? t * 2.0 : (t - 0.5) * 2.0);
    return firstHalf
        ? mix(TRAIL_SIZE_START, TRAIL_SIZE_MID, localT)
        : mix(TRAIL_SIZE_MID, TRAIL_SIZE_END, localT);
}

float getTrailRadius(vec2 halfSize, vec2 aspect, float t) {
    vec2 scaledSize = halfSize / aspect;
    return max(min(scaledSize.x, scaledSize.y) * getTrailSize(t), 0.0);
}

// ============================================================================
// MAIN
// ============================================================================

// Sample the terminal, then composite the trail, landing particles and cursor in that order.
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
    vec2 movement = cur.xy - prev.xy;
    float movementLength = length(movement);
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
    bool prevGeometryValid = prev.z > 0.0 && prev.w > 0.0;
    bool moveInRange = prevGeometryValid && mL > minD && mL < maxD && timeSince >= 0.0;
    bool smallMove = smallHorizontalMove || smallVerticalMove;
    bool valid = cursorGeometryValid && moveInRange && !smallMove;
    bool hollowSinceFocus = cursorVisible && iCurrentCursorStyle == CURSORSTYLE_BLOCK_HOLLOW
        && iTimeCursorChange > iTimeFocus;
    bool jump = hollowSinceFocus && valid;
    bool smallSlide = hollowSinceFocus && moveInRange && smallMove && movementLength > minD;
    float landingStart = CURSOR_TRAVEL_TIME;
    float jumpEnd = landingStart + CURSOR_LANDING_TIME;
    // Measure origin displacement in cells, independent of font size and aspect.
    float cellDistance = valid ? length(movement / max(cur.zw, vec2(1e-6))) : 0.0;
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
        renderedCenter = getBentPathPosition(cP, cC, headProgress, strength);
        renderedHalfSize = mix(hP, hC, headProgress);
    } else if (jump && timeSince < jumpEnd) {
        headProgress = easeSmoothStep(timeSince / CURSOR_TRAVEL_TIME);
        renderedCenter = getBentPathPosition(cP, cC, headProgress, strength);
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
        float capeSettle = 0.0;
        if (smallSlide || jump) {
            float horizontalDirection = movement.x / max(movementLength, 1e-6);
            float capeLength = CURSOR_CAPE * 0.75 * 2.0 * CURSOR_TOP_RADIUS
                * min(baseHalfSize.x, baseHalfSize.y);
            if (smallSlide) {
                // Match the moving cape to the idle flare before replacing it with the symmetric hem.
                capeSettle = easeSmoothStep((timeSince - CURSOR_CAPE_HOLD_TIME) / CURSOR_CAPE_RETURN_TIME);
                cape = sign(horizontalDirection) * mix(abs(horizontalDirection) * capeLength,
                    capeLength / CURSOR_CAPE, capeSettle);
            } else {
                float phase = clamp(timeSince / CURSOR_TRAVEL_TIME, 0.0, 1.0);
                float motion = horizontalDirection * getSquashPulse(phase) * capeLength;
                cape = motion * (1.0 + 0.10 * sin(2.0 * PI * phase));
            }
        }
        sdfCur = sdfCursor(cursorLocal, baseHalfSize) * min(renderedScale.x, renderedScale.y);
        if (cape != 0.0 && (!smallSlide || capeSettle < 1.0)) {
            sdfCur = min(sdfCur, sdfCursorCape(capeLocal, baseHalfSize, cape, capeSettle) * capeDistanceScale);
        }
        if (cursorVisible) {
            float idleDelay = jump ? jumpEnd : CURSOR_CAPE_HOLD_TIME;
            float idleStart = max(iTimeCursorChange + idleDelay, iTimeFocus + CURSOR_CAPE_HOLD_TIME);
            float idleHem = smallSlide ? capeSettle : easeSmoothStep((iTime - idleStart) / CURSOR_IDLE_HEM_TIME);
            if (idleHem > 0.0) {
                float extension = idleHem * 0.75 * 2.0 * CURSOR_TOP_RADIUS * min(baseHalfSize.x, baseHalfSize.y);
                float hemDistance = sdfCursorIdleHem(capeLocal, baseHalfSize, extension);
                if (smallSlide && cape != 0.0 && capeSettle < 1.0) {
                    // Let the moving cape cover its side until the transition finishes.
                    hemDistance = max(hemDistance, -capeLocal.x * sign(cape));
                }
                sdfCur = min(sdfCur, hemDistance * capeDistanceScale);
            }
        }
    }
    // Let the trail grow behind the moving cursor before its tail catches up.
    float trailTime = timeSince - (jump ? landingStart : 0.0);
    bool visible = trailTime < TAIL_CATCHUP_TIME;

    if (TRAIL_ENABLED > 0.5 && cursorVisible && valid && visible
        && iTimeCursorChange > iTimeFocus) {
        float progress = clamp(trailTime / TAIL_CATCHUP_TIME, 0.0, 1.0);
        progress = easeOutQuart(progress);

        float tStart = clamp(progress, 0.0, headProgress), tEnd = headProgress;

        if (tStart < tEnd) {
            float minDist = 1e6, bestT = tStart;
            // A shared aspect keeps the elliptical caps identical at joins.
            // Changed cursor proportions use the radius inside both dimensions.
            vec2 aspect = max(hC, vec2(1e-6));
            vec2 point = vu / aspect;
            float previousT = tStart;
            vec2 previousPos = getBentPathPosition(cP, cC, previousT, strength) / aspect;
            float previousRadius = getTrailRadius(mix(hP, hC, previousT), aspect, previousT);

            for (int i = 1; i < PATH_SAMPLES; i++) {
                float t = mix(tStart, tEnd, float(i) / float(PATH_SAMPLES - 1));
                vec2 pathPos = getBentPathPosition(cP, cC, t, strength) / aspect;
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

            float trailAlpha = bestT;  // Opacity rises from 0 to 1 along the full path.

            // Soft fade at trail tail
            if (bestT < tStart + TAIL_FADE_DURATION) {
                trailAlpha *= smoothstep(tStart, tStart + TAIL_FADE_DURATION, bestT);
            }

            trailAlpha *= antialiasNoBlur(minDist);

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
                float expressionWeight = envelope(expressionAge, 0.0, 0.25, expressionEvent.y - 0.35, expressionEvent.y);
                float mouthOpen = 0.0;
                float expressionClosure = 0.0;
                float lidDrop = 0.0;
                float expressionGaze = 0.0;
                float startle = 0.0;
                if (expressionWeight > 0.0) {
                    if (expressionEvent.z < 0.5) {
                        mouthOpen = envelope(expressionAge, 0.35, 1.0, 1.75, 2.25);
                        expressionClosure = envelope(expressionAge, 0.40, 1.0, 1.90, 2.70);
                        expressionGaze = 0.35 * smoothstep(0.0, 0.35, expressionAge)
                            * (1.0 - smoothstep(0.45, 0.95, expressionAge));
                    } else {
                        lidDrop = 0.92 * smoothstep(0.25, 1.90, expressionAge)
                            * (1.0 - smoothstep(2.50, 2.60, expressionAge));
                        expressionGaze = -0.70 * smoothstep(0.25, 1.90, expressionAge)
                            * (1.0 - smoothstep(2.50, 2.60, expressionAge));
                        startle = envelope(expressionAge, 2.50, 2.60, 3.80, 4.40);
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
                if (prevGeometryValid && timeSince >= 0.0 && timeSince < 2.0
                    && iTimeCursorChange > iTimeFocus && movementLength > minD && movementLength < maxD) {
                    gazePulse = (smallMove ? 1.0 : easeSmoothStep(timeSince / 0.080))
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
                    float landingAperture = 1.0 - envelope(timeSince, landingStart - 0.060, landingStart,
                        jumpEnd + 0.040, jumpEnd + 0.160);
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
