// CoinConfiguration.swift
// Configuration for selecting which coin style to use in the app

import Foundation

/// Global configuration for coin appearance
enum CoinConfiguration {

    /// Change this value to switch between different coin styles:
    /// - .classic: 10% rim width, subtle embossing - clean and simple
    /// - .thickRim: 15% rim width, prominent embossing - bold and distinct
    /// - .detailed: Multi-layer design with depth - intricate stepped look
    /// - .beveled: Beveled edges for polished look - smooth gradual transition
    static let selectedStyle: CoinStyle = .classic

    // MARK: - Preview Examples

    /// Use this to test different styles - just change the constant above!
    ///
    /// Visual differences:
    /// - Classic: Thin center (60% height) with 10% rim - balanced proportions
    /// - Thick Rim: Thinner center (50% height) with 15% rim - bold edge
    /// - Detailed: Three layers (outer, inner, center) - stepped profile
    /// - Beveled: Three layers with graduated sizes - smooth transition
}
