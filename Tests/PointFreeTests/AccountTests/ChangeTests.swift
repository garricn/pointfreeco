import Either
import Html
import HtmlPrettyPrint
import HttpPipeline
@testable import PointFree
import PointFreeTestSupport
import Prelude
import Optics
import SnapshotTesting
import XCTest
#if !os(Linux)
import WebKit
#endif

final class ChangeTests: TestCase {
  override func setUp() {
    super.setUp()
    AppEnvironment.push(\.database .~ .mock)
  }
  
  override func tearDown() {
    super.tearDown()
    AppEnvironment.pop()
  }
  
  func testChangeShow() {
    let conn = connection(from: request(to: .account(.subscription(.change(.show))), session: .loggedIn))
    let result = conn |> siteMiddleware
    
    assertSnapshot(matching: result.perform())
    
    #if !os(Linux)
    if #available(OSX 10.13, *), ProcessInfo.processInfo.environment["CIRCLECI"] == nil {
      let webView = WKWebView(frame: .init(x: 0, y: 0, width: 1080, height: 1800))
      webView.loadHTMLString(String(data: result.perform().data, encoding: .utf8)!, baseURL: nil)
      assertSnapshot(matching: webView, named: "desktop")
      
      webView.frame.size.width = 400
      assertSnapshot(matching: webView, named: "mobile")
    }
    #endif
  }
  
  func testChangeShowLoggedOut() {
    let conn = connection(from: request(to: .account(.subscription(.change(.show))), session: .loggedOut))
    let result = conn |> siteMiddleware
    
    assertSnapshot(matching: result.perform())
  }
  
  func testChangeShowNoSubscription() {
    AppEnvironment.with(\.stripe.fetchSubscription .~ const(throwE(unit))) {
      let conn = connection(from: request(to: .account(.subscription(.change(.show))), session: .loggedIn))
      let result = conn |> siteMiddleware
      
      assertSnapshot(matching: result.perform())
    }
  }
  
  func testChangeShowCancelingSubscription() {
    AppEnvironment.with(\.stripe.fetchSubscription .~ const(pure(.canceling))) {
      let conn = connection(from: request(to: .account(.subscription(.change(.show))), session: .loggedIn))
      let result = conn |> siteMiddleware
      
      assertSnapshot(matching: result.perform())
      
      #if !os(Linux)
      if #available(OSX 10.13, *), ProcessInfo.processInfo.environment["CIRCLECI"] == nil {
        let webView = WKWebView(frame: .init(x: 0, y: 0, width: 1080, height: 1800))
        webView.loadHTMLString(String(data: result.perform().data, encoding: .utf8)!, baseURL: nil)
        assertSnapshot(matching: webView, named: "desktop")
        
        webView.frame.size.width = 400
        assertSnapshot(matching: webView, named: "mobile")
      }
      #endif
    }
  }
  
  func testChangeShowCanceledSubscription() {
    AppEnvironment.with(\.stripe.fetchSubscription .~ const(pure(.canceled))) {
      let conn = connection(from: request(to: .account(.subscription(.change(.show))), session: .loggedIn))
      let result = conn |> siteMiddleware
      
      assertSnapshot(matching: result.perform())
    }
  }
  
  func testChangeUpdateUpgradeIndividualPlan() {
    #if !os(Linux)
    AppEnvironment.with(\.stripe.fetchSubscription .~ const(pure(.individualMonthly))) {
      let conn = connection(from: request(to: .account(.subscription(.change(.update(.individualYearly)))), session: .loggedIn))
      let result = conn |> siteMiddleware
      
      assertSnapshot(matching: result.perform())
    }
    #endif
  }
  
  func testChangeUpdateDowngradeIndividualPlan() {
    #if !os(Linux)
    AppEnvironment.with(\.stripe.fetchSubscription .~ const(pure(.individualYearly))) {
      let conn = connection(from: request(to: .account(.subscription(.change(.update(.individualMonthly)))), session: .loggedIn))
      let result = conn |> siteMiddleware
      
      assertSnapshot(matching: result.perform())
    }
    #endif
  }
  
  func testChangeUpdateUpgradeTeamPlan() {
    #if !os(Linux)
    AppEnvironment.with(\.stripe.fetchSubscription .~ const(pure(.teamMonthly))) {
      let conn = connection(from: request(to: .account(.subscription(.change(.update(.teamYearly)))), session: .loggedIn))
      let result = conn |> siteMiddleware
      
      assertSnapshot(matching: result.perform())
    }
    #endif
  }
  
  func testChangeUpdateDowngradeTeamPlan() {
    #if !os(Linux)
    AppEnvironment.with(\.stripe.fetchSubscription .~ const(pure(.individualYearly))) {
      let conn = connection(from: request(to: .account(.subscription(.change(.update(.teamMonthly)))), session: .loggedIn))
      let result = conn |> siteMiddleware
      
      assertSnapshot(matching: result.perform())
    }
    #endif
  }
  
  func testChangeUpdateAddSeatsIndividualPlan() {
    #if !os(Linux)
    AppEnvironment.with(\.stripe.fetchSubscription .~ const(pure(.individualMonthly))) {
      let conn = connection(from: request(to: .account(.subscription(.change(.update(.teamMonthly)))), session: .loggedIn))
      let result = conn |> siteMiddleware
      
      assertSnapshot(matching: result.perform())
    }
    #endif
  }
  
  func testChangeUpdateAddSeatsTeamPlan() {
    #if !os(Linux)
    AppEnvironment.with(\.stripe.fetchSubscription .~ const(pure(.teamMonthly))) {
      let conn = connection(from: request(to: .account(.subscription(.change(.update(.teamMonthly |> \.quantity +~ 4)))), session: .loggedIn))
      let result = conn |> siteMiddleware
      
      assertSnapshot(matching: result.perform())
    }
    #endif
  }
  
  func testChangeUpdateRemoveSeats() {
    #if !os(Linux)
    AppEnvironment.with(
      (\.stripe.fetchSubscription .~ const(pure(.teamMonthly)))
        <> (\.stripe.invoiceCustomer .~ { _ in
          XCTFail()
          return pure(.mock)
          })
    ) {
      
      let conn = connection(from: request(to: .account(.subscription(.change(.update(.teamMonthly |> \.quantity -~ 1)))), session: .loggedIn))
      let result = conn |> siteMiddleware
      
      assertSnapshot(matching: result.perform())
    }
    #endif
  }
  
  func testChangeUpdateRemoveSeatsInvalidNumber() {
    #if !os(Linux)
    let subscription = Stripe.Subscription.mock
      |> \.plan .~ .teamYearly
      |> \.quantity .~ 5
    
    let env: (Environment) -> Environment =
      (\.database.fetchSubscriptionTeammatesByOwnerId .~ const(pure([.teammate, .teammate])))
        >>> (\.database.fetchTeamInvites .~ const(pure([.mock, .mock])))
        >>> (\.stripe.fetchSubscription .~ const(pure(subscription)))
    
    AppEnvironment.with(env) {
      let conn = connection(from: request(to: .account(.subscription(.change(.update(.teamYearly |> \.quantity .~ 3)))), session: .loggedIn))
      let result = conn |> siteMiddleware
      
      assertSnapshot(matching: result.perform())
    }
    #endif
  }
}
