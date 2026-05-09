import XCTest
@testable import DebugProcessWatcher

final class ProcessMonitorTests: XCTestCase {
    func testParseLsofItemsAssociatesAddressesWithOwningProcess() {
        let input = """
        p101
        cnode
        PTCP
        n127.0.0.1:3000
        n*:3001
        p202
        cpython
        PTCP
        n[::1]:8000
        """

        let items = ProcessMonitor.parseLsofItems(from: input)

        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(items[0].pid, 101)
        XCTAssertEqual(items[0].command, "node")
        XCTAssertEqual(items[0].address, "127.0.0.1")
        XCTAssertEqual(items[0].port, 3000)
        XCTAssertEqual(items[1].pid, 101)
        XCTAssertEqual(items[1].command, "node")
        XCTAssertEqual(items[1].address, "*")
        XCTAssertEqual(items[1].port, 3001)
        XCTAssertEqual(items[2].pid, 202)
        XCTAssertEqual(items[2].command, "python")
        XCTAssertEqual(items[2].address, "[::1]")
        XCTAssertEqual(items[2].port, 8000)
    }

    func testParseCWDMapKeepsSuccessfulRowsWhenLsofReturnsNonZero() {
        let input = """
        p123
        n/Users/eugene/project-a
        p456
        n/Users/eugene/project-b
        """

        let cwdMap = ProcessMonitor.parseCWDMap(from: input)

        XCTAssertEqual(
            cwdMap,
            [
                123: "/Users/eugene/project-a",
                456: "/Users/eugene/project-b"
            ]
        )
    }

    func testParseAddressHandlesIPv4IPv6AndNoise() {
        XCTAssertEqual(ProcessMonitor.parseAddress("127.0.0.1:8080")?.0, "127.0.0.1")
        XCTAssertEqual(ProcessMonitor.parseAddress("127.0.0.1:8080")?.1, 8080)
        XCTAssertEqual(ProcessMonitor.parseAddress("[::1]:9000")?.0, "[::1]")
        XCTAssertEqual(ProcessMonitor.parseAddress("[::1]:9000")?.1, 9000)
        XCTAssertEqual(ProcessMonitor.parseAddress("*:5000 (LISTEN)")?.0, "*")
        XCTAssertEqual(ProcessMonitor.parseAddress("*:5000 (LISTEN)")?.1, 5000)
    }
}
