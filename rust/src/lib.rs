use godot::prelude::*;

struct MihoNative;

#[gdextension]
unsafe impl ExtensionLibrary for MihoNative {}
