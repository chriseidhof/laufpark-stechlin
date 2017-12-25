//
//  LaufparkUITests.swift
//  LaufparkUITests
//
//  Created by Chris Eidhof on 23.12.17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import XCTest

class LaufparkUITests: XCTestCase {
    var app: XCUIApplication! = nil
    
    override func setUp() {
        super.setUp()
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        app = XCUIApplication()
        setupSnapshot(app)
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testMain() {
        app.launchArguments.append(contentsOf: ["--uitesting", "--testHome"])
        app.launch()
        snapshot("01HomeScreen")
    }
    
    func testSelection() {
        app.launchArguments.append(contentsOf: ["--uitesting", "--testSelection"])
        app.launch()
        app.maps.element.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.4)).tap()
        snapshot("02Selection")
        
    }
    
//    func testSatellite() {
//
//    }
}
