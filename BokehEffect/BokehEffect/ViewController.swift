//
//  ViewController.swift
//  BokehEffect
//
//  Created by frank.zhang on 2018/12/10.
//  Copyright © 2018 Frank.zhang. All rights reserved.
//

import UIKit
import Accelerate
import simd

class ViewController: UIViewController {
    @IBOutlet weak var image: UIImageView!
    @IBOutlet weak var toolBar: UIToolbar!
    
    let cgImage: CGImage = {
        guard let cgImage = UIImage(named: "fruits")?.cgImage else{
            fatalError("Unable to get CGImage")
        }
        return cgImage
    }()
    
    lazy var format: vImage_CGImageFormat = {
        guard let sourceColorSpace = cgImage.colorSpace else{
            fatalError("Unable to get color space")
        }
        return vImage_CGImageFormat(bitsPerComponent: UInt32(cgImage.bitsPerComponent), bitsPerPixel: UInt32(cgImage.bitsPerPixel), colorSpace: Unmanaged.passRetained(sourceColorSpace), bitmapInfo: cgImage.bitmapInfo, version: 0, decode: nil, renderingIntent: cgImage.renderingIntent)
    }()
    
    lazy var sourceBuffer: vImage_Buffer = {
        var sourceImageBuffer = vImage_Buffer()
        vImageBuffer_InitWithCGImage(&sourceImageBuffer, &format, nil, cgImage, vImage_Flags(kvImageNoFlags))
        var scaledBuffer = vImage_Buffer()
        vImageBuffer_Init(&scaledBuffer, sourceImageBuffer.height / 3, sourceImageBuffer.width / 3, format.bitsPerPixel, vImage_Flags(kvImageNoFlags))
        vImageScale_ARGB8888(&sourceImageBuffer, &scaledBuffer, nil, vImage_Flags(kvImageNoFlags))
        return scaledBuffer
    }()
    
    lazy var destinationBuffer: vImage_Buffer = {
        var destinationBuffer = vImage_Buffer()
        vImageBuffer_Init(&destinationBuffer, sourceBuffer.height, sourceBuffer.width, format.bitsPerPixel, vImage_Flags(kvImageNoFlags))
        return destinationBuffer
    }()
    
    var numSides = 6
    let radius = 20
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initUI()
        dilate()
    }
    
    func initUI(){
        let items = (1...10).map{"\($0)"}
        let segmentedControl = UISegmentedControl(items: items)
        segmentedControl.selectedSegmentIndex = items.firstIndex(of: String(numSides)) ?? UISegmentedControl.noSegment
        segmentedControl.addTarget(self, action: #selector(segmentedControlChangeHandler(segmentedControl:)), for: .valueChanged)
        toolBar.setItems([UIBarButtonItem(customView: segmentedControl)], animated: false)
    }
    
    @objc func segmentedControlChangeHandler(segmentedControl: UISegmentedControl) {
        if let title = segmentedControl.titleForSegment(at: segmentedControl.selectedSegmentIndex), let sides = Int(title) {
            numSides = sides
            dilate()
        }
    }
    
    func dilate(){
        toolBar.alpha = 0.5
        toolBar.isUserInteractionEnabled = false
        DispatchQueue.global().async {
            let result = self.getDilatedImage()
            DispatchQueue.main.async {
                if let result = result {
                    self.image.image = result
                }
                self.toolBar.alpha = 1
                self.toolBar.isUserInteractionEnabled = true
            }
        }
    }
    
    func getMaximizedImage() -> UIImage? {
        let dismeter = vImagePixelCount(radius * 2) + 1
        vImageMax_ARGB8888(&sourceBuffer, &destinationBuffer, nil, 0, 0, dismeter, dismeter, vImage_Flags(kvImageNoFlags))
        let result = vImageCreateCGImageFromBuffer(&destinationBuffer, &format, nil, nil, vImage_Flags(kvImageNoFlags), nil)
        if let result = result {
            return UIImage(cgImage: result.takeRetainedValue())
        } else{
            return nil
        }
    }
    
    func getDilatedImage() ->UIImage? {
        let kernel = ViewController.makeStructuringElement(ofRadius: radius, withSides: numSides)
        let diameter = vImagePixelCount(radius * 2) + 1
        vImageDilate_ARGB8888(&sourceBuffer, &destinationBuffer, 0, 0, kernel, diameter, diameter, vImage_Flags(kvImageNoFlags))
        let result = vImageCreateCGImageFromBuffer(&destinationBuffer, &format, nil, nil, vImage_Flags(kvImageNoFlags), nil)
        if let result = result {
            return UIImage(cgImage: result.takeRetainedValue())
        } else{
            return nil
        }
    }
    
    static func makeStructuringElement(ofRadius radius: Int, withSides sides: Int) ->[UInt8] {
        let diameter = (radius * 2) + 1
        var values = [UInt8](repeating: 255, count: diameter * diameter)
        let angle = (Float.pi * 2) / Float(sides)
        stride(from: 0, through: Float(radius), by: Float(0.25)).forEach { scaledRadius in
            var previousVertex: simd_float2?
            stride(from: 0, through: (Float.pi * 2), by: angle).forEach{
                let x = Float(radius) + sin($0) * scaledRadius
                let y = Float(radius) + cos($0) * scaledRadius
                if let start = previousVertex {
                    let end = simd_float2(Float(x), Float(y))
                    let delta = 1.0 / max(abs(start.x - end.x), abs(start.y - end.y))
                    stride(from: Float(0), through: Float(1), by: delta).forEach{
                        t in
                        let coord = simd_mix(start, end, simd_float2(t))
                        values[(Int(round(coord.x)) + Int(round(coord.y)) * diameter)] = 0
                    }
                }
                previousVertex = simd_float2(Float(x), Float(y))
            }
        }
        return values
    }
}


