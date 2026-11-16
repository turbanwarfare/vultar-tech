# vendor

Fusion is copied here instead of being installed through Wally, because it has been patched. The project files map it into `Packages`, so it is still required as `Packages.Fusion`. Don't add Fusion to `wally.toml`, or there will be two copies of it.

Source: `elttob/fusion@0.3.0` from the Wally index (https://github.com/dphfox/Fusion), MIT license (`Fusion.LICENSE`).

Patch: in `Animation/Spring.luau`, springs go to sleep once they settle. In 0.3.0 every spring recalculates every frame, even when it isn't moving or its UI is hidden. The patched spring depends on its goal, so changing the goal wakes it up, and it stops its stopwatch once the motion drops below `EPSILON`.
