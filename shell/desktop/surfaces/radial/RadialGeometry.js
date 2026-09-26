.pragma library

// =============================================================================
// RadialGeometry.js - Pure mathematical and geometric algorithms for ctOS
// =============================================================================

function degToRad(degrees) {
    return (degrees * Math.PI) / 180.0;
}

function radToDeg(radians) {
    return (radians * 180.0) / Math.PI;
}

// Normalizes any angle into [-180, 180] range
function normalizeAngle(degrees) {
    var a = degrees % 360;
    if (a > 180) a -= 360;
    if (a < -180) a += 360;
    return a;
}

// Calculates shortest angular distance from 'fromAngle' to 'toAngle' in [-180, 180]
function angleDifference(fromAngle, toAngle) {
    return normalizeAngle(toAngle - fromAngle);
}

// Calculates Cartesian point on circle
function pointOnCircle(cx, cy, radius, angleDeg) {
    var rad = degToRad(angleDeg);
    return {
        x: cx + radius * Math.cos(rad),
        y: cy + radius * Math.sin(rad)
    };
}

// Calculates angle in degrees [-180, 180] from center (cx, cy) to target point (x, y)
function angleFromCenter(cx, cy, x, y) {
    var dx = x - cx;
    var dy = y - cy;
    var rad = Math.atan2(dy, dx);
    return radToDeg(rad);
}

// Euclidean distance between two points
function distance(x1, y1, x2, y2) {
    var dx = x2 - x1;
    var dy = y2 - y1;
    return Math.sqrt(dx * dx + dy * dy);
}

// Generates SVG Path string for an annular sector (ring slice)
// Supports innerRadius, outerRadius, startAngleDeg, endAngleDeg
function createSectorSvgPath(cx, cy, innerRadius, outerRadius, startAngleDeg, endAngleDeg) {
    var rInner = Math.max(0.1, innerRadius);
    var rOuter = Math.max(rInner + 1.0, outerRadius);

    var a1 = degToRad(startAngleDeg);
    var a2 = degToRad(endAngleDeg);

    var sweep = endAngleDeg - startAngleDeg;
    while (sweep < 0) sweep += 360;
    var largeArc = (sweep > 180) ? 1 : 0;

    var pOut1 = { x: cx + rOuter * Math.cos(a1), y: cy + rOuter * Math.sin(a1) };
    var pOut2 = { x: cx + rOuter * Math.cos(a2), y: cy + rOuter * Math.sin(a2) };
    var pIn1  = { x: cx + rInner * Math.cos(a1), y: cy + rInner * Math.sin(a1) };
    var pIn2  = { x: cx + rInner * Math.cos(a2), y: cy + rInner * Math.sin(a2) };

    // Format numbers with 2 decimal places for clean SVG
    function fmt(n) { return n.toFixed(2); }

    return "M " + fmt(pIn1.x) + " " + fmt(pIn1.y) +
           " L " + fmt(pOut1.x) + " " + fmt(pOut1.y) +
           " A " + fmt(rOuter) + " " + fmt(rOuter) + " 0 " + largeArc + " 1 " + fmt(pOut2.x) + " " + fmt(pOut2.y) +
           " L " + fmt(pIn2.x) + " " + fmt(pIn2.y) +
           " A " + fmt(rInner) + " " + fmt(rInner) + " 0 " + largeArc + " 0 " + fmt(pIn1.x) + " " + fmt(pIn1.y) +
           " Z";
}

// Returns the segment index [0, segmentCount - 1] that contains or is closest to target angle
// Segments are centered starting from top (-90 deg), progressing clockwise
function findClosestSegment(targetAngleDeg, segmentCount, currentFocusedIndex, hysteresisDegrees) {
    if (segmentCount <= 0) return 0;
    var segStep = 360.0 / segmentCount;
    var hBias = (typeof hysteresisDegrees === "number") ? hysteresisDegrees : 3.0;

    var bestIndex = 0;
    var minDiff = 999.0;

    for (var i = 0; i < segmentCount; ++i) {
        // Base center angle for segment i:
        // Segment 0 at -90 deg (12 o'clock)
        var centerAngle = -90.0 + i * segStep;
        var diff = Math.abs(angleDifference(targetAngleDeg, centerAngle));

        // Apply hysteresis bias in favor of current selection
        if (i === currentFocusedIndex) {
            diff -= hBias;
        }

        if (diff < minDiff) {
            minDiff = diff;
            bestIndex = i;
        }
    }

    return bestIndex;
}

// Finds closest node in a 2D node list with hysteresis to prevent cursor flutter
function findClosestNode(cursorX, cursorY, nodes, currentNodeId, hysteresisRadius) {
    if (!nodes || nodes.length === 0) return null;
    var hBias = (typeof hysteresisRadius === "number") ? hysteresisRadius : 20.0;

    var bestNode = null;
    var minDist = 999999.0;

    for (var i = 0; i < nodes.length; ++i) {
        var node = nodes[i];
        if (!node || typeof node.screenX !== "number" || typeof node.screenY !== "number") continue;

        var d = distance(cursorX, cursorY, node.screenX, node.screenY);
        if (node.id === currentNodeId) {
            d -= hBias;
        }

        if (d < minDist) {
            minDist = d;
            bestNode = node;
        }
    }

    return bestNode;
}

// Finds the best neighbor node in a given spatial direction (0=Up, 1=Right, 2=Down, 3=Left)
function findSpatialNeighbor(currentNode, allNodes, direction) {
    if (!currentNode || !allNodes || allNodes.length <= 1) return currentNode;

    var cx = currentNode.screenX;
    var cy = currentNode.screenY;
    var bestNeighbor = null;
    var bestScore = -999999.0;

    for (var i = 0; i < allNodes.length; ++i) {
        var n = allNodes[i];
        if (n.id === currentNode.id) continue;

        var dx = n.screenX - cx;
        var dy = n.screenY - cy;
        var d = Math.max(1.0, Math.sqrt(dx * dx + dy * dy));
        if (d < 1.0) continue;

        var score = 0;
        // Direction vectors and proximity scoring within directional cone:
        // Up: dx=0, dy=-1
        // Right: dx=1, dy=0
        // Down: dx=0, dy=1
        // Left: dx=-1, dy=0
        if (direction === 0) { // Up
            if (dy >= -5) continue; // must be above
            score = (1000.0 / d) - (Math.abs(dx) * 2.0);
        } else if (direction === 1) { // Right
            if (dx <= 5) continue; // must be right
            score = (1000.0 / d) - (Math.abs(dy) * 2.0);
        } else if (direction === 2) { // Down
            if (dy <= 5) continue; // must be below
            score = (1000.0 / d) - (Math.abs(dx) * 2.0);
        } else if (direction === 3) { // Left
            if (dx >= -5) continue; // must be left
            score = (1000.0 / d) - (Math.abs(dy) * 2.0);
        }

        // Prevent jumping over intermediate tier nodes in directional cone
        var isOccluded = false;
        for (var k = 0; k < allNodes.length; ++k) {
            var m = allNodes[k];
            if (m.id === currentNode.id || m.id === n.id) continue;
            var mdx = m.screenX - cx;
            var mdy = m.screenY - cy;
            if (direction === 1) { // Right
                if (mdx > 5 && mdx < dx - 40 && Math.abs(mdy) < 180) {
                    isOccluded = true;
                    break;
                }
            } else if (direction === 3) { // Left
                if (mdx < -5 && mdx > dx + 40 && Math.abs(mdy) < 180) {
                    isOccluded = true;
                    break;
                }
            } else if (direction === 0) { // Up
                if (mdy < -5 && mdy > dy + 40 && Math.abs(mdx) < 180) {
                    isOccluded = true;
                    break;
                }
            } else if (direction === 2) { // Down
                if (mdy > 5 && mdy < dy - 40 && Math.abs(mdx) < 180) {
                    isOccluded = true;
                    break;
                }
            }
        }
        if (isOccluded) continue;

        if (score > bestScore) {
            bestScore = score;
            bestNeighbor = n;
        }
    }

    return bestNeighbor || currentNode;
}

// Calculates dynamic start, end, and center angles for circumferential expansion
function getAngularLayout(index, count, focusedIndex, focusedWidth) {
    if (count <= 0) return { startAngle: 0, endAngle: 0, centerAngle: 0 };
    
    var baseOffset = -90.0;
    var remainder = 360.0 - focusedWidth;
    var normalWidth = count > 1 ? remainder / (count - 1) : 360.0;

    // Calculate shortest distance in index space
    var diff = index - focusedIndex;
    var half = Math.floor(count / 2);
    if (diff > half) diff -= count;
    if (diff < -half) diff += count;

    var centerOfFocused = baseOffset + focusedIndex * (360.0 / count);

    var start, end;
    if (diff === 0) {
        start = centerOfFocused - focusedWidth / 2.0;
        end = centerOfFocused + focusedWidth / 2.0;
    } else if (diff > 0) {
        start = centerOfFocused + focusedWidth / 2.0 + (diff - 1) * normalWidth;
        end = start + normalWidth;
    } else { // diff < 0
        end = centerOfFocused - focusedWidth / 2.0 + (diff + 1) * normalWidth;
        start = end - normalWidth;
    }

    // Apply a 2 degree visual gap
    var gap = 2.0;
    return {
        startAngle: start + gap / 2.0,
        endAngle: end - gap / 2.0,
        centerAngle: (start + end) / 2.0
    };
}
