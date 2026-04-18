import Testing
import Foundation

// Local duplicate — tests cannot import the executable target
private enum PanelEdge: String { case left, right }

private func drawerOriginX(
    edge: PanelEdge,
    visibleMinX: CGFloat,
    visibleMaxX: CGFloat,
    width: CGFloat,
    ribbonWidth: CGFloat
) -> CGFloat {
    switch edge {
    case .right: return visibleMaxX - width - ribbonWidth
    case .left:  return visibleMinX + ribbonWidth
    }
}

private func ribbonOriginX(
    edge: PanelEdge,
    visibleMinX: CGFloat,
    visibleMaxX: CGFloat,
    ribbonWidth: CGFloat
) -> CGFloat {
    switch edge {
    case .right: return visibleMaxX - ribbonWidth
    case .left:  return visibleMinX
    }
}

private func inHoverZone(
    edge: PanelEdge,
    mouseX: CGFloat,
    visibleMinX: CGFloat,
    visibleMaxX: CGFloat,
    hoverWidth: CGFloat
) -> Bool {
    switch edge {
    case .right: return mouseX > visibleMaxX - hoverWidth
    case .left:  return mouseX < visibleMinX + hoverWidth
    }
}

@Suite("PanelEdge coordinate calculations")
struct PanelEdgeTests {

    @Test("Right edge: drawer origin is maxX - width - ribbon")
    func drawerOrigin_rightEdge() {
        #expect(drawerOriginX(edge: .right, visibleMinX: 0, visibleMaxX: 1440, width: 800, ribbonWidth: 5) == 635)
    }

    @Test("Left edge: drawer origin is minX + ribbon")
    func drawerOrigin_leftEdge() {
        #expect(drawerOriginX(edge: .left, visibleMinX: 0, visibleMaxX: 1440, width: 800, ribbonWidth: 5) == 5)
    }

    @Test("Right edge: ribbon origin is maxX - ribbonWidth")
    func ribbonOrigin_rightEdge() {
        #expect(ribbonOriginX(edge: .right, visibleMinX: 0, visibleMaxX: 1440, ribbonWidth: 5) == 1435)
    }

    @Test("Left edge: ribbon origin is minX")
    func ribbonOrigin_leftEdge() {
        #expect(ribbonOriginX(edge: .left, visibleMinX: 0, visibleMaxX: 1440, ribbonWidth: 5) == 0)
    }

    @Test("Right edge: mouse at right margin triggers hover")
    func hover_rightEdge_inZone() {
        #expect(inHoverZone(edge: .right, mouseX: 1420, visibleMinX: 0, visibleMaxX: 1440, hoverWidth: 25) == true)
    }

    @Test("Right edge: mouse not near right margin does not trigger hover")
    func hover_rightEdge_outOfZone() {
        #expect(inHoverZone(edge: .right, mouseX: 1000, visibleMinX: 0, visibleMaxX: 1440, hoverWidth: 25) == false)
    }

    @Test("Left edge: mouse at left margin triggers hover")
    func hover_leftEdge_inZone() {
        #expect(inHoverZone(edge: .left, mouseX: 10, visibleMinX: 0, visibleMaxX: 1440, hoverWidth: 25) == true)
    }

    @Test("Left edge: mouse not near left margin does not trigger hover")
    func hover_leftEdge_outOfZone() {
        #expect(inHoverZone(edge: .left, mouseX: 500, visibleMinX: 0, visibleMaxX: 1440, hoverWidth: 25) == false)
    }
}
