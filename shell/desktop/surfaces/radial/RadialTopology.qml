pragma Singleton

import QtQuick
import "../../services"

// Topology of the settings tree: what depends on what, and nothing else.
//
// This file is the single source of the tree's *shape*. Both renderings -- the
// expanded branch and the wheel's preview -- lay out from this, and neither
// stores a position. That ordering is the point: when the preview carried its
// own geometry and the model carried hand-placed `pos` values, the two views
// disagreed about a category's shape, because nothing tied them together.
//
// Nesting rather than a flat per-node `requires`: every node here has exactly
// one parent (verified across all eight categories), which is what makes this a
// tree. A flat list would encode the same graph while making you scan for a
// node's parent instead of reading its children in place.
//
// This is QML rather than JSON because `sec-toolkit`'s children are computed at
// runtime from ToolkitService, not listed.
QtObject {
    readonly property var categories: [
        {
            id: "system",
            tree: [
                {
                    id: "sys-core",
                    children: [
                        { id: "sys-cpu-hex", children: [ { id: "sys-profiler" } ] },
                        { id: "sys-ram-bar" }
                    ]
                }
            ]
        },
        {
            id: "appearance",
            tree: [
                {
                    // Three branches off one base, which is the shape the
                    // three-branch reference shows. The other categories have two,
                    // so this is the only tree that fans three ways.
                    id: "app-engine",
                    children: [
                        { id: "app-motion", children: [ { id: "app-palette" } ] },
                        { id: "app-bar-height" },
                        { id: "app-wallpaper" }
                    ]
                }
            ]
        },
        {
            id: "desktop",
            tree: [
                {
                    id: "dt-compositor",
                    children: [
                        { id: "dt-command-deck", children: [ { id: "dt-notifications" } ] },
                        { id: "dt-command-center" }
                    ]
                }
            ]
        },
        {
            id: "network",
            tree: [
                {
                    id: "net-core",
                    children: [
                        { id: "net-flow", children: [ { id: "net-wifi-radio" } ] },
                        { id: "net-tracer" }
                    ]
                }
            ]
        },
        {
            id: "audio",
            tree: [
                {
                    // Two branches, one of which is a three-deep chain. The chain is
                    // what the depth flattening exists for: without it the three
                    // nodes sit on one ray and read as a single column rather than
                    // as a spoke leaving the base.
                    id: "audio-master",
                    children: [
                        {
                            id: "audio-mute",
                            children: [
                                { id: "audio-mic", children: [ { id: "audio-mic-mute" } ] }
                            ]
                        },
                        { id: "audio-spectrum" }
                    ]
                }
            ]
        },
        {
            id: "input",
            tree: [
                { id: "in-engine", children: [ { id: "in-pointer" } ] }
            ]
        },
        {
            id: "power",
            tree: [
                { id: "pwr-governor", children: [ { id: "pwr-supply" } ] }
            ]
        },
        {
            id: "security",
            tree: [
                {
                    id: "sec-subsystem",
                    children: [
                        {
                            id: "sec-lock",
                            children: [
                                {
                                    // Toolkit groups arrive at runtime, so this node's
                                    // children are computed rather than listed. They
                                    // used to be synthesized as node objects with a
                                    // hand-placed `x: 40 + i * 122` row and no edge
                                    // back here, which drew them as an unconnected
                                    // strip in the expanded view. Declaring them as
                                    // children is what gives them relations.
                                    id: "sec-toolkit",
                                    children: ToolkitService.groups.map(function (g) {
                                        return { id: "sec-tk-" + g.id };
                                    })
                                }
                            ]
                        },
                        { id: "sec-privacy" }
                    ]
                }
            ]
        }
    ]

    // Roots of a category's tree, or [] if the id is unknown.
    function treeFor(categoryId: string): var {
        if (!categoryId) return [];
        for (var i = 0; i < categories.length; ++i)
            if (categories[i].id === categoryId)
                return categories[i].tree ? categories[i].tree : [];
        return [];
    }

    // Every node id a category declares, nested children included.
    function idsFor(categoryId: string): var {
        var out = [];
        var walk = function (nodes) {
            if (!nodes) return;
            for (var i = 0; i < nodes.length; ++i) {
                out.push(nodes[i].id);
                walk(nodes[i].children);
            }
        };
        walk(treeFor(categoryId));
        return out;
    }

    // The id directly above `nodeId`, or "" for a category root.
    function parentOf(categoryId: string, nodeId: string): string {
        var found = "";
        var walk = function (nodes) {
            if (!nodes || found) return;
            for (var i = 0; i < nodes.length; ++i) {
                var kids = nodes[i].children;
                if (!kids) continue;
                for (var j = 0; j < kids.length; ++j)
                    if (kids[j].id === nodeId) { found = nodes[i].id; return; }
                walk(kids);
            }
        };
        walk(treeFor(categoryId));
        return found;
    }

    // Ids above `nodeId`, nearest first. Empty for a root.
    function ancestorsOf(categoryId: string, nodeId: string): var {
        var chain = [];
        var cursor = parentOf(categoryId, nodeId);
        // Bounded because this walks a hand-edited file; a cycle introduced by a
        // typo should stop here rather than hang the shell.
        var guard = 0;
        while (cursor && guard < 64) {
            chain.push(cursor);
            cursor = parentOf(categoryId, cursor);
            ++guard;
        }
        return chain;
    }
}
