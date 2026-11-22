// Murmuration app — debug-overlay hash feed.
//
// The -uitest-hash final-hash label refresh. Split out of GameModel to keep
// its type body within the lint budget.

import MUCore

extension GameModel {
    /// Refresh `hashLabel` when hash updates are enabled, at most every 30
    /// ticks (or immediately when forced: pause, day end, finish).
    func refreshHashIfNeeded(force: Bool) {
        guard hashUpdates || force else { return }
        if force || state.tick - lastHashTick >= 30 {
            lastHashTick = state.tick
            hashLabel = String(format: "%016llx", stateHash(state))
        }
    }
}
