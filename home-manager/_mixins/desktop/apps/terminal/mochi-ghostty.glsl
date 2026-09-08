/*
Mochi is the one-eyed block cursor, blinking innocently and flaring a tiny
cloak as they scurry along a line. Leap between lines and they fart rainbows,
kick-up sparkles and stars, and stick big landings hard enough to shake the
whole terminal.
*/

// Configuration.

// Toggle the rainbow trail without changing Mochi or the landing effects.
const bool TRAIL_ENABLED = true;

// Trail catch-up time in seconds, measured from landing for jumps.
// Shorter times make the trail disappear faster.
const float TRAIL_CATCHUP_TIME = 0.5;

// Width of the trail fade in path coordinates, where the full path spans 0 to 1.
const float TRAIL_FADE_WIDTH = 0.15;

// Timings are in seconds. Landing scales are multiples of Mochi's size.
const float MOCHI_TRAVEL_TIME = 0.140;
#ifndef MOCHI_KEY_REPEAT_RATE
#define MOCHI_KEY_REPEAT_RATE 30.0
#endif
const float MOCHI_SMALL_MOVE_TIME = 1.0 / MOCHI_KEY_REPEAT_RATE;
const float MOCHI_BOB_PERIOD = 1.400;
const float MOCHI_BOB_COMPRESSION = 0.14;
const float MOCHI_BOB_HOLD_TIME = 0.140;
const float MOCHI_BOB_RETURN_TIME = 0.400;
const float MOCHI_LANDING_COMPRESSION_TIME = 0.025;
const vec2 MOCHI_LANDING_HOLD_TIME_RANGE = vec2(0.040, 0.080);
const vec2 MOCHI_LANDING_RECOVERY_TIME_RANGE = vec2(0.120, 0.180);
const vec2 MOCHI_LANDING_MIN_SCALE = vec2(1.30, 0.60);
const vec2 MOCHI_LANDING_MAX_SCALE = vec2(1.65, 0.40);
const float MOCHI_TOP_RADIUS_FRACTION = 0.23;
const float MOCHI_CAPE_LENGTH_MULTIPLIER = 2.0;
const float CAPE_ROOT_INSET_RADIUS_FRACTION = 0.25;
const float MOCHI_CAPE_HOLD_TIME = 0.140;
const float MOCHI_CAPE_RETURN_TIME = 0.400;
const float MOCHI_IDLE_HEM_TIME = 0.200;
const int LANDING_PARTICLE_COUNT = 18;
const float LANDING_PARTICLE_TIME = 1.000;
const float LANDING_PARTICLE_SPREAD_BASE = 0.4;
const float LANDING_PARTICLE_SPREAD_GAIN = 2.7;
const float LANDING_PARTICLE_APEX_PROGRESS_MIN = 0.34;
const float LANDING_FULL_DISTANCE = 40.0;
const float LANDING_MIN_DISTANCE = LANDING_FULL_DISTANCE / 12.0;
const float LANDING_BLINK_LEAD_TIME = 0.060;
const float LANDING_SHAKE_DISTANCE = LANDING_FULL_DISTANCE * 1.25;
const float LANDING_SHAKE_TIME = 0.260;
const vec2 LANDING_SHAKE_PIXELS = vec2(1.25, -5.50);
const float LANDING_SHAKE_DEGREES = 0.15;

const float YAWN_DURATION = 2.7;
const float DOZE_DURATION = 4.8;
const float EXPRESSION_FADE_TIME = 0.35;
const float DOZE_CLOSE_START = 0.25;
const float DOZE_CLOSE_END = 1.90;
const float DOZE_WAKE_START = 2.50;
const float DOZE_WAKE_END = 2.60;
const float DOZE_STARTLE_HOLD_END = 3.80;
const float DOZE_STARTLE_END = 4.40;
const float DOZE_WAKE_BLINK_FIRST = 3.05;
const float DOZE_WAKE_BLINK_SECOND = 3.36;

// Scale relative to the interpolated cursor size, using fixed positions on the full path.

// Size at the previous cursor position (t = 0.0).
const float TRAIL_SIZE_START = 0.0;

// Size at path middle (t = 0.5)
const float TRAIL_SIZE_MID = 1.2;

// Size at trail head (t = 1.0, at cursor position)
const float TRAIL_SIZE_END = 1.0;

// Base lateral offset in normalised coordinates.
const float CURVE_STRENGTH = 0.12;

// Movement distance below which the path stays straight to avoid jitter on tiny moves.
const float CURVE_DISTANCE_MIN = 0.05;

// Movement distance at which the curve reaches full strength.
const float CURVE_DISTANCE_MAX = 0.30;

// Screen-space curve direction, independent of movement direction.
// For horizontal movement: 1.0 = up, -1.0 = down.
// For vertical movement: 1.0 = right, -1.0 = left.
const float CURVE_DIRECTION = 1.0;

// Catppuccin Mocha RGB values from lib/catppuccin-palette.json.
// From Mochi to the far end of the trail: Red, Peach, Yellow, Green, Sapphire, Blue, Mauve.
const vec3 TRAIL_COLOURS[7] = vec3[7](
    vec3(243.0, 139.0, 168.0) / 255.0,
    vec3(250.0, 179.0, 135.0) / 255.0,
    vec3(249.0, 226.0, 175.0) / 255.0,
    vec3(166.0, 227.0, 161.0) / 255.0,
    vec3(116.0, 199.0, 236.0) / 255.0,
    vec3(137.0, 180.0, 250.0) / 255.0,
    vec3(203.0, 166.0, 247.0) / 255.0
);

// Base opacity multiplier for the trail.
const float TRAIL_BASE_ALPHA = 0.80;

// Each half of Mochi's fade lasts this many seconds.
const float MOCHI_FADE_HALF_PERIOD = 0.75;
const float MOCHI_FADE_HOLD_TIME = 0.500;

// Maximum valid movement in cursor-height units, excluding the threshold itself.
const float MAX_VALID_MOVE_DISTANCE = 100.0;

// Minimum movement in cursor-height units, to filter out jitter.
const float MIN_MOVE_DISTANCE = 0.01;

// Allow small coordinate differences when detecting one-cell horizontal or vertical moves.
const float SMALL_MOVE_TOLERANCE = 0.05;

// Maximum number of points joined by rounded segments over the full path.
// Higher values follow the curve more closely but add GPU work.
const int PATH_SAMPLES = 32;

const float AA_DERIVATIVE_SCALE = 1.5;
const float AA_FALLBACK_WIDTH = 0.002;
const float AA_FALLBACK_BELOW = 0.001;

const float PI = 3.14159265359;

float easeLinear(float t) { return clamp(t, 0.0, 1.0); }
float easeOutQuad(float t) { t = clamp(t, 0.0, 1.0); return t * (2.0 - t); }
float easeOutQuart(float t) { t = clamp(t, 0.0, 1.0); float mt = 1.0 - t; return 1.0 - mt * mt * mt * mt; }
float easeSmoothStep(float t) { t = clamp(t, 0.0, 1.0); return t * t * (3.0 - 2.0 * t); }

float getMochiAlpha(float elapsed) {
    float phase = mod(elapsed, 2.0 * MOCHI_FADE_HALF_PERIOD);
    float t = mod(phase, MOCHI_FADE_HALF_PERIOD) / MOCHI_FADE_HALF_PERIOD;
    return phase < MOCHI_FADE_HALF_PERIOD
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

struct ExpressionEvent {
    bool valid;
    float start;
    float duration;
    bool isDoze;
};

struct LandingWindow {
    bool valid;
    float start;
    float end;
};

ExpressionEvent getIdleExpressionEvent(float time, float idleReadyTime) {
    // Starts are 20 to 40 seconds apart. Only complete events after idle readiness qualify.
    float slot = floor(time / 30.0);
    float start = slot * 30.0 + 1.0 + 10.0 * hash(vec3(slot, 740.0, 0.0));
    bool isDoze = hash(vec3(slot, 740.0, 1.0)) < 0.25;
    return ExpressionEvent(start >= idleReadyTime, start, mix(YAWN_DURATION, DOZE_DURATION, isDoze ? 1.0 : 0.0), isDoze);
}

float getEyeAperture(float time, ExpressionEvent expressionEvent, LandingWindow landingWindow) {
    // Blink events start 2 to 10 seconds apart. An event can contain two blinks.
    float slot = floor(time / 6.0);
    float slotStartOffset = 0.5 + 4.0 * hash(vec3(slot, 720.0, 0.0));
    float duration = mix(0.280, 0.360, hash(vec3(slot, 720.0, 1.0)));
    bool doubleBlink = hash(vec3(slot, 720.0, 2.0)) < 0.20;
    float secondStart = duration + 0.090;
    float eventEnd = slot * 6.0 + slotStartOffset + (doubleBlink ? secondStart + duration : duration);
    // Skip blink events that overlap an expression or landing, including transition edges.
    if (expressionEvent.valid && slot * 6.0 + slotStartOffset < expressionEvent.start + expressionEvent.duration && eventEnd > expressionEvent.start) return 1.0;
    if (landingWindow.valid && slot * 6.0 + slotStartOffset < landingWindow.end && eventEnd > landingWindow.start) return 1.0;
    float age = mod(time, 6.0) - slotStartOffset;
    float closure = getBlinkClosure(age, duration);
    if (doubleBlink) closure = max(closure, getBlinkClosure(age - secondStart, duration));
    return 1.0 - closure;
}

vec3 getIdleGaze(float time, float idleReadyTime) {
    // Jitter within fixed slots keeps event starts 5 to 12 seconds apart.
    float slot = floor(time / 8.5);
    float start = slot * 8.5 + 0.5 + 3.5 * hash(vec3(slot, 730.0, 0.0));
    float duration = mix(1.4, 2.2, hash(vec3(slot, 730.0, 1.0)));
    // Skip events that began before idle readiness instead of entering them partway through.
    if (start < idleReadyTime || time < start || time >= start + duration) return vec3(0.0);

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
vec2 normalizeCoord(vec2 v, bool isPosition) {
    return (v * 2.0 - (isPosition ? iResolution.xy : vec2(0.0))) / iResolution.y;
}

float edgeWidth(float d, float pixel) {
    return max(0.75 * fwidth(d), 0.5 * pixel);
}

float aaWidth(float derivative) {
    float w = derivative * AA_DERIVATIVE_SCALE;
    if (w < AA_FALLBACK_BELOW) w = AA_FALLBACK_WIDTH;
    return w;
}

float antialiasNoBlur(float d) {
    float w = aaWidth(fwidth(d));
    return 1.0 - smoothstep(-w, w, d);
}

float boxDistance(vec2 d) {
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

float rectangleDistance(vec2 p, vec2 c, vec2 h) {
    vec2 d = abs(p - c) - h;
    return boxDistance(d);
}

float mochiCornerRadius(vec2 halfSize) {
    return 2.0 * MOCHI_TOP_RADIUS_FRACTION * min(halfSize.x, halfSize.y);
}

float idleFlareLength(float scale, vec2 halfSize) {
    return scale * 0.75 * 2.0 * MOCHI_TOP_RADIUS_FRACTION * min(halfSize.x, halfSize.y);
}

float mochiBodyDistance(vec2 point, vec2 halfSize) {
    float radius = point.y > 0.0 ? mochiCornerRadius(halfSize) : 0.0;
    vec2 distance = abs(point) - halfSize + radius;
    return boxDistance(distance) - radius;
}

float mochiCapeDistance(vec2 point, vec2 halfSize, float signedCapeLength, float settle) {
    // Mirror the sample so one profile draws the cape opposite either horizontal movement direction.
    point.x *= -sign(signedCapeLength);
    float radius = mochiCornerRadius(halfSize);
    float root = halfSize.x - CAPE_ROOT_INSET_RADIUS_FRACTION * radius;
    float tip = halfSize.x + abs(signedCapeLength);
    float span = max(tip - root, 1e-6);
    float t = clamp((point.x - root) / span, 0.0, 1.0);
    float taper = 1.0 - t;
    float reach = abs(signedCapeLength) / span;
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
    float distance = mix(max(point.x - tip, edgeDistance), edgeDistance, settle);
    // Bound the slope-normalised distance so antialiasing cannot extend above Mochi.
    return max(distance, point.y - halfSize.y);
}

float mochiIdleHemDistance(vec2 point, vec2 halfSize, float extension) {
    float radius = mochiCornerRadius(halfSize);
    point.x = abs(point.x);
    vec2 top = vec2(halfSize.x - CAPE_ROOT_INSET_RADIUS_FRACTION * radius, -halfSize.y + radius);
    vec2 edge = vec2(CAPE_ROOT_INSET_RADIUS_FRACTION * radius + extension, -radius);
    vec2 offset = point - top;
    float upperDistance = (edge.x * offset.y - edge.y * offset.x) / max(length(edge), 1e-6);
    // Mirror both tips and keep their lower edges on the body baseline.
    return max(top.x - point.x, max(upperDistance, -halfSize.y - point.y));
}

// Return the tapered capsule distance, closest position and radial vector.
// Cursor-scaled coordinates give all segments the same elliptical aspect.
vec4 trailSegmentDistance(vec2 p, vec2 a, vec2 b, float ra, float rb) {
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
        // The taper shifts the closest point towards the wider end, beyond the perpendicular projection onto the segment.
        u = clamp((along + radiusChange * across / sideLength) / segmentLength, 0.0, 1.0);
    }

    vec2 radial = offset - segment * u;
    return vec4(length(radial) - mix(ra, rb, u), u, radial);
}

float getCurveStrength(float L) {
    return CURVE_STRENGTH * smoothstep(CURVE_DISTANCE_MIN, CURVE_DISTANCE_MAX, L);
}

// Derive a repeatable random seed that stays fixed throughout each movement.
float getMovementSeed(vec2 prev, vec2 curr, float len) {
    float t = fract(iTimeCursorChange * 10.0);
    float p = hash(vec3(prev, curr.x));
    float m = len * 10.0;
    return hash(vec3(t, p, m));
}

// Apply a screen-space curve to the straight path.
vec2 getCurvedPathPosition(vec2 A, vec2 B, float t, float strength) {
    vec2 pos = mix(A, B, t);
    if (strength < 0.001) return pos;

    vec2 dir = normalize(B - A + 0.0001);
    bool horizontal = abs(dir.x) > abs(dir.y);
    vec2 curveDirection = horizontal ? vec2(0.0, 1.0) : vec2(1.0, 0.0);
    float offset = sin(t * PI) * strength * CURVE_DIRECTION;

    return pos + curveDirection * offset;
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

// Mochi and trail rendering.

struct MochiBox {
    vec2 centre;
    vec2 halfSize;
};

struct MochiPath {
    MochiBox previous;
    MochiBox current;
    float curveStrength;
};

struct MoveState {
    vec4 currentRect;
    vec4 previousRect;
    vec2 centreDelta;
    float centreDistance;
    vec2 originDelta;
    float originDistance;
    float minDistance;
    float maxDistance;
    bool mochiGeometryValid;
    bool mochiVisible;
    bool prevGeometryValid;
    bool moveInRange;
    bool movedSinceFocus;
    bool originBeyondMinDistance;
    bool smallMove;
    bool largeMoveValid;
    bool hollowSinceFocus;
    bool jump;
    bool smallSlide;
    float timeSince;
    float landingStart;
    float jumpEnd;
    float movementEnd;
    float cellDistance;
    float landingIntensity;
    float seed;
};

struct RenderedMochi {
    vec2 centre;
    vec2 halfSize;
    vec2 scale;
    vec2 baseHalfSize;
    vec2 bodyLocal;
    vec2 capeLocal;
    float capeDistanceScale;
    float headProgress;
};

struct FragmentState {
    vec2 normalisedCoord;
    vec2 normalisedCoordDx;
    vec2 normalisedCoordDy;
    float pixel;
    float mochiOutlineDistance;
};

vec2 landingShakeCoord(vec2 fragCoord, MoveState move, out vec2 sampleCoord) {
    vec2 renderCoord = fragCoord;
    sampleCoord = fragCoord;
    if (move.jump && move.cellDistance > LANDING_SHAKE_DISTANCE
        && move.timeSince > move.landingStart && move.timeSince < move.landingStart + LANDING_SHAKE_TIME) {
        float progress = (move.timeSince - move.landingStart) / LANDING_SHAKE_TIME;
        float intensity = smoothstep(LANDING_SHAKE_DISTANCE, LANDING_SHAKE_DISTANCE * 1.5, move.cellDistance);
        float pulse = intensity * getLandingShakePulse(progress);
        // Inverse sampling moves the screen down first, then through one small rebound.
        renderCoord -= LANDING_SHAKE_PIXELS * pulse;
        float horizontalDirection = (move.currentRect.x - move.previousRect.x) / max(move.currentRect.z, 1e-6) / move.cellDistance;
        float angle = radians(LANDING_SHAKE_DEGREES) * horizontalDirection * pulse;
        float rotationCos = cos(angle);
        float rotationSin = sin(angle);
        vec2 pivot = iResolution.xy * 0.5;
        // Anticlockwise source sampling makes rightward jumps rotate the screen clockwise.
        renderCoord = pivot + mat2(rotationCos, rotationSin, -rotationSin, rotationCos) * (renderCoord - pivot);
        // Clamp the source sample to texel centres without clipping procedural effects.
        sampleCoord = clamp(renderCoord, vec2(0.5), iResolution.xy - vec2(0.5));
    }
    return renderCoord;
}

vec4 compositeTrail(vec4 outC, MochiPath path, MoveState move, FragmentState fragment, float headProgress) {
    // Let the trail grow behind Mochi before its far end catches up.
    float trailTime = move.timeSince - (move.jump ? move.landingStart : 0.0);
    bool visible = trailTime < TRAIL_CATCHUP_TIME;

    if (TRAIL_ENABLED && move.mochiVisible && move.largeMoveValid && visible
        && move.movedSinceFocus) {
        float progress = clamp(trailTime / TRAIL_CATCHUP_TIME, 0.0, 1.0);
        progress = easeOutQuart(progress);

        float tStart = clamp(progress, 0.0, headProgress), tEnd = headProgress;

        // Bound every interpolated radius, including changes in cursor proportions.
        vec2 aspect = max(path.current.halfSize, vec2(1e-6));
        float distanceScale = min(aspect.x, aspect.y);
        vec2 maxHalfSize = max(mix(path.previous.halfSize, path.current.halfSize, tStart), mix(path.previous.halfSize, path.current.halfSize, tEnd));
        vec2 maxScaledSize = maxHalfSize / aspect;
        float maxTrailSize = max(0.0, max(TRAIL_SIZE_START, max(TRAIL_SIZE_MID, TRAIL_SIZE_END)));
        float maxRadius = min(maxScaledSize.x, maxScaledSize.y) * maxTrailSize;
        // Bound the analytic AA in scaled space, including its fixed-width fallback.
        float aaSupport = max(AA_DERIVATIVE_SCALE * (length(fragment.normalisedCoordDx / aspect) + length(fragment.normalisedCoordDy / aspect)),
            AA_FALLBACK_WIDTH / distanceScale);
        // Expand the straight-path corridor by the curve offset, radius and antialiasing width to reject pixels before the segment loop.
        float corridorRadius = abs(path.curveStrength * CURVE_DIRECTION)
            + max(aspect.x, aspect.y) * (maxRadius + aaSupport);
        vec2 chordStart = mix(path.previous.centre, path.current.centre, tStart), chordEnd = mix(path.previous.centre, path.current.centre, tEnd);
        vec2 chord = chordEnd - chordStart;
        float chordLengthSquared = dot(chord, chord);
        float chordT = chordLengthSquared > 0.0
            ? clamp(dot(fragment.normalisedCoord - chordStart, chord) / chordLengthSquared, 0.0, 1.0) : 0.0;
        vec2 corridorOffset = fragment.normalisedCoord - mix(chordStart, chordEnd, chordT);
        bool inCorridor = dot(corridorOffset, corridorOffset) <= corridorRadius * corridorRadius;

        if (tStart < tEnd && inCorridor) {
            int segments = max(int(ceil(float(PATH_SAMPLES - 1) * (tEnd - tStart))), 4);
            float minDist = 1e6, bestT = tStart;
            vec2 bestRadial = vec2(0.0);
            // A shared aspect keeps the elliptical caps identical at joins.
            // Changed cursor proportions use the radius inside both dimensions.
            vec2 point = fragment.normalisedCoord / aspect;
            float previousT = tStart;
            vec2 previousPos = getCurvedPathPosition(path.previous.centre, path.current.centre, previousT, path.curveStrength) / aspect;
            float previousRadius = getTrailRadius(mix(path.previous.halfSize, path.current.halfSize, previousT), aspect, previousT);

            for (int i = 1; i <= segments; i++) {
                float t = mix(tStart, tEnd, float(i) / float(segments));
                vec2 pathPos = getCurvedPathPosition(path.previous.centre, path.current.centre, t, path.curveStrength) / aspect;
                float radius = getTrailRadius(mix(path.previous.halfSize, path.current.halfSize, t), aspect, t);
                vec4 segment = trailSegmentDistance(point, previousPos, pathPos, previousRadius, radius);

                if (segment.x < minDist) {
                    minDist = segment.x;
                    bestT = mix(previousT, t, segment.y);
                    bestRadial = segment.zw;
                }
                previousT = t;
                previousPos = pathPos;
                previousRadius = radius;
            }
            minDist *= distanceScale;

            float trailAlpha = bestT;  // Opacity rises from 0 to 1 along the full path.

            // Fade the far end of the trail.
            trailAlpha *= smoothstep(tStart, tStart + TRAIL_FADE_WIDTH, bestT);

            // At the optimal capsule position, the taper terms cancel in the spatial gradient.
            float radialLength = length(bestRadial);
            vec2 normal = radialLength > 0.0 ? bestRadial / radialLength : vec2(0.0);
            vec2 gradient = normal / aspect * distanceScale;
            float trailAA = aaWidth(abs(dot(gradient, fragment.normalisedCoordDx)) + abs(dot(gradient, fragment.normalisedCoordDy)));
            trailAlpha *= 1.0 - smoothstep(-trailAA, trailAA, minDist);

            trailAlpha *= TRAIL_BASE_ALPHA;
            trailAlpha *= step(0.0, fragment.mochiOutlineDistance);

            // Fit all seven bands to the remaining path as the trail catches up.
            float colourPosition = clamp((tEnd - bestT) / (tEnd - tStart), 0.0, 1.0);
            int colourBand = min(int(floor(colourPosition * 7.0)), 6);
            vec4 trailColor = vec4(TRAIL_COLOURS[colourBand], mix(1.0, 0.8, bestT) * trailAlpha);

            if (trailColor.a > 0.001) {
                outC = mix(outC, vec4(trailColor.rgb, outC.a), trailColor.a);
            }
        }
    }

    return outC;
}

vec4 compositeLandingParticles(vec4 outC, MochiBox current, MoveState move, FragmentState fragment) {
    float particleAge = move.timeSince - move.landingStart;
    if (move.jump && particleAge >= 0.0 && particleAge < LANDING_PARTICLE_TIME) {
        float intensity = move.landingIntensity;
        int particleCount = int(floor(mix(4.0, float(LANDING_PARTICLE_COUNT), intensity) + 0.5));
        int starCount = int(floor(4.0 * intensity + 0.5));
        float horizontalSpread = mix(0.25, 1.0, intensity);
        vec2 origin = current.centre - vec2(0.0, current.halfSize.y);
        vec2 offset = fragment.normalisedCoord - origin;
        // Star tips and antialiasing extend at most (2.6 * 2.30 + sqrt(10)) pixels, below this padding.
        vec2 padding = vec2(10.0 * fragment.pixel);
        // Horizontal reach is the spread base plus its gain: 0.4 + 2.7 = 3.1 cursor widths.
        // At the minimum apex, r = 1 / 0.34 gives a fall of r * r - 2 * r, approximately 2.768166 heights.
        // The 2.8-height fall bound is conservative. The rise peaks at 1.0 height. Recheck these bounds when tuning particle motion.
        if (all(greaterThan(offset, -move.currentRect.zw * vec2(3.1, 2.8) - padding))
            && all(lessThan(offset, move.currentRect.zw * vec2(3.1, 1.0) + padding))) {
            for (int i = 0; i < LANDING_PARTICLE_COUNT; i++) {
                if (i >= particleCount) break;
                float a = hash(vec3(move.seed, float(i), 410.0));
                float b = hash(vec3(move.seed, float(i), 411.0));
                float c = hash(vec3(move.seed, float(i), 412.0));
                float lifetime = mix(0.700, LANDING_PARTICLE_TIME, a);
                if (particleAge >= lifetime) continue;

                float strand = 2.0 * float(i) / float(particleCount - 1) - 1.0;
                float progress = particleAge / lifetime;
                float apexProgress = mix(LANDING_PARTICLE_APEX_PROGRESS_MIN, 0.38, c);
                float apexRelativeProgress = progress / apexProgress;
                // Positive Y rises from the fixed lower edge, then gravity pulls down.
                vec2 position = origin + move.currentRect.zw * vec2(
                    strand * (LANDING_PARTICLE_SPREAD_BASE + LANDING_PARTICLE_SPREAD_GAIN * easeOutQuad(progress)) * horizontalSpread,
                    mix(0.5, 1.0, b) * (2.0 * apexRelativeProgress - apexRelativeProgress * apexRelativeProgress)
                );
                float radius = clamp(min(move.currentRect.z, move.currentRect.w) * mix(0.075, 0.16, c),
                    0.80 * fragment.pixel, 2.30 * fragment.pixel);
                vec2 delta = abs(fragment.normalisedCoord - position);
                float distance = length(delta) - radius;
                if (i % 5 == 0 && i / 5 < starCount) {
                    // Two narrow diamonds form four points with concave sides.
                    distance = (min(delta.x + 3.0 * delta.y, 3.0 * delta.x + delta.y)
                        - 2.6 * radius) / sqrt(10.0);
                }
                float alpha = 1.0 - smoothstep(-fragment.pixel, fragment.pixel, distance);
                alpha *= smoothstep(0.0, 0.018, particleAge)
                    * (1.0 - smoothstep(0.58, 1.0, progress));
                float sparkle = pow(0.5 + 0.5 * sin(particleAge * 24.0 + c * 2.0 * PI), 8.0);
                alpha *= mix(0.86, 0.98, b) * (0.86 + 0.14 * sparkle);
                alpha *= smoothstep(0.0, fragment.pixel, fragment.mochiOutlineDistance);
                // Deepen the gold derived from Catppuccin Yellow and Peach.
                vec3 colour = mix(TRAIL_COLOURS[2], TRAIL_COLOURS[1], a * 0.35)
                    * vec3(1.0, 0.95, 0.55);
                float core = 1.0 - smoothstep(0.15 * radius, 0.85 * radius, length(delta));
                colour = mix(colour, vec3(1.0, 0.96, 0.72), core * (0.65 + 0.35 * sparkle));
                outC = mix(outC, vec4(colour, outC.a), alpha);
            }
        }
    }

    return outC;
}

float mochiDistance(RenderedMochi rendered, MoveState move, vec2 normalisedCoord) {
    float distance = rectangleDistance(normalisedCoord, rendered.centre, rendered.halfSize);
    if (move.mochiGeometryValid && iCurrentCursorStyle == CURSORSTYLE_BLOCK_HOLLOW) {
        float signedCapeLength = 0.0;
        float capeSettle = 0.0;
        if (move.smallSlide || move.jump) {
            float horizontalDirection = move.originDelta.x / max(move.originDistance, 1e-6);
            float capeLength = idleFlareLength(MOCHI_CAPE_LENGTH_MULTIPLIER, rendered.baseHalfSize);
            if (move.smallSlide) {
                // Match the moving cape to the idle flare before replacing it with the symmetric hem.
                capeSettle = easeSmoothStep((move.timeSince - MOCHI_CAPE_HOLD_TIME) / MOCHI_CAPE_RETURN_TIME);
                signedCapeLength = sign(horizontalDirection) * mix(abs(horizontalDirection) * capeLength,
                    capeLength / MOCHI_CAPE_LENGTH_MULTIPLIER, capeSettle);
            } else {
                float phase = clamp(move.timeSince / MOCHI_TRAVEL_TIME, 0.0, 1.0);
                float motion = horizontalDirection * getSquashPulse(phase) * capeLength;
                signedCapeLength = motion * (1.0 + 0.10 * sin(2.0 * PI * phase));
            }
        }
        distance = mochiBodyDistance(rendered.bodyLocal, rendered.baseHalfSize) * min(rendered.scale.x, rendered.scale.y);
        if (signedCapeLength != 0.0 && (!move.smallSlide || capeSettle < 1.0)) {
            distance = min(distance, mochiCapeDistance(rendered.capeLocal, rendered.baseHalfSize, signedCapeLength, capeSettle) * rendered.capeDistanceScale);
        }
        if (move.mochiVisible) {
            float hemDelay = move.jump ? move.jumpEnd : MOCHI_CAPE_HOLD_TIME;
            float hemStart = max(iTimeCursorChange + hemDelay, iTimeFocus + MOCHI_CAPE_HOLD_TIME);
            // Small slides use the cape transition, independent of slide completion and the fade hold.
            float idleHem = move.smallSlide ? capeSettle : easeSmoothStep((iTime - hemStart) / MOCHI_IDLE_HEM_TIME);
            if (idleHem > 0.0) {
                float extension = idleFlareLength(idleHem, rendered.baseHalfSize);
                float hemDistance = mochiIdleHemDistance(rendered.capeLocal, rendered.baseHalfSize, extension);
                if (move.smallSlide && signedCapeLength != 0.0 && capeSettle < 1.0) {
                    // Let the moving cape cover its side until the transition finishes.
                    hemDistance = max(hemDistance, -rendered.capeLocal.x * sign(signedCapeLength));
                }
                distance = min(distance, hemDistance * rendered.capeDistanceScale);
            }
        }
    }

    return distance;
}

vec3 drawFace(vec3 mochiColour, RenderedMochi rendered, MoveState move, float pixel) {
    float eyeRadius = 0.72 * min(rendered.baseHalfSize.x, rendered.baseHalfSize.y);
    // Keep Mochi plain at subpixel sizes when the pupil cannot remain clear.
    if (eyeRadius >= 2.0 * pixel) {
        vec2 eyeAnchor = vec2(0.0, min(0.12 * rendered.baseHalfSize.y + pixel, rendered.baseHalfSize.y - eyeRadius));
        float time = max(iTime, 0.0);
        // Idle expressions and gaze start from the latest move or focus, not animation completion.
        float lastActivityTime = max(iTimeCursorChange, iTimeFocus);
        ExpressionEvent expressionEvent = getIdleExpressionEvent(time, lastActivityTime + 10.0);
        float expressionAge = time - expressionEvent.start;
        float expressionWeight = expressionEvent.valid
            ? envelope(expressionAge, 0.0, 0.25, expressionEvent.duration - EXPRESSION_FADE_TIME, expressionEvent.duration) : 0.0;
        float mouthOpen = 0.0;
        float expressionClosure = 0.0;
        float lidDrop = 0.0;
        float expressionGaze = 0.0;
        float startle = 0.0;
        if (expressionWeight > 0.0) {
            if (!expressionEvent.isDoze) {
                mouthOpen = envelope(expressionAge, 0.35, 1.0, 1.75, 2.25);
                expressionClosure = envelope(expressionAge, 0.40, 1.0, 1.90, YAWN_DURATION);
                expressionGaze = 0.35 * smoothstep(0.0, 0.35, expressionAge)
                    * (1.0 - smoothstep(0.45, 0.95, expressionAge));
            } else {
                lidDrop = 0.92 * smoothstep(DOZE_CLOSE_START, DOZE_CLOSE_END, expressionAge)
                    * (1.0 - smoothstep(DOZE_WAKE_START, DOZE_WAKE_END, expressionAge));
                expressionGaze = -0.70 * smoothstep(DOZE_CLOSE_START, DOZE_CLOSE_END, expressionAge)
                    * (1.0 - smoothstep(DOZE_WAKE_START, DOZE_WAKE_END, expressionAge));
                startle = envelope(expressionAge, DOZE_WAKE_START, DOZE_WAKE_END, DOZE_STARTLE_HOLD_END, DOZE_STARTLE_END);
                expressionClosure = max(getBlinkClosure(expressionAge - DOZE_WAKE_BLINK_FIRST, 0.220),
                    getBlinkClosure(expressionAge - DOZE_WAKE_BLINK_SECOND, 0.220));
            }
        }
        float restingEyeRadius = eyeRadius;
        eyeRadius = mix(eyeRadius, min(1.15 * eyeRadius,
            min(rendered.baseHalfSize.x, rendered.baseHalfSize.y - eyeAnchor.y)), startle);
        vec2 eyeCoord = rendered.bodyLocal - eyeAnchor;
        vec3 idleGaze = getIdleGaze(time, lastActivityTime + 2.0);
        vec2 gazeDirection = idleGaze.xy;
        float gazePulse = idleGaze.z;
        if (move.prevGeometryValid && move.timeSince >= 0.0 && move.timeSince < 2.0
            && move.movedSinceFocus && move.originBeyondMinDistance && move.originDistance < move.maxDistance) {
            gazePulse = (move.smallMove ? 1.0 : easeSmoothStep(move.timeSince / 0.080))
                * (1.0 - easeSmoothStep((move.timeSince - MOCHI_TRAVEL_TIME) / 1.200));
            gazeDirection = move.originDelta / move.originDistance;
        }
        // Blend gaze vectors before separating direction and strength so opposite looks pass smoothly through the centre.
        vec2 blendedGaze = mix(gazeDirection * gazePulse, vec2(0.0, expressionGaze), expressionWeight);
        gazePulse = length(blendedGaze);
        gazeDirection = gazePulse > 0.0 ? blendedGaze / gazePulse : vec2(0.0);
        vec2 gaze = gazeDirection * (0.20 * eyeRadius * gazePulse);
        vec2 eyeMargin = rendered.baseHalfSize - vec2(eyeRadius);
        vec2 eyeShift = clamp(gazeDirection * (0.08 * eyeRadius),
            -eyeMargin - eyeAnchor, eyeMargin - eyeAnchor);
        eyeCoord -= eyeShift * gazePulse;

        float landingHold = mix(0.080, 0.250, move.landingIntensity);
        float landingReopen = move.landingStart + landingHold;
        float landingBlinkEnd = landingReopen + 0.120;
        LandingWindow landingWindow = LandingWindow(move.jump,
            iTimeCursorChange + (move.landingStart - LANDING_BLINK_LEAD_TIME), iTimeCursorChange + landingBlinkEnd);
        float aperture = getEyeAperture(time, expressionEvent, landingWindow) * (1.0 - expressionClosure);
        if (move.jump) {
            float landingAperture = 1.0 - envelope(move.timeSince, move.landingStart - LANDING_BLINK_LEAD_TIME, move.landingStart,
                landingReopen, landingBlinkEnd);
            aperture = min(aperture, landingAperture);
        }
        float distanceScale = min(rendered.scale.x, rendered.scale.y);
        float eyeDistance = max(length(eyeCoord) - eyeRadius,
            abs(eyeCoord.y) - eyeRadius * aperture) * distanceScale;
        // Positive Y points up. Lower only the upper eyelid during the doze.
        eyeDistance = max(eyeDistance, (eyeCoord.y - eyeRadius * (1.0 - 2.0 * lidDrop)) * distanceScale);
        float eyeAA = edgeWidth(eyeDistance, pixel);
        float openVisibility = smoothstep(0.0, pixel, eyeRadius * aperture * rendered.scale.y);
        // Inset the outline and its antialiasing within the original eye footprint.
        float outlineMask = (1.0 - smoothstep(-eyeAA, 0.0, eyeDistance)) * openVisibility;
        float eyeMask = (1.0 - smoothstep(-eyeAA, 0.0, eyeDistance + 0.90 * pixel)) * openVisibility;
        float pupilDistance = (length(eyeCoord - gaze) - 0.40 * eyeRadius) * distanceScale;
        float pupilAA = edgeWidth(pupilDistance, pixel);
        float pupilMask = min(eyeMask, 1.0 - smoothstep(-pupilAA, pupilAA, pupilDistance));
        vec2 glintCentre = gaze + vec2(-0.13, 0.15) * eyeRadius;
        float glintDistance = (length(eyeCoord - glintCentre) - 0.11 * eyeRadius) * distanceScale;
        float glintAA = edgeWidth(glintDistance, pixel);
        float glintMask = min(pupilMask, 1.0 - smoothstep(-glintAA, glintAA, glintDistance));
        float lidX = eyeCoord.x / eyeRadius;
        float lidCurve = -0.13 * eyeRadius * (1.0 - lidX * lidX);
        // Divide by the curve's local slope factor to approximate perpendicular distance and keep the eyelid line thickness consistent.
        float lidDistance = max(abs(eyeCoord.y - lidCurve)
            / sqrt(1.0 + 0.0676 * lidX * lidX) * distanceScale - 0.50 * pixel,
            (abs(eyeCoord.x) - 0.82 * eyeRadius) * distanceScale);
        float lidAA = edgeWidth(lidDistance, pixel);
        float lidMask = (1.0 - smoothstep(-lidAA, lidAA, lidDistance))
            * (1.0 - smoothstep(0.0, 0.35, aperture));
        lidMask *= 1.0 - smoothstep(-eyeAA, 0.0,
            (length(eyeCoord) - eyeRadius) * distanceScale);
        mochiColour = mix(mochiColour, vec3(0.0), max(outlineMask, lidMask));
        mochiColour = mix(mochiColour, vec3(1.0), eyeMask);
        mochiColour = mix(mochiColour, vec3(0.0), pupilMask);
        mochiColour = mix(mochiColour, vec3(1.0), glintMask);
        if (mouthOpen > 0.0) {
            // Raise the mouth into the space below the closing eye.
            float mouthTop = eyeAnchor.y - 1.08 * restingEyeRadius - pixel
                + min(1.5 * pixel, 0.25 * restingEyeRadius) * expressionClosure;
            float mouthSpace = mouthTop + rendered.baseHalfSize.y;
            if (mouthSpace >= 1.5 * pixel) {
                vec2 mouthRadius = vec2(0.32 * restingEyeRadius,
                    min(0.34 * restingEyeRadius, 0.45 * mouthSpace));
                vec2 mouthCentre = vec2(0.0, mouthTop - 0.5 * mouthSpace);
                mouthRadius.y *= mouthOpen;
                float mouthDistance = (length((rendered.bodyLocal - mouthCentre)
                    / max(mouthRadius, vec2(1e-6))) - 1.0) * min(mouthRadius.x, mouthRadius.y) * distanceScale;
                float mouthAA = edgeWidth(mouthDistance, pixel);
                float mouthMask = (1.0 - smoothstep(-mouthAA, 0.0, mouthDistance)) * mouthOpen;
                mochiColour = mix(mochiColour, vec3(0.0), mouthMask);
            }
        }
    }

    return mochiColour;
}

// Sample the terminal, then composite the trail, landing particles and Mochi in that order.
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 off = vec2(-0.5, 0.5);

    MoveState move;
    move.currentRect = vec4(normalizeCoord(iCurrentCursor.xy, true), normalizeCoord(iCurrentCursor.zw, false));
    move.previousRect = vec4(normalizeCoord(iPreviousCursor.xy, true), normalizeCoord(iPreviousCursor.zw, false));

    MochiPath path;
    path.current.centre = move.currentRect.xy - (move.currentRect.zw * off);
    path.current.halfSize = move.currentRect.zw * 0.5;
    path.previous.centre = move.previousRect.xy - (move.previousRect.zw * off);
    path.previous.halfSize = move.previousRect.zw * 0.5;

    move.centreDelta = path.current.centre - path.previous.centre;
    move.centreDistance = length(move.centreDelta);
    move.originDelta = move.currentRect.xy - move.previousRect.xy;
    move.originDistance = length(move.originDelta);
    move.minDistance = move.currentRect.w * MIN_MOVE_DISTANCE;
    move.maxDistance = move.currentRect.w * MAX_VALID_MOVE_DISTANCE;
    // Compare origins so cursor size changes do not imply a different row or column.
    bool smallHorizontalMove = abs(move.currentRect.y - move.previousRect.y) <= min(move.currentRect.w, move.previousRect.w) * SMALL_MOVE_TOLERANCE
        && abs(move.currentRect.x - move.previousRect.x) <= min(move.currentRect.z, move.previousRect.z) * (1.0 + SMALL_MOVE_TOLERANCE);
    bool smallVerticalMove = abs(move.currentRect.x - move.previousRect.x) <= min(move.currentRect.z, move.previousRect.z) * SMALL_MOVE_TOLERANCE
        && abs(move.currentRect.y - move.previousRect.y) <= min(move.currentRect.w, move.previousRect.w) * (1.0 + SMALL_MOVE_TOLERANCE);

    move.timeSince = iTime - iTimeCursorChange;

    move.mochiGeometryValid = move.currentRect.z > 0.0 && move.currentRect.w > 0.0;
    move.mochiVisible = iFocus > 0 && iCursorVisible > 0 && move.mochiGeometryValid;
    move.prevGeometryValid = move.previousRect.z > 0.0 && move.previousRect.w > 0.0;
    move.moveInRange = move.prevGeometryValid && move.centreDistance > move.minDistance && move.centreDistance < move.maxDistance && move.timeSince >= 0.0;
    move.movedSinceFocus = iTimeCursorChange > iTimeFocus;
    move.originBeyondMinDistance = move.originDistance > move.minDistance;
    move.smallMove = smallHorizontalMove || smallVerticalMove;
    move.largeMoveValid = move.mochiGeometryValid && move.moveInRange && !move.smallMove;
    move.hollowSinceFocus = move.mochiVisible && iCurrentCursorStyle == CURSORSTYLE_BLOCK_HOLLOW
        && move.movedSinceFocus;
    move.jump = move.hollowSinceFocus && move.largeMoveValid;
    move.smallSlide = move.hollowSinceFocus && move.moveInRange && move.smallMove && move.originBeyondMinDistance;
    // Measure origin displacement in cells, independent of font size and aspect.
    move.cellDistance = move.largeMoveValid ? length(move.originDelta / max(move.currentRect.zw, vec2(1e-6))) : 0.0;
    move.landingIntensity = smoothstep(LANDING_MIN_DISTANCE, LANDING_FULL_DISTANCE, move.cellDistance);
    move.landingStart = MOCHI_TRAVEL_TIME;
    float landingHoldTime = mix(MOCHI_LANDING_HOLD_TIME_RANGE.x, MOCHI_LANDING_HOLD_TIME_RANGE.y, move.landingIntensity);
    float landingRecoveryTime = mix(MOCHI_LANDING_RECOVERY_TIME_RANGE.x, MOCHI_LANDING_RECOVERY_TIME_RANGE.y, move.landingIntensity);
    float landingCompressionEnd = move.landingStart + MOCHI_LANDING_COMPRESSION_TIME;
    float landingRecoveryStart = landingCompressionEnd + landingHoldTime;
    move.jumpEnd = landingRecoveryStart + landingRecoveryTime;
    move.movementEnd = move.jump ? move.jumpEnd : (move.smallSlide ? MOCHI_SMALL_MOVE_TIME : 0.0);
    vec2 sampleCoord;
    vec2 renderCoord = landingShakeCoord(fragCoord, move, sampleCoord);

    fragColor = texture(iChannel0, sampleCoord.xy / iResolution.xy);

    FragmentState fragment;
    fragment.normalisedCoord = normalizeCoord(renderCoord, true);
    fragment.normalisedCoordDx = dFdx(fragment.normalisedCoord);
    fragment.normalisedCoordDy = dFdy(fragment.normalisedCoord);
    fragment.pixel = 2.0 / iResolution.y;
    vec4 outC = fragColor;
    path.curveStrength = (move.largeMoveValid || move.smallSlide) ? getCurveStrength(move.centreDistance) : 0.0;
    move.seed = (move.largeMoveValid || move.smallSlide) ? getMovementSeed(path.previous.centre, path.current.centre, move.centreDistance) : 0.0;
    RenderedMochi rendered;
    rendered.headProgress = 1.0;
    rendered.centre = path.current.centre;
    rendered.halfSize = path.current.halfSize;
    rendered.scale = vec2(1.0);

    if (move.smallSlide && move.timeSince < MOCHI_SMALL_MOVE_TIME) {
        rendered.headProgress = easeLinear(move.timeSince / MOCHI_SMALL_MOVE_TIME);
        rendered.centre = getCurvedPathPosition(path.previous.centre, path.current.centre, rendered.headProgress, path.curveStrength);
        rendered.halfSize = mix(path.previous.halfSize, path.current.halfSize, rendered.headProgress);
    } else if (move.jump && move.timeSince < move.jumpEnd) {
        rendered.headProgress = easeSmoothStep(move.timeSince / MOCHI_TRAVEL_TIME);
        rendered.centre = getCurvedPathPosition(path.previous.centre, path.current.centre, rendered.headProgress, path.curveStrength);
        vec2 landingHalfSize = mix(path.previous.halfSize, path.current.halfSize, rendered.headProgress);
        vec2 landingPeakScale = mix(MOCHI_LANDING_MIN_SCALE, MOCHI_LANDING_MAX_SCALE, move.landingIntensity);
        float landingCompression = envelope(move.timeSince, move.landingStart, landingCompressionEnd, landingRecoveryStart, move.jumpEnd);
        rendered.scale = mix(vec2(1.0), landingPeakScale, landingCompression);
        rendered.halfSize = landingHalfSize * rendered.scale;
        // Keep the lower edge fixed while Mochi becomes shorter.
        rendered.centre.y += rendered.halfSize.y - landingHalfSize.y;
    }

    // Undo the landing squash for local geometry, then scale its distances back when drawing the body and face.
    rendered.baseHalfSize = rendered.halfSize / rendered.scale;
    rendered.bodyLocal = (fragment.normalisedCoord - rendered.centre) / rendered.scale;
    rendered.capeLocal = rendered.bodyLocal;
    rendered.capeDistanceScale = min(rendered.scale.x, rendered.scale.y);
    if (move.smallSlide) {
        // The shared clock keeps the bob phase continuous across repeated cells.
        float cycle = 0.5 - 0.5 * cos(2.0 * PI * iTime / MOCHI_BOB_PERIOD);
        float release = 1.0 - easeSmoothStep((move.timeSince - MOCHI_BOB_HOLD_TIME) / MOCHI_BOB_RETURN_TIME);
        float bobScale = 1.0 - MOCHI_BOB_COMPRESSION * cycle * release;
        // Scale only the head and eye about the lower edge, leaving the cape unchanged.
        rendered.bodyLocal.y = (rendered.bodyLocal.y + rendered.baseHalfSize.y) / bobScale - rendered.baseHalfSize.y;
        rendered.scale.y *= bobScale;
    }
    fragment.mochiOutlineDistance = mochiDistance(rendered, move, fragment.normalisedCoord);
    outC = compositeTrail(outC, path, move, fragment, rendered.headProgress);

    outC = compositeLandingParticles(outC, path.current, move, fragment);

    if (move.mochiVisible) {
        float mochiAlpha = 1.0;
        vec3 mochiColour = iCurrentCursorColor.rgb;
        if (iCurrentCursorStyle == CURSORSTYLE_BLOCK_HOLLOW) {
            // Fade waits for slide or jump completion, then the hold. Focus resets it without a hold.
            float fadeDelay = move.movementEnd + ((move.smallSlide || move.jump) ? MOCHI_FADE_HOLD_TIME : 0.0);
            float fadeStart = max(iTimeCursorChange + fadeDelay, iTimeFocus);
            mochiAlpha = getMochiAlpha(max(iTime - fadeStart, 0.0));

            mochiColour = drawFace(mochiColour, rendered, move, fragment.pixel);
        }

        float mochiMask = antialiasNoBlur(fragment.mochiOutlineDistance) * mochiAlpha;
        outC = mix(outC, vec4(mochiColour, outC.a), mochiMask);
    }

    fragColor = outC;
}
