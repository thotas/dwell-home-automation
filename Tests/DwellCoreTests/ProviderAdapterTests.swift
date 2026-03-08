import XCTest
@testable import DwellCore

final class ProviderAdapterTests: XCTestCase {
    func test_allProvidersAreRegistered() {
        let registry = ProviderRegistry.mockDefault()
        XCTAssertEqual(Set(registry.availableProviders), Set(Provider.allCases))
    }
}
