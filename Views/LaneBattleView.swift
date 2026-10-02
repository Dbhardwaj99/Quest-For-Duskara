import SpriteKit
import SwiftUI

@MainActor private enum BattleSession { static var confirmedWithdrawal = false }

/// The scene owns the live simulation; SwiftUI receives quantized HUD snapshots.
struct LaneBattleView: View {
    let battle: LaneBattle
    let attackerName: String
    let targetTown: Town
    let onFinish: (LaneBattle) -> Void
    @State private var scene: LaneBattleScene?
    @State private var selected: SoldierKind = .knight
    @State private var hud: BattleHUDState?
    @State private var confirmingWithdrawal = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            DuskaraTheme.panelDark.ignoresSafeArea()
            if let scene {
                BattleSpriteView(scene: scene).ignoresSafeArea().accessibilityHidden(true)
            }
            if let hud {
                BattleHUD(state: hud, selected: selected, townName: targetTown.name,
                          power: battle.survivors(.attacker).armyStrength(using: GameBalance.duskDefault.soldierDefinitions),
                          garrison: targetTown.armyStrength,
                          fortification: Int((battle.gateMaxHealth-LaneBattle.gateBase)/LaneBattle.gatePerFortification),
                          onSelect: { selected = $0 }, onWithdraw: requestWithdrawal,
                          confirming: confirmingWithdrawal, onCancelWithdrawal: { confirmingWithdrawal = false },
                          onConfirmWithdrawal: {
                              BattleSession.confirmedWithdrawal = true
                              confirmingWithdrawal = false; scene?.withdraw()
                          })
                    .equatable()
            }
        }
        .onAppear {
            guard scene == nil else { return }
            let scene = LaneBattleScene(battle: battle, town: targetTown)
            scene.onFinish = onFinish
            scene.onHUD = { next in
                let summaryChanged = hud?.spokenSummary != next.spokenSummary
                hud = next
                if summaryChanged {
                    NSAccessibility.post(element: NSApp!, notification: .announcementRequested,
                                         userInfo: [.announcement: next.spokenSummary, .priority: NSAccessibilityPriorityLevel.low.rawValue])
                }
            }
            scene.onSelect = { selected = $0 }
            scene.onWithdrawRequest = requestWithdrawal
            scene.reduceMotion = reduceMotion
            scene.selected = selected
            hud = BattleHUDState(battle)
            self.scene = scene
        }
        .onDisappear {
            scene?.onFinish = nil; scene?.onHUD = nil; scene?.onSelect = nil; scene?.onWithdrawRequest = nil
            scene = nil
        }
        .onChange(of: selected) { _, kind in
            scene?.selected = kind
            if let view = scene?.view { view.window?.makeFirstResponder(view) }
        }
        .onChange(of: confirmingWithdrawal) { _, confirming in
            if let view = scene?.view { view.window?.makeFirstResponder(confirming ? nil : view) }
        }
        .onChange(of: reduceMotion) { _, value in scene?.reduceMotion = value }
    }
    private func requestWithdrawal() {
        if confirmingWithdrawal { confirmingWithdrawal = false }
        else if BattleSession.confirmedWithdrawal { scene?.withdraw() }
        else { confirmingWithdrawal = true }
    }
}

private struct BattleHUD: View, Equatable {
    let state: BattleHUDState
    let selected: SoldierKind
    let townName: String
    let power, garrison, fortification: Int
    let onSelect: (SoldierKind) -> Void
    let onWithdraw: () -> Void
    let confirming: Bool
    let onCancelWithdrawal, onConfirmWithdrawal: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static func == (a: Self,b: Self) -> Bool {
        a.state == b.state && a.selected == b.selected && a.townName == b.townName
            && a.power == b.power && a.garrison == b.garrison && a.fortification == b.fortification && a.confirming == b.confirming
    }
    var body: some View {
        ZStack {
            VStack {
                HStack(alignment: .top) {
                    VStack(alignment: .leading,spacing: 4) {
                        Text("Assault on \(townName)").font(DuskaraTheme.Fonts.heading)
                        Text("Your power \(power) · Garrison \(garrison) · Fortification \(fortification)")
                            .font(DuskaraTheme.Fonts.body).foregroundStyle(DuskaraTheme.mutedInk)
                    }.battlePlate().allowsHitTesting(false)
                    Spacer()
                }
                Spacer()
                HStack(alignment: .bottom) {
                    Spacer().frame(maxWidth: .infinity)
                    VStack(spacing: 10) {
                        Text("1 2 3 lanes · ←/→ pan · pinch or +/− zoom")
                            .font(DuskaraTheme.Fonts.caption).battlePlate()
                            .opacity(state.hasLanded ? 0 : 1).accessibilityHidden(state.hasLanded)
                            .animation(reduceMotion ? nil : .easeOut(duration: 0.35), value: state.hasLanded)
                        BattlePips(filled: state.command,total: Int(LaneBattle.maxCommand))
                            .battlePlate().accessibilityElement(children: .ignore).accessibilityHidden(false).accessibilityLabel("Command \(state.command) of \(Int(LaneBattle.maxCommand))")
                        HStack(spacing: 10) { card(.knight,key: "K"); card(.archer,key: "A") }
                    }
                    HStack {
                        Spacer()
                        Button("Withdraw  Esc", systemImage: "flag.fill", action: onWithdraw)
                            .buttonStyle(DuskaraButtonStyle()).keyboardShortcut(.cancelAction)
                            .frame(width: 160).accessibilityLabel("Withdraw from battle")
                            .accessibilityHint("Escape. Confirms the first withdrawal this session.")
                            .popover(isPresented: Binding(get: { confirming },set: { if !$0 { onCancelWithdrawal() } }),arrowEdge: .bottom) {
                                VStack(alignment: .leading,spacing: 12) {
                                    Text("Withdraw from the assault?").font(DuskaraTheme.Fonts.heading)
                                    Text("Survivors sail home. Lost units stay lost.").font(DuskaraTheme.Fonts.body)
                                    HStack {
                                        Button("Keep fighting",action: onCancelWithdrawal).keyboardShortcut(.cancelAction)
                                        Button("Withdraw",action: onConfirmWithdrawal).keyboardShortcut(.defaultAction)
                                    }.buttonStyle(DuskaraButtonStyle())
                                }.foregroundStyle(DuskaraTheme.ink).padding(18).frame(width: 320)
                                    .background(DuskaraTheme.sheetBackground)
                            }
                    }.frame(maxWidth: .infinity)
                }
            }
            Text(state.timer).font(DuskaraTheme.Fonts.title.monospacedDigit())
                .foregroundStyle(state.seconds < 15 ? Color(red: 1,green: 0.38,blue: 0.30) : DuskaraTheme.ink)
                .battlePlate().frame(maxHeight: .infinity,alignment: .top)
                .accessibilityLabel("\(state.seconds) seconds remaining")
        }
        .padding(18).foregroundStyle(DuskaraTheme.ink)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Battle. \(state.spokenSummary)")
    }
    private func card(_ kind: SoldierKind,key: String) -> some View {
        let available = state.affordable.contains(kind)
        return Button { onSelect(kind) } label: {
            HStack(spacing: 8) {
                Image("\(kind.rawValue)_blue_portrait").resizable().scaledToFit().frame(width: 58,height: 62)
                    .accessibilityHidden(true)
                VStack(alignment: .leading,spacing: 4) {
                    Text("\(kind.title) ×\(state.reserve[kind])").font(DuskaraTheme.Fonts.number)
                    BattlePips(filled: Int(LaneBattle.stats(kind).cost),total: Int(LaneBattle.stats(kind).cost),size: 6)
                    Text("\(key) · \(selected == kind ? "Selected" : "Select")").font(DuskaraTheme.Fonts.caption)
                }
            }.frame(width: 165,height: 66).opacity(available ? 1 : 0.75)
        }
        .buttonStyle(DuskaraButtonStyle())
        .overlay(Capsule().stroke(selected == kind ? DuskaraTheme.warmGold : .clear,lineWidth: 2))
        .keyboardShortcut(KeyEquivalent(key.lowercased().first!),modifiers: [])
        .disabled(state.reserve[kind] == 0).saturation(available ? 1 : 0.35)
        .accessibilityLabel("\(kind.title), \(state.reserve[kind]) ready, costs \(Int(LaneBattle.stats(kind).cost)) command, \(selected == kind ? "selected" : "unselected")")
        .accessibilityHint("\(key) selects. 1, 2, or 3 lands in that lane. \(available ? "Ready to land." : "Not enough command or no units left.")")
    }
}

struct BattlePips: View {
    let filled, total: Int
    var size: CGFloat = 9
    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<total,id: \.self) { index in
                Circle().fill(index < filled ? DuskaraTheme.warmGold : DuskaraTheme.mutedInk.opacity(0.22))
                    .frame(width: size,height: size)
            }
        }.accessibilityHidden(true)
    }
}

extension View {
    func battlePlate() -> some View {
        padding(.horizontal,14).padding(.vertical,10)
            .background(DuskaraTheme.hudFill,in: RoundedRectangle(cornerRadius: DuskaraTheme.cornerM))
            .overlay(RoundedRectangle(cornerRadius: DuskaraTheme.cornerM).stroke(DuskaraTheme.glassStroke))
    }
}
