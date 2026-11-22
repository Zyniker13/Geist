// Murmuration app — save/resume behavior (S2.4).
//
// SavedGame assembly and local persistence. Split out of GameModel to keep
// its type body within the lint budget.

extension GameModel {
    /// Snapshot the running game for resume.
    public func makeSave() -> SavedGame {
        SavedGame(
            regionID: region.id,
            day: day,
            state: state,
            rng: rng,
            autoplayer: autoplayer,
            rival: rival
        )
    }

    public func saveLocally() {
        SavedGame.store(makeSave())
    }

    public static func loadSave(regionID: String) -> SavedGame? {
        SavedGame.load(regionID: regionID)
    }
}
