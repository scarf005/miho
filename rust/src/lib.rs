//! Board primitives the rules call many times a round: breadth-first search,
//! shadowcast sight and light, and a round of gas. GDScript reaches them through
//! Grid.search, Sight.field, Light.spread/field and Gas.spread, passing masks
//! (one byte per tile, row by row) instead of callables, so no call goes back to
//! GDScript per tile. Results match the GDScript originals bit for bit: saved
//! runs replay their actions, so the same order, tie-breaks and float precision
//! are kept.

use godot::prelude::*;

struct MihoNative;

#[gdextension]
unsafe impl ExtensionLibrary for MihoNative {}

/// Grid.DIRS, in the same order.
const DIRS: [(i32, i32); 8] = [
    (0, -1),
    (1, -1),
    (1, 0),
    (1, 1),
    (0, 1),
    (-1, 1),
    (-1, 0),
    (-1, -1),
];

/// The share of a light left at the edge of its radius (Brogue CE paintLight).
const FADE: f64 = 0.25;

#[derive(Clone, Copy)]
struct Board {
    w: i32,
    h: i32,
}

impl Board {
    fn of(len: usize, width: i32) -> Self {
        let w = width.max(1);
        Self {
            w,
            h: len as i32 / w,
        }
    }

    fn inside(self, x: i32, y: i32) -> bool {
        x >= 0 && y >= 0 && x < self.w && y < self.h
    }

    fn index(self, x: i32, y: i32) -> usize {
        (y * self.w + x) as usize
    }
}

#[derive(GodotClass)]
#[class(no_init, base = Object)]
pub struct Native {
    base: Base<Object>,
}

#[godot_api]
impl Native {
    /// `table[t]` for every tile kind t in `tiles` (0 for kinds past its end).
    #[func]
    fn mask(tiles: PackedByteArray, table: PackedByteArray) -> PackedByteArray {
        let table = table.as_slice();
        let out: Vec<u8> = tiles
            .as_slice()
            .iter()
            .map(|&t| table.get(t as usize).copied().unwrap_or(0))
            .collect();
        PackedByteArray::from(out.as_slice())
    }

    /// Breadth-first search from `from` over tiles whose `open` byte is not 0,
    /// leaving tiles farther than `limit` (when 0 or more) unreached.
    /// {dist, parent}, with -1 for unreached tiles.
    #[func]
    fn search(from: Vector2i, open: PackedByteArray, limit: i32, width: i32) -> VarDictionary {
        let open = open.as_slice();
        let b = Board::of(open.len(), width);
        let mut dist = vec![-1i32; open.len()];
        let mut parent = dist.clone();
        if b.inside(from.x, from.y) {
            dist[b.index(from.x, from.y)] = 0;
            let mut queue = vec![(from.x, from.y)];
            let mut head = 0;
            while head < queue.len() {
                let (x, y) = queue[head];
                head += 1;
                let i = b.index(x, y);
                if dist[i] == limit {
                    continue;
                }
                for (dx, dy) in DIRS {
                    let (qx, qy) = (x + dx, y + dy);
                    if !b.inside(qx, qy) {
                        continue;
                    }
                    let j = b.index(qx, qy);
                    if dist[j] < 0 && open[j] != 0 {
                        dist[j] = dist[i] + 1;
                        parent[j] = i as i32;
                        queue.push((qx, qy));
                    }
                }
            }
        }
        let mut out = VarDictionary::new();
        out.set(
            &StringName::from("dist").to_variant(),
            &PackedInt32Array::from(dist.as_slice()).to_variant(),
        );
        out.set(
            &StringName::from("parent").to_variant(),
            &PackedInt32Array::from(parent.as_slice()).to_variant(),
        );
        out
    }

    /// Sight.field: 1 for every tile visible from `origin` within `radius`.
    #[func]
    fn sight(
        origin: Vector2i,
        radius: i32,
        opaque: PackedByteArray,
        width: i32,
    ) -> PackedByteArray {
        let opaque = opaque.as_slice();
        PackedByteArray::from(
            sight(origin, radius, opaque, Board::of(opaque.len(), width)).as_slice(),
        )
    }

    /// Gas.spread: one round of gas over `amount` and `kind` (a byte per tile)
    /// where `hold` is not 0, thinned by `decay[kind]` percent; [tile, amount,
    /// kind] triplets of the tiles with gas left.
    #[func]
    fn gas(
        amount: PackedByteArray,
        kind: PackedByteArray,
        hold: PackedByteArray,
        decay: PackedByteArray,
        seed: i64,
        width: i32,
    ) -> PackedInt32Array {
        let amount = amount.as_slice();
        let b = Board::of(amount.len(), width);
        PackedInt32Array::from(
            gas(
                amount,
                kind.as_slice(),
                hold.as_slice(),
                decay.as_slice(),
                seed as u64,
                b,
            )
            .as_slice(),
        )
    }

    /// Light.spread: the strength (0 to 1) a source gives each tile it reaches.
    #[func]
    fn spread(
        at: Vector2i,
        radius: i32,
        opaque: PackedByteArray,
        width: i32,
    ) -> PackedFloat32Array {
        let opaque = opaque.as_slice();
        PackedFloat32Array::from(
            spread(at, radius, opaque, Board::of(opaque.len(), width)).as_slice(),
        )
    }

    /// Light.field: the sum of every source {at, radius, color}.
    #[func]
    fn light(
        sources: Array<VarDictionary>,
        opaque: PackedByteArray,
        width: i32,
    ) -> PackedVector3Array {
        let opaque = opaque.as_slice();
        let b = Board::of(opaque.len(), width);
        let mut out = vec![Vector3::ZERO; opaque.len()];
        let key = |src: &VarDictionary, k: &str| src.get_or_nil(&StringName::from(k).to_variant());
        for src in sources.iter_shared() {
            let at = key(&src, "at")
                .try_to::<Vector2i>()
                .unwrap_or(Vector2i::new(-1, -1));
            let radius = key(&src, "radius").try_to::<i32>().unwrap_or(0);
            let color = key(&src, "color")
                .try_to::<Vector3>()
                .unwrap_or(Vector3::ZERO);
            for (o, s) in out.iter_mut().zip(spread(at, radius, opaque, b)) {
                if s > 0.0 {
                    *o += color * s;
                }
            }
        }
        PackedVector3Array::from(out.as_slice())
    }
}

/// Symmetric shadowcasting (Albert Ford, 2021); see Sight.
fn sight(origin: Vector2i, radius: i32, opaque: &[u8], b: Board) -> Vec<u8> {
    let mut seen = vec![0u8; opaque.len()];
    if !b.inside(origin.x, origin.y) {
        return seen;
    }
    seen[b.index(origin.x, origin.y)] = 1;
    let mut cast = Cast {
        seen: &mut seen,
        opaque,
        b,
        origin,
        radius,
    };
    for quadrant in 0..4 {
        cast.scan(quadrant, 1, -1.0, 1.0);
    }
    seen
}

struct Cast<'a> {
    seen: &'a mut [u8],
    opaque: &'a [u8],
    b: Board,
    origin: Vector2i,
    radius: i32,
}

impl Cast<'_> {
    fn tile(&self, quadrant: i32, depth: i32, col: i32) -> (i32, i32) {
        let o = self.origin;
        match quadrant {
            0 => (o.x + col, o.y - depth),
            1 => (o.x + depth, o.y + col),
            2 => (o.x + col, o.y + depth),
            _ => (o.x - depth, o.y + col),
        }
    }

    fn scan(&mut self, quadrant: i32, depth: i32, mut start: f64, end: f64) {
        if depth > self.radius {
            return;
        }
        let reach = (self.radius as f64 + 0.5) * (self.radius as f64 + 0.5);
        let d = depth as f64;
        let mut prev = -1;
        let first = (d * start + 0.5).floor() as i32;
        let last = (d * end - 0.5).ceil() as i32;
        for col in first..=last {
            let (x, y) = self.tile(quadrant, depth, col);
            let inside = self.b.inside(x, y);
            let wall = !inside || self.opaque[self.b.index(x, y)] != 0;
            let c = col as f64;
            let symmetric = c >= d * start && c <= d * end;
            if inside && (wall || symmetric) && ((depth * depth + col * col) as f64) <= reach {
                self.seen[self.b.index(x, y)] = 1;
            }
            let slope = (2.0 * c - 1.0) / (2.0 * d);
            if prev == 1 && !wall {
                start = slope;
            }
            if prev == 0 && wall {
                self.scan(quadrant, depth + 1, start, slope);
            }
            prev = if wall { 1 } else { 0 };
        }
        if prev == 0 {
            self.scan(quadrant, depth + 1, start, end);
        }
    }
}

/// splitmix64, seeded by the World's own generator once a round, so a round of
/// gas is the same on every machine and in every replay.
struct Rng(u64);

impl Rng {
    /// 0 up to but not including `n`.
    fn below(&mut self, n: u64) -> u64 {
        self.0 = self.0.wrapping_add(0x9E37_79B9_7F4A_7C15);
        let mut z = self.0;
        z = (z ^ (z >> 30)).wrapping_mul(0xBF58_476D_1CE4_E5B9);
        z = (z ^ (z >> 27)).wrapping_mul(0x94D0_49BB_1331_11EB);
        (z ^ (z >> 31)) % n
    }
}

/// One round of gas (Gas.spread): each tile that holds gas (`hold`, never on
/// the outermost ring) takes the average of its own amount and that of its
/// neighbours that hold gas, the remainder going to chance, and the kind of the
/// strongest of them; then it loses 1 with the percent chance `decay[kind]`.
/// Returns [tile, amount, kind] for every tile left with gas, in tile order.
fn gas(amount: &[u8], kind: &[u8], hold: &[u8], decay: &[u8], seed: u64, b: Board) -> Vec<i32> {
    let mut rng = Rng(seed);
    let holds =
        |x: i32, y: i32| x > 0 && y > 0 && x < b.w - 1 && y < b.h - 1 && hold[b.index(x, y)] != 0;
    let mut spread = vec![0u8; amount.len()];
    let mut strongest = vec![0u8; amount.len()];
    for y in 1..b.h - 1 {
        for x in 1..b.w - 1 {
            let i = b.index(x, y);
            if !holds(x, y) {
                continue;
            }
            let (mut sum, mut count) = (amount[i] as u64, 1u64);
            let (mut best, mut k) = (amount[i], kind[i]);
            for (dx, dy) in DIRS {
                if holds(x + dx, y + dy) {
                    let j = b.index(x + dx, y + dy);
                    sum += amount[j] as u64;
                    count += 1;
                    if amount[j] > best {
                        (best, k) = (amount[j], kind[j]);
                    }
                }
            }
            if sum > 0 {
                let odd = rng.below(count) < sum % count;
                spread[i] = (sum / count) as u8 + odd as u8;
                strongest[i] = k;
            }
        }
    }
    let mut out = Vec::new();
    for (i, &a) in spread.iter().enumerate() {
        if a == 0 {
            continue;
        }
        let chance = decay.get(strongest[i] as usize).copied().unwrap_or(0) as u64;
        let left = a - (chance > 0 && rng.below(100) < chance) as u8;
        if left > 0 {
            out.extend([i as i32, left as i32, strongest[i] as i32]);
        }
    }
    out
}

/// Brogue fade: 1 - (1 - FADE) * distance / radius, in the GDScript precision
/// (the distance is a Vector2 length in f32, the rest in f64, stored as f32).
fn spread(at: Vector2i, radius: i32, opaque: &[u8], b: Board) -> Vec<f32> {
    let seen = sight(at, radius, opaque, b);
    let r = f64::max(1.0, radius as f64);
    seen.iter()
        .enumerate()
        .map(|(i, &s)| {
            if s != 1 {
                return 0.0;
            }
            let x = (i as i32 % b.w - at.x) as f32;
            let y = (i as i32 / b.w - at.y) as f32;
            let d = (x * x + y * y).sqrt() as f64;
            f64::max(0.0, 1.0 - (1.0 - FADE) * d / r) as f32
        })
        .collect()
}
