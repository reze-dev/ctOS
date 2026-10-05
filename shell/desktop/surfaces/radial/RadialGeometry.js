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

// Calculates dynamic layout for radial segments where one is expanded and others shrink
// Maintains fixed gaps and ensures segments push each other sequentially.
function getSegmentTargetLayout(index, focusedIndex, categoryCount, gapAngle, focusedWidth, previousCenterAngle) {
    if (categoryCount <= 0) return { width: 0, centerAngle: previousCenterAngle || 0, startAngle: 0, endAngle: 0 };
    
    var totalAvailable = 360.0 - categoryCount * gapAngle;
    var isIdle = (focusedIndex < 0 || focusedIndex >= categoryCount);
    
    var normalWidth = totalAvailable / categoryCount;
    if (!isIdle && categoryCount > 1) {
        normalWidth = (totalAvailable - focusedWidth) / (categoryCount - 1);
    }
    
    var widths = [];
    for (var i = 0; i < categoryCount; i++) {
        widths.push(isIdle ? (totalAvailable / categoryCount) : (i === focusedIndex ? focusedWidth : normalWidth));
    }
    
    var anchorIndex = isIdle ? 0 : focusedIndex;
    var nominalAnchorAngle = -90.0 + anchorIndex * (360.0 / categoryCount);
    
    var dist = 0.0;
    if (index >= anchorIndex) {
        for (var j = anchorIndex; j < index; j++) {
            dist += (widths[j] / 2.0) + gapAngle + (widths[j+1] / 2.0);
        }
    } else {
        for (var j = anchorIndex; j > index; j--) {
            dist -= (widths[j] / 2.0) + gapAngle + (widths[j-1] / 2.0);
        }
    }
    
    var targetCenter = nominalAnchorAngle + dist;
    
    if (previousCenterAngle !== undefined && previousCenterAngle !== null) {
        while (targetCenter - previousCenterAngle > 180.0) targetCenter -= 360.0;
        while (targetCenter - previousCenterAngle < -180.0) targetCenter += 360.0;
    }
    
    return {
        width: widths[index],
        centerAngle: targetCenter,
        startAngle: targetCenter - widths[index] / 2.0,
        endAngle: targetCenter + widths[index] / 2.0
    };
}


// ---------------------------------------------------------------------------
// Tree layout
//
// Takes declared relationships and parameters, and produces coordinates. It
// never sees a tree that has positions baked in: RadialTopology.qml holds only
// who is connected to whom, and this decides where they land in one view while
// layoutPreviewTree below decides where they land in the other. Same
// relationships, two projections, so the views cannot disagree about a
// category's shape -- only about how it is drawn.
//
// Polar convention, and it is worth stating because it is easy to get backwards:
//   x = parentX + sin(angle) * distance
//   y = parentY - cos(angle) * distance
// Angle 0 points UP, +90 points right. The expanded branch grows rightward from
// a wheel anchored off the left edge, so rootAngle defaults to 90 -- at 0 the
// tree grows up out of the ring.
//
// Angles accumulate down a branch rather than being measured from the root, so
// a child placed at -85 puts its own children around -85. Without that, every
// generation tries to orbit the original root and the tree becomes a disc of
// unrelated spokes instead of branches.
// ---------------------------------------------------------------------------

// Offsets for childCount children spread evenly across a total fan of `total`
// degrees, centred on zero.
//
// One child gets no spread at all: a single child is a link in a chain, and
// giving it an offset is what turns a three-deep chain into three stray nodes.
function fanOffsets(childCount, total) {
    if (childCount <= 1) return [0.0];
    var half = total / 2.0;
    var out = [];
    for (var i = 0; i < childCount; ++i)
        out.push(-half + (total * i) / (childCount - 1));
    return out;
}

// The narrowest total fan that still leaves `minSeparation` between siblings.
//
// A fixed fan collapses as children are added: at 120 degrees, six children sit
// 30 degrees apart, which is 72px apart at a 140px distance -- closer than the
// nodes are wide. So the fan has to grow with the child count, which is what
// this returns, and it is the reason nodeRadius is worth passing in at all.
function minimumFan(childCount, distance, minSeparation) {
    if (childCount <= 1 || distance <= 0.0) return 0.0;
    var ratio = Math.min(1.0, minSeparation / (2.0 * distance));
    var step = 2.0 * Math.asin(ratio) * 180.0 / Math.PI;
    return step * (childCount - 1);
}

function layoutTree(nodes, opts) {
    opts = opts || {};

    var rootAngle = (typeof opts.rootAngle === "number") ? opts.rootAngle : 90.0;

    // Total fan per depth, index = depth - 1, clamped at the last entry.
    //
    // 150 at the root, 100 below. This was 170/120, which is what the reference
    // first level measures, and it was too wide to stay clear of the wheel: a
    // branch that had already rotated once put its own children at up to -145,
    // which is left of the root. security's recon node landed 67px that way --
    // toward a ring whose outer radius is 180 -- and on a deeper tree the worst
    // case reached 204px, which is inside the ring itself.
    //
    // 150/100 puts security's furthest node exactly at the root's own x and pulls
    // the 40-node worst case back to 156px, clear of the rim. Going narrower
    // still starts to cost the reference's up/right/down first level, which is
    // the one thing currently matching it exactly.
    var fans = (opts.fans && opts.fans.length > 0) ? opts.fans : [150.0, 100.0];

    var baseDistance = (typeof opts.distance === "number") ? opts.distance : 140.0;
    var nodeRadius = (typeof opts.nodeRadius === "number") ? opts.nodeRadius : 24.0;
    var gap = (typeof opts.gap === "number") ? opts.gap : 10.0;

    // Distance holds for the first two levels, then shortens. A tree that keeps
    // marching at full stride spreads very wide by depth 4; security already
    // reaches x = -344 at depth 3.
    var shrinkFromDepth = (typeof opts.shrinkFromDepth === "number") ? opts.shrinkFromDepth : 2;
    var shrinkPerLevel = (typeof opts.shrinkPerLevel === "number") ? opts.shrinkPerLevel : 0.8;

    // Measure a fork from the direction its own branch arrived on (the default),
    // or from rootAngle. The second reads as a fork hanging off the side of a
    // chain, which shoots back across the tree; the first reads as a tree.
    var recentreDeepForks = opts.recentreDeepForks === true;

    function fanAt(depth) {
        return fans[Math.min(depth - 1, fans.length - 1)];
    }

    function distanceAt(depth) {
        if (depth <= shrinkFromDepth) return baseDistance;
        return baseDistance * Math.pow(shrinkPerLevel, depth - shrinkFromDepth);
    }

    var out = {};
    if (!nodes || nodes.length === 0) return out;

    out[nodes[0].id] = {
        x: 0.0, y: 0.0, depth: 0, angle: rootAngle, parent: null, spoke: -1
    };

    var queue = [{ node: nodes[0], angle: rootAngle, depth: 0 }];

    while (queue.length > 0) {
        var cur = queue.shift();
        var kids = cur.node.children || [];
        if (kids.length === 0) continue;

        var depth = cur.depth + 1;
        var distance = distanceAt(depth);

        // Widen the fan if this many children would otherwise sit inside each
        // other at this distance.
        var total = Math.max(
            fanAt(depth),
            minimumFan(kids.length, distance, 2.0 * nodeRadius + gap)
        );
        var offsets = fanOffsets(kids.length, total);

        var origin = out[cur.node.id];
        var from = (recentreDeepForks && cur.depth > 0) ? rootAngle : cur.angle;

        for (var i = 0; i < kids.length; ++i) {
            var kid = kids[i];
            // Already placed means it was reached by another branch; leave it
            // where it is rather than letting a second parent drag it.
            if (!kid || out[kid.id]) continue;

            var angle = from + offsets[i];
            var rad = angle * Math.PI / 180.0;
            out[kid.id] = {
                x: origin.x + Math.sin(rad) * distance,
                y: origin.y - Math.cos(rad) * distance,
                depth: depth,
                angle: angle,
                parent: cur.node.id,
                spoke: i
            };
            queue.push({ node: kid, angle: angle, depth: depth });
        }
    }

    // Nodes the relationships never reach. They cannot be placed relative to a
    // parent that does not exist, but leaving them out would make them vanish
    // instead of failing visibly, so park them on a shallow arc off the root.
    var orphans = [];
    for (var n = 0; n < nodes.length; ++n)
        if (nodes[n] && !out[nodes[n].id]) orphans.push(nodes[n]);

    for (var o = 0; o < orphans.length; ++o) {
        var spread = orphans.length === 1 ? 0.0 : -45.0 + (90.0 * o) / (orphans.length - 1);
        var orad = (rootAngle + spread) * Math.PI / 180.0;
        out[orphans[o].id] = {
            x: Math.sin(orad) * baseDistance,
            y: -Math.cos(orad) * baseDistance,
            depth: 1,
            angle: rootAngle + spread,
            parent: nodes[0].id,
            spoke: 90 + o
        };
    }

    return out;
}

// Rotate a laid-out point so the tree's +x axis points along `angleDeg`, then
// translate it to `origin`.
//
// This is the whole of the difference between the two renderings: the expanded
// branch draws the layout directly, the wheel's preview draws it through this.
// Same angles, same fan, same parent-to-child pairs -- only the scale, the
// anchor and the rotation differ, which is why the two cannot drift apart.
function projectPoint(p, angleDeg, scale, origin) {
    var rad = angleDeg * Math.PI / 180.0;
    var cos = Math.cos(rad) * scale;
    var sin = Math.sin(rad) * scale;
    return {
        x: origin.x + p.x * cos - p.y * sin,
        y: origin.y + p.x * sin + p.y * cos
    };
}

// ---------------------------------------------------------------------------
// Wheel preview tree layout
//
// Deliberately not layoutTree() above. The wheel packs eight of these into a
// ring, so a tree here is compact and symmetric about its own segment axis,
// where the expanded branch is read one node at a time and fans to fill space.
//
// The rule, in the tree's own space where +x is "outward along the segment":
//
//              |
//              o
//             / \
//            o   o
//            |   |
//            o   o
//
// A fork straddles the parent's own direction by +/- forkDeg, and everything
// below a fork carries on straight along the ray that node already left on. It
// does NOT come back to the segment axis: two siblings that forked apart stay
// apart, so a tree reads as a fork with two arms rather than as a row of nodes
// stacked back up the middle.
//
// That "stay diverged" is the whole rule, and getting it wrong in either
// direction is visible. Snapping every node back to the axis collapses the arms
// onto each other; inheriting the fork only at the root, as an earlier version
// did, leaves a second fork in the middle of a chain drawn as a straight line.
//
// Direction convention: dir 0 is +x, so the step is (cos, sin) and a tree grows
// rightward in its own space. That is a 90 degree clockwise turn from the (sin,
// -cos) frame, where 0 would mean up, and it has to be +x because
// projectPoint() rotates by the segment angle and so maps local +x onto the
// outward radial direction (cos a, sin a). Under the old (sin, -cos) frame a
// segment's own axis mapped to (sin a, -cos a), which coincides with the
// outward ray only at a = 180 -- so every tree grew sideways across its
// segment instead of away from the wheel.
function layoutPreviewTree(nodes, opts) {
    opts = opts || {};
    var step = (typeof opts.step === "number") ? opts.step : 56.0;
    var forkDeg = (typeof opts.forkDeg === "number") ? opts.forkDeg : 45.0;

    var out = {};
    if (!nodes || nodes.length === 0) return out;
    out[nodes[0].id] = {
        x: 0.0, y: 0.0, depth: 0, dir: 0.0, spoke: -1, parent: null
    };

    var queue = [{ node: nodes[0], depth: 0, dir: 0.0 }];

    while (queue.length > 0) {
        var cur = queue.shift();
        var kids = cur.node.children || [];
        if (kids.length === 0) continue;

        var depth = cur.depth + 1;
        var distance = step;

        // One child gets no offset at all: it is a link in an arm, and it
        // continues along the ray its parent is already on.
        var offsets = fanOffsets(kids.length, forkDeg * 2.0);

        for (var i = 0; i < kids.length; ++i) {
            var kid = kids[i];
            if (!kid || out[kid.id]) continue;

            var dir = cur.dir + offsets[i];
            var rad = dir * Math.PI / 180.0;
            out[kid.id] = {
                x: out[cur.node.id].x + Math.cos(rad) * distance,
                y: out[cur.node.id].y + Math.sin(rad) * distance,
                depth: depth,
                dir: dir,
                spoke: offsets[i] === 0.0 ? -1 : i,
                parent: cur.node.id
            };
            queue.push({ node: kid, depth: depth, dir: dir });
        }
    }

    // Nodes the relationships never reach cannot be placed against a parent that
    // does not exist, but dropping them would make them vanish instead of failing
    // visibly. Park them on the parent's ray.
    var orphans = [];
    for (var n = 0; n < nodes.length; ++n)
        if (nodes[n] && !out[nodes[n].id]) orphans.push(nodes[n]);

    for (var o = 0; o < orphans.length; ++o) {
        var orad = (out[nodes[0].id].dir) * Math.PI / 180.0;
        out[orphans[o].id] = {
            x: out[nodes[0].id].x + Math.cos(orad) * step,
            y: out[nodes[0].id].y + Math.sin(orad) * step,
            depth: 1, dir: out[nodes[0].id].dir, spoke: 90 + o, parent: nodes[0].id
        };
    }

    return out;
}

