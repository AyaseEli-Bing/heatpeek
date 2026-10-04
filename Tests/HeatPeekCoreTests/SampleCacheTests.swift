import XCTest
@testable import HeatPeekCore

final class SampleCacheTests: XCTestCase {
    private let epoch = Date(timeIntervalSince1970: 1_800_000_000)

    func testEmptyCacheHasNothing() {
        XCTAssertNil(SampleCache<[Int]>(cadence: 5).cached(at: epoch))
    }

    func testValueIsReusedWithinCadence() {
        var cache = SampleCache<[Int]>(cadence: 5)
        cache.store([1, 2], at: epoch)
        XCTAssertEqual(cache.cached(at: epoch.addingTimeInterval(4.9)), [1, 2])
        XCTAssertNil(cache.cached(at: epoch.addingTimeInterval(5)), "cadence is exclusive")
    }

    func testStoreReplacesTheStamp() {
        var cache = SampleCache<[Int]>(cadence: 5)
        cache.store([1], at: epoch)
        cache.store([2], at: epoch.addingTimeInterval(4))
        XCTAssertEqual(cache.cached(at: epoch.addingTimeInterval(8)), [2])
    }
}
