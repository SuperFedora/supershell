import QtQuick
import QtQuick.Shapes

// ConcaveFillet — the single corner primitive shared by the bar and every surface attached to it
// (STYLE_RESEARCH.md §2 concave bar-attached popout, §3 rounded screen corners). It paints one
// `size` px corner box in the bar/drawer background colour so a flush bar melts into its surroundings:
//   concave: false -> the quarter disc: a flush top bar rounds off at the screen corners.
//   concave: true  -> the complementary crescent: the bar/drawer junction reads as a notch.
// `corner` names the OUTER corner of the box (TopLeft/TopRight/BottomLeft/BottomRight); the arc centre
// is always the diagonally opposite one and the sweep is exactly 90 degrees, per the survey recipe.
// Painted only — the Wayland input mask stays rectangular, so this never steals a click.
Shape {
    id: root
    property int size: Theme.radius > 0 ? Theme.radius : 0
    property color color: Theme.bg
    property color strokeColor: "transparent"
    property real strokeWidth: 0
    property bool concave: false
    property string corner: "TopLeft"
    visible: root.size > 0
    implicitWidth: root.size
    implicitHeight: root.size
    preferredRendererType: Shape.CurveRenderer
    antialiasing: true
    layer.enabled: root.size > 0
    layer.smooth: true

    // Arc geometry: centre on the opposite corner, radius = full size, sweep 90 degrees either way.
    // The sweep sign is what makes the disc bulge toward (TopLeft/BottomRight) or away from the corner.
    readonly property var g: {
        const s = root.size, left = root.corner === "TopLeft" || root.corner === "BottomLeft";
        const top = root.corner === "TopLeft" || root.corner === "TopRight";
        const cx = left ? s : 0, cy = top ? s : 0, a = top ? 270 : 90, rad = a * Math.PI / 180;
        return {
            cx: cx, cy: cy, a: a, w: (root.corner === "TopLeft" || root.corner === "BottomRight") ? -90 : 90,
            sx: cx + s * Math.cos(rad), sy: cy + s * Math.sin(rad),
            tx: root.concave ? s - cx : cx, ty: root.concave ? s - cy : cy
        };
    }

    ShapePath {
        strokeWidth: 0
        fillColor: root.color
        pathHints: ShapePath.PathSolid & ShapePath.PathNonIntersecting
        PathLine { x: root.g.sx; y: root.g.sy }
        PathAngleArc {
            moveToStart: false
            centerX: root.g.cx; centerY: root.g.cy
            radiusX: root.size; radiusY: root.size
            startAngle: root.g.a; sweepAngle: root.g.w
        }
        PathLine { x: root.g.tx; y: root.g.ty }
    }
    ShapePath {
        strokeWidth: root.strokeWidth
        strokeColor: root.strokeWidth > 0 ? root.strokeColor : "transparent"
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        PathAngleArc {
            centerX: root.g.cx; centerY: root.g.cy
            radiusX: Math.max(1, root.size - root.strokeWidth / 2); radiusY: Math.max(1, root.size - root.strokeWidth / 2)
            startAngle: root.g.a; sweepAngle: root.g.w
        }
    }
}
