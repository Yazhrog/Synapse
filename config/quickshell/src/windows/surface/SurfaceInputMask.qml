import QtQuick
import Quickshell
import "../../"

// SurfaceInputMask — the input mask of a DynamicSurface: only the visible
// frame takes clicks. The screen edges only take clicks where there is a
// border (frame) or the bar (bar); in pills the gaps let clicks through.
// Also covers the border triggers, the screen-recording options, the whole
// screen while the click shield is on, and nothing while the frame is
// hidden over a fullscreen window. The surface uses `region` as its mask.

Item {
    id: m

    // The DynamicSurface: style, border, notch and region geometry
    required property var surface
    // SurfaceTriggers (its zones) and the screen-recording options strip
    required property Item triggers
    required property Item recOptions

    readonly property int _edge:    surface.framed ? Math.max(1, surface.borderWidth) : 0
    // At least 1 px, so the focus-mode dashboard strip stays clickable.
    readonly property int _topEdge: surface.barStyle === "bar" ? Math.max(1, Math.ceil(surface.notchBottom)) : _edge

    component RegionMask: Item {
        property rect r
        x: r.x; y: r.y; width: r.width; height: r.height
    }

    Item { id: maskTop;    x: 0; y: 0; width: m.surface.width; height: m._topEdge }
    Item { id: maskLeft;   x: 0; y: 0; width: m._edge; height: m.surface.height }
    Item { id: maskRight;  x: m.surface.width - m._edge; y: 0; width: m._edge; height: m.surface.height }
    Item { id: maskBottom; x: 0; y: m.surface.height - m._edge; width: m.surface.width; height: m._edge }
    Item { id: maskLeftNotch;   x: 0; y: 0; width: m.surface.lWidth; height: m.surface.notchBottom }
    Item { id: maskCenterNotch; x: (m.surface.width - m.surface.cWidth) / 2; y: 0; width: m.surface.cWidth; height: m.surface.centerBottom }
    Item { id: maskRightNotch;  x: m.surface.width - m.surface.rWidth; y: 0; width: m.surface.rWidth; height: m.surface.rightBottom }
    RegionMask { id: maskLeftCenter;   r: m.surface.regionRect("leftCenter") }
    RegionMask { id: maskRightCenter;  r: m.surface.regionRect("rightCenter") }
    RegionMask { id: maskBottomCenter; r: m.surface.regionRect("bottomCenter") }
    RegionMask { id: maskBottomRight;  r: m.surface.regionRect("bottomRight") }
    Item { id: maskRecOptions; x: m.recOptions.x; y: m.recOptions.y
           width: m.recOptions.visible ? m.recOptions.width : 0; height: m.recOptions.visible ? m.recOptions.height : 0 }
    Item { id: maskShield;  width: m.surface.shieldActive ? m.surface.width : 0; height: m.surface.shieldActive ? m.surface.height : 0 }
    Item { id: maskVisible; width: m.surface.frameHidden ? 0 : m.surface.width; height: m.surface.frameHidden ? 0 : m.surface.height }

    readonly property Region region: Region {
        Region { item: maskTop;          intersection: Intersection.Combine }
        Region { item: maskLeft;         intersection: Intersection.Combine }
        Region { item: maskRight;        intersection: Intersection.Combine }
        Region { item: maskBottom;       intersection: Intersection.Combine }
        Region { item: maskLeftNotch;    intersection: Intersection.Combine }
        Region { item: maskCenterNotch;  intersection: Intersection.Combine }
        Region { item: maskRightNotch;   intersection: Intersection.Combine }
        Region { item: maskLeftCenter;   intersection: Intersection.Combine }
        Region { item: maskRightCenter;  intersection: Intersection.Combine }
        Region { item: maskBottomCenter; intersection: Intersection.Combine }
        Region { item: maskBottomRight;  intersection: Intersection.Combine }
        Region { item: m.triggers.rightZone;  intersection: Intersection.Combine }
        Region { item: m.triggers.bottomZone; intersection: Intersection.Combine }
        Region { item: m.triggers.cornerZone; intersection: Intersection.Combine }
        Region { item: maskShield;       intersection: Intersection.Combine }
        Region { item: maskRecOptions;   intersection: Intersection.Combine }
        // Hidden over a fullscreen window: take no input at all.
        Region { item: maskVisible;      intersection: Intersection.Intersect }
    }
}
