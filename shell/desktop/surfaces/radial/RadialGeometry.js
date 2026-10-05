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
// The one place a settings tree gets geometry. Both renderings call this: the
// expanded branch at one scale, the wheel's preview at another. They used to
// have separate geometry -- hand-placed `pos` in the model for the first, a
// synthetic +/-8 degree fan for the second -- so the two views disagreed about
// how many branches a category had, and nothing in the code could catch it.
//
// Same algorithm for both views is deliberate. Letting each pick its own angles
// would fix today's mismatch and reintroduce it the next time one is tuned, so
// difference between the views lives in `params` instead.
// ---------------------------------------------------------------------------

// How a node's children fan out, as offsets in degrees from the direction that
// led to their parent.
//
// The numbers come from the two reference layouts rather than from taste: three
// branches off one base sit at about -85/0/+85, and two at about -74/+74. A
// single child returns [0], so it continues along its parent's direction -- that
// is what makes a three-deep chain read as one spoke leaving the base instead of
// three unrelated nodes.
function childFanAngles(childCount) {
    if (childCount <= 1) return [0.0];
    if (childCount === 2) return [-74.0, 74.0];
    if (childCount === 3) return [-85.0, 0.0, 85.0];

    // No reference for this case, and nothing in the tree currently reaches it
    // (the widest node has three children). Spread evenly rather than guess
    // unevenly: if a category ever does fan four ways, this is the shape to
    // argue about, and it should start from "evenly spaced", not from a number
    // someone picked.
    var out = [];
    for (var i = 0; i < childCount; ++i)
        out.push(-90.0 + (180.0 * i) / (childCount - 1));
    return out;
}

// Lay out a nested tree literal ({ id, children }) into coordinates.
//
// opts.step      distance between depth levels, in the view's own units
// opts.flatten   per-level pull of each spoke toward its parent's axis, so a
//                chain arcs outward instead of running along one ray
//
// Returns { <id>: { x, y, depth, spoke } } with the root at (0, 0).
//
// Breadth-first from the root, and each node carries the axis it was placed on
// so its own children continue outward from there rather than re-fanning around
// a fixed global axis. That is the whole difference between a tree that reads as
// a tree and one that reads as nodes scattered near each other.
function layoutTree(nodes, opts) {
    opts = opts || {};
    var step = (typeof opts.step === "number") ? opts.step : 140.0;
    var flatten = (typeof opts.flatten === "number") ? opts.flatten : 0.15;

    var out = {};
    if (!nodes || nodes.length === 0) return out;

    // A node already placed is left alone, so a second parent cannot drag it to a
    // new position. The topology is authored as a tree, but this keeps a
    // mistake in the file from silently relocating a subtree.
    var queue = [{ node: nodes[0], depth: 0, axis: 0.0, spoke: -1 }];
    out[nodes[0].id] = { x: 0.0, y: 0.0, depth: 0, spoke: -1, parent: null };

    while (queue.length > 0) {
        var cur = queue.shift();
        var kids = cur.node.children || [];
        if (kids.length === 0) continue;

        var fan = childFanAngles(kids.length);

        // A fork inherits its parent's axis, so a deep fork can be aimed backwards.
        //
        // security is the case that matters: root -> sec-lock (-74) -> sec-toolkit
        // (-63), and sec-toolkit has three children. Fanning those around its own
        // axis gave -148, -63 and +22, so the recon node was thrown up and to the
        // LEFT, back over the hub it belongs to. The subtree stopped reading as
        // growing outward from the wheel.
        //
        // When the inherited fan would leave the forward half-plane, drop the
        // parent's axis for this fork and open it symmetrically instead. It is the
        // same shape the reference uses for a three-way fork, just aimed outward
        // rather than continuing to rotate.
        var raw = [];
        for (var q = 0; q < kids.length; ++q) raw.push(cur.axis + fan[q]);
        var backwards = false;
        for (var q2 = 0; q2 < raw.length; ++q2)
            if (raw[q2] < -90.0 || raw[q2] > 90.0) backwards = true;
        if (backwards) {
            var centred = childFanAngles(kids.length);
            for (var q3 = 0; q3 < centred.length; ++q3) raw[q3] = centred[q3];
        }

        for (var k = 0; k < kids.length; ++k) {
            var child = kids[k];
            if (!child || out[child.id]) continue;

            var depth = cur.depth + 1;
            var axis = raw[k];
            var dir = axis * Math.pow(1.0 - flatten, depth - 1);
            var rad = dir * Math.PI / 180.0;
            var radius = step * depth;

            out[child.id] = {
                x: radius * Math.cos(rad),
                y: radius * Math.sin(rad),
                depth: depth,
                spoke: (depth === 1) ? k : cur.spoke,
                // Recorded rather than re-derived by the renderer. Both views
                // need a parent-to-child pair to draw one edge, and re-walking
                // the tree in each of them is how they came to disagree.
                parent: cur.node.id
            };
            queue.push({ node: child, depth: depth, axis: axis, spoke: (depth === 1) ? k : cur.spoke });
        }
    }

    // Nodes the children lists never reached. They cannot be laid out from a
    // parent that does not exist, but leaving them out would make them vanish
    // instead of failing visibly, so park them on a shallow arc off the root.
    var orphans = [];
    for (var i = 0; i < nodes.length; ++i)
        if (nodes[i] && !out[nodes[i].id]) orphans.push(nodes[i]);

    for (var m = 0; m < orphans.length; ++m) {
        var od = orphans.length === 1 ? 0.0 : -90.0 + (180.0 * m) / (orphans.length - 1);
        var orad = od * Math.PI / 180.0;
        out[orphans[m].id] = {
            x: step * Math.cos(orad), y: step * Math.sin(orad), depth: 1, spoke: 100 + m,
            parent: null
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
// Deliberately not layoutTree() above. These are two different drawings of the
// same topology and they do not want the same shape.
//
// The expanded branch has the canvas to itself and is read one node at a time,
// so it fans wide and lets its chains arc outward. The wheel packs eight of
// these trees into a ring, so the base tree is compact and mostly straight:
//
//   arc -> first node -> two children at 45 degrees -> each child's children
//   continue in a straight line radially outward
//
// One fork, at the first node, and then straight rays. No arcing, and the fan is
// 45 degrees rather than the expanded view's 74-85.
//
// Sharing layoutTree() here is what made the base look wrong: it inherited the
// expanded view's wide fan and its per-level flattening, so a fork of two at 74
// degrees that curved as it went read as a sprawl rather than a pair of branches.
// ---------------------------------------------------------------------------

function previewForkAngles(childCount, forkDeg) {
    if (childCount <= 1) return [0.0];
    if (childCount === 2) return [-forkDeg, forkDeg];

    // Past two there is nothing to copy, so spread evenly across the same 90
    // degrees rather than inventing a wider fan for a shape nobody has drawn.
    var out = [];
    for (var i = 0; i < childCount; ++i)
        out.push(-forkDeg + (2.0 * forkDeg * i) / (childCount - 1));
    return out;
}

// Lay out a nested tree literal for the wheel's preview.
// Returns { <id>: { x, y, depth, spoke, parent } }, root at (0, 0).
function layoutPreviewTree(nodes, opts) {
    opts = opts || {};
    var step = (typeof opts.step === "number") ? opts.step : 56.0;
    var forkDeg = (typeof opts.forkDeg === "number") ? opts.forkDeg : 45.0;

    var out = {};
    if (!nodes || nodes.length === 0) return out;
    out[nodes[0].id] = { x: 0.0, y: 0.0, depth: 0, spoke: -1, parent: null };

    function place(node, depth, dirDeg, spoke) {
        if (!node || out[node.id]) return null;
        var rad = dirDeg * Math.PI / 180.0;
        var radius = step * depth;
        out[node.id] = {
            x: radius * Math.cos(rad),
            y: radius * Math.sin(rad),
            depth: depth,
            spoke: spoke,
            parent: null
        };
        return out[node.id];
    }

    // Siblings on a straight ray are told who their parent is by the caller,
    // because below the fork the parent is the node being walked, not the node
    // one level up.
    var queue = [{ node: nodes[0], depth: 0, dir: 0.0, spoke: -1 }];
    while (queue.length > 0) {
        var cur = queue.shift();
        var kids = cur.node.children || [];
        if (kids.length === 0) continue;

        // Fork at EVERY branching node, not just the root.
        //
        // This only forked when cur.depth === 0, which quietly assumed a tree
        // branches once. security does not: sec-toolkit has three children, and
        // with the fork reserved for the root they were placed as a straight line
        // of three dots along one ray -- six dots in a row in the wheel, which
        // read as a bar rather than a branch.
        //
        // The rule is per node, not per level: a node with two or more children
        // is a branch point and its children fan at forkDeg; a node with exactly
        // one child is a link in a chain and that child continues straight out.
        if (kids.length >= 2) {
            var fan = previewForkAngles(kids.length, forkDeg);
            for (var k = 0; k < kids.length; ++k) {
                var rec = place(kids[k], cur.depth + 1, cur.dir + fan[k], k);
                if (!rec) continue;
                rec.parent = cur.node.id;
                queue.push({ node: kids[k], depth: cur.depth + 1, dir: cur.dir + fan[k], spoke: k });
            }
        } else {
            // Straight out from here. Siblings share the ray and step outward in
            // order, so a node with two children draws as two dots in a line
            // rather than as a second fork.
            for (var m = 0; m < kids.length; ++m) {
                var rec2 = place(kids[m], cur.depth + 1 + m, cur.dir, cur.spoke);
                if (!rec2) continue;
                rec2.parent = cur.node.id;
                queue.push({ node: kids[m], depth: cur.depth + 1 + m, dir: cur.dir, spoke: cur.spoke });
            }
        }
    }

    // Same orphan handling as layoutTree(): a node the topology never reaches is
    // parked rather than dropped, so a mistake shows up instead of vanishing.
    var orphans = [];
    for (var i = 0; i < nodes.length; ++i)
        if (nodes[i] && !out[nodes[i].id]) orphans.push(nodes[i]);

    for (var o = 0; o < orphans.length; ++o) {
        var od = orphans.length === 1 ? 0.0 : -forkDeg + (2.0 * forkDeg * o) / (orphans.length - 1);
        var rec3 = place(orphans[o], 1, od, 90 + o);
        if (rec3) rec3.parent = nodes[0].id;
    }

    return out;
}
