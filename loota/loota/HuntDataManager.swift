// HuntDataManager.swift

import Combine
import Foundation

public class HuntDataManager: ObservableObject {
  public static let shared = HuntDataManager()

  @Published public var huntData: HuntData?

  private init() {}
}
