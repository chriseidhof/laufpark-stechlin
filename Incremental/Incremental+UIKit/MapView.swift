//
//  MapView.swift
//  Incremental
//
//  Created by Chris Eidhof on 18.10.17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import MapKit

extension IBox where V: MKMapView {
    public func bind(annotations: [MKPointAnnotation], visible: I<Bool>) {
        disposables.append(visible.observe { [unowned self] value in
            if value {
                self.unbox.addAnnotations(annotations)
            } else {
                self.unbox.removeAnnotations(annotations)
            }
        })

    }
    
    public func bind(annotations: I<[MKPointAnnotation]>) {
        var previous: [MKPointAnnotation]? = nil
        disposables.append(annotations.observe { [unowned self] value in
            if let p = previous {
                self.unbox.removeAnnotations(p)
            }
            self.unbox.addAnnotations(value)
            previous = value
        })
        
    }
    
    public func bind<O: MKOverlay>(overlays: I<[O]>) {
        var previous: [O]? = nil
        disposables.append(overlays.observe { [unowned self] value in
            if let p = previous {
                self.unbox.removeOverlays(p)
            }
            print("overlays: \(value.count)")
            self.unbox.addOverlays(value)
            previous = value
        })
        
    }
    
    public var delegate: MKMapViewDelegate? {
        get { return unbox.delegate }
        set {
            if let existing = disposables.index(where: { ($0 as? MKMapViewDelegate) === unbox.delegate }) {
                disposables.remove(at: existing)
            }
            if let value = newValue { disposables.append(value) }
            unbox.delegate = newValue
        }
    }
}

public final class MapViewDelegate: NSObject, MKMapViewDelegate {
    let rendererForOverlay: (_ mapView: MKMapView, _ overlay: MKOverlay) -> MKOverlayRenderer
    let viewForAnnotation: (_ mapView: MKMapView, _ annotation: MKAnnotation) -> MKAnnotationView?
    let regionDidChangeAnimated: (_ mapView: MKMapView) -> ()
    let didSelectAnnotation: ((_ mapView: MKMapView, _ annotation: MKAnnotationView) -> ())?
    
    public init(rendererForOverlay: @escaping (_ mapView: MKMapView, _ overlay: MKOverlay) -> MKOverlayRenderer,
         viewForAnnotation: @escaping (_ mapView: MKMapView, _ annotation: MKAnnotation) -> MKAnnotationView?,
         regionDidChangeAnimated: @escaping (_ mapView: MKMapView) -> (),
         didSelectAnnotation: ((_ mapView: MKMapView, _ annotation: MKAnnotationView) -> ())? = nil) {
        self.rendererForOverlay = rendererForOverlay
        self.viewForAnnotation = viewForAnnotation
        self.regionDidChangeAnimated = regionDidChangeAnimated
        self.didSelectAnnotation = didSelectAnnotation
    }
    
    
    public func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        return rendererForOverlay(mapView, overlay)
    }
    
    public func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        return viewForAnnotation(mapView, annotation)
    }
    
    public func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        didSelectAnnotation?(mapView, view)
    }
    
    public func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        return regionDidChangeAnimated(mapView)
    }
}

public func newMapView() -> IBox<MKMapView> {
    let box = IBox(MKMapView())
    let view = box.unbox
    view.showsCompass = true
    view.showsScale = true
    view.showsUserLocation = true
    view.mapType = .standard
    view.isRotateEnabled = false
    view.isPitchEnabled = false
    return box
}

public func polygonRenderer(polygon: MKPolygon, strokeColor: I<IncColor>, fillColor: I<IncColor?>, alpha: I<CGFloat>, lineWidth: I<CGFloat>) -> IBox<MKPolygonRenderer> {
    let renderer = MKPolygonRenderer(polygon: polygon)
    let box = IBox(renderer)
    box.bind(strokeColor, to: \.strokeColor)
    box.bind(alpha, to : \.alpha)
    box.bind(lineWidth, to: \.lineWidth)
    box.bind(fillColor, to: \.fillColor)
    return box
}

public func annotation(location: I<CLLocationCoordinate2D>) -> IBox<MKPointAnnotation> {
    let result = IBox(MKPointAnnotation())
    result.bind(location, to: \.coordinate)
    return result
}
