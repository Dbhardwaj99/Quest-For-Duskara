import Foundation

struct ResourceSystem {
    func canAfford(_ cost: [ResourceKind: Int], in wallet: ResourceWallet) -> Bool {
        wallet.canAfford(cost)
    }

    func applyIncome(_ income: [ResourceKind: Int], to wallet: inout ResourceWallet) {
        wallet.apply(income)
    }

    func spend(_ cost: [ResourceKind: Int], from wallet: inout ResourceWallet) -> Bool {
        wallet.spend(cost)
    }
}
