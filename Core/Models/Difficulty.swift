//
//  Difficulty.swift
//  Quest For Duskara
//
//  Created by db on 11/06/26.
//

import Foundation

enum Difficulty: String, CaseIterable, Identifiable {
	case easy
	case medium
	case hard
	
	var id: String { rawValue.capitalized }
	
	var description: String {
		switch self {
		case .easy:
			return "Fairly easy"
		case .medium:
			return "Named Medium, but also easy"
		case .hard:
			return "Hard, but its also the same"
		}
	}
	
	var modebalance: [ResourceKind: Int] {
		switch self {
		case .easy:
			return [
				.gold: 500,
				.skill: 250,
			]
		case .medium:
			return [
				.gold: 300,
				.skill: 150,
			]
		case .hard:
			return [
				.gold: 100,
				.skill: 50,
			]
		}
	}
}
