// A tiny mutable box: stored properties cannot live in extensions, so the
// audio feed's mutable state rides in a `Ref` owned by GameModel.

final class Ref<T> {
    var value: T

    init(_ value: T) {
        self.value = value
    }
}
