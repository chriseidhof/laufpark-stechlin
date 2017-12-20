//
//  ViewController.swift
//  Laufpark
//
//  Created by Chris Eidhof on 07.09.17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import UIKit
import MapKit
import Incremental

extension MKPolyline {
    convenience init(_ coords: [CLLocationCoordinate2D]) {
        self.init(coordinates: coords, count: coords.count)
    }
}

/// Returns a function that you can call to set the visible map rect
func addMapView(persistent: Input<StoredState>, state: Input<DisplayState>, rootView: IBox<UIView>) -> ((MKMapRect) -> ()) {
    var polygonToTrack: [MKPolygon:Track] = [:]
    let darkMode = persistent[\.satellite]

    func buildRenderer(_ polygon: MKPolygon) -> IBox<MKPolygonRenderer> {
        let track = polygonToTrack[polygon]!
        let isSelected = state.i[\.selection].map { $0 == track }
        let shouldHighlight = !state.i[\.hasSelection] || isSelected
        let lineColor = polygonToTrack[polygon]!.color.uiColor
        let fillColor = if_(isSelected, then: lineColor.withAlphaComponent(0.4), else: lineColor.withAlphaComponent(0.3))
        return polygonRenderer(polygon: polygon,
                               strokeColor: I(constant: lineColor),
                               fillColor: fillColor.map { $0 },
                               alpha: I(constant: 1.0),
                               lineWidth: if_(shouldHighlight, then: 3.0, else: 1.0))
    }
    
    let mapView: IBox<MKMapView> = newMapView()
    rootView.addSubview(mapView, constraints: sizeToParent())

    
    // MapView
    mapView.delegate = MapViewDelegate(rendererForOverlay: { [unowned mapView] mapView_, overlay in
        if let polygon = overlay as? MKPolygon {
            let renderer = buildRenderer(polygon)
            mapView.disposables.append(renderer)
            return renderer.unbox
        } else if let line = overlay as? MKPolyline {
            let result = MKPolylineRenderer(polyline: line)
            result.strokeColor = .black
            result.lineWidth = 5
            return result
        }
        return MKOverlayRenderer(overlay: overlay)
    }, viewForAnnotation: { (mapView, annotation) -> MKAnnotationView? in
            guard annotation is MKPointAnnotation else { return nil }
            if POI.all.contains(where: { $0.location == annotation.coordinate }) {
                let result: MKAnnotationView
                
                if #available(iOS 11.0, *) {
                    let ma = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: nil)
                    ma.glyphText = "⚑"
                    ma.glyphTintColor = .white
                    ma.markerTintColor = .lightGray
                    ma.titleVisibility = .adaptive
                    result = ma
                } else {
                    result = MKAnnotationView(annotation: annotation, reuseIdentifier: nil)
                    result.image = UIImage(named: "partner")!
                    result.frame.size = CGSize(width: 32, height: 32)
                }
                result.canShowCallout = true
                return result
            } else {
                let result = MKPinAnnotationView(annotation: annotation, reuseIdentifier: nil)
                result.pinTintColor = .red
                return result
            }
    }, regionDidChangeAnimated: { [unowned mapView] _ in
    }, didSelectAnnotation: { mapview, annotation in
    })
    
    mapView.disposables.append(state.i.map { $0.tracks }.observe { [unowned mapView] in
        mapView.unbox.removeOverlays(mapView.unbox.overlays)
        $0.forEach { track in
            let polygon = track.polygon
            polygonToTrack[polygon] = track
            mapView.unbox.add(polygon)
        }
    })
    
    mapView.bind(annotations: POI.all.map { poi in MKPointAnnotation(coordinate: poi.location, title: poi.name) }, visible: persistent[\.annotationsVisible])
    
    func selectTrack(mapView: IBox<MKMapView>, sender: UITapGestureRecognizer) {
        let point = sender.location(ofTouch: 0, in: mapView.unbox)
        let mapPoint = MKMapPointForCoordinate(mapView.unbox.convert(point, toCoordinateFrom: mapView.unbox))
        let possibilities = polygonToTrack.filter { (polygon, track) in
            let renderer = mapView.unbox.renderer(for: polygon) as! MKPolygonRenderer
            let point = renderer.point(for: mapPoint)
            return renderer.path.contains(point)
        }

        // in case of multiple matches, toggle between the selections, and start out with the smallest route
        if let s = state.i[\.selection].value ?? nil, possibilities.count > 1 && possibilities.values.contains(s) {
            state.change {
                $0.selection = possibilities.lazy.sorted { $0.key.pointCount < $1.key.pointCount }.first(where: { $0.value != s }).map { $0.value }
            }
        } else {
            state.change { $0.selection = possibilities.first?.value }
        }
    }
    
    do { // routing
        let waypoints: I<[Coordinate]> = state.i.map { $0.route?.wayPoints ?? [] }
        let waypointAnnotations = waypoints.map { coordinates in
            coordinates.map {
                MKPointAnnotation(coordinate: $0.clLocationCoordinate, title: "")
            }
        }
        mapView.bind(annotations: waypointAnnotations)
        
        let allRoutePoints: I<[Coordinate]> = state.i.map { $0.route?.allPoints(tracks: $0.tracks).map { $0.coordinate } ?? [] }
        let lines: I<[MKPolyline]> = allRoutePoints.map {
            $0.isEmpty ? [] : [MKPolyline($0.map { $0.clLocationCoordinate })]
        }
        mapView.bind(overlays: lines)
        
        func addWaypoint(mapView: IBox<MKMapView>, sender: UITapGestureRecognizer) {
            let point = sender.location(in: mapView.unbox)
            let coordinate = mapView.unbox.convert(point, toCoordinateFrom: mapView.unbox)
            let mapPoint = MKMapPointForCoordinate(coordinate)
            
            let region = MKCoordinateRegionMakeWithDistance(mapView.unbox.centerCoordinate, 1, 1)
            let rect = mapView.unbox.convertRegion(region, toRectTo: mapView.unbox)
            let meterPerPixel = Double(1/rect.width)
            let tresholdPixels: Double = 40
            let treshold = meterPerPixel*tresholdPixels
            
            let possibilities = polygonToTrack.filter { (polygon, track) in
                polygon.boundingMapRect.contains(mapPoint)
            }
            
            if let (track, segment) = possibilities.flatMap({ (_,track) in track.segment(closestTo: coordinate, maxDistance: treshold).map { (track, $0) }}).first {
                state.change {
                    if let r = $0.route, r.startingPoint.coordinate.clLocationCoordinate.squaredDistanceApproximation(to: coordinate).squareRoot() < treshold {
                        // close the route
                        let endPoint = r.startingPoint.coordinate.clLocationCoordinate
                        let segment = r.startingPoint.track.segment(closestTo: endPoint, maxDistance: treshold)!
                        $0.addWayPoint(track: track, coordinate: r.startingPoint.coordinate.clLocationCoordinate, segment: segment)
                    } else {
                        let pointOnSegment = coordinate.closestPointOn(segment: segment)
                        $0.addWayPoint(track: track, coordinate: pointOnSegment, segment: segment)
                    }
                }
            }
        }
        
        
        mapView.addGestureRecognizer(tapGestureRecognizer { [unowned mapView] sender in
            if state.i.value.routing {
                addWaypoint(mapView: mapView, sender: sender)
            } else {
                selectTrack(mapView: mapView, sender: sender)
            }
        })
    }
    mapView.bind(persistent.i.map { $0.satellite ? .hybrid : .standard }, to: \.mapType)

    let draggedLocation = state.i.map { $0.draggedLocation }

    // Dragged Point Annotation
    let draggedPoint: I<CLLocationCoordinate2D> = draggedLocation.map {
        $0?.1.coordinate ?? CLLocationCoordinate2D()
    }
    let draggedPointAnnotation = annotation(location: draggedPoint)
    mapView.unbox.addAnnotation(draggedPointAnnotation.unbox)
    
    // Center the map location on position dragging
    mapView.disposables.append(draggedLocation.observe { [unowned mapView] x in
        guard let (_, location) = x else { return }
        // todo subtract the height of the trackInfo box (if selected)
        if !mapView.unbox.annotations(in: mapView.unbox.visibleMapRect).contains(draggedPointAnnotation.unbox) {
            mapView.unbox.setCenter(location.coordinate, animated: true)
        }
    })
    
    return { mapView.unbox.setVisibleMapRect($0, animated: true) }
}

func build(persistent: Input<StoredState>, state: Input<DisplayState>, rootView: IBox<UIView>, presentInfo: @escaping () -> ()) -> (MKMapRect) -> () {
    let darkMode = persistent[\.satellite]
    let setMapRect = addMapView(persistent: persistent, state: state, rootView: rootView)
    
    let draggedLocation = state.i.map { $0.draggedLocation }
    
    // Track Info View
    let position: I<CGFloat?> = draggedLocation.map { ($0?.0).map { CGFloat($0) } }
    let elevations = state.i[\.selection].map(eq: { _, _ in false }) { $0?.elevationProfile }
    let points: I<[LineView.Point]> = elevations.map { ele in
        ele.map { profile in
            profile.map { LineView.Point(x: $0.distance, y: $0.elevation) }
        } ?? []
    }
    let (trackInfo, location) = trackInfoView(position: position, points: points, track: state.i[\.selection], darkMode: darkMode)
    trackInfo.disposables.append(location.observe { loc in
        state.change { $0.trackPosition = loc }
    })
    
    func switchWith(label text: String, value: I<Bool>, textColor: I<UIColor>, action: @escaping (Bool) -> ()) -> IBox<UIView> {
        let switchLabel = label(text: I(constant: text), textColor: textColor.map { $0 }, font: I(constant: Stylesheet.smallFont) )
        switchLabel.unbox.textAlignment = .left
        let switch_ = uiSwitch(value: value, valueChange: action)
        let stack = stackView(arrangedSubviews: [switch_.cast, switchLabel.cast], axis: .vertical)
        return stack.cast
    }
    
    let textColor = darkMode.map { $0 ? UIColor.white : .black }
    
    let inset: CGFloat = 10

    // Info button
    let infoButton = button(type: .infoLight, backgroundColor: I(constant: .clear), tintColor: textColor, onTap: {
        presentInfo()
    })
    rootView.addSubview(infoButton.cast, constraints: [
        equal(\.safeAreaLayoutGuide.bottomAnchor, to: \.bottomAnchor, constant: inset), equal(\.trailingAnchor, inset)
        ])

    let satelliteValue = persistent.i.map { $0.satellite ? 1 : 0 }
    let satellite = segmentedControl(segments: I(constant: [.init(image: #imageLiteral(resourceName: "btn_map.png"), title: .karte), .init(image: #imageLiteral(resourceName: "btn_satellite.png"), title: .satellite)]), value: satelliteValue, textColor: textColor, selectedTextColor: textColor, onChange: { value in
        persistent.change {
            $0.satellite = value == 1
        }
    })
    
    func headerButton(title: String, image: UIImage, color: I<UIColor>, action: @escaping () -> ()) -> IBox<UIView> {
        let button = IBox(segment(image.withRenderingMode(.alwaysTemplate), title: title, textColor: color.value, size: CGSize(width: 55, height: 55))) //todo fix for color scheme change)
        button.unbox.isUserInteractionEnabled = true
        button.bind(color, to: \.textColor)
        button.addGestureRecognizer(tapGestureRecognizer { _ in
            action()
        })
        return button.cast
    }
    
    let routeColor = if_(state[\.routing], then: I(constant: Stylesheet.blue), else: textColor)
    let routeButton = headerButton(title: .route, image: #imageLiteral(resourceName: "btn_route.png"), color: routeColor) { state.change { $0.routing.toggle() }} // todo localize
    let closeButton = headerButton(title: .close, image: #imageLiteral(resourceName: "btn_close.png"), color: textColor, action: { persistent.change { $0.showConfiguration.toggle() } }) // todo localize

    
    let selectionColor = state.i[\.selection].map { $0?.color.uiColor } ?? if_(persistent.i.map { $0.satellite }, then: UIColor.white, else: .black)
    
    func border() -> IBox<UIView> {
        let _border = UIView()
        _border.heightAnchor.constraint(equalToConstant: 1).isActive = true
        let border = IBox(_border)
        border.bind(selectionColor, to: \.backgroundColor)
        return border
    }
    
    func blurredView<V: UIView>(borderAnchor: @escaping Constraint, child: IBox<V>, inset: CGFloat = 10) -> IBox<UIVisualEffectView> {
        let result = effectView(effect: darkMode.map { UIBlurEffect(style: $0 ? .dark : .light)})
        result.addSubview(border(), path: \.contentView, constraints: [equal(\.leadingAnchor), equal(\.trailingAnchor), borderAnchor])
        result.addSubview(child, path: \.contentView, constraints: [equal(\.leftAnchor, constant: I(constant: -inset)), equal(\.safeAreaLayoutGuide.topAnchor, to: \.topAnchor, constant: I(constant: -inset)), equal(\.rightAnchor, constant: I(constant: inset))])
        return result
    }
    
    
    // Blurred Top View (Configuration)
    let blurredTopViewHeight: CGFloat = 140
    let topOffset: I<CGFloat> = if_(persistent.i[\.showConfiguration], then: 0, else: blurredTopViewHeight + 1)
    
    let topStackview = stackView(arrangedSubviews: [/*accomodation.cast, */ satellite.cast, routeButton.cast, closeButton.cast], axis: .horizontal)
    let topContainr = IBox(UIView())
    topContainr.addSubview(topStackview, constraints: [equal(\.topAnchor), equal(\.rightAnchor), equal(\.leftAnchor), equal(\.bottomAnchor)])
    let topView = blurredView(borderAnchor: equal(\.bottomAnchor), child: topContainr, inset: 25)
    
    rootView.addSubview(topView, constraints: [equal(\.leftAnchor), equal(\.rightAnchor), equal(\.topAnchor, constant: topOffset, animation: Stylesheet.dampingAnimation), equalTo(constant: I(constant: blurredTopViewHeight), \.heightAnchor)])
    
    topStackview.unbox.alignment = .top
    topStackview.unbox.distribution = .equalSpacing
    
    // Blurred Bottom View (Showing the current track)
    let bottomView = blurredView(borderAnchor: equal(\.topAnchor), child: trackInfo)
    
    let trackInfoHeight: CGFloat = 120
    let blurredViewHeight = trackInfoHeight + 2 * inset
    let bottomOffset: I<CGFloat> = if_(state.i[\.hasSelection], then: 0, else: -(blurredViewHeight + 20))
    trackInfo.unbox.heightAnchor.constraint(equalToConstant: trackInfoHeight).isActive = true
    
    rootView.addSubview(bottomView.map { $0 }, constraints: [equal(\.leftAnchor), equal(\.rightAnchor), equalTo(constant: I(constant: blurredViewHeight), \.heightAnchor), equal(\.bottomAnchor, constant: bottomOffset, animation: Stylesheet.dampingAnimation)])
    
    // Number View
    let trackNumber = trackNumberView(state.i.map { $0.selection} ?? Track(color: .blue, number: 0, name: "", points: []))
    rootView.addSubview(trackNumber)
    let yConstraint = bottomView.unbox.topAnchor.constraint(equalTo: trackNumber.unbox.centerYAnchor)
    let xConstraint = bottomView.unbox.rightAnchor.constraint(equalTo: trackNumber.unbox.centerXAnchor, constant: 42)
    NSLayoutConstraint.activate([xConstraint,yConstraint])
    
    let formatter = MKDistanceFormatter()

    do { // Routing info view
        // todo: compute the shortest path async
        // todo: show the elevation graph
        // todo: allow the user to save the route
        let routeInfo: I<String> = state.i.map {
            if $0.graph == nil {
                return .loadingGraph
            }
            if let r = $0.route {
                return formatter.string(fromDistance: r.distance)
            } else {
                return .tapAnyWhereToStart
            }
        }
        let routingInfo = label(text: routeInfo, textColor: textColor.map { $0 })
        routingInfo.unbox.adjustsFontSizeToFitWidth = true
        let removeLastWayPointButton = button(title: I(constant: .undo), backgroundColor: I(constant: .clear), titleColor: textColor.map { $0 } ) { state.change {
            $0.removeLastWayPoint()
        }}
        let routeHasWaypoints = state.i.map { $0.route != nil && $0.route!.wayPoints.count > 0 }
        removeLastWayPointButton.bind(!routeHasWaypoints, to: \.hidden)
        let infoStack = stackView(arrangedSubviews: [routingInfo.cast, removeLastWayPointButton.cast], axis: .horizontal)
        let progress = progressView(progress: state[\.graphBuildingProgress])
//        progress.unbox.heightAnchor.constraint(equalToConstant: 1)
        let hasGraph = state.i.map { $0.graph != nil }
        progress.bind(hasGraph, to: \.hidden)
        let routingStack = stackView(arrangedSubviews: [infoStack.cast, progress.cast])
        let bottomRoutingView = blurredView(borderAnchor: equal(\.topAnchor), child: routingStack)
        
        let bottomHeight: I<CGFloat> = if_(hasGraph, then: 50, else: 70)
        let bottomRoutingOffset: I<CGFloat> = if_(state.i[\.routing], then: I(constant: 0), else: -bottomHeight)

        rootView.addSubview(bottomRoutingView.map { $0 }, constraints: [equal(\.leftAnchor), equal(\.rightAnchor), equalTo(constant: bottomHeight, \.heightAnchor), equal(\.bottomAnchor, constant: bottomRoutingOffset, animation: Stylesheet.dampingAnimation)])
    }

    
    // Loading Indicator
    let isLoading = state[\.loading] || (state[\.routing] && (state.i.map { $0.graph } == nil))
    let loadingIndicator = activityIndicator(style: darkMode.map { $0 ? .gray : .white }, animating: isLoading)
    rootView.addSubview(loadingIndicator, constraints: [equal(\.centerXAnchor), equal(\.centerXAnchor)])
    
    
    // Toggle Map Button
    let toggleMapButton = button(type: .custom, title: I(constant: "…"), backgroundColor: I(constant: UIColor(white: 1, alpha: 0.8)), titleColor: I(constant: .black), onTap: {
        persistent.change { $0.showConfiguration.toggle() }
    })
    toggleMapButton.unbox.layer.cornerRadius = 3
    rootView.addSubview(toggleMapButton.cast, constraints: [equal(\.safeAreaLayoutGuide.topAnchor, to: \.topAnchor, constant: -inset), equal(\.trailingAnchor, 10)])
    toggleMapButton.bind(persistent.i.map { $0.showConfiguration }, to: \.hidden)
    toggleMapButton.unbox.widthAnchor.constraint(equalToConstant: 40).isActive = true
    toggleMapButton.unbox.heightAnchor.constraint(equalToConstant: 40).isActive = true
    
	
    
//    // Toggle Routing Button
//    let toggleRoutingButton = button(type: .custom, title: I(constant: "Route"), backgroundColor: I(constant: UIColor(white: 1, alpha: 0.8)), titleColor: I(constant: .black), onTap: {
//        state.change {
//            if $0.routing {
//                $0.routing = false
//                $0.route = nil
//            } else {
//                $0.routing = true
//                $0.selection = nil
//            }
//        }
//    })
//    toggleRoutingButton.unbox.layer.cornerRadius = 3
//    // todo: the layout is a bit of a hack.
//    rootView.addSubview(toggleRoutingButton.cast, constraints: [equal(\.safeAreaLayoutGuide.topAnchor, to: \.topAnchor, constant: -(inset + 50)), equal(\.trailingAnchor, 10)])
    
    return setMapRect
}

class ViewController: UIViewController {
    let state: Input<DisplayState>
    let persistentState: Input<StoredState> = persistent(key: "de.laufpark-stechlin.state", initial: StoredState())
    var rootView: IBox<UIView>!

    var disposables: [Any] = []
    var locationManager: CLLocationManager?
    var setMapRect: ((MKMapRect) -> ())?
    
    lazy var graphURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("graph.json")

    init() {
        state = Input(DisplayState(tracks: []))

        super.init(nibName: nil, bundle: nil)
        
        if let g = readGraph(url: graphURL) {
            state.change { $0.graph = g }
        }
        
        var alreadyBuilding = false
        disposables.append(state.i.observe { [unowned self] newValue in
            if newValue.routing && newValue.graph == nil && !alreadyBuilding {
                alreadyBuilding = true
                DispatchQueue(label: "graph builder").async {

                    let graph = time { buildGraph(tracks: newValue.tracks, url: self.graphURL, progress: { p in
                        DispatchQueue.main.async {
                            self.state.change { $0.graphBuildingProgress = p }
                        }
                    }) }
                    DispatchQueue.main.async { [unowned self] in
                        self.state.change { $0.graph = graph }
                    }
                }
            }
        })

    }
    
    func setTracks(_ t: [Track]) {
        state.change { $0.tracks = t }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError()
    }
    
    override func viewDidLoad() {
        rootView = IBox(view!)
        setMapRect = build(persistent: persistentState, state: state, rootView: rootView, presentInfo: { [unowned self] in
            let infoVC = InfoViewController()
            infoVC.modalPresentationStyle = .formSheet
            self.present(infoVC, animated: true)
        })
    }
    
    func resetMapRect() {
        setMapRect?(MKMapRect(origin: MKMapPoint(x: 143758507.60971117, y: 86968700.835495561), size: MKMapSize(width: 437860.61378830671, height: 749836.27541357279)))
    }
    
    override func viewDidAppear(_ animated: Bool) {
        resetMapRect()
        
        if CLLocationManager.authorizationStatus() == .notDetermined {
            locationManager = CLLocationManager()
            locationManager!.requestWhenInUseAuthorization()
        }
    }
}

class InfoViewController: UIViewController {
    override func viewDidLoad() {
        let textView = UITextView()
        let url = Bundle.main.url(forResource: "Attribution_en", withExtension: "rtf")!
        let attributedString = try! NSAttributedString(url: url, options: [:], documentAttributes: nil)
        textView.attributedText = attributedString
        textView.isEditable = false
        textView.contentInset = .init(top: 20, left: 20, bottom: 20, right: 20)
        view.addSubview(textView, constraints: [
            textView.topAnchor.constraint(equalTo: view.topAnchor),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        ])
    }
}

extension String {
    static let tapAnyWhereToStart = NSLocalizedString("tapAnyWhereToStart", comment: "")
    static let loadingGraph = NSLocalizedString("loadingGraph", comment: "")
    static let karte = NSLocalizedString("karte", comment: "")
    static let satellite = NSLocalizedString("satellite", comment: "")
    static let route = NSLocalizedString("route", comment: "")
    static let close = NSLocalizedString("close", comment: "")
    static let undo = NSLocalizedString("undo", comment: "")
}
