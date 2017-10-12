//
//  Views.swift
//  Laufpark
//
//  Created by Chris Eidhof on 17.09.17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import MapKit

func buildMapView() -> MKMapView {
    let view = MKMapView()
    view.showsCompass = true
    view.showsScale = true
    view.showsUserLocation = true
    view.mapType = .standard
    view.isRotateEnabled = false
    view.isPitchEnabled = false
    return view
}

