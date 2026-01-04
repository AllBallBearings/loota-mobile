import Combine
import RealityKit

enum DollarSignEntityFactory {
  private static var cachedModel: ModelEntity?
  private static var modelCancellable: AnyCancellable?
  private static var isLoadingModel = false
  private static var didFailLoadingModel = false

  static var isModelReady: Bool {
    return cachedModel != nil
  }

  static var isModelLoading: Bool {
    return isLoadingModel
  }

  static var shouldDeferPlacement: Bool {
    return cachedModel == nil && !didFailLoadingModel
  }

  static func preload(completion: ((Bool) -> Void)? = nil) {
    if cachedModel != nil {
      completion?(true)
      return
    }
    if isLoadingModel || didFailLoadingModel {
      completion?(false)
      return
    }

    isLoadingModel = true
    modelCancellable = ModelEntity.loadModelAsync(named: "DollarSign")
      .sink(
        receiveCompletion: { completionResult in
          switch completionResult {
          case .finished:
            break
          case .failure(let error):
            print("❌ DOLLAR_MODEL: Async load failed: \(error)")
            didFailLoadingModel = true
            isLoadingModel = false
            completion?(false)
          }
        },
        receiveValue: { model in
          cachedModel = model
          isLoadingModel = false
          completion?(true)
        }
      )
  }

  static func make() -> ModelEntity? {
    guard let cachedModel else {
      if !isLoadingModel && !didFailLoadingModel {
        preload()
      }
      return nil
    }

    let model = cachedModel.clone(recursive: true)
    model.scale = SIMD3<Float>(repeating: 0.02)

    // Apply Blender-to-ARKit coordinate system conversion
    // This converts from Z-up (Blender) to Y-up (ARKit)
    ModelTransformUtilities.applyBlenderToARKitConversion(model)

    return model
  }
}
