import SwiftUI

struct BattleBriefingView: View {
    let briefing: BattleBriefing
    let onAttack, onCancel: () -> Void
    var body: some View {
        BattlePanel {
            Text("Assault on \(briefing.target.name)").font(DuskaraTheme.Fonts.title)
            Text("Land your army, break the gate, and take the island.")
                .font(DuskaraTheme.Fonts.bodyLarge).foregroundStyle(DuskaraTheme.mutedInk)
            HStack(alignment: .top,spacing: 24) {
                army(briefing.battle.survivors(.attacker),team: "blue",name: briefing.source.name,power: briefing.power)
                army(briefing.battle.survivors(.defender),team: "red",name: "Garrison",power: briefing.defense)
            }
            HStack {
                Label("Gate \(Int(briefing.battle.gateMaxHealth))",systemImage: "door.left.hand.closed")
                Spacer()
                Label(String(format: "Tower %.1f damage",briefing.battle.towerDamage),systemImage: "arrow.up.right")
            }.font(DuskaraTheme.Fonts.subheading)
            Text(briefing.odds).font(DuskaraTheme.Fonts.title).foregroundStyle(DuskaraTheme.warmGold)
                .accessibilityLabel("Battle odds: \(briefing.odds). Your power \(briefing.power), defense \(briefing.defense).")
            HStack {
                Button("Cancel",action: onCancel).keyboardShortcut(.cancelAction)
                Button("Attack",systemImage: "shield.lefthalf.filled",action: onAttack)
                    .buttonStyle(DuskaraButtonStyle(prominent: true)).keyboardShortcut(.defaultAction)
            }.buttonStyle(DuskaraButtonStyle())
        }
    }
    private func army(_ roster: SoldierRoster,team: String,name: String,power: Int) -> some View {
        VStack(alignment: .leading,spacing: 8) {
            Text(name).font(DuskaraTheme.Fonts.heading)
            Text("\(power) \(team == "red" ? "defense" : "power")").font(DuskaraTheme.Fonts.number)
            ForEach([SoldierKind.knight,.archer]) { kind in
                HStack {
                    Image("\(kind.rawValue)_\(team)_portrait").resizable().scaledToFit().frame(width: 60,height: 62)
                        .accessibilityHidden(true)
                    Text("\(kind.title) ×\(roster[kind])").font(DuskaraTheme.Fonts.subheading)
                }
            }
        }.frame(maxWidth: .infinity,alignment: .leading).padding(14)
            .background(DuskaraTheme.card,in: RoundedRectangle(cornerRadius: DuskaraTheme.cornerM))
    }
}

struct BattleReportView: View {
    let report: BattleReport
    let onContinue: () -> Void
    var body: some View {
        BattlePanel {
            Text(report.title).font(DuskaraTheme.Fonts.hero).foregroundStyle(DuskaraTheme.warmGold)
            Text(report.townName).font(DuskaraTheme.Fonts.heading)
            HStack(alignment: .top,spacing: 24) {
                casualties("Your army",survivors: report.attackers,losses: report.attackerLosses)
                casualties("Garrison",survivors: report.defenders,losses: report.defenderLosses)
            }
            if !report.plunder.isEmpty {
                Text("Plunder").font(DuskaraTheme.Fonts.heading)
                Text(GameRules.sharedKinds.map { "\(report.plunder[$0] ?? 0) \($0.title.lowercased())" }.joined(separator: " · "))
                    .font(DuskaraTheme.Fonts.bodyLarge)
            }
            Text("Time taken · \(Int(report.elapsed.rounded())) seconds")
                .font(DuskaraTheme.Fonts.body).foregroundStyle(DuskaraTheme.mutedInk)
            Button("Continue",action: onContinue).buttonStyle(DuskaraButtonStyle(prominent: true))
                .keyboardShortcut(.defaultAction)
        }
    }
    private func casualties(_ title: String,survivors: SoldierRoster,losses: SoldierRoster) -> some View {
        VStack(alignment: .leading,spacing: 12) {
            Text(title).font(DuskaraTheme.Fonts.heading)
            Text("Lost / Survived").font(DuskaraTheme.Fonts.caption).foregroundStyle(DuskaraTheme.mutedInk)
            ForEach([SoldierKind.knight,.archer]) { kind in
                HStack {
                    Text(kind.title)
                    Spacer()
                    Text("\(losses[kind]) / \(survivors[kind])").font(DuskaraTheme.Fonts.number)
                }.font(DuskaraTheme.Fonts.body)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(kind.title): \(losses[kind]) lost, \(survivors[kind]) survived")
            }
        }.frame(maxWidth: .infinity).padding(16)
            .background(DuskaraTheme.card,in: RoundedRectangle(cornerRadius: DuskaraTheme.cornerM))
    }
}

private struct BattlePanel<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View {
        ZStack {
            Color.black.opacity(0.68).ignoresSafeArea()
            VStack(alignment: .leading,spacing: 18,content: content)
                .foregroundStyle(DuskaraTheme.ink).padding(26).frame(width: 560)
                .background(DuskaraTheme.sheetBackground,in: RoundedRectangle(cornerRadius: DuskaraTheme.cornerL))
                .overlay(RoundedRectangle(cornerRadius: DuskaraTheme.cornerL).stroke(DuskaraTheme.glassStroke))
        }
    }
}
