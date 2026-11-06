//! Board primitives the rules call many times a round: breadth-first search,
//! shadowcast sight and light, a round of gas, what Miho senses and the loops of
//! storey generation. GDScript reaches them through Grid.search, Sight.field,
//! Light.spread/field, Gas.spread, World.sense and FloorGen, passing masks (one
//! byte per tile, row by row) instead of callables, so no call goes back to
//! GDScript per tile. Results match the GDScript originals bit for bit: saved
//! runs replay their actions, so the same order, tie-breaks and float precision
//! are kept. A loop that draws random numbers draws them from the World's own
//! RandomNumberGenerator, in the same order and count as it did in GDScript.

use godot::classes::RandomNumberGenerator;
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

    fn at(self, i: usize) -> (i32, i32) {
        (i as i32 % self.w, i as i32 / self.w)
    }
}

/// Rect2i.has_point.
fn has(r: Rect2i, x: i32, y: i32) -> bool {
    x >= r.position.x && y >= r.position.y && x < r.end().x && y < r.end().y
}

/// A board's rows as bits, so that a search that needs no parents takes a word at a time.
/// Grid.W is 56.
const MOST_ROWS: usize = 32;
type Rows = [u64; MOST_ROWS];

fn rows_of(open: &[u8], b: Board) -> Rows {
    let mut rows = [0u64; MOST_ROWS];
    for (row, line) in rows.iter_mut().zip(open.chunks_exact(b.w as usize)) {
        for (x, &o) in line.iter().enumerate() {
            *row |= ((o != 0) as u64) << x;
        }
    }
    rows
}

/// Breadth-first search from `from`, which need not be open itself and lies on the board,
/// across `open`: the steps to `goal` (-1 when unreached).
fn walk(open: &Rows, b: Board, from: (i32, i32), goal: (i32, i32)) -> i32 {
    assert!(b.w <= 64 && b.h as usize <= MOST_ROWS);
    let full = u64::MAX >> (64 - b.w);
    let rows = b.h as usize;
    let wide = |f: u64| (f | f << 1 | f >> 1) & full;
    let mut seen = [0u64; MOST_ROWS];
    let (mut now, mut fresh) = ([0u64; MOST_ROWS], [0u64; MOST_ROWS]);
    now[from.1 as usize] = 1 << from.0;
    seen[from.1 as usize] = now[from.1 as usize];
    if goal == from {
        return 0;
    }
    let mut steps = 0;
    loop {
        steps += 1;
        let mut any = 0;
        let (mut above, mut here) = (0, wide(now[0]));
        for y in 0..rows {
            let below = if y + 1 < rows { wide(now[y + 1]) } else { 0 };
            fresh[y] = (above | here | below) & open[y] & !seen[y];
            seen[y] |= fresh[y];
            any |= fresh[y];
            (above, here) = (here, below);
        }
        if any == 0 {
            return -1;
        }
        if seen[goal.1 as usize] >> goal.0 & 1 == 1 {
            return steps;
        }
        std::mem::swap(&mut now, &mut fresh);
    }
}

/// Every tile reachable from `from`, which need not be open itself and lies on the board:
/// `walk` with no goal and no count of steps, in sweeps down and up the rows.
fn flood(open: &Rows, b: Board, from: (i32, i32)) -> Rows {
    assert!(b.w <= 64 && b.h as usize <= MOST_ROWS);
    let full = u64::MAX >> (64 - b.w);
    let rows = b.h as usize;
    let wide = |f: u64| (f | f << 1 | f >> 1) & full;
    let mut seen = [0u64; MOST_ROWS];
    seen[from.1 as usize] = 1 << from.0;
    let mut changed = true;
    let mut sweep = |y: usize, changed: &mut bool| {
        let mut near = wide(seen[y]);
        if y > 0 {
            near |= wide(seen[y - 1]);
        }
        if y + 1 < rows {
            near |= wide(seen[y + 1]);
        }
        let was = seen[y];
        let mut row = was | (near & open[y]);
        loop {
            let more = row | (wide(row) & open[y]);
            if more == row {
                break;
            }
            row = more;
        }
        seen[y] = row;
        *changed |= row != was;
    };
    while changed {
        changed = false;
        for y in 0..rows {
            sweep(y, &mut changed);
        }
        for y in (0..rows).rev() {
            sweep(y, &mut changed);
        }
    }
    seen
}

/// Distances and parents of a breadth-first search, as `Native.search` gives them, into
/// `dist` and `parent`, which hold -1.
fn search(from: Vector2i, open: &[u8], limit: i32, b: Board, dist: &mut [i32], parent: &mut [i32]) {
    if !b.inside(from.x, from.y) {
        return;
    }
    dist[b.index(from.x, from.y)] = 0;
    let mut queue = Vec::with_capacity(open.len());
    queue.push((from.x, from.y));
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

/// The tile kinds and chances of FloorGen._doorway.
struct Doorway {
    floor: u8,
    door: u8,
    door_open: u8,
    doors: f64,
    open_doors: f64,
}

impl Doorway {
    fn cut(&self, tile: &mut u8, rng: &mut Gd<RandomNumberGenerator>) {
        let mut t = self.floor;
        if (rng.randf() as f64) < self.doors {
            t = if (rng.randf() as f64) < self.open_doors {
                self.door_open
            } else {
                self.door
            };
        }
        *tile = t;
    }
}

/// FloorGen._root.
fn root(joined: &[usize], mut k: usize) -> usize {
    while joined[k] != k {
        k = joined[k];
    }
    k
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
        let mut out = tiles;
        for t in out.as_mut_slice() {
            *t = table.get(*t as usize).copied().unwrap_or(0);
        }
        out
    }

    /// Breadth-first search from `from` over tiles whose `open` byte is not 0,
    /// leaving tiles farther than `limit` (when 0 or more) unreached.
    /// {dist, parent}, with -1 for unreached tiles.
    #[func]
    fn search(from: Vector2i, open: PackedByteArray, limit: i32, width: i32) -> VarDictionary {
        let open = open.as_slice();
        let b = Board::of(open.len(), width);
        let mut dist = PackedInt32Array::new();
        dist.resize(open.len());
        dist.as_mut_slice().fill(-1);
        let mut parent = dist.clone();
        search(
            from,
            open,
            limit,
            b,
            dist.as_mut_slice(),
            parent.as_mut_slice(),
        );
        let mut out = VarDictionary::new();
        out.set(&StringName::from("dist").to_variant(), &dist.to_variant());
        out.set(
            &StringName::from("parent").to_variant(),
            &parent.to_variant(),
        );
        out
    }

    /// The `dist` that `search` gives at `to` (-1 when unreached), without the rest of the
    /// board: the search stops when it reaches `to`.
    #[func]
    fn distance(from: Vector2i, open: PackedByteArray, to: Vector2i, width: i32) -> i32 {
        let open = open.as_slice();
        let b = Board::of(open.len(), width);
        if !b.inside(from.x, from.y) || !b.inside(to.x, to.y) {
            return -1;
        }
        walk(&rows_of(open, b), b, (from.x, from.y), (to.x, to.y))
    }

    /// Whether a search from `from` reaches every tile whose `open` byte is not 0.
    #[func]
    fn whole(from: Vector2i, open: PackedByteArray, width: i32) -> bool {
        let open = open.as_slice();
        let b = Board::of(open.len(), width);
        let rows = rows_of(open, b);
        let seen = if b.inside(from.x, from.y) {
            flood(&rows, b, (from.x, from.y))
        } else {
            [0; MOST_ROWS]
        };
        rows.iter().zip(&seen).all(|(r, s)| r & !s == 0)
    }

    /// Skeletons.two_ways once `open` is known: `from` reaches `end`, and no block of 3 by
    /// 3 tiles on the shortest walk between them, its middle outside `near_home` and
    /// `near_goal`, cuts them apart.
    #[func]
    fn two_ways(
        from: Vector2i,
        open: PackedByteArray,
        end: Vector2i,
        near_home: Rect2i,
        near_goal: Rect2i,
        width: i32,
    ) -> bool {
        let open = open.as_slice();
        let b = Board::of(open.len(), width);
        let (mut dist, mut parent) = (vec![-1i32; open.len()], vec![-1i32; open.len()]);
        search(from, open, -1, b, &mut dist, &mut parent);
        let to = b.index(end.x, end.y);
        if dist[to] < 0 {
            return false;
        }
        let rows = rows_of(open, b);
        let full = u64::MAX >> (64 - b.w);
        // A middle may lie one tile off the board.
        let mut tried = vec![false; ((b.w + 2) * (b.h + 2)) as usize];
        let mut at = to as i32;
        while at >= 0 {
            let (ax, ay) = b.at(at as usize);
            for (dx, dy) in DIRS.into_iter().chain([(0, 0)]) {
                let (mx, my) = (ax + dx, ay + dy);
                let slot = ((my + 1) * (b.w + 2) + mx + 1) as usize;
                if tried[slot] || has(near_home, mx, my) || has(near_goal, mx, my) {
                    continue;
                }
                tried[slot] = true;
                let mut left = rows;
                let span = (0b111u64 << (mx + 1) >> 2) & full;
                for y in (my - 1).max(0)..(my + 2).min(b.h) {
                    left[y as usize] &= !span;
                }
                let seen = flood(&left, b, (from.x, from.y));
                if seen[end.y as usize] >> end.x & 1 == 0 {
                    return false;
                }
            }
            at = parent[at as usize];
        }
        true
    }

    /// FloorGen._fill: `tiles` with the tiles of `r` set to `t`.
    #[func]
    fn fill(mut tiles: PackedByteArray, r: Rect2i, t: i32, width: i32) -> PackedByteArray {
        let out = tiles.as_mut_slice();
        let len = out.len() as i32;
        for y in r.position.y..r.end().y {
            for x in r.position.x..r.end().x {
                let i = y * width + x;
                // As a PackedByteArray index in GDScript: below 0 counts from the end.
                let i = if i < 0 { i + len } else { i };
                if (0..len).contains(&i) {
                    out[i as usize] = t as u8;
                }
            }
        }
        tiles
    }

    /// FloorGen._windows: a window at the chance `chance` on each wall that faces sky one
    /// way and floor the other, with neither sky nor a window on its two sides.
    #[func]
    #[allow(clippy::too_many_arguments)]
    fn windows(
        mut tiles: PackedByteArray,
        mut rng: Gd<RandomNumberGenerator>,
        wall: i32,
        sky: i32,
        floor: i32,
        window: i32,
        chance: f64,
        width: i32,
    ) -> PackedByteArray {
        let t = tiles.as_mut_slice();
        let (w, h) = (width as isize, t.len() as isize / width as isize);
        let (wall, sky, floor, window) = (wall as u8, sky as u8, floor as u8, window as u8);
        for y in 1..h - 1 {
            for x in 1..w - 1 {
                let i = y * w + x;
                if t[i as usize] != wall {
                    continue;
                }
                for (step, side) in [(-w, -1), (w, -1), (-1, -w), (1, -w)] {
                    if t[(i + step) as usize] == sky
                        && t[(i - step) as usize] == floor
                        && t[(i + side) as usize] != sky
                        && t[(i - side) as usize] != sky
                        && t[(i + side) as usize] != window
                        && t[(i - side) as usize] != window
                        && (rng.randf() as f64) < chance
                    {
                        t[i as usize] = window;
                        break;
                    }
                }
            }
        }
        tiles
    }

    /// FloorGen._doorways: doorways in the walls between `parts` (rooms, then galleries);
    /// parts a walk over `open` already joins count as one. `kinds` are the tile kinds wall,
    /// floor, door and open door; `secrets` the hidden doors (World.secrets). [tiles, the
    /// spots left as 4 ints each: tile, 0 across x or 1 across y, part, part].
    #[func]
    #[allow(clippy::too_many_arguments)]
    fn doorways(
        parts: Array<Rect2i>,
        mut tiles: PackedByteArray,
        open: PackedByteArray,
        secrets: VarArray,
        mut rng: Gd<RandomNumberGenerator>,
        kinds: PackedByteArray,
        doors: f64,
        open_doors: f64,
        width: i32,
    ) -> VarArray {
        let [wall, floor, door, door_open] = kinds.as_slice()[..4] else {
            panic!("doorways: kinds are wall, floor, door, open door")
        };
        let doorway = Doorway {
            floor,
            door,
            door_open,
            doors,
            open_doors,
        };
        let open = open.as_slice();
        let t = tiles.as_mut_slice();
        let b = Board::of(t.len(), width);
        let parts: Vec<Rect2i> = parts.iter_shared().collect();
        let mut part = vec![-1i32; t.len()];
        for (k, r) in parts.iter().enumerate() {
            for y in r.position.y..r.end().y {
                for x in r.position.x..r.end().x {
                    part[b.index(x, y)] = k as i32;
                }
            }
        }
        let mut spots: Vec<[i32; 4]> = Vec::new();
        for (i, &kind) in t.iter().enumerate() {
            if kind != wall {
                continue;
            }
            let (x, y) = b.at(i);
            if x > 0 && x < b.w - 1 {
                let (p, q) = (part[i - 1], part[i + 1]);
                if p >= 0 && q >= 0 && p != q {
                    spots.push([i as i32, 0, p, q]);
                }
            }
            if y > 0 && y < b.h - 1 {
                let (p, q) = (part[i - b.w as usize], part[i + b.w as usize]);
                if p >= 0 && q >= 0 && p != q {
                    spots.push([i as i32, 1, p, q]);
                }
            }
        }
        let mut joined: Vec<usize> = (0..parts.len()).collect();
        let rows = rows_of(open, b);
        for (k, from) in parts.iter().enumerate() {
            let seen = flood(&rows, b, (from.position.x, from.position.y));
            for (j, to) in parts.iter().enumerate() {
                if seen[to.position.y as usize] >> to.position.x & 1 == 1 {
                    let (rj, rk) = (root(&joined, j), root(&joined, k));
                    joined[rj] = rk;
                }
            }
        }
        for i in (1..spots.len()).rev() {
            let j = rng.randi_range(0, i as i32) as usize;
            spots.swap(i, j);
        }
        let hidden = marks(&secrets, b, t.len());
        let mut left: Vec<i32> = Vec::new();
        for s in &spots {
            let (x, y) = b.at(s[0] as usize);
            let (rp, rq) = (root(&joined, s[2] as usize), root(&joined, s[3] as usize));
            // FloorGen._walled: a wall, with wall and no hidden door on the two sides.
            let (sx, sy) = if s[1] == 0 { (0, 1) } else { (1, 0) };
            let side = |px: i32, py: i32| {
                !b.inside(px, py) || (t[b.index(px, py)] == wall && !hidden[b.index(px, py)])
            };
            let walled = t[s[0] as usize] == wall && side(x + sx, y + sy) && side(x - sx, y - sy);
            if rp == rq || !walled {
                left.extend(s);
                continue;
            }
            joined[rp] = rq;
            doorway.cut(&mut t[s[0] as usize], &mut rng);
        }
        let mut out = VarArray::new();
        out.push(&tiles.to_variant());
        out.push(&PackedInt32Array::from(left.as_slice()).to_variant());
        out
    }

    /// Skeletons._door_spots: the wall tiles with `a` on one side and `b` on the other,
    /// each once for each way across, as tile numbers.
    #[func]
    fn door_spots(
        tiles: PackedByteArray,
        a: Rect2i,
        b: Rect2i,
        wall: i32,
        width: i32,
    ) -> PackedInt32Array {
        let t = tiles.as_slice();
        let board = Board::of(t.len(), width);
        let mut out = Vec::new();
        for y in a.position.y - 1..a.end().y + 1 {
            for x in a.position.x - 1..a.end().x + 1 {
                if !board.inside(x, y) || t[board.index(x, y)] as i32 != wall {
                    continue;
                }
                for (dx, dy) in [(1, 0), (0, 1)] {
                    let (x0, y0, x1, y1) = (x - dx, y - dy, x + dx, y + dy);
                    if (has(a, x0, y0) && has(b, x1, y1)) || (has(b, x0, y0) && has(a, x1, y1)) {
                        out.push(y * width + x);
                    }
                }
            }
        }
        PackedInt32Array::from(out.as_slice())
    }

    /// Placement._spots: tile numbers of the tiles of kind `on` in `rooms` but `skip`, in
    /// order, without the `blocked` tiles.
    #[func]
    fn room_tiles(
        rooms: Array<Rect2i>,
        skip: Rect2i,
        tiles: PackedByteArray,
        on: i32,
        blocked: VarArray,
        width: i32,
    ) -> PackedInt32Array {
        let t = tiles.as_slice();
        let b = Board::of(t.len(), width);
        let mut free: Vec<bool> = t.iter().map(|&k| k as i32 == on).collect();
        for p in blocked.iter_shared() {
            let p: Vector2i = p.to();
            if b.inside(p.x, p.y) {
                free[b.index(p.x, p.y)] = false;
            }
        }
        let mut out = Vec::new();
        for r in rooms.iter_shared() {
            if r == skip {
                continue;
            }
            for y in r.position.y..r.end().y {
                for x in r.position.x..r.end().x {
                    if free[b.index(x, y)] {
                        out.push(y * width + x);
                    }
                }
            }
        }
        PackedInt32Array::from(out.as_slice())
    }

    /// FloorGen._random_spot: tile numbers of the `free` tiles in `rooms`, at least `least`
    /// steps by `dist` and more than `clear` tiles from `start`; within `spread` of `near`
    /// and in its room when `near` is given (its x is 0 or more).
    #[func]
    #[allow(clippy::too_many_arguments)]
    fn spots(
        rooms: Array<Rect2i>,
        free: PackedByteArray,
        dist: PackedInt32Array,
        least: i32,
        start: Vector2i,
        clear: i32,
        near: Vector2i,
        spread: i32,
        width: i32,
    ) -> PackedInt32Array {
        let (free, dist) = (free.as_slice(), dist.as_slice());
        let b = Board::of(free.len(), width);
        let cheb = |x: i32, y: i32, p: Vector2i| (x - p.x).abs().max((y - p.y).abs());
        let mut out = Vec::new();
        for r in rooms.iter_shared() {
            if near.x >= 0 && !has(r, near.x, near.y) {
                continue;
            }
            for y in r.position.y..r.end().y {
                for x in r.position.x..r.end().x {
                    let i = b.index(x, y);
                    if free[i] != 0
                        && dist[i] >= least
                        && (near.x < 0 || cheb(x, y, near) <= spread)
                        && cheb(x, y, start) > clear
                    {
                        out.push(i as i32);
                    }
                }
            }
        }
        PackedInt32Array::from(out.as_slice())
    }

    /// World.sense: what Miho at `me` sees and makes out in the dark, of the tiles in
    /// `view` (her own field). `reach` is how far she sees in the dark. `asleep` and `blind`
    /// are her states, `fox` whether a blind creature feels the tiles next to it. `opaque`,
    /// `hides` and `lit` are World.opaque, World.hides and World.lit for every tile. `sight`
    /// is World.VIEW, `dim` is World.DIM. [seen, dim, known], `known` added to.
    #[func]
    #[allow(clippy::too_many_arguments)]
    fn sense(
        me: Vector2i,
        reach: i32,
        asleep: bool,
        blind: bool,
        fox: bool,
        view: PackedByteArray,
        opaque: PackedByteArray,
        hides: PackedByteArray,
        lit: PackedByteArray,
        mut known: PackedByteArray,
        sight: i32,
        dim: i32,
        width: i32,
    ) -> VarArray {
        let (view, opaque, hides, lit) = (
            view.as_slice(),
            opaque.as_slice(),
            hides.as_slice(),
            lit.as_slice(),
        );
        let b = Board::of(view.len(), width);
        let mut seen_out = vec![0u8; view.len()];
        let mut dim_out = vec![0u8; view.len()];
        let know = known.as_mut_slice();
        let clear = b.inside(me.x, me.y) && opaque[b.index(me.x, me.y)] == 0;
        for (i, _) in view.iter().enumerate().filter(|&(_, &v)| v != 0) {
            let (x, y) = b.at(i);
            let near = (x - me.x).abs().max((y - me.y).abs());
            let reaches = if asleep {
                false
            } else if blind {
                fox && near <= 1
            } else {
                (hides[i] == 0 || near <= 1) && (near <= reach || lit[i] == 1)
            };
            if reaches
                && ((clear && opaque[i] == 0)
                    || blind
                    || sees(Vector2i::new(x, y), me, sight, opaque, b))
            {
                seen_out[i] = 1;
                know[i] = 1;
            } else if !blind && (near <= dim || (hides[i] == 1 && lit[i] == 1)) {
                dim_out[i] = 1;
                know[i] = 1;
            }
        }
        let mut out = VarArray::new();
        out.push(&PackedByteArray::from(seen_out.as_slice()).to_variant());
        out.push(&PackedByteArray::from(dim_out.as_slice()).to_variant());
        out.push(&known.to_variant());
        out
    }

    /// 1 for every tile of `light` whose brightest channel (Light.level) reaches `least`.
    #[func]
    fn lit(light: PackedVector3Array, least: f64) -> PackedByteArray {
        let out: Vec<u8> = light
            .as_slice()
            .iter()
            .map(|c| ((c.x as f64).max(c.y as f64).max(c.z as f64).max(0.0) >= least) as u8)
            .collect();
        PackedByteArray::from(out.as_slice())
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

    /// Gas.spread: one round of gas over `amount`, `kind` and `heat` (a byte
    /// per tile) where `hold` is not 0, thinned by `decay[kind]` percent and
    /// cooled into the kind `cools[kind]` unless that is 255; [tile, amount,
    /// kind, heat] quadruplets of the tiles with gas left.
    #[func]
    #[allow(clippy::too_many_arguments)]
    fn gas(
        amount: PackedByteArray,
        kind: PackedByteArray,
        heat: PackedByteArray,
        hold: PackedByteArray,
        decay: PackedByteArray,
        cools: PackedByteArray,
        seed: i64,
        width: i32,
    ) -> PackedInt32Array {
        let amount = amount.as_slice();
        let b = Board::of(amount.len(), width);
        PackedInt32Array::from(
            gas(
                amount,
                kind.as_slice(),
                heat.as_slice(),
                hold.as_slice(),
                decay.as_slice(),
                cools.as_slice(),
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
        let mut lit = PackedVector3Array::new();
        lit.resize(opaque.len());
        let out = lit.as_mut_slice();
        let (at_key, radius_key, color_key) = (
            StringName::from("at").to_variant(),
            StringName::from("radius").to_variant(),
            StringName::from("color").to_variant(),
        );
        let mut seen = vec![false; opaque.len()];
        let mut reached = Vec::new();
        for src in sources.iter_shared() {
            let at = src
                .get_or_nil(&at_key)
                .try_to::<Vector2i>()
                .unwrap_or(Vector2i::new(-1, -1));
            let radius = src.get_or_nil(&radius_key).try_to::<i32>().unwrap_or(0);
            let color = src
                .get_or_nil(&color_key)
                .try_to::<Vector3>()
                .unwrap_or(Vector3::ZERO);
            cast(at, radius, opaque, b, |i| {
                if !seen[i] {
                    seen[i] = true;
                    reached.push(i);
                }
            });
            for i in reached.drain(..) {
                seen[i] = false;
                let s = strength(i, at, radius, b);
                if s > 0.0 {
                    out[i] += color * s;
                }
            }
        }
        lit
    }

    /// InfoBox._fit: lines of `widths` in the fewest columns at the largest scale down to
    /// `least` that fit `room`; a column does not end before an `indented` line. Each
    /// scale is `shrink` less than the last, columns stand `gap` apart, and a block of
    /// `extra` cells may stand after the last column. Empty when nothing fits, else [scale,
    /// cells x, cells y, x of the block], then [x, first line, end line] of each column.
    #[func]
    fn fit(
        widths: PackedFloat64Array,
        indented: PackedByteArray,
        room: Vector2,
        least: f64,
        shrink: f64,
        gap: f64,
        extra: Vector2,
    ) -> PackedFloat64Array {
        let (widths, indented) = (widths.as_slice(), indented.as_slice());
        let count = widths.len();
        let mut out: Vec<f64> = Vec::new();
        for k in 0..((1.0 - least) / shrink).ceil() as i64 + 1 {
            let scale = 1.0 - k as f64 * shrink;
            for columns in 1..=count {
                let height = (count as f64 / columns as f64).ceil() as usize;
                let mut x = 0.5;
                let mut first = 0;
                out.clear();
                out.extend([scale, 0.0, 0.0, 0.0]);
                while first < count {
                    let mut end = (first + height).min(count);
                    while end < count && end > first + 1 && indented[end] != 0 {
                        end -= 1;
                    }
                    out.extend([x, first as f64, end as f64]);
                    x += widths[first..end].iter().copied().fold(f64::MIN, f64::max) + gap;
                    first = end;
                }
                // The cells are a Vector2: GDScript compares them in single precision.
                let (cx, cy) = if extra != Vector2::ZERO {
                    (
                        (x + extra.x as f64 + 0.5) as f32,
                        (height as f64).max(extra.y as f64 + 1.0) as f32,
                    )
                } else {
                    ((x - gap + 0.5) as f32, height as f32)
                };
                if cx as f64 * scale <= room.x as f64 && cy as f64 * scale <= room.y as f64 {
                    (out[1], out[2], out[3]) = (cx as f64, cy as f64, x);
                    return PackedFloat64Array::from(out.as_slice());
                }
            }
        }
        PackedFloat64Array::new()
    }

    /// Scattered.join: bridges between `blocks`, first where no walk joins the two ends yet,
    /// then where the walk round is at least `apart`; every straight way between two of them,
    /// shuffled, is one try on each pass. `walk` is Tiles.walk, `secrets` World.secrets and
    /// `kinds` the tile kinds wall, floor, sky and bridge. [tiles, 7 ints for each bridge in
    /// the order it was laid: a, b, dir (x, y each), 1 when it was laid on the second pass].
    #[func]
    #[allow(clippy::too_many_arguments)]
    fn join(
        blocks: Array<Rect2i>,
        mut tiles: PackedByteArray,
        walk_table: PackedByteArray,
        secrets: VarArray,
        mut rng: Gd<RandomNumberGenerator>,
        kinds: PackedByteArray,
        apart: i32,
        width: i32,
    ) -> VarArray {
        let [wall, floor, sky, bridge] = kinds.as_slice()[..4] else {
            panic!("join: kinds are wall, floor, sky, bridge")
        };
        let walkable = walk_table.as_slice();
        let t = tiles.as_mut_slice();
        let b = Board::of(t.len(), width);
        let hidden = marks(&secrets, b, t.len());
        let blocks: Vec<Rect2i> = blocks.iter_shared().collect();
        // [a, b, dir] of each span, with the tiles just inside the walls it goes through.
        let mut spans: Vec<[(i32, i32); 3]> = Vec::new();
        for p in &blocks {
            for q in &blocks {
                if p.end().x <= q.position.x {
                    let from = p.position.y.max(q.position.y) + 1;
                    for y in from..p.end().y.min(q.end().y) - 1 {
                        spans.push([(p.end().x - 2, y), (q.position.x + 1, y), (1, 0)]);
                    }
                }
                if p.end().y <= q.position.y {
                    let from = p.position.x.max(q.position.x) + 1;
                    for x in from..p.end().x.min(q.end().x) - 1 {
                        spans.push([(x, p.end().y - 2), (x, q.position.y + 1), (0, 1)]);
                    }
                }
            }
        }
        for i in (1..spans.len()).rev() {
            let j = rng.randi_range(0, i as i32) as usize;
            spans.swap(i, j);
        }
        let tile = |t: &[u8], x: i32, y: i32| {
            if b.inside(x, y) {
                t[b.index(x, y)]
            } else {
                wall
            }
        };
        // FloorGen._walled, the sides of (x, y) running across (dx, dy).
        let walled = |t: &[u8], x: i32, y: i32, dx: i32, dy: i32| {
            let side = |px: i32, py: i32| {
                tile(t, px, py) == wall && !(b.inside(px, py) && hidden[b.index(px, py)])
            };
            tile(t, x, y) == wall && side(x + dy, y + dx) && side(x - dy, y - dx)
        };
        let walk_rows = |t: &[u8]| {
            let mut rows = [0u64; MOST_ROWS];
            for (row, line) in rows.iter_mut().zip(t.chunks_exact(b.w as usize)) {
                for (x, &k) in line.iter().enumerate() {
                    let open = walkable.get(k as usize).copied().unwrap_or(0) != 0;
                    *row |= (open as u64) << x;
                }
            }
            rows
        };
        let mut rows = walk_rows(t);
        let mut laid: Vec<i32> = Vec::new();
        for far in [false, true] {
            for &[(ax, ay), (bx, by), (dx, dy)] in &spans {
                let clear = tile(t, ax, ay) == floor
                    && tile(t, bx, by) == floor
                    && walled(t, ax + dx, ay + dy, dx, dy)
                    && walled(t, bx - dx, by - dy, dx, dy)
                    && {
                        let (mut x, mut y) = (ax + dx * 2, ay + dy * 2);
                        let mut open = true;
                        while (x, y) != (bx - dx, by - dy) {
                            if tile(t, x, y) != sky
                                || tile(t, x + dy, y + dx) != sky
                                || tile(t, x - dy, y - dx) != sky
                            {
                                open = false;
                                break;
                            }
                            (x, y) = (x + dx, y + dy);
                        }
                        open
                    };
                if !clear {
                    continue;
                }
                let dist = walk(&rows, b, (ax, ay), (bx, by));
                if if far { dist >= apart } else { dist < 0 } {
                    t[b.index(ax + dx, ay + dy)] = floor;
                    t[b.index(bx - dx, by - dy)] = floor;
                    let (mut x, mut y) = (ax + dx * 2, ay + dy * 2);
                    while (x, y) != (bx - dx, by - dy) {
                        t[b.index(x, y)] = bridge;
                        (x, y) = (x + dx, y + dy);
                    }
                    rows = walk_rows(t);
                    laid.extend([ax, ay, bx, by, dx, dy, far as i32]);
                }
            }
        }
        let mut out = VarArray::new();
        out.push(&tiles.to_variant());
        out.push(&PackedInt32Array::from(laid.as_slice()).to_variant());
        out
    }

    /// BrokenFloor._free: tile numbers of the `floor` and `wall` tiles inside `hall`, row by
    /// row, off the middle of every room and clear of every walkable tile of `hall` outside
    /// the rooms.
    #[func]
    #[allow(clippy::too_many_arguments)]
    fn tearable(
        tiles: PackedByteArray,
        walk_table: PackedByteArray,
        rooms: Array<Rect2i>,
        hall: Rect2i,
        floor: i32,
        wall: i32,
        width: i32,
    ) -> PackedInt32Array {
        let (t, walkable) = (tiles.as_slice(), walk_table.as_slice());
        let b = Board::of(t.len(), width);
        let mut roomy = vec![false; t.len()];
        for r in rooms.iter_shared() {
            for y in r.position.y..r.end().y {
                for x in r.position.x..r.end().x {
                    roomy[b.index(x, y)] = true;
                }
            }
        }
        let mut free = vec![false; t.len()];
        for y in hall.position.y + 1..hall.end().y - 1 {
            for x in hall.position.x + 1..hall.end().x - 1 {
                let i = b.index(x, y);
                free[i] = i32::from(t[i]) == floor || i32::from(t[i]) == wall;
            }
        }
        let mut clear = |x: i32, y: i32| {
            if b.inside(x, y) {
                free[b.index(x, y)] = false;
            }
            for (dx, dy) in DIRS {
                if b.inside(x + dx, y + dy) {
                    free[b.index(x + dx, y + dy)] = false;
                }
            }
        };
        for y in hall.position.y..hall.end().y {
            for x in hall.position.x..hall.end().x {
                let i = b.index(x, y);
                if walkable[usize::from(t[i])] == 1 && !roomy[i] {
                    clear(x, y);
                }
            }
        }
        for r in rooms.iter_shared() {
            clear(r.position.x + r.size.x / 2, r.position.y + r.size.y / 2);
        }
        let out: Vec<i32> = (0..t.len())
            .filter(|&i| free[i])
            .map(|i| i as i32)
            .collect();
        PackedInt32Array::from(out.as_slice())
    }

    /// The end of BrokenFloor.tear: each `wall` of `hall` with only `wall` and `sky` beside
    /// it turns to `sky`.
    #[func]
    fn fallen(
        mut tiles: PackedByteArray,
        hall: Rect2i,
        wall: i32,
        sky: i32,
        width: i32,
    ) -> PackedByteArray {
        let t = tiles.as_mut_slice();
        let b = Board::of(t.len(), width);
        for y in hall.position.y..hall.end().y {
            for x in hall.position.x..hall.end().x {
                let stands = DIRS.iter().any(|(dx, dy)| {
                    b.inside(x + dx, y + dy) && {
                        let near = i32::from(t[b.index(x + dx, y + dy)]);
                        near != wall && near != sky
                    }
                });
                let i = b.index(x, y);
                if i32::from(t[i]) == wall && !stands {
                    t[i] = sky as u8;
                }
            }
        }
        tiles
    }

    /// PondGarden._noise: tile numbers of the solid tiles of cellular noise over `area`, row
    /// by row, each tile drawn from `rng` at `chance`.
    #[func]
    fn noise(
        area: Rect2i,
        chance: f64,
        passes: i32,
        mut rng: Gd<RandomNumberGenerator>,
        width: i32,
    ) -> PackedInt32Array {
        let (w, h) = (area.size.x, area.size.y);
        let at = |x: i32, y: i32| (y * w + x) as usize;
        let mut solid: Vec<bool> = (0..w * h)
            .map(|_| f64::from(rng.randf()) < chance)
            .collect();
        for _ in 0..passes {
            let mut next = vec![false; solid.len()];
            for y in 0..h {
                for x in 0..w {
                    let near = DIRS
                        .iter()
                        .filter(|(dx, dy)| {
                            let (nx, ny) = (x + dx, y + dy);
                            nx >= 0 && ny >= 0 && nx < w && ny < h && solid[at(nx, ny)]
                        })
                        .count();
                    next[at(x, y)] = near >= 5 || (near == 4 && solid[at(x, y)]);
                }
            }
            solid = next;
        }
        let mut out = Vec::new();
        for y in 0..h {
            for x in 0..w {
                if solid[at(x, y)] {
                    out.push((area.position.y + y) * width + area.position.x + x);
                }
            }
        }
        PackedInt32Array::from(out.as_slice())
    }

    /// The straight rows Vault._row may choose from, each `count` tile numbers in a row: on
    /// `floor` tiles of `hall`, not its middle, 2 to `near` tiles from `wall`.
    #[func]
    #[allow(clippy::too_many_arguments)]
    fn lantern_rows(
        tiles: PackedByteArray,
        hall: Rect2i,
        wall: Vector2i,
        floor: i32,
        near: i32,
        count: i32,
        gaps: PackedInt32Array,
        sides: Array<Vector2i>,
        width: i32,
    ) -> PackedInt32Array {
        let t = tiles.as_slice();
        let b = Board::of(t.len(), width);
        let (mid_x, mid_y) = (
            hall.position.x + hall.size.x / 2,
            hall.position.y + hall.size.y / 2,
        );
        let fits = |x: i32, y: i32| {
            let from_wall = (x - wall.x).abs().max((y - wall.y).abs());
            has(hall, x, y)
                && (x, y) != (mid_x, mid_y)
                && i32::from(t[b.index(x, y)]) == floor
                && (2..=near).contains(&from_wall)
        };
        let sides: Vec<Vector2i> = sides.iter_shared().collect();
        let mut out = Vec::new();
        for y in hall.position.y..hall.end().y {
            for x in hall.position.x..hall.end().x {
                for d in &sides {
                    for &gap in gaps.as_slice() {
                        let along = |k: i32| (x + d.x * gap * k, y + d.y * gap * k);
                        if (0..count).all(|k| fits(along(k).0, along(k).1)) {
                            out.extend((0..count).map(|k| b.index(along(k).0, along(k).1) as i32));
                        }
                    }
                }
            }
        }
        PackedInt32Array::from(out.as_slice())
    }
}

/// A flag for each tile on the board that `tiles` (Vector2i) names.
fn marks(tiles: &VarArray, b: Board, len: usize) -> Vec<bool> {
    let mut out = vec![false; len];
    for p in tiles.iter_shared() {
        let p: Vector2i = p.to();
        if b.inside(p.x, p.y) {
            out[b.index(p.x, p.y)] = true;
        }
    }
    out
}

/// Symmetric shadowcasting (Albert Ford, 2021); see Sight.
fn sight(origin: Vector2i, radius: i32, opaque: &[u8], b: Board) -> Vec<u8> {
    let mut seen = vec![0u8; opaque.len()];
    cast(origin, radius, opaque, b, |i| seen[i] = 1);
    seen
}

/// Calls `mark` for every tile `sight` holds, some of them more than once.
fn cast(origin: Vector2i, radius: i32, opaque: &[u8], b: Board, mut mark: impl FnMut(usize)) {
    if !b.inside(origin.x, origin.y) {
        return;
    }
    mark(b.index(origin.x, origin.y));
    let mut scan = Cast {
        mark,
        opaque,
        b,
        origin,
        radius,
        deepest: radius,
    };
    for quadrant in 0..4 {
        scan.scan(quadrant, 1, -1.0, 1.0);
    }
}

/// `sight(origin, radius, opaque, b)` at `target`, which lies on the board: only the rows of
/// the quadrants that hold `target`, up to its own row, are scanned.
fn sees(origin: Vector2i, target: Vector2i, radius: i32, opaque: &[u8], b: Board) -> bool {
    if !b.inside(origin.x, origin.y) {
        return false;
    }
    if origin == target {
        return true;
    }
    let at = b.index(target.x, target.y);
    let (dx, dy) = (target.x - origin.x, target.y - origin.y);
    let mut hit = false;
    for (quadrant, depth, col) in [(0, -dy, dx), (1, dx, dy), (2, dy, dx), (3, -dx, dy)] {
        if depth >= 1 && col.abs() <= depth {
            let mut cast = Cast {
                mark: |i: usize| hit |= i == at,
                opaque,
                b,
                origin,
                radius,
                deepest: depth,
            };
            cast.scan(quadrant, 1, -1.0, 1.0);
        }
    }
    hit
}

struct Cast<'a, F: FnMut(usize)> {
    mark: F,
    opaque: &'a [u8],
    b: Board,
    origin: Vector2i,
    radius: i32,
    /// The last row worth scanning.
    deepest: i32,
}

impl<F: FnMut(usize)> Cast<'_, F> {
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
        if depth > self.radius || depth > self.deepest {
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
                (self.mark)(self.b.index(x, y));
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
/// A kind with `cools[kind]` below 255 also carries a heat: a tile takes the
/// greater of its own heat and the greatest heat of a neighbour of that kind
/// less 1, and with none left the gas that remains is of kind `cools[kind]`.
/// Returns [tile, amount, kind, heat] for every tile left with gas, in tile
/// order; the heat is 0 for a gas that does not cool.
#[allow(clippy::too_many_arguments)]
fn gas(
    amount: &[u8],
    kind: &[u8],
    heat: &[u8],
    hold: &[u8],
    decay: &[u8],
    cools: &[u8],
    seed: u64,
    b: Board,
) -> Vec<i32> {
    let mut rng = Rng(seed);
    let holds =
        |x: i32, y: i32| x > 0 && y > 0 && x < b.w - 1 && y < b.h - 1 && hold[b.index(x, y)] != 0;
    let mut spread = vec![0u8; amount.len()];
    let mut strongest = vec![0u8; amount.len()];
    let mut warmth = vec![0i32; amount.len()];
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
                if cools.get(k as usize).is_some_and(|&c| c != 255) {
                    let of_k = |j: usize| {
                        if amount[j] > 0 && kind[j] == k {
                            heat[j] as i32
                        } else {
                            0
                        }
                    };
                    let mut h = of_k(i);
                    for (dx, dy) in DIRS {
                        if holds(x + dx, y + dy) {
                            h = h.max(of_k(b.index(x + dx, y + dy)) - 1);
                        }
                    }
                    warmth[i] = h;
                }
            }
        }
    }
    let mut out = Vec::new();
    for (i, &a) in spread.iter().enumerate() {
        if a == 0 {
            continue;
        }
        let k = strongest[i] as usize;
        let chance = decay.get(k).copied().unwrap_or(0) as u64;
        let left = a - (chance > 0 && rng.below(100) < chance) as u8;
        if left > 0 {
            let cools_to = cools.get(k).copied().filter(|&c| c != 255);
            match cools_to {
                Some(c) if warmth[i] <= 0 => out.extend([i as i32, left as i32, c as i32, 0]),
                Some(_) => out.extend([i as i32, left as i32, k as i32, warmth[i]]),
                None => out.extend([i as i32, left as i32, k as i32, 0]),
            }
        }
    }
    out
}

/// Brogue fade: 1 - (1 - FADE) * distance / radius, in the GDScript precision
/// (the distance is a Vector2 length in f32, the rest in f64, stored as f32).
fn spread(at: Vector2i, radius: i32, opaque: &[u8], b: Board) -> Vec<f32> {
    let seen = sight(at, radius, opaque, b);
    seen.iter()
        .enumerate()
        .map(|(i, &s)| {
            if s == 1 {
                strength(i, at, radius, b)
            } else {
                0.0
            }
        })
        .collect()
}

/// What a source at `at` gives tile `i`, which it reaches.
fn strength(i: usize, at: Vector2i, radius: i32, b: Board) -> f32 {
    let r = f64::max(1.0, radius as f64);
    let x = (i as i32 % b.w - at.x) as f32;
    let y = (i as i32 / b.w - at.y) as f32;
    let d = (x * x + y * y).sqrt() as f64;
    f64::max(0.0, 1.0 - (1.0 - FADE) * d / r) as f32
}
