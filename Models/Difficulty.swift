//
//  Difficulty.swift
//  Quest For Duskara
//
//  Created by db on 11/06/26.
//

import Foundation

enum Difficulty: String, CaseIterable, Identifiable, Codable {
	case easy
	case medium
	case hard

	var id: String { rawValue }

	var title: String {
		rawValue.capitalized
	}

	var description: String {
		switch self {
		case .easy:
			return "A generous treasury to learn the ropes."
		case .medium:
			return "A balanced stockpile for seasoned commanders."
		case .hard:
			return "Scarce coin and skill. Earn every island."
		}
	}

	var modeBalance: [ResourceKind: Int] {
		switch self {
		case .easy:
			return [
				.gold: 5_000,
				.skill: 2_500,
			]
		case .medium:
			return [
				.gold: 3_000,
				.skill: 1_500,
			]
		case .hard:
			return [
				.gold: 1_000,
				.skill: 500,
			]
		}
	}
}
